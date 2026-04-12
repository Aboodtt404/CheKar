import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../../models/obd_result.dart';

/// Transport mode for ELM327 connection.
enum ObdTransport { wifi, bluetooth }

/// On-device OBD-II scanner via ELM327 (WiFi TCP or Bluetooth SPP).
///
/// The ELM327 AT command protocol is identical over both transports —
/// only the underlying connection changes.
class ObdScanner {
  static const String defaultHost = '192.168.0.10';
  static const int defaultPort = 35000;
  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration commandTimeout = Duration(seconds: 5);

  // Transport state
  ObdTransport? _transport;
  Socket? _tcpSocket;
  BluetoothConnection? _btConnection;

  final StringBuffer _buffer = StringBuffer();
  Completer<String>? _responseCompleter;

  /// Status callback for UI progress updates.
  void Function(String status)? onStatus;

  // ── Connection ──────────────────────────────────────────────────────

  /// Connect via WiFi TCP (classic ELM327 WiFi adapters).
  Future<void> connectWifi({String host = defaultHost, int port = defaultPort}) async {
    _transport = ObdTransport.wifi;
    _tcpSocket = await Socket.connect(host, port, timeout: connectTimeout);
    _tcpSocket!.listen(
      _onData,
      onError: (e) => _responseCompleter?.completeError(e),
      onDone: () => _responseCompleter?.completeError('Connection closed'),
    );
  }

  /// Connect via Bluetooth SPP (classic Bluetooth ELM327 adapters).
  Future<void> connectBluetooth(String macAddress) async {
    _transport = ObdTransport.bluetooth;
    _btConnection = await BluetoothConnection.toAddress(macAddress)
        .timeout(connectTimeout, onTimeout: () {
      throw TimeoutException('Bluetooth connection timed out');
    });
    _btConnection!.input?.listen(
      _onData,
      onError: (e) => _responseCompleter?.completeError(e),
      onDone: () => _responseCompleter?.completeError('Connection closed'),
    );
  }

  /// Backward-compatible connect (defaults to WiFi).
  Future<void> connect({String host = defaultHost, int port = defaultPort}) async {
    await connectWifi(host: host, port: port);
  }

  void disconnect() {
    _tcpSocket?.destroy();
    _tcpSocket = null;
    _btConnection?.finish();
    _btConnection = null;
    _transport = null;
  }

  bool get isConnected => _tcpSocket != null || (_btConnection?.isConnected ?? false);

  // ── Data handler (shared for both transports) ─────────────────────

  void _onData(dynamic data) {
    final String chunk;
    if (data is Uint8List) {
      chunk = utf8.decode(data, allowMalformed: true);
    } else {
      chunk = data.toString();
    }
    _buffer.write(chunk);
    // ELM327 signals end of response with '>'
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

    final bytes = utf8.encode('$command\r');
    if (_transport == ObdTransport.bluetooth) {
      _btConnection!.output.add(Uint8List.fromList(bytes));
      await _btConnection!.output.allSent;
    } else {
      _tcpSocket!.add(bytes);
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

    // Reset
    final reset = await _send('ATZ');
    if (!reset.contains('ELM') && !reset.contains('OK')) return false;

    // Echo off
    await _send('ATE0');
    // Headers on (needed for multi-ECU responses)
    await _send('ATH1');
    // Linefeeds off
    await _send('ATL0');
    // Spaces off (compact hex)
    await _send('ATS0');
    // Auto-detect protocol
    await _send('ATSP0');

    // Trigger protocol detection
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
      vin: vin,
      milOn: milOn,
      dtcCount: dtcCount,
      storedDtcs: storedDtcs,
      pendingDtcs: pendingDtcs,
      coolantTempC: coolantTempC,
      batteryVoltage: batteryVoltage,
      distanceWithMilKm: distanceWithMilKm,
      timeSinceDtcClearedMin: timeSinceDtcClearedMin,
      warmupsSinceDtcCleared: warmupsSinceDtcCleared,
      obdCompliance: obdCompliance,
      odometerKm: odometerKm,
    );
  }

