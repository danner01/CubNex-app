import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const ink = Color(0xFF111512);
  static const charcoal = Color(0xFF171717);
  static const darkBackground = Color(0xFF0D0D0D);
  static const darkSurface = Color(0xFF1A1A1A);
  static const darkSurfaceVariant = Color(0xFF242424);
static const gold = Color(0xFFD4AF37);
  // Darkened for WCAG AA contrast (>=4.5:1) on white/light surfaces;
  // still >=3:1 on dark surfaces for non-text/UI use.
  static const goldDark = Color(0xFF8A6D0F);
  // Natural cacao-leaf greens used by the ConKkao identity.
  static const green = Color(0xFF2F7454);
  static const greenLight = Color(0xFF65B77B);
  static const blue = Color(0xFF2563EB);
  // Material 3 accessible "danger" red (AA on white/light and on-error surfaces).
  static const danger = Color(0xFFB3261E);
  // Bright error red reserved for DARK surfaces (AA on darkBackground/Surface).
  static const dangerDark = Color(0xFFF87171);
  static const onDangerDark = Color(0xFF450A0A);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);

  static const lightBackground = Color(0xFFF5F4EF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFEFEDE6);
  static const lightPrimary = ink;
  static const lightTextSecondary = Color(0xFF5D6159);
  static const darkTextSecondary = Color(0xFFA8AAA2);
}
