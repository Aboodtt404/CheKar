import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../config/theme.dart';
import '../models/finding.dart';
import '../models/inspection.dart';
import '../providers/auth_provider.dart';
import '../providers/inspection_provider.dart';
import '../widgets/finding_card.dart';
import '../widgets/score_circle.dart';

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
  bool _subScoresExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadInspection();
  }

  Future<void> _loadInspection() async {
    // Try provider state first
    final current = ref.read(inspectionProvider).current;
    if (current != null && current.id == widget.inspectionId) {
      setState(() {
        _inspection = current;
        _loading = false;
      });
      return;
    }
    // Fall back to API
    try {
      final inspection = await ref.read(apiServiceProvider).getInspection(widget.inspectionId);
      setState(() {
        _inspection = inspection;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Finding> _parseFindings(Map<String, dynamic>? report) {
    final raw = (report?['النتائج'] as List?);
    if (raw == null) return [];
    final findings = raw.map((f) => Finding.fromArabicJson(f as Map<String, dynamic>)).toList();
    findings.sort((a, b) => (b.isMajor ? 1 : 0) - (a.isMajor ? 1 : 0));
    return findings;
  }

  Map<String, dynamic>? _parseSubScores(Map<String, dynamic>? report) {
    final sub = report?['الدرجات_الفرعية'];
    if (sub is Map) return sub.cast<String, dynamic>();
    return null;
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
    final text = 'تقرير فحص CheKar\n'
        '${inspection.carModel} ${inspection.year}\n'
        'درجة الثقة: ${inspection.trustScore}/100\n'
        '${inspection.scoreLabelAr}\n'
        'عدد المشاكل: ${findings.length}';
    Share.share(text);
  }

  Future<void> _downloadPdf(Inspection inspection) async {
    try {
      final api = ref.read(apiServiceProvider);
      // Download to temp path
      final path = '/tmp/chekar_report_${inspection.id}.pdf';
      await api.downloadReportPdf(inspection.id, path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحميل التقرير', style: GoogleFonts.cairo()),
            backgroundColor: CheKarColors.scoreGood,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل التقرير', style: GoogleFonts.cairo()),
            backgroundColor: CheKarColors.scoreBad,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: CheKarColors.dark,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: CheKarColors.orange));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('حصل خطأ', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_error!, style: GoogleFonts.cairo(color: CheKarColors.textMuted, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _loadInspection, child: Text('حاول تاني', style: GoogleFonts.cairo())),
          ],
        ),
      );
    }
    if (_inspection == null) return const SizedBox.shrink();

    final inspection = _inspection!;
    final report = inspection.result?['نتيجة_الفحص'] as Map<String, dynamic>?;
    final findings = _parseFindings(report);
    final subScores = _parseSubScores(report);
    final score = inspection.trustScore ?? 0;
    final scoreColor = CheKarColors.scoreColor(score);
    final isQuick = inspection.photoCount <= 4;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeroHeader(inspection, score, scoreColor, isQuick)),
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
                  _buildFindingsSection(findings),
                  if (subScores != null && subScores.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _buildSubScoresSection(subScores),
                  ],
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

  Widget _buildHeroHeader(Inspection inspection, int score, Color scoreColor, bool isQuick) {
    return Container(
      color: CheKarColors.dark,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top nav row
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'تقرير الفحص',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40), // balance
                ],
              ),

              const SizedBox(height: 28),

              // Glow + ScoreCircle
              Stack(
                alignment: Alignment.center,
                children: [
                  // Glow behind circle
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: scoreColor.withAlpha(77),
                          blurRadius: 60,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  ScoreCircle(score: score, animate: true),
                ],
              ),

              const SizedBox(height: 20),

              // Score label — design statement
              Text(
                inspection.scoreLabelAr,
                style: GoogleFonts.cairo(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: scoreColor,
                ),
              ),

              const SizedBox(height: 8),

              // Car info
              Text(
                _toArabicNumerals('${inspection.carModel} ${inspection.year} · ${_formatMileage(inspection.mileage)} كم'),
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withAlpha(153),
                ),
              ),

              const SizedBox(height: 12),

              // Mode badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: CheKarColors.orange.withAlpha(38),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CheKarColors.orange.withAlpha(102), width: 1),
                ),
                child: Text(
                  isQuick ? 'فحص سريع' : 'فحص شامل',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: CheKarColors.orange,
                  ),
                ),
              ),

              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMileage(int mileage) {
    if (mileage >= 1000) {
      final s = (mileage ~/ 1000).toString();
      return _toArabicNumerals('${s},000');
    }
    return _toArabicNumerals(mileage.toString());
  }

  Widget _buildFindingsSection(List<Finding> findings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'النتائج (${_toArabicNumerals(findings.length.toString())} مشاكل)',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: CheKarColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        if (findings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CheKarColors.scoreGood.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CheKarColors.scoreGood.withAlpha(51), width: 1),
            ),
            child: Text(
              'ما لقيناش مشاكل واضحة في الصور',
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CheKarColors.scoreGood,
              ),
              textAlign: TextAlign.center,
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

  Widget _buildSubScoresSection(Map<String, dynamic> subScores) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _subScoresExpanded = !_subScoresExpanded),
          child: Row(
            children: [
              Text(
                'الدرجات التفصيلية',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: CheKarColors.textPrimary,
                ),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: _subScoresExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.keyboard_arrow_down_rounded, color: CheKarColors.textMuted),
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 280),
          crossFadeState: _subScoresExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: subScores.entries.map((entry) {
                final name = entry.key;
                final data = entry.value;
                int scoreVal = 0;
                if (data is Map) {
                  final raw = data['الدرجة'];
                  scoreVal = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
                }
                final barColor = CheKarColors.scoreColor(scoreVal);
                final fraction = (scoreVal / 100).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: CheKarColors.textPrimary,
                            ),
                          ),
                          Text(
                            _toArabicNumerals('$scoreVal'),
                            style: GoogleFonts.saira(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: barColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          backgroundColor: const Color(0xFFF5F5F4),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                          minHeight: 7,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Inspection inspection, List<Finding> findings) {
    return Column(
      children: [
        // WhatsApp share — green
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _shareWhatsApp(inspection, findings),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.share_rounded, size: 20),
            label: Text(
              'شارك على واتساب',
              style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Download PDF — dark
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _downloadPdf(inspection),
            style: ElevatedButton.styleFrom(
              backgroundColor: CheKarColors.dark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.download_rounded, size: 20),
            label: Text(
              'حمل PDF',
              style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: CheKarColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'التقرير ده تقييم بالذكاء الاصطناعي بناءً على الصور — مش بديل عن الفحص الميكانيكي',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: CheKarColors.textMuted,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
