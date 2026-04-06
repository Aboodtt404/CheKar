import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GradeBadge extends StatelessWidget {
  final String grade;
  final Color color;
  final double size;

  const GradeBadge({super.key, required this.grade, required this.color, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: size * 0.04),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 40, spreadRadius: 10)],
      ),
      child: Center(
        child: Text(grade, style: GoogleFonts.saira(fontSize: size * 0.45, fontWeight: FontWeight.w800, color: color)),
      ),
    );
  }
}
