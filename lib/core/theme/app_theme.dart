import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF101923);
  static const midnight = Color(0xFF192633);
  static const porcelain = Color(0xFFF6F4EF);
  static const teal = Color(0xFF2E827C);
  static const brass = Color(0xFFD6AE76);
  static const muted = Color(0xFFA8B5BB);
  static const border = Color(0xFF354653);
}

abstract final class AppTheme {
  static ThemeData get dark => _theme(
    brightness: Brightness.dark,
    background: AppColors.ink,
    surface: AppColors.midnight,
    foreground: AppColors.porcelain,
  );

  static ThemeData get light => _theme(
    brightness: Brightness.light,
    background: AppColors.porcelain,
    surface: Colors.white,
    foreground: AppColors.ink,
  );

  static ThemeData _theme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color foreground,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: brightness,
      surface: surface,
      onSurface: foreground,
      primary: brightness == Brightness.dark
          ? const Color(0xFF7ACBC1)
          : AppColors.teal,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme
          .apply(
            bodyColor: foreground,
            displayColor: foreground,
            fontFamily: 'sans-serif',
          )
          .copyWith(
            displayLarge: const TextStyle(
              fontSize: 42,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.6,
            ),
            headlineMedium: const TextStyle(
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.7,
            ),
            titleLarge: const TextStyle(
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
          ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: foreground.withValues(alpha: .10)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
