import 'package:flutter/material.dart';

import 'palette.dart';

/// Light and dark palettes; [highContrast] darkens text and outlines.
YoncaPalette buildPalette(Brightness brightness, {bool highContrast = false}) {
  final dark = brightness == Brightness.dark;
  final p = dark ? YoncaPalette.dark : YoncaPalette.light;
  if (!highContrast) return p;
  return p.copyWith(
    text: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
    text2: dark ? const Color(0xFFE5E5EA) : const Color(0xFF3A3A3C),
    outline: dark ? const Color(0xFFD1D1D6) : const Color(0xFF3A3A3C),
    glassBorder: dark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
  );
}

/// Same text styles with no letter-spacing (the design uses 0 everywhere).
TextTheme _noTracking(TextTheme t) => t.copyWith(
      displayLarge: t.displayLarge?.copyWith(letterSpacing: 0),
      displayMedium: t.displayMedium?.copyWith(letterSpacing: 0),
      displaySmall: t.displaySmall?.copyWith(letterSpacing: 0),
      headlineLarge: t.headlineLarge?.copyWith(letterSpacing: 0),
      headlineMedium: t.headlineMedium?.copyWith(letterSpacing: 0),
      headlineSmall: t.headlineSmall?.copyWith(letterSpacing: 0),
      titleLarge: t.titleLarge?.copyWith(letterSpacing: 0),
      titleMedium: t.titleMedium?.copyWith(letterSpacing: 0),
      titleSmall: t.titleSmall?.copyWith(letterSpacing: 0),
      bodyLarge: t.bodyLarge?.copyWith(letterSpacing: 0),
      bodyMedium: t.bodyMedium?.copyWith(letterSpacing: 0),
      bodySmall: t.bodySmall?.copyWith(letterSpacing: 0),
      labelLarge: t.labelLarge?.copyWith(letterSpacing: 0),
      labelMedium: t.labelMedium?.copyWith(letterSpacing: 0),
      labelSmall: t.labelSmall?.copyWith(letterSpacing: 0),
    );

/// IBM Plex Sans for Latin text. For Arabic the user picks `plex` (default), `noto`, `cairo`
/// or `system` (the phone's own font); each falls back to the other script's font.
ThemeData buildYoncaTheme(Brightness brightness,
    {bool arabic = false, bool highContrast = false, String arabicFont = 'plex', bool indicDigits = false}) {
  final p = buildPalette(brightness, highContrast: highContrast);
  final system = arabicFont == 'system';
  final arabicFamily = switch (arabicFont) {
    'cairo' => 'Cairo',
    'noto' => 'NotoSansArabic',
    _ => 'IBMPlexSansArabic',
  };
  const latin = 'IBMPlexSans';
  final scheme = ColorScheme.fromSeed(seedColor: p.primary, brightness: brightness).copyWith(
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.primaryContainer,
    onPrimaryContainer: p.onPrimaryContainer,
    surface: p.bg,
    onSurface: p.text,
    onSurfaceVariant: p.text2,
    outline: p.outline,
    outlineVariant: p.separator,
    error: p.error,
    errorContainer: p.errorContainer,
    onErrorContainer: p.onErrorContainer,
    scrim: p.scrim,
  );
  final family = indicDigits ? 'YoncaIndicDigits' : (arabic && !system ? arabicFamily : latin);
  final fallback = <String>[
    if (indicDigits) (arabic && !system ? arabicFamily : latin),
    if (arabic && !system) latin else if (!arabic) arabicFamily,
  ];
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  return ThemeData(
    useMaterial3: true,
    fontFamily: family,
    fontFamilyFallback: fallback,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    dividerColor: p.separator,
    textTheme: _noTracking(base.textTheme),
    extensions: <ThemeExtension<dynamic>>[p],
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: p.onAccent,
      elevation: 4,
      focusColor: Colors.transparent,
      focusElevation: 4,
      hoverElevation: 4,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      sizeConstraints: const BoxConstraints.tightFor(width: 52, height: 52),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
      extendedSizeConstraints: const BoxConstraints.tightFor(height: 52),
      // Material replaces (not merges) the default style for these, so the chosen font is named here.
      extendedTextStyle: TextStyle(fontFamily: family, fontFamilyFallback: fallback, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.toast,
      contentTextStyle: TextStyle(fontFamily: family, fontFamilyFallback: fallback, color: p.toastText, letterSpacing: 0),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.sheet,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.sheet,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Color(0xFFFFFFFF)),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.glassBorder),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}
