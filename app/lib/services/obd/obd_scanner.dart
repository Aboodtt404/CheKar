import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';

import '../../models/obd_live_data.dart';
import '../../models/obd_result.dart';

/// Transport mode for ELM327 connection.
enum ObdTransport { wifi, bluetooth }

/// Standard SPP UUID for Bluetooth serial communication.
const _sppUuid = '00001101-0000-1000-8000-00805F9B34FB';

/// On-device OBD-II scanner via ELM327 (WiFi TCP or Bluetooth SPP).
class ObdScanner {
  static const String defaultHost = '192.168.0.10';
  static const int defaultPort = 35000;
  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration commandTimeout = Duration(seconds: 5);

  ObdTransport? _transport;
  Socket? _tcpSocket;
  final BluetoothClassic _bt = BluetoothClassic();
  StreamSubscription<Uint8List>? _btSubscription;
  bool _btConnected = false;

  final StringBuffer _buffer = StringBuffer();
  Completer<String>? _responseCompleter;

  void Function(String status)? onStatus;

  // ── Connection ──────────────────────────────────────────────────────

  Future<void> connectWifi({String host = defaultHost, int port = defaultPort}) async {
    _transport = ObdTransport.wifi;
    _tcpSocket = await Socket.connect(host, port, timeout: connectTimeout);
    _tcpSocket!.listen(
      _onData,
      onError: (e) => _responseCompleter?.completeError(e),
      onDone: () => _responseCompleter?.completeError('Connection closed'),
    );
  }

  Future<void> connectBluetooth(String macAddress) async {
    _transport = ObdTransport.bluetooth;
    final connected = await _bt.connect(macAddress, _sppUuid).timeout(
      connectTimeout,
      onTimeout: () => false,
    );
    if (!connected) throw Exception('Bluetooth connection failed');
    _btConnected = true;

    _btSubscription = _bt.onDeviceDataReceived().listen(
      _onData,
      onError: (e) => _responseCompleter?.completeError(e),
    );
  }

  Future<void> connect({String host = defaultHost, int port = defaultPort}) async {
    await connectWifi(host: host, port: port);
  }

  void disconnect() {
    _tcpSocket?.destroy();
    _tcpSocket = null;
    _btSubscription?.cancel();
    _btSubscription = null;
    if (_btConnected) {
      _bt.disconnect();
      _btConnected = false;
    }
    _transport = null;
  }

  bool get isConnected => _tcpSocket != null || _btConnected;

  // ── Data handler ───────────────────────────────────────────────────

  void _onData(dynamic data) {
    final String chunk;
    if (data is Uint8List) {
      chunk = utf8.decode(data, allowMalformed: true);
    } else {
      chunk = data.toString();
    }
    _buffer.write(chunk);
    if (chunk.contains('>')) {
      _responseCompleter?.complete(_buffer.toString());
      _buffer.clear();
    }
  }

  // ── Send/Receive ───────────────────────────────────────────────────

  Future<String> _send(String command) async {
    if (!isConnected) throw StateError('Not connected');
    _buffer.clear();
    _responseCompleter = Completer<String>();

    if (_transport == ObdTransport.bluetooth) {
      await _bt.write('$command\r');
    } else {
      _tcpSocket!.add(utf8.encode('$command\r'));
    }

    final response = await _responseCompleter!.future.timeout(
      commandTimeout,
      onTimeout: () => '',
    );
    return response
        .replaceAll('>', '')
        .replaceAll(command, '')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .trim();
  }

  // ── Init ────────────────────────────────────────────────────────────

  Future<bool> initialize() async {
    onStatus?.call('جاري تهيئة الاتصال...');

    final reset = await _send('ATZ');
    if (!reset.contains('ELM') && !reset.contains('OK')) return false;

    await _send('ATE0');
    await _send('ATH1');
    await _send('ATL0');
    await _send('ATS0');
    await _send('ATSP0');

    onStatus?.call('جاري كشف نوع البروتوكول...');
    final proto = await _send('0100');
    if (proto.contains('UNABLE') || proto.contains('NO DATA') || proto.contains('ERROR')) {
      return false;
    }
    return true;
  }

