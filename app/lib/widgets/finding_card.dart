import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  (Color, String) get _confidenceBadge {
    switch (widget.finding.confidence) {
      case 'عالي':
        return (CheKarColors.scoreGood, 'ثقة عالية');
      case 'منخفض':
        return (CheKarColors.scoreBad, 'ثقة منخفضة');
      default:
        return (CheKarColors.scoreWarn, 'ثقة متوسطة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCost = widget.finding.costMin != null && widget.finding.costMax != null;
    final hasNote = widget.finding.note != null && widget.finding.note!.isNotEmpty;
    final (confidenceColor, confidenceLabel) = _confidenceBadge;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF5F5F4), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Collapsed header — always visible
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Severity dot — angular (borderRadius 2)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _severityColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.finding.type,
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: CheKarColors.textPrimary,
                          ),
                        ),
                        if (widget.finding.location.isNotEmpty)
                          Text(
                            widget.finding.location,
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: CheKarColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Chevron rotates on expand
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: CheKarColors.textMuted,
                      size: 22,
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
                  const Divider(height: 1, color: Color(0xFFF5F5F4)),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Note / description
                        if (hasNote)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              widget.finding.note!,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: CheKarColors.textMuted,
                                height: 1.6,
                              ),
                            ),
                          ),

                        // Cost box — angular (borderRadius 4)
                        if (hasCost)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFDBA74).withAlpha(128), width: 1),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'تكلفة الإصلاح',
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: CheKarColors.textMuted,
                                  ),
                                ),
                                Text(
                                  _toArabicNumerals(
                                    '${_formatCost(widget.finding.costMin!)} - ${_formatCost(widget.finding.costMax!)} جنيه',
                                  ),
                                  style: GoogleFonts.saira(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: CheKarColors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Confidence badge
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: confidenceColor.withAlpha(26),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              confidenceLabel,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: confidenceColor,
                              ),
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
    );
  }
}
