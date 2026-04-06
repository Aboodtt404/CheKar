import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../config/theme.dart';
import '../models/finding.dart';

class FindingCard extends StatefulWidget {
  final Finding finding;

  const FindingCard({super.key, required this.finding});

  @override
  State<FindingCard> createState() => _FindingCardState();
}

class _FindingCardState extends State<FindingCard> {
  bool _expanded = false;

  String _formatCost(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }

  String _toArabicNumerals(String text) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ','];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩', '،'];
    var result = text;
    for (int i = 0; i < en.length; i++) {
      result = result.replaceAll(en[i], ar[i]);
    }
    return result;
  }

  Color get _severityColor => widget.finding.isMajor ? CheKarColors.scoreBad : CheKarColors.scoreMid;

  (Color, String, IconData) get _confidenceBadge {
    switch (widget.finding.confidence) {
      case 'عالي':
        return (CheKarColors.scoreGood, 'ثقة عالية', Iconsax.shield_tick);
      case 'منخفض':
        return (CheKarColors.scoreBad, 'ثقة منخفضة', Iconsax.info_circle);
      default:
        return (CheKarColors.scoreWarn, 'ثقة متوسطة', Iconsax.warning_2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCost = widget.finding.costMin != null && widget.finding.costMax != null;
    final hasNote = widget.finding.note != null && widget.finding.note!.isNotEmpty;
    final (confidenceColor, confidenceLabel, confidenceIcon) = _confidenceBadge;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CheKarColors.borderLight),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Severity accent strip
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _severityColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _severityColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              widget.finding.isMajor ? Iconsax.danger : Iconsax.warning_2,
                              color: _severityColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.finding.type, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700, color: CheKarColors.textPrimary)),
                                if (widget.finding.location.isNotEmpty)
                                  Text(widget.finding.location, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w500, color: CheKarColors.textMuted)),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(color: CheKarColors.borderLight, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Iconsax.arrow_down_1, color: CheKarColors.textMuted, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Expanded content
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 1, color: CheKarColors.borderLight),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasNote)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Text(widget.finding.note!, style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.w500, color: CheKarColors.textSecondary, height: 1.6)),
                                  ),
                                if (hasCost)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    margin: const EdgeInsets.only(bottom: 14),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [CheKarColors.orange.withOpacity(0.06), CheKarColors.orange.withOpacity(0.02)]),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: CheKarColors.orange.withOpacity(0.12)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Iconsax.setting_2, size: 14, color: CheKarColors.orange.withOpacity(0.6)),
                                            const SizedBox(width: 6),
                                            Text('تكلفة الإصلاح', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: CheKarColors.textSecondary)),
                                          ],
                                        ),
                                        Text(
                                          _toArabicNumerals('${_formatCost(widget.finding.costMin!)} - ${_formatCost(widget.finding.costMax!)} جنيه'),
                                          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700, color: CheKarColors.orange),
                                        ),
                                      ],
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: confidenceColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(confidenceIcon, size: 13, color: confidenceColor),
                                        const SizedBox(width: 4),
                                        Text(confidenceLabel, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: confidenceColor)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