  // ── Full Scan ───────────────────────────────────────────────────────

  Future<ObdResult> scan() async {
    String? vin;
    bool milOn = false;
    int dtcCount = 0;
    List<String> storedDtcs = [];
    List<String> pendingDtcs = [];
    double? coolantTempC;
    double? batteryVoltage;
    int? distanceWithMilKm;
    int? timeSinceDtcClearedMin;
    int? warmupsSinceDtcCleared;
    String? obdCompliance;
    int? odometerKm;

    onStatus?.call('جاري قراءة رقم الشاسيه...');
    vin = await _readVin();

    onStatus?.call('جاري فحص لمبة المحرك...');
    final milResult = await _readMilStatus();
    milOn = milResult.$1;
    dtcCount = milResult.$2;

    onStatus?.call('جاري قراءة أكواد الأعطال...');
    storedDtcs = await _readDtcs('03');
    pendingDtcs = await _readDtcs('07');

    onStatus?.call('جاري قراءة حرارة المحرك...');
    coolantTempC = await _readCoolantTemp();

    onStatus?.call('جاري فحص البطارية...');
    batteryVoltage = await _readBatteryVoltage();

    distanceWithMilKm = await _readTwoByteValue('0121');

    onStatus?.call('جاري فحص تاريخ الأعطال...');
    timeSinceDtcClearedMin = await _readTwoByteValue('014E');
    warmupsSinceDtcCleared = await _readSingleByteValue('0130');

    obdCompliance = await _readObdCompliance();

    onStatus?.call('جاري قراءة العداد...');
    odometerKm = await _readOdometer();

    onStatus?.call('تم الفحص بنجاح');

    return ObdResult(
      vin: vin, milOn: milOn, dtcCount: dtcCount,
      storedDtcs: storedDtcs, pendingDtcs: pendingDtcs,
      coolantTempC: coolantTempC, batteryVoltage: batteryVoltage,
      distanceWithMilKm: distanceWithMilKm,
      timeSinceDtcClearedMin: timeSinceDtcClearedMin,
      warmupsSinceDtcCleared: warmupsSinceDtcCleared,
      obdCompliance: obdCompliance, odometerKm: odometerKm,
    );
  }

  // ── PID Parsers ────────────────────────────────────────────────────

  Future<String?> _readVin() async {
    try {
      final raw = await _send('0902');
      if (_isError(raw)) return null;
      final hex = _extractDataBytes(raw);
      if (hex.length < 17) return null;
      final vinChars = hex.take(17).map((b) => String.fromCharCode(b)).join();
      if (RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(vinChars)) return vinChars;
      return vinChars.length == 17 ? vinChars : null;
    } catch (_) { return null; }
  }

  Future<(bool, int)> _readMilStatus() async {
    try {
      final raw = await _send('0101');
      if (_isError(raw)) return (false, 0);
      final bytes = _extractPidData(raw, '4101');
      if (bytes.isEmpty) return (false, 0);
      final a = bytes[0];
      return ((a & 0x80) != 0, a & 0x7F);
    } catch (_) { return (false, 0); }
  }

  Future<List<String>> _readDtcs(String command) async {
    try {
      final raw = await _send(command);
      if (_isError(raw)) return [];
      final expectedPrefix = command == '03' ? '43' : '47';
      final bytes = _extractPidData(raw, expectedPrefix);
      if (bytes.isEmpty) return [];
      final dtcs = <String>[];
      for (int i = 0; i + 1 < bytes.length; i += 2) {
        final code = _decodeDtc(bytes[i], bytes[i + 1]);
        if (code != 'P0000') dtcs.add(code);
      }
      return dtcs;
    } catch (_) { return []; }
  }

  Future<double?> _readCoolantTemp() async {
    try {
      final raw = await _send('0105');
      if (_isError(raw)) return null;
      final bytes = _extractPidData(raw, '4105');
      if (bytes.isEmpty) return null;
      return (bytes[0] - 40).toDouble();
    } catch (_) { return null; }
  }

