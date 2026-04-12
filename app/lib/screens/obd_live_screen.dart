import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bluetooth_classic/models/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/theme.dart';
import '../models/obd_live_data.dart';
import '../models/obd_result.dart';
import '../services/obd/obd_scanner.dart';

class ObdLiveScreen extends ConsumerStatefulWidget {
  const ObdLiveScreen({super.key});

  @override
  ConsumerState<ObdLiveScreen> createState() => _ObdLiveScreenState();
}

class _ObdLiveScreenState extends ConsumerState<ObdLiveScreen> {
  ObdScanner _scanner = ObdScanner();
  _Phase _phase = _Phase.pickConnection;
  ObdTransport? _transport;
  Device? _selectedDevice;
  List<Device> _pairedDevices = [];
  String _statusText = '';
  String? _error;

  // Diagnostic data (one-shot)
  ObdResult? _diagResult;

  // Live data
  ObdLiveData? _liveData;
  bool _liveRunning = false;
  Timer? _liveTimer;

  @override
  void dispose() {
    _liveTimer?.cancel();
    _scanner.disconnect();
    super.dispose();
  }

  // ── Permissions + Device Selection ────────────────────────────────

  Future<void> _pickBluetooth() async {
    setState(() {
      _transport = ObdTransport.bluetooth;
      _phase = _Phase.pickDevice;
      _error = null;
    });

    final permissions = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    if (!permissions.values.every((s) => s.isGranted || s.isLimited)) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _error = 'لازم تدي صلاحية البلوتوث والموقع.';
        });
      }
      return;
    }

    try {
      await ObdScanner.initPermissions();
      final devices = await ObdScanner.getPairedDevices();
      if (mounted) setState(() => _pairedDevices = devices);
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _error = 'مش قادر يجيب الأجهزة. تأكد إن البلوتوث مفتوح.';
        });
      }
    }
  }

  void _pickWifi() {
    setState(() {
      _transport = ObdTransport.wifi;
      _phase = _Phase.ready;
    });
  }

  // ── Connect + Diagnose + Go Live ──────────────────────────────────

  Future<void> _startScan() async {
    _scanner.disconnect();
    _scanner = ObdScanner();

    setState(() {
      _phase = _Phase.connecting;
      _statusText = 'جاري الاتصال بجهاز OBD...';
      _error = null;
    });

    _scanner.onStatus = (s) {
      if (mounted) setState(() => _statusText = s);
    };

    try {
      if (_transport == ObdTransport.bluetooth) {
        await _scanner.connectBluetooth(_selectedDevice!.address);
      } else {
        await _scanner.connectWifi();
      }

      setState(() {
        _phase = _Phase.diagnosing;
        _statusText = 'جاري الفحص التشخيصي...';
      });

      final ok = await _scanner.initialize();
      if (!ok) {
        setState(() {
          _phase = _Phase.error;
          _error = 'مش قادر يتصل بالعربية. تأكد إن جهاز OBD متوصل والمحرك شغال.';
        });
        return;
      }

      // One-shot diagnostics
      final diag = await _scanner.scan();
      setState(() => _diagResult = diag);

      // Switch to live
      _startLivePolling();
    } catch (e) {
      setState(() {
        _phase = _Phase.error;
        if (e is SocketException) {
          _error = 'مش قادر يتصل بجهاز OBD.\nتأكد إنك متصل بشبكة WiFi الخاصة بجهاز OBD.';
        } else if (e is TimeoutException) {
          _error = 'الاتصال أخد وقت طويل. تأكد إن الجهاز شغال وقريب.';
        } else {
          _error = 'حصل خطأ: $e';
        }
      });
    }
  }

  void _startLivePolling() {
    setState(() {
      _phase = _Phase.live;
      _liveRunning = true;
    });
    _pollOnce();
    _liveTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_liveRunning && _scanner.isConnected) _pollOnce();
    });
  }

  Future<void> _pollOnce() async {
    try {
      final data = await _scanner.readLiveData();
      if (mounted) setState(() => _liveData = data);
    } catch (_) {}
  }

  void _stopLive() {
    _liveTimer?.cancel();
    _liveRunning = false;
    _scanner.disconnect();
    setState(() => _phase = _Phase.summary);
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: CheKarColors.darkDeep,
        body: SafeArea(
          child: switch (_phase) {
            _Phase.pickConnection => _buildConnectionPicker(),
            _Phase.pickDevice => _buildDevicePicker(),
            _Phase.ready => _buildReady(),
            _Phase.connecting || _Phase.diagnosing => _buildConnecting(),
            _Phase.live => _buildLiveDashboard(),
            _Phase.summary => _buildSummary(),
            _Phase.error => _buildError(),
          },
        ),
      ),
    );
  }

  // ── Connection Picker ─────────────────────────────────────────────

  Widget _buildConnectionPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _header(),
          const Spacer(),
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: CheKarColors.orange.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Iconsax.cpu, color: CheKarColors.orange, size: 44),
          ),
          const SizedBox(height: 32),
          Text('فحص OBD مباشر', style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          Text('بيانات العربية لحظة بلحظة', style: GoogleFonts.cairo(fontSize: 14, color: Colors.white38)),
          const SizedBox(height: 36),
          _connectionCard(icon: Iconsax.bluetooth, label: 'بلوتوث', sub: 'ARC-101 وأجهزة مشابهة', onTap: _pickBluetooth),
          const SizedBox(height: 12),
          _connectionCard(icon: Iconsax.wifi, label: 'واي فاي', sub: 'أجهزة WiFi ELM327', onTap: _pickWifi),
          const Spacer(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Device Picker ─────────────────────────────────────────────────

  Widget _buildDevicePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _header(title: 'اختار الجهاز', onBack: () => setState(() => _phase = _Phase.pickConnection)),
          if (_pairedDevices.isEmpty) ...[
            const Spacer(),
            Icon(Iconsax.bluetooth, size: 48, color: Colors.white.withOpacity(0.15)),
            const SizedBox(height: 20),
            Text('مفيش أجهزة مقترنة', style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            Text('روح إعدادات البلوتوث واقرن جهاز OBD الأول', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 13, color: Colors.white38)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _pickBluetooth, style: ElevatedButton.styleFrom(backgroundColor: CheKarColors.darkElevated), child: Text('تحديث', style: GoogleFonts.cairo(fontWeight: FontWeight.w700))),
            const Spacer(),
          ] else ...[
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: _pairedDevices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = _pairedDevices[i];
                  final isObd = (d.name ?? '').toLowerCase().contains(RegExp(r'obd|elm|arc').pattern);
                  return GestureDetector(
                    onTap: () => setState(() { _selectedDevice = d; _phase = _Phase.ready; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isObd ? CheKarColors.orange.withOpacity(0.08) : CheKarColors.darkCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isObd ? CheKarColors.orange.withOpacity(0.3) : CheKarColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Icon(isObd ? Iconsax.cpu : Iconsax.bluetooth, size: 20, color: isObd ? CheKarColors.orange : Colors.white38),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.name ?? 'جهاز غير معروف', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700, color: isObd ? CheKarColors.orange : Colors.white)),
                              Text(d.address, style: GoogleFonts.saira(fontSize: 12, color: Colors.white30)),
                            ],
                          )),
                          const Icon(Iconsax.arrow_left_2, color: Colors.white24, size: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Ready to Scan ─────────────────────────────────────────────────

  Widget _buildReady() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _header(onBack: () => setState(() => _phase = _Phase.pickConnection)),
          const Spacer(),
          Icon(_transport == ObdTransport.bluetooth ? Iconsax.bluetooth : Iconsax.wifi, color: CheKarColors.orange, size: 48),
          const SizedBox(height: 24),
          Text('جاهز', style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          if (_selectedDevice != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: CheKarColors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(_selectedDevice!.name ?? _selectedDevice!.address, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: CheKarColors.orange)),
            ),
          ],
          const SizedBox(height: 32),
          _ctaButton('ابدأ الفحص المباشر', _startScan),
          const Spacer(),
        ],
      ),
    );
  }

  // ── Connecting ────────────────────────────────────────────────────

  Widget _buildConnecting() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 64, height: 64, child: CircularProgressIndicator(color: CheKarColors.orange, strokeWidth: 3)),
          const SizedBox(height: 32),
          Text(_statusText, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }

  // ── Live Dashboard ────────────────────────────────────────────────

  Widget _buildLiveDashboard() {
    final d = _liveData;
    final diag = _diagResult;

    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: CheKarColors.scoreGood.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: CheKarColors.scoreGood, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('مباشر', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: CheKarColors.scoreGood)),
                  ],
                ),
              ),
              const Spacer(),
              Text('فحص OBD', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const Spacer(),
              GestureDetector(
                onTap: _stopLive,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: CheKarColors.scoreBad.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text('إيقاف', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700, color: CheKarColors.scoreBad)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Dashboard
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Big gauges: RPM + Speed
                Row(
                  children: [
                    Expanded(child: _bigGauge('RPM', '${d?.rpm ?? '--'}', Iconsax.flash_1, d?.rpm != null && d!.rpm! > 5000 ? CheKarColors.scoreBad : CheKarColors.orange)),
                    const SizedBox(width: 12),
                    Expanded(child: _bigGauge('السرعة', '${d?.speedKmh ?? '--'}', Iconsax.speedometer, CheKarColors.orange, unit: 'كم/س')),
                  ],
                ),
                const SizedBox(height: 12),

                // Engine Health
                _sectionLabel('صحة المحرك'),
                _metricsGrid([
                  _metric('حرارة المحرك', d?.coolantTempC != null ? '${d!.coolantTempC!.toInt()}°C' : '--', Iconsax.flash_1, _tempColor(d?.coolantTempC)),
                  _metric('حمل المحرك', d?.engineLoadPct != null ? '${d!.engineLoadPct}%' : '--', Iconsax.chart, _loadColor(d?.engineLoadPct)),
                  _metric('دعسة البنزين', d?.throttlePct != null ? '${d!.throttlePct}%' : '--', Iconsax.arrow_up_3, null),
                  _metric('حرارة الهوا', d?.intakeAirTempC != null ? '${d!.intakeAirTempC!.toInt()}°C' : '--', Iconsax.wind, null),
                ]),
                const SizedBox(height: 12),

                // Fuel System (fraud indicators)
                _sectionLabel('نظام الوقود'),
                _metricsGrid([
                  _metricWithHint(
                    'STFT', d?.shortTermFuelTrimB1 != null ? '${d!.shortTermFuelTrimB1!.toStringAsFixed(1)}%' : '--',
                    Iconsax.chart, _fuelTrimColor(d?.shortTermFuelTrimB1),
                    _fuelTrimHint(d?.shortTermFuelTrimB1, 'قصير'),
                  ),
                  _metricWithHint(
                    'LTFT', d?.longTermFuelTrimB1 != null ? '${d!.longTermFuelTrimB1!.toStringAsFixed(1)}%' : '--',
                    Iconsax.chart, _fuelTrimColor(d?.longTermFuelTrimB1),
                    _fuelTrimHint(d?.longTermFuelTrimB1, 'طويل'),
                  ),
                  _metricWithHint(
                    'O2 سنسور', d?.o2VoltageB1S1 != null ? '${d!.o2VoltageB1S1!.toStringAsFixed(2)}V' : '--',
                    Iconsax.flash_1, null,
                    d?.o2VoltageB1S1 != null ? (d!.o2VoltageB1S1! < 0.1 || d!.o2VoltageB1S1! > 0.9 ? 'ثابت — مشكلة' : 'طبيعي') : null,
                  ),
                  _metric('مستوى البنزين', d?.fuelLevelPct != null ? '${d!.fuelLevelPct}%' : '--', Iconsax.gas_station, d?.fuelLevelPct != null && d!.fuelLevelPct! < 15 ? CheKarColors.scoreBad : null),
                ]),
                const SizedBox(height: 12),

                // Electrical
                _sectionLabel('الكهرباء'),
                _metricsGrid([
                  _metricWithHint(
                    'البطارية', d?.batteryVoltage != null ? '${d!.batteryVoltage!.toStringAsFixed(1)}V' : '--',
                    Iconsax.battery_charging, _voltageColor(d?.batteryVoltage),
                    _voltageHint(d?.batteryVoltage),
                  ),
                  _metricWithHint(
                    'الدينامو', d?.controlModuleVoltage != null ? '${d!.controlModuleVoltage!.toStringAsFixed(1)}V' : '--',
                    Iconsax.flash_1, _voltageColor(d?.controlModuleVoltage),
                    _voltageHint(d?.controlModuleVoltage),
                  ),
                ]),
                const SizedBox(height: 12),

                // Other
                _sectionLabel('بيانات تانية'),
                _metricsGrid([
                  _metric('وقت التشغيل', d?.runTimeSec != null ? _formatSeconds(d!.runTimeSec!) : '--', Iconsax.clock, null),
                  _metricWithHint(
                    'مسافة بلمبة المحرك', d?.distanceWithMilKm != null ? '${d!.distanceWithMilKm} كم' : '--',
                    Iconsax.routing, d?.distanceWithMilKm != null && d!.distanceWithMilKm! > 0 ? CheKarColors.scoreBad : null,
                    d?.distanceWithMilKm != null && d!.distanceWithMilKm! > 500 ? 'إهمال — ماشي بلمبة المحرك' : null,
                  ),
                ]),
                const SizedBox(height: 12),

                // Diagnostics (one-shot)
                if (diag != null) ...[
                  _sectionLabel('التشخيص'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: CheKarColors.darkCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: CheKarColors.borderSubtle)),
                    child: Column(
                      children: [
                        _diagRow('لمبة المحرك', diag.milOn ? 'شغالة' : 'مطفية', diag.milOn ? CheKarColors.scoreBad : CheKarColors.scoreGood),
                        _diagRow('أكواد أعطال', '${diag.dtcCount}', diag.dtcCount > 0 ? CheKarColors.scoreBad : CheKarColors.scoreGood),
                        if (diag.storedDtcs.isNotEmpty) _diagRow('الأكواد', diag.storedDtcs.join(', '), CheKarColors.scoreBad),
                        if (diag.vin != null) _diagRow('VIN', diag.vin!, null),
                        if (diag.odometerKm != null) _diagRow('العداد (كمبيوتر)', '${diag.odometerKm} كم', null),
                        if (diag.warmupsSinceDtcCleared != null) _diagRow(
                          'تشغيلات بعد المسح', '${diag.warmupsSinceDtcCleared}',
                          diag.warmupsSinceDtcCleared! < 3 ? CheKarColors.scoreBad : CheKarColors.scoreGood,
                        ),
                        if (diag.timeSinceDtcClearedMin != null) _diagRow(
                          'وقت مسح الأكواد', _formatMinutes(diag.timeSinceDtcClearedMin!),
                          diag.timeSinceDtcClearedMin! < 30 ? CheKarColors.scoreBad : null,
                        ),
                        if (diag.distanceWithMilKm != null && diag.distanceWithMilKm! > 0) _diagRow(
                          'مسافة بلمبة المحرك', '${diag.distanceWithMilKm} كم', CheKarColors.scoreBad,
                        ),
                      ],
                    ),
                  ),

                  if (diag.warnings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: CheKarColors.scoreBad.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: CheKarColors.scoreBad.withOpacity(0.2))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Iconsax.danger, size: 16, color: CheKarColors.scoreBad),
                              const SizedBox(width: 8),
                              Text('تحذيرات', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700, color: CheKarColors.scoreBad)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...diag.warnings.map((w) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $w', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600, color: CheKarColors.scoreBad, height: 1.5)),
                          )),
                        ],
                      ),
                    ),
                  ],

                  // LTFT fraud check
                  if (d?.longTermFuelTrimB1 != null && d!.longTermFuelTrimB1!.abs() < 1.0 && diag.warmupsSinceDtcCleared != null && diag.warmupsSinceDtcCleared! < 10) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: CheKarColors.scoreMid.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: CheKarColors.scoreMid.withOpacity(0.2))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Iconsax.warning_2, size: 16, color: CheKarColors.scoreMid),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'LTFT = 0% مع تشغيلات قليلة بعد المسح — ممكن الأكواد اتمسحت مؤخراً',
                            style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600, color: CheKarColors.scoreMid, height: 1.5),
                          )),
                        ],
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Summary (after stopping) ──────────────────────────────────────

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _header(title: 'الفحص انتهى'),
          const SizedBox(height: 24),
          Icon(Iconsax.tick_circle, size: 64, color: CheKarColors.scoreGood),
          const SizedBox(height: 16),
          Text('تم إيقاف الفحص المباشر', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 32),
          _ctaButton('فحص جديد', () => setState(() { _phase = _Phase.pickConnection; _diagResult = null; _liveData = null; })),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/home'),
            child: Text('رجوع للرئيسية', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white38)),
          ),
        ],
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 80, height: 80, decoration: BoxDecoration(color: CheKarColors.scoreBad.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Iconsax.close_circle, color: CheKarColors.scoreBad, size: 36)),
            const SizedBox(height: 24),
            Text('فشل الاتصال', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 12),
            Text(_error ?? '', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 14, color: Colors.white38, height: 1.6)),
            const SizedBox(height: 32),
            _ctaButton('حاول تاني', () => setState(() => _phase = _Phase.pickConnection)),
          ],
        ),
      ),
    );
  }

  // ── Reusable Widgets ──────────────────────────────────────────────

  Widget _header({String title = 'فحص OBD', VoidCallback? onBack}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack ?? () => context.go('/home'),
            child: Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(13)), child: const Icon(Iconsax.arrow_right_3, color: Colors.white70, size: 20)),
          ),
          const Spacer(),
          Text(title, style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const Spacer(),
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _connectionCard({required IconData icon, required String label, required String sub, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(color: CheKarColors.darkCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: CheKarColors.borderSubtle)),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: CheKarColors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: CheKarColors.orange, size: 22)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(sub, style: GoogleFonts.cairo(fontSize: 12, color: Colors.white38)),
            ])),
            const Icon(Iconsax.arrow_left_2, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _ctaButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFB923C), CheKarColors.orange, Color(0xFFEA580C)]), borderRadius: BorderRadius.circular(16)),
          alignment: Alignment.center,
          child: Text(label, style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _bigGauge(String label, String value, IconData icon, Color color, {String? unit}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: CheKarColors.darkCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: CheKarColors.borderSubtle)),
      child: Column(
        children: [
          Icon(icon, color: color.withOpacity(0.6), size: 22),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.saira(fontSize: 32, fontWeight: FontWeight.w700, color: color)),
          if (unit != null) Text(unit, style: GoogleFonts.cairo(fontSize: 11, color: Colors.white30)),
          Text(label, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Align(alignment: Alignment.centerRight, child: Text(label, style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white54))),
    );
  }

  Widget _metricsGrid(List<Widget> children) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: children.map((c) => SizedBox(width: (MediaQuery.of(context).size.width - 42) / 2, child: c)).toList(),
    );
  }

  Widget _metric(String label, String value, IconData icon, Color? valueColor) {
    return _metricWithHint(label, value, icon, valueColor, null);
  }

  Widget _metricWithHint(String label, String value, IconData icon, Color? valueColor, String? hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: CheKarColors.darkCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: CheKarColors.borderSubtle)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: CheKarColors.orange.withOpacity(0.5)),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54))),
              Text(value, style: GoogleFonts.saira(fontSize: 14, fontWeight: FontWeight.w700, color: valueColor ?? Colors.white)),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w600, color: valueColor ?? Colors.white38)),
          ],
        ],
      ),
    );
  }

  Widget _diagRow(String label, String value, Color? color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white54))),
          Text(value, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? Colors.white)),
        ],
      ),
    );
  }

  Color? _tempColor(double? temp) {
    if (temp == null) return null;
    if (temp > 105) return CheKarColors.scoreBad;
    if (temp > 95) return CheKarColors.scoreMid;
    return CheKarColors.scoreGood;
  }

  Color? _loadColor(int? load) {
    if (load == null) return null;
    if (load > 50) return CheKarColors.scoreMid; // high at idle
    return null;
  }

  Color? _fuelTrimColor(double? trim) {
    if (trim == null) return null;
    if (trim.abs() > 25) return CheKarColors.scoreBad;
    if (trim.abs() > 15) return CheKarColors.scoreMid;
    return CheKarColors.scoreGood;
  }

  String? _fuelTrimHint(double? trim, String type) {
    if (trim == null) return null;
    if (trim.abs() > 25) return 'مشكلة في الوقود — خطير';
    if (trim.abs() > 15) return trim > 0 ? 'المحرك بيسحب وقود زيادة' : 'المحرك بيضخ وقود زيادة';
    if (trim.abs() < 1.0) return 'ممكن تكون اتريست مؤخراً';
    return 'طبيعي';
  }

  Color? _voltageColor(double? v) {
    if (v == null) return null;
    if (v < 11.5) return CheKarColors.scoreBad;
    if (v > 15.0) return CheKarColors.scoreBad;
    if (v >= 13.5 && v <= 14.5) return CheKarColors.scoreGood;
    return CheKarColors.scoreMid;
  }

  String? _voltageHint(double? v) {
    if (v == null) return null;
    if (v < 11.5) return 'ضعيفة — محتاجة تتغير';
    if (v > 15.0) return 'عالية — الدينامو فيه مشكلة';
    if (v >= 13.5 && v <= 14.5) return 'الشحن شغال كويس';
    if (v < 13.0) return 'الدينامو مش بيشحن كويس';
    return 'طبيعي';
  }

  String _formatSeconds(int sec) {
    if (sec < 60) return '${sec}ث';
    if (sec < 3600) return '${sec ~/ 60}د';
    return '${sec ~/ 3600}س ${(sec % 3600) ~/ 60}د';
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes دقيقة';
    if (minutes < 1440) return '${minutes ~/ 60} ساعة';
    return '${minutes ~/ 1440} يوم';
  }
}

enum _Phase { pickConnection, pickDevice, ready, connecting, diagnosing, live, summary, error }
