import 'package:flutter/material.dart';

class AppColors {
  // Background colors
  static const bg = Color(0xFF0D1117);
  static const panel = Color(0xFF161B22);
  static const card = Color(0xFF1C2333);
  static const node = Color(0xFF1E2A3A);

  // Border colors
  static const border = Color(0xFF30363D);
  static const borderHi = Color(0xFF58A6FF);

  // Text colors
  static const text = Color(0xFFE6EDF3);
  static const text2 = Color(0xFF8B949E);
  static const text3 = Color(0xFF484F58);

  // Accent colors
  static const blue = Color(0xFF58A6FF);
  static const green = Color(0xFF3FB950);
  static const orange = Color(0xFFD29922);
  static const red = Color(0xFFF85149);
  static const purple = Color(0xFFBC8CFF);
  static const yellow = Color(0xFFE3B341);
  static const cyan = Color(0xFF39D353);

  // Category colors
  static const catProxy = Color(0xFF58A6FF);
  static const catRecon = Color(0xFF3FB950);
  static const catExploit = Color(0xFFF85149);
  static const catCred = Color(0xFFD29922);
  static const catLateral = Color(0xFFBC8CFF);
  static const catNtlm = Color(0xFFE3B341);
  static const catDomain = Color(0xFF39D353);
  static const catDC = Color(0xFFFF7B72);
  static const catUtil = Color(0xFF8B949E);

  // Risk colors
  static const riskCritical = Color(0xFFF85149);
  static const riskHigh = Color(0xFFD29922);
  static const riskMedium = Color(0xFFE3B341);
  static const riskLow = Color(0xFF3FB950);
  static const riskNone = Color(0xFF8B949E);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.blue,
        secondary: AppColors.green,
        surface: AppColors.panel,
        error: AppColors.red,
      ),
      fontFamily: 'Consolas',
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.text, fontSize: 13),
        bodyMedium: TextStyle(color: AppColors.text2, fontSize: 11),
        bodySmall: TextStyle(color: AppColors.text3, fontSize: 10),
        labelLarge: TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w600),
      ),
      dividerColor: AppColors.border,
      cardColor: AppColors.card,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.blue),
        ),
        hintStyle: const TextStyle(color: AppColors.text3, fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.border),
        thickness: WidgetStateProperty.all(3),
      ),
    );
  }
}
