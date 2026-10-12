import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const ink = Color(0xFF111512);
  static const charcoal = Color(0xFF171717);
  static const darkBackground = Color(0xFF020319);
  static const darkSurface = Color(0xFF100E22);
  static const darkSurfaceVariant = Color(0xFF18172C);
  static const gold = Color(0xFFE3AB5B);
  // Darkened for WCAG AA contrast (>=4.5:1) on white/light surfaces.
  static const goldDark = Color(0xFF9A6A24);
  static const green = Color(0xFF2F7454);
  static const greenLight = Color(0xFF65B77B);
  static const blue = Color(0xFF0B357C);
  // Material 3 accessible "danger" red (AA on white/light and on-error surfaces).
  static const danger = Color(0xFFB3261E);
  // Bright error red reserved for DARK surfaces (AA on darkBackground/Surface).
  static const dangerDark = Color(0xFFF87171);
  static const onDangerDark = Color(0xFF450A0A);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);

  static const lightBackground = Color(0xFFF8F9FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFEEF1F6);
  static const lightPrimary = blue;
  static const lightTextSecondary = Color(0xFF5D6159);
  static const darkTextSecondary = Color(0xFFA8AAA2);
}
