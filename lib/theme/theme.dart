import 'package:flutter/material.dart';

import 'palette.dart';

/// Roboto for English, Noto Sans Arabic for Arabic; each falls back to the other.
ThemeData buildYoncaTheme(Brightness brightness, {bool arabic = false}) {
  final p = brightness == Brightness.light ? YoncaPalette.light : YoncaPalette.dark;
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
    fontFamily: arabic ? 'NotoSansArabic' : 'Roboto',
    fontFamilyFallback: arabic ? const ['Roboto'] : const ['NotoSansArabic'],
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
