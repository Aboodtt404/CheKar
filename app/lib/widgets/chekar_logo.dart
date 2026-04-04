import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class CheKarLogo extends StatelessWidget {
  final double fontSize;
  const CheKarLogo({super.key, this.fontSize = 32});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('CHE', style: GoogleFonts.saira(fontSize: fontSize, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 2)),
        Text('KAR', style: GoogleFonts.saira(fontSize: fontSize, fontWeight: FontWeight.w700, color: CheKarColors.orange, letterSpacing: 2)),
        Padding(
          padding: const EdgeInsets.only(left: 3, bottom: 4),
          child: Container(width: fontSize * 0.18, height: fontSize * 0.18, decoration: const BoxDecoration(color: CheKarColors.orange, shape: BoxShape.circle)),
        ),
      ],
    );
  }
}
