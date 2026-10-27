import 'package:flutter/material.dart';

/// Colours of the app: flat neutral surfaces with one blue accent (light and dark).
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
    required this.surface2,
    required this.separator,
    required this.avBg,
    required this.avFg,
    required this.wonBg,
    required this.wonFg,
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

  /// Chips and secondary buttons, row dividers, avatar tile, and the soft green of a won deal.
  final Color surface2;
  final Color separator;
  final Color avBg;
  final Color avFg;
  final Color wonBg;
  final Color wonFg;

  static const light = YoncaPalette(
    bg: Color(0xFFF2F2F7),
    text: Color(0xFF1C1C1E),
    text2: Color(0xFF636366),
    glass: Color(0xFFFFFFFF),
    glassBorder: Color(0xFFD1D1D6),
    primary: Color(0xFF0062CC),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE9E9EE),
    onPrimaryContainer: Color(0xFF0062CC),
    outline: Color(0xFF636366),
    track: Color(0xFFD1D1D6),
    navBar: Color(0xFFFFFFFF),
    error: Color(0xFFC5281C),
    errorContainer: Color(0xFFFFE5E2),
    onErrorContainer: Color(0xFFA3261B),
    sheet: Color(0xFFFFFFFF),
    scrim: Color.fromRGBO(0, 0, 0, .4),
    toast: Color(0xFF1C1C1E),
    toastText: Color(0xFFFFFFFF),
    blobOpacity: 0,
    header: Color(0xFFF2F2F7),
    onHeader: Color(0xFF1C1C1E),
    headerSoft: Color(0xFFFFFFFF),
    accent: Color(0xFF0062CC),
    onAccent: Color(0xFFFFFFFF),
    leaves: [Color(0xFF0062CC), Color(0xFF4D8FD6), Color(0xFF8CB6E4), Color(0xFF636366)],
    hotBg: Color(0xFFFFE5E2),
    hotFg: Color(0xFFA3261B),
    warmBg: Color(0xFFFFF0D6),
    warmFg: Color(0xFF7A4A00),
    coldBg: Color(0xFFE1ECFA),
    coldFg: Color(0xFF1F4E8C),
    surface2: Color(0xFFE9E9EE),
    separator: Color(0xFFE5E5EA),
    avBg: Color(0xFFE5E5EA),
    avFg: Color(0xFF3A3A3C),
    wonBg: Color(0xFFDDF3E4),
    wonFg: Color(0xFF1B5E36),
  );

  static const dark = YoncaPalette(
    bg: Color(0xFF000000),
    text: Color(0xFFF2F2F7),
    text2: Color(0xFF98989F),
    glass: Color(0xFF1C1C1E),
    glassBorder: Color(0xFF38383A),
    primary: Color(0xFF409CFF),
    onPrimary: Color(0xFF00152E),
    primaryContainer: Color(0xFF2C2C2E),
    onPrimaryContainer: Color(0xFF409CFF),
    outline: Color(0xFF98989F),
    track: Color(0xFF38383A),
    navBar: Color(0xFF1C1C1E),
    error: Color(0xFFFF8A80),
    errorContainer: Color(0xFF4A2420),
    onErrorContainer: Color(0xFFFFB4A6),
    sheet: Color(0xFF1C1C1E),
    scrim: Color.fromRGBO(0, 0, 0, .6),
    toast: Color(0xFFF2F2F7),
    toastText: Color(0xFF1C1C1E),
    blobOpacity: 0,
    header: Color(0xFF000000),
    onHeader: Color(0xFFF2F2F7),
    headerSoft: Color(0xFF1C1C1E),
    accent: Color(0xFF409CFF),
    onAccent: Color(0xFF00152E),
    leaves: [Color(0xFF409CFF), Color(0xFF2E78C7), Color(0xFF1F5A99), Color(0xFF98989F)],
    hotBg: Color(0xFF4A2420),
    hotFg: Color(0xFFFFB4A6),
    warmBg: Color(0xFF4A3612),
    warmFg: Color(0xFFF5CD7A),
    coldBg: Color(0xFF1E3A57),
    coldFg: Color(0xFFA6CFF5),
    surface2: Color(0xFF2C2C2E),
    separator: Color(0xFF2C2C2E),
    avBg: Color(0xFF2C2C2E),
    avFg: Color(0xFFD1D1D6),
    wonBg: Color(0xFF1C4030),
    wonFg: Color(0xFF9FDDB8),
  );

  @override
  YoncaPalette copyWith({
    Color? bg, Color? text, Color? text2, Color? glass, Color? glassBorder, Color? primary, Color? onPrimary,
    Color? primaryContainer, Color? onPrimaryContainer, Color? outline, Color? track, Color? navBar, Color? sheet,
    Color? header, Color? accent, Color? onAccent, List<Color>? leaves,
  }) =>
      YoncaPalette(
        bg: bg ?? this.bg,
        text: text ?? this.text,
        text2: text2 ?? this.text2,
        glass: glass ?? this.glass,
        glassBorder: glassBorder ?? this.glassBorder,
        primary: primary ?? this.primary,
        onPrimary: onPrimary ?? this.onPrimary,
        primaryContainer: primaryContainer ?? this.primaryContainer,
        onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
        outline: outline ?? this.outline,
        track: track ?? this.track,
        navBar: navBar ?? this.navBar,
        error: error,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        sheet: sheet ?? this.sheet,
        scrim: scrim,
        toast: toast,
        toastText: toastText,
        blobOpacity: blobOpacity,
        header: header ?? this.header,
        onHeader: onHeader,
        headerSoft: headerSoft,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        leaves: leaves ?? this.leaves,
        hotBg: hotBg,
        hotFg: hotFg,
        warmBg: warmBg,
        warmFg: warmFg,
        coldBg: coldBg,
        coldFg: coldFg,
        surface2: surface2,
        separator: separator,
        avBg: avBg,
        avFg: avFg,
        wonBg: wonBg,
        wonFg: wonFg,
      );

  @override
  YoncaPalette lerp(ThemeExtension<YoncaPalette>? other, double t) =>
      t < .5 ? this : (other as YoncaPalette? ?? this);
}

extension YoncaPaletteContext on BuildContext {
  YoncaPalette get palette => Theme.of(this).extension<YoncaPalette>()!;
}
