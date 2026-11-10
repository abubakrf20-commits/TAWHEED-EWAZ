import 'package:flutter/material.dart';

/// کوچک‌ترین صفحه‌بندی مشترک برای داشبورد مدیر.
class AdminTheme {
  static const Color primary = Color(0xFF1565C0);
  static const Color surface = Color(0xFFF4F6F9);
  static const Color card = Colors.white;

  static ThemeData theme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primary),
      scaffoldBackgroundColor: surface,
      cardTheme: const CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
  }
}
