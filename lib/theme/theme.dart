import 'package:flutter/material.dart';

import 'palette.dart';

ThemeData buildYoncaTheme(Brightness brightness) {
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
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: <ThemeExtension<dynamic>>[p],
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.toast,
      contentTextStyle: TextStyle(color: p.toastText),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
