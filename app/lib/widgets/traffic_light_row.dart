import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TrafficLightRow extends StatelessWidget {
  final String nameAr;
  final String light; // "green", "yellow", "red", "not_assessed"

  const TrafficLightRow({super.key, required this.nameAr, required this.light});

  Color get _color {
    switch (light) {
      case 'green': return const Color(0xFF16A34A);
      case 'yellow': return const Color(0xFFEAB308);
      case 'red': return const Color(0xFFDC2626);
      default: return const Color(0xFF78716C);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: light == 'not_assessed' ? Colors.transparent : _color,
              borderRadius: BorderRadius.circular(3),
              border: light == 'not_assessed' ? Border.all(color: const Color(0xFF78716C), width: 1.5) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(nameAr, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1C1917)))),
          Text(_labelAr, style: GoogleFonts.cairo(fontSize: 12, color: _color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
