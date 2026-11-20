import 'package:flutter/material.dart';

abstract final class AppColors {
  static const accent = Color(0xFF42634F);
  static const accentLight = Color(0xFFA9C4AE);
  static const paper = Color(0xFFF5F4EF);
  static const paperCard = Color(0xFFFFFEFA);
  static const charcoal = Color(0xFF1D211E);
  static const charcoalCard = Color(0xFF282E29);
  static const mutedLight = Color(0xFF646A63);
  static const mutedDark = Color(0xFFB6BDB5);
  static const lineLight = Color(0xFFDFE1D9);
  static const lineDark = Color(0xFF424A43);

  // Compatibility colors used by the existing screens while they adopt the
  // new theme tokens. They resolve to the same restrained green palette.
  static const ink = charcoal;
  static const midnight = charcoalCard;
  static const porcelain = paper;
  static const teal = accent;
  static const brass = accentLight;
  static const muted = mutedLight;
  static const border = lineLight;
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? AppColors.charcoal : AppColors.paper;
    final surface = isDark ? AppColors.charcoalCard : AppColors.paperCard;
    final foreground = isDark
        ? const Color(0xFFF2F0E9)
        : const Color(0xFF252A25);
    final muted = isDark ? AppColors.mutedDark : AppColors.mutedLight;
    final line = isDark ? AppColors.lineDark : AppColors.lineLight;
    final accent = isDark ? AppColors.accentLight : AppColors.accent;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
      surface: surface,
      primary: accent,
      onPrimary: isDark ? AppColors.charcoal : Colors.white,
      onSurface: foreground,
      secondary: accent,
      onSecondary: isDark ? AppColors.charcoal : Colors.white,
      outline: line,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: base.textTheme
          .apply(bodyColor: foreground, displayColor: foreground)
          .copyWith(
            displayLarge: const TextStyle(
              fontSize: 38,
              height: 1.08,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.2,
            ),
            headlineMedium: const TextStyle(
              fontSize: 27,
              height: 1.18,
              fontWeight: FontWeight.w600,
              letterSpacing: -.6,
            ),
            titleLarge: const TextStyle(
              fontSize: 19,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: const TextStyle(fontSize: 16, height: 1.45),
            bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: muted),
          ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: TextStyle(color: foreground),
      ),
      dividerColor: line,
      sliderTheme: base.sliderTheme.copyWith(activeTrackColor: accent),
    );
  }
}
