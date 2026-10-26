import 'package:flutter/material.dart';

/// Colours from docs/tokens.json (glass.light and glass.dark).
@immutable
class YoncaPalette extends ThemeExtension<YoncaPalette> {
  const YoncaPalette({
    required this.bg,
    required this.text,
    required this.text2,
    required this.glass,
    required this.glassBorder,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.outline,
    required this.track,
    required this.navBar,
    required this.error,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.sheet,
    required this.scrim,
    required this.toast,
    required this.toastText,
    required this.blobOpacity,
  });

  final Color bg;
  final Color text;
  final Color text2;
  final Color glass;
  final Color glassBorder;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color outline;
  final Color track;
  final Color navBar;
  final Color error;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color sheet;
  final Color scrim;
  final Color toast;
  final Color toastText;
  final double blobOpacity;

  static const light = YoncaPalette(
    bg: Color(0xFFEAF4EF),
    text: Color(0xFF14201B),
    text2: Color(0xFF47574F),
    glass: Color.fromRGBO(255, 255, 255, .66),
    glassBorder: Color.fromRGBO(255, 255, 255, .95),
    primary: Color(0xFF0B6E5E),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFBDF0DD),
    onPrimaryContainer: Color(0xFF00201A),
    outline: Color(0xFF7B8B83),
    track: Color(0xFFCFE0D6),
    navBar: Color.fromRGBO(255, 255, 255, .82),
    error: Color(0xFFBA1A1A),
    errorContainer: Color.fromRGBO(255, 218, 214, .85),
    onErrorContainer: Color(0xFF410002),
    sheet: Color.fromRGBO(255, 255, 255, .96),
    scrim: Color.fromRGBO(20, 32, 27, .45),
    toast: Color(0xFF26302B),
    toastText: Color(0xFFFFFFFF),
    blobOpacity: 1,
  );

  static const dark = YoncaPalette(
    bg: Color(0xFF0C1713),
    text: Color(0xFFE3EEE8),
    text2: Color(0xFFA5B8AE),
    glass: Color.fromRGBO(255, 255, 255, .07),
    glassBorder: Color.fromRGBO(255, 255, 255, .13),
    primary: Color(0xFF5FD9BE),
    onPrimary: Color(0xFF00382E),
    primaryContainer: Color(0xFF1D4A40),
    onPrimaryContainer: Color(0xFFBDF0DD),
    outline: Color(0xFF6B7F75),
    track: Color(0xFF2A3B34),
    navBar: Color.fromRGBO(16, 28, 24, .9),
    error: Color(0xFFFFB4AB),
    errorContainer: Color.fromRGBO(147, 0, 10, .5),
    onErrorContainer: Color(0xFFFFDAD6),
    sheet: Color.fromRGBO(24, 38, 32, .98),
    scrim: Color.fromRGBO(0, 0, 0, .62),
    toast: Color(0xFFDCE9E2),
    toastText: Color(0xFF0C1713),
    blobOpacity: .5,
  );

  @override
  YoncaPalette copyWith() => this;

  @override
  YoncaPalette lerp(ThemeExtension<YoncaPalette>? other, double t) =>
      t < .5 ? this : (other as YoncaPalette? ?? this);
}

extension YoncaPaletteContext on BuildContext {
  YoncaPalette get palette => Theme.of(this).extension<YoncaPalette>()!;
}
