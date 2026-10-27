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

(Color, Color)? _seedFor(int accent, (Color, Color)? phone) {
  if (accent < 0) return phone ?? accentChoices[4];
  if (accent > 0) return accentChoices[accent.clamp(0, accentChoices.length - 1)];
  return null;
}

/// [accent] -1 follows the phone (its Material You colours, or warm brown when it has none),
/// 0 is the original forest green, 1 and up are the fixed swatches.
YoncaPalette buildPalette(Brightness brightness, {int accent = 0, bool highContrast = false, (Color, Color)? phone}) {
  final dark = brightness == Brightness.dark;
  var p = dark ? YoncaPalette.dark : YoncaPalette.light;
  final seed = _seedFor(accent, phone);
  if (seed != null) {
    final c = dark ? seed.$2 : seed.$1;
    final hsl = HSLColor.fromColor(seed.$1);
    Color tone(double l, double s, [double dh = 0]) => hsl.withHue((hsl.hue + dh) % 360).withLightness(l).withSaturation(s).toColor();
    final accentColor = dark ? seed.$2 : tone(.82, .55);
    p = p.copyWith(
      primary: c,
      onPrimary: dark ? tone(.12, .5) : const Color(0xFFFFFFFF),
      header: dark ? tone(.18, hsl.saturation) : seed.$1,
      primaryContainer: dark ? tone(.24, hsl.saturation) : tone(.88, .5),
      onPrimaryContainer: dark ? tone(.88, .5) : tone(.14, hsl.saturation),
      // The floating button, active chips and the call button follow the chosen colour too.
      accent: accentColor,
      onAccent: dark ? tone(.12, .5) : tone(.14, hsl.saturation),
      bg: dark ? tone(.06, .2) : tone(.965, .25),
      track: dark ? tone(.2, .2) : tone(.9, .3),
      glass: dark ? tone(.1, .2) : const Color(0xFFFFFFFF),
      glassBorder: dark ? tone(.18, .2) : tone(.9, .2),
      navBar: dark ? tone(.08, .2) : const Color(0xFFFFFFFF),
      sheet: dark ? tone(.1, .2) : const Color(0xFFFFFFFF),
      text: dark ? tone(.92, .12) : tone(.1, .3),
      text2: dark ? tone(.72, .1) : tone(.3, .15),
      outline: dark ? tone(.5, .1) : tone(.45, .1),
      // Avatars, pipeline bar and type dots: four shades of the chosen colour.
      leaves: dark
          ? [tone(.38, .5), accentColor, tone(.5, .55, 22), tone(.58, .5, -22)]
          : [tone(.28, .5), accentColor, tone(.34, .55, 22), tone(.4, .5, -22)],
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
    {bool arabic = false, int accent = 0, bool highContrast = false, String arabicFont = 'noto', bool indicDigits = false, (Color, Color)? phone}) {
  final p = buildPalette(brightness, accent: accent, highContrast: highContrast, phone: phone);
  final system = arabicFont == 'system';
  final arabicFamily = switch (arabicFont) {
    'cairo' => 'Cairo',
    'plex' => 'IBMPlexSansArabic',
    _ => 'NotoSansArabic',
  };
  final scheme = ColorScheme.fromSeed(
    seedColor: _seedFor(accent, phone)?.$1 ?? const Color(0xFF0B6E5E),
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
  final family = indicDigits ? 'YoncaIndicDigits' : (arabic && !system ? arabicFamily : 'Roboto');
  final fallback = <String>[
    if (indicDigits) (arabic && !system ? arabicFamily : 'Roboto'),
    if (arabic && !system) 'Roboto' else if (!arabic) arabicFamily,
  ];
  return ThemeData(
    useMaterial3: true,
    fontFamily: family,
    fontFamilyFallback: fallback,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: <ThemeExtension<dynamic>>[p],
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: p.onAccent,
      extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
      extendedSizeConstraints: const BoxConstraints.tightFor(height: 60),
      // Material replaces (not merges) the default style for these, so the chosen font is named here.
      extendedTextStyle: TextStyle(fontFamily: family, fontFamilyFallback: fallback, fontSize: 16, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.toast,
      contentTextStyle: TextStyle(fontFamily: family, fontFamilyFallback: fallback, color: p.toastText),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
