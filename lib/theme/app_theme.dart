import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color f1Red = Color(0xFFE10600);
  static const Color f1RedBright = Color(0xFFFF3B30);
  static const Color background = Color(0xFF0C0F14);
  static const Color backgroundAlt = Color(0xFF121722);
  static const Color surface = Color(0xFF151B24);
  static const Color surfaceAlt = Color(0xFF1C2430);
  static const Color border = Color(0xFF232C3A);
  static const Color textMuted = Color(0xFF9EA7B5);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final bodyTheme = GoogleFonts.titilliumWebTextTheme(base.textTheme);
    final displayTheme = GoogleFonts.bebasNeueTextTheme(base.textTheme);
    final mergedTheme = bodyTheme.copyWith(
      displayLarge: displayTheme.displayLarge,
      displayMedium: displayTheme.displayMedium,
      displaySmall: displayTheme.displaySmall,
      headlineLarge: displayTheme.headlineLarge,
      headlineMedium: displayTheme.headlineMedium,
      headlineSmall: displayTheme.headlineSmall,
    );

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: base.colorScheme.copyWith(
        primary: f1Red,
        secondary: f1RedBright,
        surface: surface,
        background: background,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.bebasNeue(
          color: Colors.white,
          fontSize: 26,
          letterSpacing: 1.2,
        ),
      ),
      textTheme: mergedTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      dividerColor: border,
    );
  }
}