  Future<double?> _readBatteryVoltage() async {
    try {
      final raw = await _send('ATRV');
      final match = RegExp(r'(\d+\.?\d*)').firstMatch(raw);
      return match != null ? double.tryParse(match.group(1)!) : null;
    } catch (_) { return null; }
  }

  Future<int?> _readTwoByteValue(String command) async {
    try {
      final raw = await _send(command);
      if (_isError(raw)) return null;
      final pid = command.substring(0, 4);
      final expectedPrefix = '41${pid.substring(2)}';
      final bytes = _extractPidData(raw, expectedPrefix);
      if (bytes.length < 2) return null;
      return bytes[0] * 256 + bytes[1];
    } catch (_) { return null; }
  }

  Future<int?> _readSingleByteValue(String command) async {
    try {
      final raw = await _send(command);
      if (_isError(raw)) return null;
      final pid = command.substring(0, 4);
      final expectedPrefix = '41${pid.substring(2)}';
      final bytes = _extractPidData(raw, expectedPrefix);
      if (bytes.isEmpty) return null;
      return bytes[0];
    } catch (_) { return null; }
  }

  Future<String?> _readObdCompliance() async {
    try {
      final val = await _readSingleByteValue('011C');
      if (val == null) return null;
      return _obdComplianceTable[val] ?? 'Unknown ($val)';
    } catch (_) { return null; }
  }

  Future<int?> _readOdometer() async {
    try {
      final raw = await _send('01A6');
      if (_isError(raw)) return null;
      final bytes = _extractPidData(raw, '41A6');
      if (bytes.length < 4) return null;
      final rawKm = (bytes[0] << 24) + (bytes[1] << 16) + (bytes[2] << 8) + bytes[3];
      return rawKm ~/ 10;
    } catch (_) { return null; }
  }

  // ── Live Data (single poll cycle) ───────────────────────────────────

