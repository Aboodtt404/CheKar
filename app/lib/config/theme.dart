import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CheKarColors {
  // ── Brand ──
  static const Color orange = Color(0xFFF97316);
  static const Color orangeLight = Color(0xFFFDBA74);
  static const Color orangeGlow = Color(0xFFFFA94D);
  static const Color orangeDim = Color(0xFF7C3A0A);

  // ── Dark palette (layered) ──
  static const Color darkDeep = Color(0xFF0F0F1A);
  static const Color dark = Color(0xFF1A1A2B);
  static const Color darkSurface = Color(0xFF222236);
  static const Color darkCard = Color(0xFF2A2A40);
  static const Color darkElevated = Color(0xFF32324A);

  // ── Light palette ──
  static const Color surface = Color(0xFFFFFBF5);
  static const Color background = Color(0xFFF8F7F4);
  static const Color cardWhite = Color(0xFFFFFFFF);

  // ── Text ──
  static const Color textPrimary = Color(0xFF1C1917);
  static const Color textSecondary = Color(0xFF57534E);
  static const Color textMuted = Color(0xFF9C9891);

  // ── Borders ──
  static const Color borderSubtle = Color(0xFF333347);
  static const Color borderLight = Color(0xFFECEBE8);

  // ── Status ──
  static const Color scoreGood = Color(0xFF22C55E);
  static const Color scoreMid = Color(0xFFEAB308);
  static const Color scoreWarn = Color(0xFFF97316);
  static const Color scoreBad = Color(0xFFEF4444);

  static Color scoreColor(int score) {
    if (score >= 85) return scoreGood;
    if (score >= 65) return scoreMid;
    if (score >= 40) return scoreWarn;
    return scoreBad;
  }

  // ── Grade colors (richer) ──
  static const gradeColors = {
    'A': Color(0xFF22C55E),
    'B': Color(0xFF84CC16),
    'C': Color(0xFFEAB308),
    'D': Color(0xFFF97316),
    'F': Color(0xFFEF4444),
  };
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
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CheKarColors.darkSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CheKarColors.borderSubtle)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CheKarColors.borderSubtle)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CheKarColors.orange, width: 1.5)),
        hintStyle: GoogleFonts.cairo(color: CheKarColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: CheKarColors.borderLight),
        ),
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
