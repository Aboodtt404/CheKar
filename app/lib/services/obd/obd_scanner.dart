import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/obd_result.dart';

/// On-device OBD-II scanner via WiFi ELM327 TCP socket.
///
/// Connects to a WiFi ELM327 adapter (typically 192.168.0.10:35000),
/// runs 11 diagnostic commands, and returns parsed results.
/// All parsing follows the public SAE J1979 / ISO 15031-5 standard.
class ObdScanner {
  static const String defaultHost = '192.168.0.10';
  static const int defaultPort = 35000;
  static const Duration connectTimeout = Duration(seconds: 5);
  static const Duration commandTimeout = Duration(seconds: 5);

  Socket? _socket;
  final StringBuffer _buffer = StringBuffer();
  Completer<String>? _responseCompleter;

  /// Status callback for UI progress updates.
  void Function(String status)? onStatus;

  // ── Connection ──────────────────────────────────────────────────────

  Future<void> connect({String host = defaultHost, int port = defaultPort}) async {
    _socket = await Socket.connect(host, port, timeout: connectTimeout);
    _socket!.listen(
      (data) {
        final chunk = utf8.decode(data, allowMalformed: true);
        _buffer.write(chunk);
        if (chunk.contains('>')) {
          _responseCompleter?.complete(_buffer.toString());
          _buffer.clear();
        }
      },
      onError: (e) => _responseCompleter?.completeError(e),
      onDone: () => _responseCompleter?.completeError('Connection closed'),
    );
  }

  void disconnect() {
    _socket?.destroy();
    _socket = null;
  }

  bool get isConnected => _socket != null;

  // ── Send/Receive ───────────────────────────────────────────────────

  Future<String> _send(String command) async {
    if (_socket == null) throw StateError('Not connected');
    _buffer.clear();
    _responseCompleter = Completer<String>();
    _socket!.add(utf8.encode('$command\r'));
    final response = await _responseCompleter!.future.timeout(
      commandTimeout,
      onTimeout: () => '',
    );
    // Clean response: strip echo, prompt, whitespace
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

    // 1. VIN
    onStatus?.call('جاري قراءة رقم الشاسيه...');
    vin = await _readVin();

    // 2. MIL status + DTC count
    onStatus?.call('جاري فحص لمبة المحرك...');
    final milResult = await _readMilStatus();
    milOn = milResult.$1;
    dtcCount = milResult.$2;

    // 3. Stored DTCs
    onStatus?.call('جاري قراءة أكواد الأعطال...');
    storedDtcs = await _readDtcs('03');

    // 4. Pending DTCs
    pendingDtcs = await _readDtcs('07');

    // 5. Coolant temp
    onStatus?.call('جاري قراءة حرارة المحرك...');
    coolantTempC = await _readCoolantTemp();

    // 6. Battery voltage
    onStatus?.call('جاري فحص البطارية...');
    batteryVoltage = await _readBatteryVoltage();

    // 7. Distance with MIL on
    distanceWithMilKm = await _readTwoByteValue('0121');

    // 8. Time since DTCs cleared
    onStatus?.call('جاري فحص تاريخ الأعطال...');
    timeSinceDtcClearedMin = await _readTwoByteValue('014E');

    // 9. Warmups since DTCs cleared
    warmupsSinceDtcCleared = await _readSingleByteValue('0130');

    // 10. OBD compliance
    obdCompliance = await _readObdCompliance();

    // 11. Odometer (2019+ vehicles only)
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

  /// VIN: Mode 09 PID 02 — multi-frame 17 ASCII characters.
  Future<String?> _readVin() async {
    try {
      final raw = await _send('0902');
      if (_isError(raw)) return null;
      // Extract hex bytes, skip headers and mode/PID bytes
      final hex = _extractDataBytes(raw);
      if (hex.length < 17) return null;
      // VIN bytes are ASCII
      final vinChars = hex.take(17).map((b) => String.fromCharCode(b)).join();
      // Validate: VIN is 17 alphanumeric chars
      if (RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(vinChars)) return vinChars;
      return vinChars.length == 17 ? vinChars : null;
    } catch (_) {
      return null;
    }
  }

  /// MIL status: Mode 01 PID 01 — byte A bit 7 = MIL, bits 0-6 = DTC count.
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

  /// DTCs: Mode 03 (stored) or 07 (pending) — 2-byte pairs.
  Future<List<String>> _readDtcs(String command) async {
    try {
      final raw = await _send(command);
      if (_isError(raw)) return [];
      final expectedPrefix = command == '03' ? '43' : '47';
      final bytes = _extractPidData(raw, expectedPrefix);
      if (bytes.isEmpty) return [];
      final dtcs = <String>[];
      // Skip count byte, then read 2-byte pairs
      for (int i = 0; i + 1 < bytes.length; i += 2) {
        final code = _decodeDtc(bytes[i], bytes[i + 1]);
        if (code != 'P0000') dtcs.add(code);
      }
      return dtcs;
    } catch (_) {
      return [];
    }
  }

  /// Coolant temp: Mode 01 PID 05 — single byte, value - 40 = °C.
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

  /// Battery voltage: AT RV — returns string like "12.3V".
  Future<double?> _readBatteryVoltage() async {
    try {
      final raw = await _send('ATRV');
      final match = RegExp(r'(\d+\.?\d*)').firstMatch(raw);
      return match != null ? double.tryParse(match.group(1)!) : null;
    } catch (_) {
      return null;
    }
  }

  /// Two-byte unsigned value: (A*256 + B).
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

  /// Single byte value.
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

  /// OBD compliance: Mode 01 PID 1C — lookup table.
  Future<String?> _readObdCompliance() async {
    try {
      final val = await _readSingleByteValue('011C');
      if (val == null) return null;
      return _obdComplianceTable[val] ?? 'Unknown ($val)';
    } catch (_) {
      return null;
    }
  }

  /// Odometer: Mode 01 PID A6 — 4 bytes, (A<<24+B<<16+C<<8+D)/10 km.
  /// Only available on 2019+ vehicles.
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

  /// Extract data bytes after a known response prefix (e.g. "4101").
  /// Handles multi-ECU responses (takes first valid one).
  List<int> _extractPidData(String raw, String prefix) {
    final hex = raw.replaceAll(' ', '');
    // Find the prefix in the hex stream
    final idx = hex.indexOf(prefix);
    if (idx < 0) return [];
    final dataHex = hex.substring(idx + prefix.length);
    return _hexToBytes(dataHex);
  }

  /// Extract all data bytes from a multi-frame response (for VIN).
  List<int> _extractDataBytes(String raw) {
    final parts = raw.split(' ').where((s) => s.isNotEmpty).toList();
    final bytes = <int>[];
    for (final part in parts) {
      final val = int.tryParse(part, radix: 16);
      if (val != null && val <= 0xFF) bytes.add(val);
    }
    // Skip mode/PID overhead for VIN (09 02 01 header bytes)
    // Find '49 02' pattern and skip
    for (int i = 0; i < bytes.length - 1; i++) {
      if (bytes[i] == 0x49 && bytes[i + 1] == 0x02) {
        // Skip 49 02 XX (3 bytes) then read data
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

  /// Decode 2 bytes into a DTC code (P0xxx, C0xxx, B0xxx, U0xxx).
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
}
