import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../config/theme.dart';
import '../models/obd_result.dart';
import '../providers/auth_provider.dart';
import '../services/obd/obd_scanner.dart';

class ObdScanScreen extends ConsumerStatefulWidget {
  final String inspectionId;
  const ObdScanScreen({super.key, required this.inspectionId});

  @override
  ConsumerState<ObdScanScreen> createState() => _ObdScanScreenState();
}

class _ObdScanScreenState extends ConsumerState<ObdScanScreen> {
  final ObdScanner _scanner = ObdScanner();
  _ScanState _state = _ScanState.instructions;
  String _statusText = '';
  ObdResult? _result;
  String? _error;

  @override
  void dispose() {
    _scanner.disconnect();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _state = _ScanState.connecting;
      _statusText = 'جاري الاتصال بجهاز OBD...';
      _error = null;
    });

    _scanner.onStatus = (status) {
      if (mounted) setState(() => _statusText = status);
    };

    try {
      await _scanner.connect();
      setState(() => _state = _ScanState.initializing);

      final ok = await _scanner.initialize();
      if (!ok) {
        setState(() {
          _state = _ScanState.error;
          _error = 'مش قادر يتصل بالعربية. تأكد إن جهاز OBD متوصل والمحرك شغال.';
        });
        return;
      }

      setState(() => _state = _ScanState.scanning);
      final result = await _scanner.scan();

      setState(() {
        _state = _ScanState.done;
        _result = result;
      });
    } catch (e) {
      setState(() {
        _state = _ScanState.error;
        _error = e is SocketException
            ? 'مش قادر يتصل بجهاز OBD.\nتأكد إنك متصل بشبكة WiFi الخاصة بجهاز OBD.'
            : 'حصل خطأ: $e';
      });
    } finally {
      _scanner.disconnect();
    }
  }

  bool get _isStandalone => widget.inspectionId.isEmpty;

  void _skipObd() {
    if (_isStandalone) {
      context.go('/home');
    } else {
      context.go('/processing/${widget.inspectionId}');
    }
  }

  Future<void> _continueWithResults() async {
    if (_result == null) return;

    // Save OBD results locally
    final storage = ref.read(storageServiceProvider);
    final obdJson = jsonEncode({
      ...(_result!.toJson()),
      'scanned_at': DateTime.now().toIso8601String(),
      'inspection_id': _isStandalone ? null : widget.inspectionId,
    });
    await storage.addObdResult(obdJson);

    if (_isStandalone) {
      context.go('/home');
    } else {
      context.go('/processing/${widget.inspectionId}');
    }
  }

  void _shareResults() {
    if (_result == null) return;
    final r = _result!;
    final lines = <String>[
      'تقرير فحص OBD — CheKar',
      '─────────────────',
    ];
    if (r.vin != null) lines.add('رقم الشاسيه: ${r.vin}');
    lines.add('لمبة المحرك: ${r.milOn ? "شغالة ⚠️" : "مطفية ✅"}');
    if (r.dtcCount > 0) lines.add('أكواد أعطال: ${r.dtcCount}');
    if (r.storedDtcs.isNotEmpty) lines.add('الأكواد: ${r.storedDtcs.join(", ")}');
    if (r.pendingDtcs.isNotEmpty) lines.add('أكواد معلقة: ${r.pendingDtcs.join(", ")}');
    if (r.coolantTempC != null) lines.add('حرارة المحرك: ${r.coolantTempC!.toInt()}°C');
    if (r.batteryVoltage != null) lines.add('البطارية: ${r.batteryVoltage!.toStringAsFixed(1)}V');
    if (r.odometerKm != null) lines.add('العداد (كمبيوتر): ${r.odometerKm} كم');
    if (r.distanceWithMilKm != null) lines.add('مسافة بلمبة المحرك: ${r.distanceWithMilKm} كم');
    if (r.timeSinceDtcClearedMin != null) lines.add('وقت مسح الأكواد: ${_formatMinutes(r.timeSinceDtcClearedMin!)}');
    if (r.warmupsSinceDtcCleared != null) lines.add('تشغيلات بعد المسح: ${r.warmupsSinceDtcCleared}');
    if (r.warnings.isNotEmpty) {
      lines.add('');
      lines.add('تحذيرات:');
      for (final w in r.warnings) lines.add('⚠️ $w');
    }
    Share.share(lines.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: CheKarColors.darkDeep,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: switch (_state) {
              _ScanState.instructions => _buildInstructions(),
              _ScanState.connecting || _ScanState.initializing || _ScanState.scanning => _buildScanning(),
              _ScanState.done => _buildResults(),
              _ScanState.error => _buildError(),
            },
          ),
        ),
      ),
    );
  }

  // ── Instructions Screen ──────────────────────────────────────────

  Widget _buildInstructions() {
    return Column(
      children: [
        const SizedBox(height: 24),
        // Header
        Row(
          children: [
            GestureDetector(
              onTap: _skipObd,
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Iconsax.arrow_right_3, color: Colors.white70, size: 20),
              ),
            ),
            const Spacer(),
            Text('فحص OBD', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            const Spacer(),
            const SizedBox(width: 42),
          ],
        ),
        const Spacer(),
        // Icon
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: CheKarColors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Iconsax.cpu, color: CheKarColors.orange, size: 44),
        ),
        const SizedBox(height: 32),
        Text(
          'فحص كمبيوتر العربية',
          style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 16),
        // Steps
        _InstructionStep(number: '١', text: 'وصل جهاز OBD بمدخل OBD-II في العربية (تحت الدركسيون)'),
        _InstructionStep(number: '٢', text: 'شغل المحرك'),
        _InstructionStep(number: '٣', text: 'اتصل بشبكة WiFi الخاصة بجهاز OBD من إعدادات التليفون'),
        _InstructionStep(number: '٤', text: 'ارجع هنا واضغط ابدأ الفحص'),
        const SizedBox(height: 32),
        // Start button
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: _startScan,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFB923C), CheKarColors.orange, Color(0xFFEA580C)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: CheKarColors.orange.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              alignment: Alignment.center,
              child: Text('ابدأ الفحص', style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Skip button
        TextButton(
          onPressed: _skipObd,
          child: Text('تخطي فحص OBD', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white38)),
        ),
        const Spacer(),
      ],
    );
  }

  // ── Scanning Screen ──────────────────────────────────────────────

  Widget _buildScanning() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 64, height: 64,
            child: CircularProgressIndicator(
              color: CheKarColors.orange,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _statusText,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'لا تقفل التطبيق أو تغير شبكة الواي فاي',
            style: GoogleFonts.cairo(fontSize: 13, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  // ── Results Screen ────────────────────────────────────────────────

  Widget _buildResults() {
    final r = _result!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          // Header
          Center(child: Text('نتائج فحص OBD', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white))),
          const SizedBox(height: 24),

          // Warnings
          if (r.warnings.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CheKarColors.scoreBad.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CheKarColors.scoreBad.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.danger, color: CheKarColors.scoreBad, size: 18),
                      const SizedBox(width: 8),
                      Text('تحذيرات', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700, color: CheKarColors.scoreBad)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...r.warnings.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $w', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: CheKarColors.scoreBad, height: 1.5)),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Data rows
          _ResultCard(children: [
            if (r.vin != null)
              _ResultRow(icon: Iconsax.car, label: 'رقم الشاسيه (VIN)', value: r.vin!),
            _ResultRow(
              icon: Iconsax.warning_2,
              label: 'لمبة المحرك (MIL)',
              value: r.milOn ? 'شغالة' : 'مطفية',
              valueColor: r.milOn ? CheKarColors.scoreBad : CheKarColors.scoreGood,
            ),
            _ResultRow(icon: Iconsax.danger, label: 'أكواد أعطال مسجلة', value: '${r.dtcCount}'),
            if (r.storedDtcs.isNotEmpty)
              _ResultRow(icon: Iconsax.document_text, label: 'الأكواد', value: r.storedDtcs.join(', ')),
            if (r.pendingDtcs.isNotEmpty)
              _ResultRow(icon: Iconsax.document_text, label: 'أكواد معلقة', value: r.pendingDtcs.join(', ')),
          ]),
          const SizedBox(height: 12),

          _ResultCard(children: [
            if (r.coolantTempC != null)
              _ResultRow(
                icon: Iconsax.flash_1,
                label: 'حرارة المحرك',
                value: '${r.coolantTempC!.toInt()}°C',
                valueColor: r.coolantTempC! > 105 ? CheKarColors.scoreBad : null,
              ),
            if (r.batteryVoltage != null)
              _ResultRow(
                icon: Iconsax.battery_charging,
                label: 'البطارية',
                value: '${r.batteryVoltage!.toStringAsFixed(1)}V',
                valueColor: r.batteryVoltage! < 11.5 ? CheKarColors.scoreBad : null,
              ),
            if (r.odometerKm != null)
              _ResultRow(icon: Iconsax.speedometer, label: 'العداد (من الكمبيوتر)', value: '${r.odometerKm} كم'),
          ]),
          const SizedBox(height: 12),

          _ResultCard(children: [
            if (r.timeSinceDtcClearedMin != null)
              _ResultRow(
                icon: Iconsax.timer_1,
                label: 'وقت مسح الأكواد',
                value: _formatMinutes(r.timeSinceDtcClearedMin!),
                valueColor: r.timeSinceDtcClearedMin! < 30 ? CheKarColors.scoreBad : null,
              ),
            if (r.warmupsSinceDtcCleared != null)
              _ResultRow(
                icon: Iconsax.refresh,
                label: 'تشغيلات بعد المسح',
                value: '${r.warmupsSinceDtcCleared}',
                valueColor: r.warmupsSinceDtcCleared! < 3 ? CheKarColors.scoreBad : null,
              ),
            if (r.distanceWithMilKm != null)
              _ResultRow(icon: Iconsax.routing, label: 'مسافة بلمبة المحرك', value: '${r.distanceWithMilKm} كم'),
          ]),

          const SizedBox(height: 32),
          // Share button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shareResults,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: const Icon(Iconsax.share, size: 18),
              label: Text('شارك النتائج', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          // Continue button
          GestureDetector(
            onTap: _continueWithResults,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFB923C), CheKarColors.orange, Color(0xFFEA580C)]),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                _isStandalone ? 'رجوع' : 'استمر في الفحص',
                style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Error Screen ──────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: CheKarColors.scoreBad.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.close_circle, color: CheKarColors.scoreBad, size: 36),
            ),
            const SizedBox(height: 24),
            Text('فشل الاتصال', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 12),
            Text(_error ?? '', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 14, color: Colors.white38, height: 1.6)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => _state = _ScanState.instructions),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CheKarColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('حاول تاني', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _skipObd,
              child: Text('تخطي فحص OBD', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes دقيقة';
    if (minutes < 1440) return '${minutes ~/ 60} ساعة';
    return '${minutes ~/ 1440} يوم';
  }
}

// ── State ────────────────────────────────────────────────────────────

enum _ScanState { instructions, connecting, initializing, scanning, done, error }

// ── Instruction Step ────────────────────────────────────────────────

class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;
  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: CheKarColors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(number, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700, color: CheKarColors.orange)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70, height: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Result Card ─────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final List<Widget> children;
  const _ResultCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CheKarColors.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CheKarColors.borderSubtle),
      ),
      child: Column(children: children),
    );
  }
}

// ── Result Row ──────────────────────────────────────────────────────

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ResultRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: CheKarColors.orange.withOpacity(0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white60)),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor ?? Colors.white),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}
