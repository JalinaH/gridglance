import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color f1Red;
  final Color f1RedBright;
  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textMuted;

  const AppColors({
    required this.f1Red,
    required this.f1RedBright,
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textMuted,
  });

  @override
  AppColors copyWith({
    Color? f1Red,
    Color? f1RedBright,
    Color? background,
    Color? backgroundAlt,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textMuted,
  }) {
    return AppColors(
      f1Red: f1Red ?? this.f1Red,
      f1RedBright: f1RedBright ?? this.f1RedBright,
      background: background ?? this.background,
      backgroundAlt: backgroundAlt ?? this.backgroundAlt,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      f1Red: Color.lerp(f1Red, other.f1Red, t) ?? f1Red,
      f1RedBright:
          Color.lerp(f1RedBright, other.f1RedBright, t) ?? f1RedBright,
      background: Color.lerp(background, other.background, t) ?? background,
      backgroundAlt:
          Color.lerp(backgroundAlt, other.backgroundAlt, t) ?? backgroundAlt,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t) ?? surfaceAlt,
      border: Color.lerp(border, other.border, t) ?? border,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
    );
  }

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ?? AppTheme.darkColors;
  }
}

class AppTheme {
  static const Color f1Red = Color(0xFFE10600);
  static const Color f1RedBright = Color(0xFFFF3B30);
  static const AppColors darkColors = AppColors(
    f1Red: f1Red,
    f1RedBright: f1RedBright,
    background: Color(0xFF0C0F14),
    backgroundAlt: Color(0xFF121722),
    surface: Color(0xFF151B24),
    surfaceAlt: Color(0xFF1C2430),
    border: Color(0xFF232C3A),
    textMuted: Color(0xFF9EA7B5),
  );

  static const AppColors lightColors = AppColors(
    f1Red: f1Red,
    f1RedBright: f1RedBright,
    background: Color(0xFFF8F9FC),
    backgroundAlt: Color(0xFFEFF2F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF4F6FA),
    border: Color(0xFFDCE1EA),
    textMuted: Color(0xFF5A6576),
  );

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
        primary: darkColors.f1Red,
        secondary: darkColors.f1RedBright,
        surface: darkColors.surface,
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
      dividerColor: darkColors.border,
      extensions: [darkColors],
    );
  }

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
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
        primary: lightColors.f1Red,
        secondary: lightColors.f1RedBright,
        surface: lightColors.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: GoogleFonts.bebasNeue(
          color: Colors.black87,
          fontSize: 26,
          letterSpacing: 1.2,
        ),
      ),
      textTheme: mergedTheme.apply(
        bodyColor: Colors.black87,
        displayColor: Colors.black87,
      ),
      dividerColor: lightColors.border,
      extensions: [lightColors],
    );
  }
}
