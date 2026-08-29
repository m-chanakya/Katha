import 'package:flutter/material.dart';

/// A warm palette nodding to Telugu culture — turmeric, peacock teal,
/// temple maroon — as a placeholder brand until custom illustration and
/// a mascot character are designed.
class AppColors {
  AppColors._();

  static const turmeric = Color(0xFFE8A33D);
  static const peacockTeal = Color(0xFF0E7C7B);
  static const maroon = Color(0xFF7A2E2E);
  static const cream = Color(0xFFFFF8ED);
  static const ink = Color(0xFF2B2118);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.peacockTeal,
      primary: AppColors.peacockTeal,
      secondary: AppColors.turmeric,
      surface: AppColors.cream,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
        bodyLarge: TextStyle(color: AppColors.ink),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.peacockTeal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}
