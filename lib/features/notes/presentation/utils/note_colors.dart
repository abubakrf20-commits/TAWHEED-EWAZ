import 'package:flutter/material.dart';

class NoteColors {
  NoteColors._();

  static const List<Color> palette = [
    Color(0x00000000), // 0: Default
    Color(0xFFB3D4FF), // 1: Blue 30%
    Color(0xFFB3E3B3), // 2: Green 30%
    Color(0xFFFFD1A8), // 3: Orange 30%
    Color(0xFFFFB3B3), // 4: Red 30%
    Color(0xFFFFF0CC), // 5: Cream
  ];

  static const List<String> labels = [
    'پیش‌فرض',
    'آبی',
    'سبز',
    'نارنجی',
    'قرمز',
    'کرمی',
  ];

  static Color getColor(int index) {
    if (index < 0 || index >= palette.length) return palette[0];
    return palette[index];
  }

  static String getLabel(int index) {
    if (index < 0 || index >= labels.length) return labels[0];
    return labels[index];
  }

  static bool isLightBackground(int index) {
    return true;
  }
}
