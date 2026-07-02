import 'package:flutter/material.dart';

import '../../modules/business/data/models/store_customization_model.dart';
import 'app_colors.dart';

class StoreBrandTheme {
  StoreBrandTheme.fromCustomization(
    StoreCustomizationModel customization,
    Brightness brightness,
  ) : primary = parseStoreColor(
        customization.primaryColor,
        fallback: AppColors.gold,
      ),
      secondary = parseStoreColor(
        customization.secondaryColor,
        fallback: brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
      ),
      accent = parseStoreColor(
        customization.accentColor,
        fallback: AppColors.greenLight,
      ),
      background = parseStoreColor(
        customization.backgroundColor,
        fallback: brightness == Brightness.dark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
      ),
      requestedText = parseStoreColor(
        customization.textColor,
        fallback: brightness == Brightness.dark ? Colors.white : AppColors.ink,
      ),
      requestedHeadingText = parseStoreColor(
        customization.headingTextColor,
        fallback: brightness == Brightness.dark ? Colors.white : AppColors.ink,
      ),
      requestedSecondaryText = parseStoreColor(
        customization.secondaryTextColor,
        fallback: brightness == Brightness.dark
            ? Colors.white70
            : AppColors.lightTextSecondary,
      ),
      fontFamily = customization.fontFamily.trim().isEmpty
          ? 'Inter'
          : customization.fontFamily.trim(),
      gradientStart = parseStoreColor(
        customization.gradientStart,
        fallback: AppColors.gold,
      ),
      gradientEnd = parseStoreColor(
        customization.gradientEnd,
        fallback: AppColors.greenLight,
      ),
      gradientDirection = customization.gradientDirection,
      gradientEnabled = customization.gradientEnabled;

  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color requestedText;
  final Color requestedHeadingText;
  final Color requestedSecondaryText;
  final String fontFamily;
  final Color gradientStart;
  final Color gradientEnd;
  final String gradientDirection;
  final bool gradientEnabled;

  Color get onPrimary => readableOn(primary);
  Color get onAccent => readableOn(accent);
  Color get onBackground => readableOn(background, preferred: requestedText);
  Color get headingOnBackground =>
      readableOn(background, preferred: requestedHeadingText);
  Color get secondaryOnBackground =>
      readableOn(background, preferred: requestedSecondaryText);
  Color get surface => Color.alphaBlend(
    readableOn(background).withValues(alpha: 0.06),
    background,
  );
  Color get onSurface => readableOn(surface, preferred: requestedText);
  Color get headingOnSurface =>
      readableOn(surface, preferred: requestedHeadingText);
  Color get secondaryOnSurface =>
      readableOn(surface, preferred: requestedSecondaryText);

  LinearGradient get heroGradient {
    if (gradientEnabled) {
      return LinearGradient(
        begin: _gradientBegin,
        end: _gradientEnd,
        colors: [gradientStart, gradientEnd],
      );
    }
    return LinearGradient(colors: [primary, secondary, accent]);
  }

  ThemeData applyTo(ThemeData base) {
    final scheme = base.colorScheme.copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: accent,
      onSecondary: onAccent,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: Color.alphaBlend(
        onSurface.withValues(alpha: 0.08),
        surface,
      ),
      outlineVariant: Color.alphaBlend(
        onSurface.withValues(alpha: 0.18),
        surface,
      ),
    );

    final baseTextTheme = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: onBackground,
      displayColor: headingOnBackground,
    );
    final brandedTextTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        color: headingOnBackground,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        color: headingOnBackground,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        color: headingOnBackground,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        color: headingOnBackground,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        color: headingOnBackground,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        color: headingOnBackground,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(color: headingOnSurface),
      titleMedium: baseTextTheme.titleMedium?.copyWith(color: headingOnSurface),
      titleSmall: baseTextTheme.titleSmall?.copyWith(color: headingOnSurface),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: onSurface),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: onSurface),
      bodySmall: baseTextTheme.bodySmall?.copyWith(color: secondaryOnSurface),
      labelLarge: baseTextTheme.labelLarge?.copyWith(fontFamily: fontFamily),
      labelMedium: baseTextTheme.labelMedium?.copyWith(fontFamily: fontFamily),
      labelSmall: baseTextTheme.labelSmall?.copyWith(fontFamily: fontFamily),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: brandedTextTheme,
      cardTheme: base.cardTheme.copyWith(
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onBackground,
          side: BorderSide(color: onBackground.withValues(alpha: 0.34)),
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Alignment get _gradientBegin {
    return switch (gradientDirection) {
      'horizontal' => Alignment.centerLeft,
      'diagonal' => Alignment.topLeft,
      _ => Alignment.topCenter,
    };
  }

  Alignment get _gradientEnd {
    return switch (gradientDirection) {
      'horizontal' => Alignment.centerRight,
      'diagonal' => Alignment.bottomRight,
      _ => Alignment.bottomCenter,
    };
  }
}

Color parseStoreColor(String? value, {required Color fallback}) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return fallback;
  final normalized = raw.replaceFirst('#', '');
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  return Color(int.tryParse(hex, radix: 16) ?? fallback.toARGB32());
}

String normalizeHexColor(String value, {required String fallback}) {
  final raw = value.trim().replaceFirst('#', '').toUpperCase();
  if (RegExp(r'^[0-9A-F]{6}$').hasMatch(raw)) return '#$raw';
  if (RegExp(r'^[0-9A-F]{8}$').hasMatch(raw)) return '#${raw.substring(2)}';
  return fallback;
}

Color readableOn(Color background, {Color? preferred}) {
  if (preferred != null && contrastRatio(background, preferred) >= 3.2) {
    return preferred;
  }
  final whiteRatio = contrastRatio(background, Colors.white);
  final blackRatio = contrastRatio(background, AppColors.ink);
  return whiteRatio >= blackRatio ? Colors.white : AppColors.ink;
}

double contrastRatio(Color a, Color b) {
  final lightA = a.computeLuminance();
  final lightB = b.computeLuminance();
  final lighter = lightA > lightB ? lightA : lightB;
  final darker = lightA > lightB ? lightB : lightA;
  return (lighter + 0.05) / (darker + 0.05);
}
