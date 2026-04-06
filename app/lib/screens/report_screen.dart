import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../config/theme.dart';
import '../models/finding.dart';
import '../models/inspection.dart';
import '../providers/auth_provider.dart';
import '../providers/inspection_provider.dart';
import '../widgets/finding_card.dart';
import '../widgets/grade_badge.dart';
import '../widgets/traffic_light_row.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final String inspectionId;

  const ReportScreen({super.key, required this.inspectionId});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  Inspection? _inspection;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInspection();
  }

  Future<void> _loadInspection() async {
    final current = ref.read(inspectionProvider).current;
    if (current != null && current.id == widget.inspectionId) {
      setState(() { _inspection = current; _loading = false; });
      return;
    }
    try {
      final inspection = await ref.read(apiServiceProvider).getInspection(widget.inspectionId);
      setState(() { _inspection = inspection; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Finding> _parseFindings(Map<String, dynamic>? report) {
    final raw = (report?['النتائج'] as List?);
    if (raw == null) return [];
    final findings = raw.map((f) => Finding.fromArabicJson(f as Map<String, dynamic>)).toList();
    findings.sort((a, b) => (b.isMajor ? 1 : 0) - (a.isMajor ? 1 : 0));
    return findings;
  }

  String _toArabicNumerals(String text) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '.'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩', '،', '٫'];
    var result = text;
    for (int i = 0; i < en.length; i++) {
      result = result.replaceAll(en[i], ar[i]);
    }
    return result;
  }

  void _shareWhatsApp(Inspection inspection, List<Finding> findings) {
    final gradeLabel = inspection.grade != null
        ? 'التقييم: ${inspection.grade} - ${inspection.scoreLabelAr}'
        : 'درجة الثقة: ${inspection.trustScore}/100\n${inspection.scoreLabelAr}';
    final text = 'تقرير فحص CheKar\n'
        '${inspection.carModel} ${inspection.year}\n'
        '$gradeLabel\n'
        'عدد المشاكل: ${findings.length}';
    Share.share(text);
  }

  Future<void> _downloadPdf(Inspection inspection) async {
    try {
      final api = ref.read(apiServiceProvider);
      final path = '/tmp/chekar_report_${inspection.id}.pdf';
      await api.downloadReportPdf(inspection.id, path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحميل التقرير', style: GoogleFonts.cairo()), backgroundColor: CheKarColors.scoreGood),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل التقرير', style: GoogleFonts.cairo()), backgroundColor: CheKarColors.scoreBad),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(backgroundColor: CheKarColors.darkDeep, body: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: CheKarColors.orange));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(shape: BoxShape.circle, color: CheKarColors.scoreBad.withOpacity(0.12)),
                child: const Icon(Iconsax.close_circle, color: CheKarColors.scoreBad, size: 30),
              ),
              const SizedBox(height: 16),
              Text('حصل خطأ', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_error!, style: GoogleFonts.cairo(color: Colors.white38, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _loadInspection, child: Text('حاول تاني', style: GoogleFonts.cairo())),
            ],
          ),
        ),
      );
    }
    if (_inspection == null) return const SizedBox.shrink();

    final inspection = _inspection!;
    final report = inspection.result?['نتيجة_الفحص'] as Map<String, dynamic>?;
    final findings = _parseFindings(report);
    final categories = report?['الفئات'] as Map<String, dynamic>? ?? {};
    final unassessed = (report?['مالقدرناش_نفحص'] as List?)?.cast<String>() ?? [];
    final recommendation = report?['النصيحة'] as String? ?? '';
    final isQuick = inspection.photoCount <= 4;
    final gradeColor = inspection.gradeColor;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeroHeader(inspection, gradeColor, isQuick)),
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              color: CheKarColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recommendation.isNotEmpty) ...[
                    _buildRecommendationCard(recommendation, gradeColor),
                    const SizedBox(height: 28),
                  ],
                  if (categories.isNotEmpty) ...[
                    _buildCategoriesSection(categories),
                    const SizedBox(height: 28),
                  ],
                  if (unassessed.isNotEmpty) ...[
                    _buildUnassessedSection(unassessed),
                    const SizedBox(height: 28),
                  ],
                  _buildFindingsSection(findings),
                  const SizedBox(height: 32),
                  _buildActionButtons(inspection, findings),
                  const SizedBox(height: 20),
                  _buildDisclaimer(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroHeader(Inspection inspection, Color gradeColor, bool isQuick) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CheKarColors.darkDeep, CheKarColors.dark],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 80, left: 0, right: 0,
            child: Center(
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [gradeColor.withOpacity(0.08), gradeColor.withOpacity(0.02), Colors.transparent],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (context.canPop()) { context.pop(); } else { context.go('/home'); }
                        },
                        child: Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: const Icon(Iconsax.arrow_right_3, color: Colors.white70, size: 20),
                        ),
                      ),
                      const Spacer(),
                      Text('تقرير الفحص', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                      const Spacer(),
                      const SizedBox(width: 42),
                    ],
                  ),
                  const SizedBox(height: 32),
                  GradeBadge(grade: inspection.grade ?? '?', color: gradeColor, size: 130),
                  const SizedBox(height: 24),
                  Text(inspection.scoreLabelAr, style: GoogleFonts.cairo(fontSize: 26, fontWeight: FontWeight.w700, color: gradeColor)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Text(
                      _toArabicNumerals('${inspection.carModel} ${inspection.year} · ${_formatMileage(inspection.mileage)} كم'),
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: CheKarColors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: CheKarColors.orange.withOpacity(0.2)),
                    ),
                    child: Text(
                      isQuick ? 'فحص سريع' : 'فحص شامل',
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: CheKarColors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMileage(int mileage) {
    if (mileage >= 1000) {
      return _toArabicNumerals('${(mileage ~/ 1000)},000');
    }
    return _toArabicNumerals(mileage.toString());
  }

  Widget _buildRecommendationCard(String recommendation, Color gradeColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [gradeColor.withOpacity(0.06), gradeColor.withOpacity(0.02)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gradeColor.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: gradeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(Iconsax.lamp_on, color: gradeColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نصيحة', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700, color: gradeColor)),
                const SizedBox(height: 4),
                Text(recommendation, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w500, color: CheKarColors.textPrimary, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(Map<String, dynamic> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'حالة الأجزاء', icon: Iconsax.task_square),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: CheKarColors.borderLight),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              for (final entry in categories.entries)
                TrafficLightRow(
                  nameAr: entry.key,
                  light: (entry.value as Map<String, dynamic>?)?['الحالة'] as String? ?? 'not_assessed',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnassessedSection(List<String> unassessed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'مالقدرناش نفحص', icon: Iconsax.setting_2),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: CheKarColors.orange.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: CheKarColors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.warning_2, color: CheKarColors.orange, size: 15),
                    const SizedBox(width: 6),
                    Text('محتاجة فحص ميكانيكي', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: CheKarColors.orange)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ...unassessed.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(width: 5, height: 5, decoration: BoxDecoration(color: CheKarColors.textMuted, borderRadius: BorderRadius.circular(3))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w500, color: CheKarColors.textSecondary, height: 1.5))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFindingsSection(List<Finding> findings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionHeader(title: 'النتائج', icon: Iconsax.clipboard_tick),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: CheKarColors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(_toArabicNumerals(findings.length.toString()), style: GoogleFonts.saira(fontSize: 13, fontWeight: FontWeight.w700, color: CheKarColors.orange)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (findings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CheKarColors.scoreGood.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: CheKarColors.scoreGood.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: CheKarColors.scoreGood.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Iconsax.tick_circle, color: CheKarColors.scoreGood, size: 24),
                ),
                const SizedBox(height: 12),
                Text('ما لقيناش مشاكل واضحة في الصور', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600, color: CheKarColors.scoreGood), textAlign: TextAlign.center),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: findings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => FindingCard(finding: findings[i]),
          ),
      ],
    );
  }

  Widget _buildActionButtons(Inspection inspection, List<Finding> findings) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _shareWhatsApp(inspection, findings),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
            icon: const Icon(Iconsax.share, size: 20),
            label: Text('شارك على واتساب', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _downloadPdf(inspection),
            style: ElevatedButton.styleFrom(backgroundColor: CheKarColors.dark, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
            icon: const Icon(Iconsax.document_download, size: 20),
            label: Text('حمل PDF', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: CheKarColors.borderLight.withOpacity(0.5), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.info_circle, size: 18, color: CheKarColors.textMuted.withOpacity(0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'التقرير ده تقييم بالذكاء الاصطناعي بناءً على الصور — مش بديل عن الفحص الميكانيكي',
              style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w500, color: CheKarColors.textMuted, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: CheKarColors.textSecondary),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w700, color: CheKarColors.textPrimary)),
      ],
    );
  }
}
