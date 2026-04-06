import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CheKarColors {
  static const Color orange = Color(0xFFF97316);
  static const Color orangeLight = Color(0xFFFDBA74);
  static const Color dark = Color(0xFF1E1E2E);
  static const Color darkSurface = Color(0xFF272738);
  static const Color darkCard = Color(0xFF2E2E42);
  static const Color surface = Color(0xFFFFF7ED);
  static const Color background = Color(0xFFFAFAF9);
  static const Color textPrimary = Color(0xFF1C1917);
  static const Color textMuted = Color(0xFF78716C);
  static const Color scoreGood = Color(0xFF16A34A);
  static const Color scoreMid = Color(0xFFEAB308);
  static const Color scoreWarn = Color(0xFFF97316);
  static const Color scoreBad = Color(0xFFDC2626);

  static Color scoreColor(int score) {
    if (score >= 85) return scoreGood;
    if (score >= 65) return scoreMid;
    if (score >= 40) return scoreWarn;
    return scoreBad;
  }
}

class CheKarTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: CheKarColors.background,
      colorScheme: ColorScheme.light(
        primary: CheKarColors.orange,
        surface: CheKarColors.surface,
        onPrimary: Colors.white,
      ),
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        displayLarge: GoogleFonts.cairo(fontSize: 48, fontWeight: FontWeight.w900, color: CheKarColors.textPrimary),
        headlineMedium: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w700, color: CheKarColors.textPrimary),
        bodyLarge: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w500, color: CheKarColors.textPrimary),
        bodyMedium: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w500, color: CheKarColors.textPrimary),
        bodySmall: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w500, color: CheKarColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CheKarColors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CheKarColors.darkSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3A3A4D))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3A3A4D))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CheKarColors.orange)),
        hintStyle: GoogleFonts.cairo(color: CheKarColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFF5F5F4))),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CheKarColors.dark,
      colorScheme: ColorScheme.dark(primary: CheKarColors.orange, surface: CheKarColors.darkSurface),
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
    );
  }
}