  Future<ObdLiveData> readLiveData() async {
    // RPM: PID 0C — ((A*256)+B)/4
    int? rpm;
    try {
      final raw = await _send('010C');
      if (!_isError(raw)) {
        final bytes = _extractPidData(raw, '410C');
        if (bytes.length >= 2) rpm = ((bytes[0] * 256) + bytes[1]) ~/ 4;
      }
    } catch (_) {}

    // Speed: PID 0D — A km/h
    int? speed;
    try {
      speed = await _readSingleByteValue('010D');
    } catch (_) {}

    // Coolant temp: PID 05 — A-40
    double? coolant;
    try {
      coolant = await _readCoolantTemp();
    } catch (_) {}

    // Intake air temp: PID 0F — A-40
    double? intakeTemp;
    try {
      final val = await _readSingleByteValue('010F');
      if (val != null) intakeTemp = (val - 40).toDouble();
    } catch (_) {}

    // Engine load: PID 04 — A*100/255
    int? engineLoad;
    try {
      final val = await _readSingleByteValue('0104');
      if (val != null) engineLoad = (val * 100) ~/ 255;
    } catch (_) {}

    // Throttle position: PID 11 — A*100/255
    int? throttle;
    try {
      final val = await _readSingleByteValue('0111');
      if (val != null) throttle = (val * 100) ~/ 255;
    } catch (_) {}

    // Fuel level: PID 2F — A*100/255
    int? fuelLevel;
    try {
      final val = await _readSingleByteValue('012F');
      if (val != null) fuelLevel = (val * 100) ~/ 255;
    } catch (_) {}

    // Intake manifold pressure: PID 0B — A kPa
    int? manifoldPressure;
    try {
      manifoldPressure = await _readSingleByteValue('010B');
    } catch (_) {}

    // Fuel pressure: PID 0A — A*3 kPa
    int? fuelPressure;
    try {
      final val = await _readSingleByteValue('010A');
      if (val != null) fuelPressure = val * 3;
    } catch (_) {}

    // Battery voltage: AT RV
    double? battery;
    try {
      battery = await _readBatteryVoltage();
    } catch (_) {}

    // Run time since engine start: PID 1F — (A*256+B) seconds
    int? runTime;
    try {
      runTime = await _readTwoByteValue('011F');
    } catch (_) {}

    // MAF air flow rate: PID 10 — ((A*256)+B)/100 g/s
    double? maf;
    try {
      final raw = await _send('0110');
      if (!_isError(raw)) {
        final bytes = _extractPidData(raw, '4110');
        if (bytes.length >= 2) maf = ((bytes[0] * 256) + bytes[1]) / 100.0;
      }
    } catch (_) {}

    // Timing advance: PID 0E — (A/2)-64 degrees
    int? timing;
    try {
      final val = await _readSingleByteValue('010E');
      if (val != null) timing = (val ~/ 2) - 64;
    } catch (_) {}

    // Catalyst temp bank 1 sensor 1: PID 3C — ((A*256)+B)/10 - 40
    int? catalystTemp;
    try {
      final raw = await _send('013C');
      if (!_isError(raw)) {
        final bytes = _extractPidData(raw, '413C');
        if (bytes.length >= 2) catalystTemp = (((bytes[0] * 256) + bytes[1]) ~/ 10) - 40;
      }
    } catch (_) {}

    return ObdLiveData(
      rpm: rpm,
      speedKmh: speed,
      coolantTempC: coolant,
      intakeAirTempC: intakeTemp,
      engineLoadPct: engineLoad,
      throttlePct: throttle,
      fuelLevelPct: fuelLevel,
      intakeManifoldPressureKpa: manifoldPressure,
      fuelPressureKpa: fuelPressure,
      batteryVoltage: battery,
      runTimeSec: runTime,
      mafFlowGps: maf,
      timingAdvanceDeg: timing,
      catalystTempC: catalystTemp,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  bool _isError(String raw) =>
      raw.contains('NO DATA') || raw.contains('UNABLE') ||
      raw.contains('ERROR') || raw.contains('?') || raw.isEmpty;

  List<int> _extractPidData(String raw, String prefix) {
    final hex = raw.replaceAll(' ', '');
    final idx = hex.indexOf(prefix);
    if (idx < 0) return [];
    return _hexToBytes(hex.substring(idx + prefix.length));
  }

  List<int> _extractDataBytes(String raw) {
    final parts = raw.split(' ').where((s) => s.isNotEmpty).toList();
    final bytes = <int>[];
    for (final part in parts) {
      final val = int.tryParse(part, radix: 16);
      if (val != null && val <= 0xFF) bytes.add(val);
    }
    for (int i = 0; i < bytes.length - 1; i++) {
      if (bytes[i] == 0x49 && bytes[i + 1] == 0x02) {
        final start = i + 3;
        if (start < bytes.length) return bytes.sublist(start);
      }
    }
    return bytes;
  }

  List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i + 1 < hex.length; i += 2) {
      final val = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (val != null) bytes.add(val);
    }
    return bytes;
  }

  String _decodeDtc(int byte1, int byte2) {
    const prefixes = ['P', 'C', 'B', 'U'];
    final prefix = prefixes[(byte1 >> 6) & 0x03];
    final d1 = ((byte1 >> 4) & 0x03).toString();
    final d2 = (byte1 & 0x0F).toRadixString(16).toUpperCase();
    final d34 = byte2.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '$prefix$d1$d2$d34';
  }

  static const _obdComplianceTable = {
    1: 'OBD-II (CARB)', 2: 'OBD (EPA)', 3: 'OBD + OBD-II',
    4: 'OBD-I', 5: 'Not OBD compliant', 6: 'EOBD',
    7: 'EOBD + OBD-II', 8: 'EOBD + OBD', 9: 'EOBD + OBD + OBD-II',
    13: 'JOBD', 17: 'EOBD (II)', 18: 'EOBD (II) + OBD-II',
  };

  // ── Bluetooth Helpers ──────────────────────────────────────────────

  static final BluetoothClassic _btStatic = BluetoothClassic();

  static Future<List<Device>> getPairedDevices() async {
    return await _btStatic.getPairedDevices();
  }

  static Future<bool> initPermissions() async {
    return await _btStatic.initPermissions();
  }
}
