import 'package:flutter/material.dart';

import 'palette.dart';
import 'tokens.dart';

/// Light and dark palettes; [highContrast] darkens text and outlines.
YoncaPalette buildPalette(Brightness brightness, {bool highContrast = false}) {
  final dark = brightness == Brightness.dark;
  final p = dark ? YoncaPalette.dark : YoncaPalette.light;
  if (!highContrast) return p;
  return p.copyWith(
    text: dark ? AppHighContrast.textDark : AppHighContrast.textLight,
    text2: dark ? AppHighContrast.text2Dark : AppHighContrast.text2Light,
    outline: dark ? AppHighContrast.outlineDark : AppHighContrast.outlineLight,
    glassBorder: dark ? AppHighContrast.borderDark : AppHighContrast.borderLight,
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

/// Inter for Latin text. For Arabic the user picks `plex` (default), `noto`, `cairo`
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
  const latin = 'Inter';
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
    // The only shadow in the theme is the FAB's; its strength follows the mode.
    shadowColor: brightness == Brightness.dark ? AppShadow.dark : AppShadow.light,
    dividerColor: p.separator,
    // Named explicitly: a supplied textTheme keeps the platform default family (Roboto) otherwise.
    textTheme: _noTracking(base.textTheme).apply(fontFamily: family, fontFamilyFallback: fallback),
    primaryTextTheme: _noTracking(base.primaryTextTheme).apply(fontFamily: family, fontFamilyFallback: fallback),
    extensions: <ThemeExtension<dynamic>>[p],
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: p.onAccent,
      elevation: 4,
      focusColor: Colors.transparent,
      focusElevation: 4,
      hoverElevation: 4,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      sizeConstraints: const BoxConstraints.tightFor(width: 52, height: 52),
      extendedPadding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl),
      extendedIconLabelSpacing: 10,
      extendedSizeConstraints: const BoxConstraints.tightFor(height: 52),
      // Material replaces (not merges) the default style for these, so the chosen font is named here.
      extendedTextStyle: TextStyle(fontFamily: family, fontFamilyFallback: fallback, fontSize: AppFont.label, fontWeight: FontWeight.w600, letterSpacing: 0),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.toast,
      contentTextStyle: TextStyle(fontFamily: family, fontFamilyFallback: fallback, color: p.toastText, letterSpacing: 0),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.sheet,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl, vertical: AppSpace.xxl),
      titleTextStyle: TextStyle(fontFamily: family, fontFamilyFallback: fallback, fontSize: AppFont.lead, height: AppLine.tight, fontWeight: FontWeight.w600, color: p.text),
      contentTextStyle: TextStyle(fontFamily: family, fontFamilyFallback: fallback, fontSize: AppFont.body, height: AppLine.normal, color: p.text2),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.sheet,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(p.knob),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.surface2),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.transparent : p.glassBorder),
    ),
  );
}
