import 'package:flutter/material.dart';

import 'palette.dart';

/// Roboto for English, Noto Sans Arabic for Arabic; each falls back to the other.
/// Main colour choices (light primary, dark primary); index 0 is the original forest green.
const accentChoices = <(Color, Color)>[
  (Color(0xFF17562B), Color(0xFFA8F0D0)),
  (Color(0xFF0B5F66), Color(0xFF9FE3EA)),
  (Color(0xFF1F4E8C), Color(0xFFB3CEF7)),
  (Color(0xFF6A2C70), Color(0xFFE9BEEE)),
  (Color(0xFF8A4A2A), Color(0xFFF2C4A6)),
];

YoncaPalette buildPalette(Brightness brightness, {int accent = 0, bool highContrast = false}) {
  final dark = brightness == Brightness.dark;
  var p = dark ? YoncaPalette.dark : YoncaPalette.light;
  final i = accent.clamp(0, accentChoices.length - 1);
  if (i != 0) {
    final c = dark ? accentChoices[i].$2 : accentChoices[i].$1;
    final hsl = HSLColor.fromColor(accentChoices[i].$1);
    p = p.copyWith(
      primary: c,
      header: dark ? hsl.withLightness(.18).toColor() : accentChoices[i].$1,
      primaryContainer: dark ? hsl.withLightness(.24).toColor() : hsl.withLightness(.88).withSaturation(.5).toColor(),
      // The floating button, active chips and the call button follow the chosen colour too.
      accent: dark ? accentChoices[i].$2 : hsl.withLightness(.82).withSaturation(.55).toColor(),
      onAccent: dark ? hsl.withLightness(.12).toColor() : hsl.withLightness(.14).toColor(),
      bg: dark ? hsl.withLightness(.06).withSaturation(.2).toColor() : hsl.withLightness(.965).withSaturation(.25).toColor(),
      track: dark ? hsl.withLightness(.2).withSaturation(.2).toColor() : hsl.withLightness(.9).withSaturation(.3).toColor(),
    );
  }
  if (highContrast) {
    p = p.copyWith(
      text: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
      text2: dark ? const Color(0xFFE6EEE9) : const Color(0xFF1F2A24),
      outline: dark ? const Color(0xFFC7D4CC) : const Color(0xFF2E3B34),
      glassBorder: dark ? const Color(0xFF8FA399) : const Color(0xFF5E7066),
    );
  }
  return p;
}

ThemeData buildYoncaTheme(Brightness brightness,
    {bool arabic = false, int accent = 0, bool highContrast = false, bool systemFont = false, bool indicDigits = false}) {
  final p = buildPalette(brightness, accent: accent, highContrast: highContrast);
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B6E5E),
    brightness: brightness,
  ).copyWith(
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.primaryContainer,
    onPrimaryContainer: p.onPrimaryContainer,
    surface: p.bg,
    onSurface: p.text,
    onSurfaceVariant: p.text2,
    outline: p.outline,
    error: p.error,
    errorContainer: p.errorContainer,
    onErrorContainer: p.onErrorContainer,
    scrim: p.scrim,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: indicDigits ? 'YoncaIndicDigits' : (arabic && !systemFont ? 'NotoSansArabic' : 'Roboto'),
    fontFamilyFallback: [
      if (indicDigits) (arabic && !systemFont ? 'NotoSansArabic' : 'Roboto'),
      if (arabic && !systemFont) 'Roboto' else if (!arabic) 'NotoSansArabic',
    ],
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: <ThemeExtension<dynamic>>[p],
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: p.onAccent,
      extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
      extendedSizeConstraints: const BoxConstraints.tightFor(height: 60),
      extendedTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.toast,
      contentTextStyle: TextStyle(color: p.toastText),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
