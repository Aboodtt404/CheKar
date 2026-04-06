import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../config/theme.dart';

class TrafficLightRow extends StatelessWidget {
  final String nameAr;
  final String light; // "green", "yellow", "red", "not_assessed"

  const TrafficLightRow({super.key, required this.nameAr, required this.light});

  Color get _color {
    switch (light) {
      case 'green': return CheKarColors.scoreGood;
      case 'yellow': return CheKarColors.scoreMid;
      case 'red': return CheKarColors.scoreBad;
      default: return CheKarColors.textMuted;
    }
  }

  String get _labelAr {
    switch (light) {
      case 'green': return 'سليم';
      case 'yellow': return 'يحتاج مراجعة';
      case 'red': return 'مشكلة';
      default: return 'لم يتم الفحص';
    }
  }

  IconData get _statusIcon {
    switch (light) {
      case 'green': return Iconsax.tick_circle;
      case 'yellow': return Iconsax.warning_2;
      case 'red': return Iconsax.close_circle;
      default: return Iconsax.info_circle;
    }
  }

  // Map category names to Iconsax icons
  IconData get _categoryIcon {
    if (nameAr.contains('الطلاء') || nameAr.contains('دهان') || nameAr.contains('paint')) {
      return Iconsax.brush_1;
    }
    if (nameAr.contains('الهيكل') || nameAr.contains('body')) {
      return Iconsax.car;
    }
    if (nameAr.contains('الزجاج') || nameAr.contains('إضاءة') || nameAr.contains('glass')) {
      return Iconsax.lamp;
    }
    if (nameAr.contains('الداخلية') || nameAr.contains('interior')) {
      return Iconsax.smart_car;
    }
    if (nameAr.contains('حوادث') || nameAr.contains('accident')) {
      return Iconsax.danger;
    }
    if (nameAr.contains('مستندات') || nameAr.contains('document')) {
      return Iconsax.document_text;
    }
    return Iconsax.info_circle;
  }

  @override
  Widget build(BuildContext context) {
    final isAssessed = light != 'not_assessed';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Category icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isAssessed ? _color.withOpacity(0.08) : Colors.grey.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _categoryIcon,
              size: 16,
              color: isAssessed ? _color.withOpacity(0.7) : CheKarColors.textMuted.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 12),
          // Category name
          Expanded(
            child: Text(
              nameAr,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CheKarColors.textPrimary,
              ),
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _color.withOpacity(isAssessed ? 0.08 : 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon, size: 13, color: _color),
                const SizedBox(width: 4),
                Text(
                  _labelAr,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: _color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
