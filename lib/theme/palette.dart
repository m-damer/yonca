import 'package:flutter/material.dart';

/// Colours of the "Four Leaves" look (docs/DESIGN.md): the four logo greens by role.
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
    required this.header,
    required this.onHeader,
    required this.headerSoft,
    required this.accent,
    required this.onAccent,
    required this.leaves,
    required this.hotBg,
    required this.hotFg,
    required this.warmBg,
    required this.warmFg,
    required this.coldBg,
    required this.coldFg,
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

  /// Header band (forest green in light, deep green in dark) and what sits on it.
  final Color header;
  final Color onHeader;
  final Color headerSoft;

  /// Mint accent: floating button, active chip, call button.
  final Color accent;
  final Color onAccent;

  /// The four logo greens: avatars, pipeline bar.
  final List<Color> leaves;

  /// Status colours stay red, amber and blue so green never doubles as a status.
  final Color hotBg;
  final Color hotFg;
  final Color warmBg;
  final Color warmFg;
  final Color coldBg;
  final Color coldFg;

  static const light = YoncaPalette(
    bg: Color(0xFFF1F7F2),
    text: Color(0xFF10241A),
    text2: Color(0xFF43584C),
    glass: Color(0xFFFFFFFF),
    glassBorder: Color(0xFFDCE8DF),
    primary: Color(0xFF17562B),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFC9F2DE),
    onPrimaryContainer: Color(0xFF0F3A1F),
    outline: Color(0xFF6F8177),
    track: Color(0xFFD9EFE2),
    navBar: Color(0xFFFFFFFF),
    error: Color(0xFFBA1A1A),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    sheet: Color(0xFFFFFFFF),
    scrim: Color.fromRGBO(16, 36, 26, .45),
    toast: Color(0xFF26302B),
    toastText: Color(0xFFFFFFFF),
    blobOpacity: 0,
    header: Color(0xFF17562B),
    onHeader: Color(0xFFFFFFFF),
    headerSoft: Color.fromRGBO(255, 255, 255, .14),
    accent: Color(0xFF8DE5C0),
    onAccent: Color(0xFF0F3A1F),
    leaves: [Color(0xFF226B36), Color(0xFF8DE5C0), Color(0xFF0D8A78), Color(0xFF2F8A7A)],
    hotBg: Color(0xFFFFDAD6),
    hotFg: Color(0xFF8C1D18),
    warmBg: Color(0xFFFFE9B8),
    warmFg: Color(0xFF6E4A00),
    coldBg: Color(0xFFD3E8F7),
    coldFg: Color(0xFF0B4A6E),
  );

  static const dark = YoncaPalette(
    bg: Color(0xFF0C1713),
    text: Color(0xFFE3EEE8),
    text2: Color(0xFFA5B8AE),
    glass: Color(0xFF13241D),
    glassBorder: Color(0xFF223730),
    primary: Color(0xFFA8F0D0),
    onPrimary: Color(0xFF08301F),
    primaryContainer: Color(0xFF1F4A3B),
    onPrimaryContainer: Color(0xFFC9F2DE),
    outline: Color(0xFF6B7F75),
    track: Color(0xFF2A3B34),
    navBar: Color(0xFF0F1D18),
    error: Color(0xFFFFB4AB),
    errorContainer: Color(0xFF3D1F1D),
    onErrorContainer: Color(0xFFFFDAD6),
    sheet: Color(0xFF13241D),
    scrim: Color.fromRGBO(0, 0, 0, .62),
    toast: Color(0xFFDCE9E2),
    toastText: Color(0xFF0C1713),
    blobOpacity: 0,
    header: Color(0xFF0F2F22),
    onHeader: Color(0xFFFFFFFF),
    headerSoft: Color.fromRGBO(255, 255, 255, .12),
    accent: Color(0xFFA8F0D0),
    onAccent: Color(0xFF08301F),
    leaves: [Color(0xFF2E8A4B), Color(0xFFA8F0D0), Color(0xFF1FB09A), Color(0xFF3FB09A)],
    hotBg: Color(0xFF4A2420),
    hotFg: Color(0xFFFFB4A8),
    warmBg: Color(0xFF4A3A12),
    warmFg: Color(0xFFFFD98A),
    coldBg: Color(0xFF173E57),
    coldFg: Color(0xFF9ADBFF),
  );

  @override
  YoncaPalette copyWith({Color? primary, Color? onPrimary, Color? primaryContainer, Color? header, Color? accent, Color? onAccent, Color? bg, Color? track, Color? text, Color? text2, Color? outline, Color? glassBorder}) => YoncaPalette(
        bg: bg ?? this.bg,
        text: text ?? this.text,
        text2: text2 ?? this.text2,
        glass: glass,
        glassBorder: glassBorder ?? this.glassBorder,
        primary: primary ?? this.primary,
        onPrimary: onPrimary ?? this.onPrimary,
        primaryContainer: primaryContainer ?? this.primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        outline: outline ?? this.outline,
        track: track ?? this.track,
        navBar: navBar,
        error: error,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        sheet: sheet,
        scrim: scrim,
        toast: toast,
        toastText: toastText,
        blobOpacity: blobOpacity,
        header: header ?? this.header,
        onHeader: onHeader,
        headerSoft: headerSoft,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        leaves: leaves,
        hotBg: hotBg,
        hotFg: hotFg,
        warmBg: warmBg,
        warmFg: warmFg,
        coldBg: coldBg,
        coldFg: coldFg,
      );

  @override
  YoncaPalette lerp(ThemeExtension<YoncaPalette>? other, double t) =>
      t < .5 ? this : (other as YoncaPalette? ?? this);
}

extension YoncaPaletteContext on BuildContext {
  YoncaPalette get palette => Theme.of(this).extension<YoncaPalette>()!;
}
