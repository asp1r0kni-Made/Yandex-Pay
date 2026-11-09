import 'package:flutter/material.dart';

/// Оригинальная цветовая схема «Сплит Банк»: глубокий тёмно-бирюзовый
/// в сочетании с фиолетовым и акцентным янтарным — не повторяет
/// палитру существующих платёжных приложений.
class AppColors {
  static const Color background = Color(0xFF0B1020);
  static const Color surface = Color(0xFF151B2E);
  static const Color surfaceAlt = Color(0xFF1E2640);
  static const Color primary = Color(0xFF5B21B6); // глубокий фиолетовый
  static const Color primaryLight = Color(0xFF7C3AED);
  static const Color teal = Color(0xFF0C4A6E); // глубокий бирюзовый
  static const Color accent = Color(0xFFFFB74D); // янтарный акцент
  static const Color textPrimary = Color(0xFFF5F6FA);
  static const Color textSecondary = Color(0xFF9AA3B8);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, primary],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E2640), Color(0xFF5B21B6)],
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primaryLight,
      secondary: AppColors.accent,
      surface: AppColors.surface,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
      fontFamily: 'Roboto',
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.textPrimary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