  // ── Individual PID Parsers ──────────────────────────────────────────

  Future<String?> _readVin() async {
    try {
      final raw = await _send('0902');
      if (_isError(raw)) return null;
      final hex = _extractDataBytes(raw);
      if (hex.length < 17) return null;
      final vinChars = hex.take(17).map((b) => String.fromCharCode(b)).join();
      if (RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(vinChars)) return vinChars;
      return vinChars.length == 17 ? vinChars : null;
    } catch (_) {
      return null;
    }
  }

  Future<(bool, int)> _readMilStatus() async {
    try {
      final raw = await _send('0101');
      if (_isError(raw)) return (false, 0);
      final bytes = _extractPidData(raw, '4101');
      if (bytes.isEmpty) return (false, 0);
      final a = bytes[0];
      return ((a & 0x80) != 0, a & 0x7F);
    } catch (_) {
      return (false, 0);
    }
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
    } catch (_) {
      return [];
    }
  }

  Future<double?> _readCoolantTemp() async {
    try {
      final raw = await _send('0105');
      if (_isError(raw)) return null;
      final bytes = _extractPidData(raw, '4105');
      if (bytes.isEmpty) return null;
      return (bytes[0] - 40).toDouble();
    } catch (_) {
      return null;
    }
  }

  Future<double?> _readBatteryVoltage() async {
    try {
      final raw = await _send('ATRV');
      final match = RegExp(r'(\d+\.?\d*)').firstMatch(raw);
      return match != null ? double.tryParse(match.group(1)!) : null;
    } catch (_) {
      return null;
    }
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
    } catch (_) {
      return null;
    }
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
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readObdCompliance() async {
    try {
      final val = await _readSingleByteValue('011C');
      if (val == null) return null;
      return _obdComplianceTable[val] ?? 'Unknown ($val)';
    } catch (_) {
      return null;
    }
  }

  Future<int?> _readOdometer() async {
    try {
      final raw = await _send('01A6');
      if (_isError(raw)) return null;
      final bytes = _extractPidData(raw, '41A6');
      if (bytes.length < 4) return null;
      final rawKm = (bytes[0] << 24) + (bytes[1] << 16) + (bytes[2] << 8) + bytes[3];
      return rawKm ~/ 10;
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  bool _isError(String raw) =>
      raw.contains('NO DATA') ||
      raw.contains('UNABLE') ||
      raw.contains('ERROR') ||
      raw.contains('?') ||
      raw.isEmpty;

  List<int> _extractPidData(String raw, String prefix) {
    final hex = raw.replaceAll(' ', '');
    final idx = hex.indexOf(prefix);
    if (idx < 0) return [];
    final dataHex = hex.substring(idx + prefix.length);
    return _hexToBytes(dataHex);
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
        if (start < bytes.length) {
          return bytes.sublist(start);
        }
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
    1: 'OBD-II (CARB)',
    2: 'OBD (EPA)',
    3: 'OBD + OBD-II',
    4: 'OBD-I',
    5: 'Not OBD compliant',
    6: 'EOBD',
    7: 'EOBD + OBD-II',
    8: 'EOBD + OBD',
    9: 'EOBD + OBD + OBD-II',
    13: 'JOBD',
    17: 'EOBD (II)',
    18: 'EOBD (II) + OBD-II',
  };

  // ── Bluetooth Helpers (static) ─────────────────────────────────────

  /// Get list of paired Bluetooth devices.
  static Future<List<BluetoothDevice>> getPairedDevices() async {
    return await FlutterBluetoothSerial.instance.getBondedDevices();
  }

  /// Check if Bluetooth is enabled.
  static Future<bool> isBluetoothEnabled() async {
    return await FlutterBluetoothSerial.instance.isEnabled ?? false;
  }

  /// Request to enable Bluetooth.
  static Future<bool> requestEnableBluetooth() async {
    return await FlutterBluetoothSerial.instance.requestEnable() ?? false;
  }
}
