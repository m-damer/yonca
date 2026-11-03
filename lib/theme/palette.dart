import 'package:flutter/material.dart';

/// Colours of the app (Clay): warm cream and ink surfaces with one terracotta accent (light and dark).
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
    required this.leadBg,
    required this.leadFg,
    required this.supplierBg,
    required this.supplierFg,
    required this.surface2,
    required this.separator,
    required this.avBg,
    required this.avFg,
    required this.wonBg,
    required this.wonFg,
    required this.handle,
    required this.sheetLine,
    required this.segmentOn,
    required this.segmentShadow,
    required this.switchOff,
    required this.chipFill,
    required this.swatchBorder,
    required this.swatchBorderStrong,
    required this.scrimSoft,
    required this.noticeBg,
    required this.noticeFg,
    required this.noticeInk,
    required this.noteDot,
    required this.meetDot,
    required this.calTask,
    required this.calMeet,
    required this.calEvent,
    required this.viewerBg,
    required this.onViewer,
    required this.onDanger,
    required this.onMedia,
    required this.qrPaper,
    required this.whatsapp,
    required this.radioOff,
    required this.onTint,
    required this.skeleton,
    required this.logoLeaves,
    required this.knob,
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
  final Color leadBg;
  final Color leadFg;
  final Color supplierBg;
  final Color supplierFg;

  /// Chips and secondary buttons, row dividers, avatar tile, and the soft green of a won deal.
  final Color surface2;
  final Color separator;
  final Color avBg;
  final Color avFg;
  final Color wonBg;
  final Color wonFg;

  /// Drag-handle dots.
  final Color handle;

  /// Line of an outlined secondary button and of the sheet grabber.
  final Color sheetLine;

  /// Selected segment of a segmented control.
  final Color segmentOn;

  /// Shadow under the selected segment.
  final Color segmentShadow;

  /// Track of a switch or radio that is off.
  final Color switchOff;

  /// Fill of a small input chip.
  final Color chipFill;

  /// Hairline around a colour swatch.
  final Color swatchBorder;

  /// Hairline around a bigger colour swatch.
  final Color swatchBorderStrong;

  /// Dim behind a press-and-hold menu.
  final Color scrimSoft;

  /// Warning banner fill.
  final Color noticeBg;

  /// Warning banner icon and strong text.
  final Color noticeFg;

  /// Warning banner body text.
  final Color noticeInk;

  /// Orange dot for a contact with a temporary note.
  final Color noteDot;

  /// Calendar dot of a meeting.
  final Color meetDot;

  /// Calendar task colour.
  final Color calTask;

  /// Calendar meeting colour.
  final Color calMeet;

  /// Calendar event colour.
  final Color calEvent;

  /// Background of the PDF and image viewer.
  final Color viewerBg;

  /// Text on the viewer.
  final Color onViewer;

  /// Text and icons on a red fill.
  final Color onDanger;

  /// Icons and text over photos and the dim.
  final Color onMedia;

  /// White paper behind a QR code (must stay white to scan).
  final Color qrPaper;

  /// WhatsApp swipe action.
  final Color whatsapp;

  /// Ring of a radio button that is off.
  final Color radioOff;

  /// Check marks and text on the pastel tag and stage colours.
  final Color onTint;

  /// Grey of loading placeholders.
  final Color skeleton;

  /// The four leaves of the logo.
  final List<Color> logoLeaves;

  /// Knob of a switch.
  final Color knob;

  static const light = YoncaPalette(
    bg: Color(0xFFF0EEE6),
    text: Color(0xFF141413),
    text2: Color(0xFF66655E),
    glass: Color(0xFFFAF9F5),
    glassBorder: Color(0xFFDDD9CC),
    primary: Color(0xFF9C4A2B),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE6E2D6),
    onPrimaryContainer: Color(0xFF3D3D3A),
    outline: Color(0xFF66655E),
    track: Color(0xFFE6E2D6),
    navBar: Color(0xFFFAF9F5),
    error: Color(0xFF9B1C3A),
    errorContainer: Color(0xFFFBE3E6),
    onErrorContainer: Color(0xFF9B1C3A),
    sheet: Color(0xFFFAF9F5),
    scrim: Color.fromRGBO(20, 20, 19, .4),
    toast: Color(0xFF141413),
    toastText: Color(0xFFFAF9F5),
    blobOpacity: 0,
    header: Color(0xFFF0EEE6),
    onHeader: Color(0xFF141413),
    headerSoft: Color(0xFFFAF9F5),
    accent: Color(0xFF9C4A2B),
    onAccent: Color(0xFFFFFFFF),
    leaves: [Color(0xFF9C4A2B), Color(0xFFB5651D), Color(0xFF2E7D5B), Color(0xFF66655E)],
    hotBg: Color(0xFFFBE3E6),
    hotFg: Color(0xFF9B1C3A),
    warmBg: Color(0xFFFFF0D6),
    warmFg: Color(0xFF7A4A00),
    coldBg: Color(0xFFE1ECFA),
    coldFg: Color(0xFF1F4E8C),
    leadBg: Color(0xFFEAE3F6),
    leadFg: Color(0xFF4C3487),
    supplierBg: Color(0xFFFBE8D0),
    supplierFg: Color(0xFF8A4A0A),
    surface2: Color(0xFFE6E2D6),
    separator: Color(0xFFDDD9CC),
    avBg: Color(0xFFE6E2D6),
    avFg: Color(0xFF3D3D3A),
    wonBg: Color(0xFFDDF3E4),
    wonFg: Color(0xFF1B5E36),
    handle: Color(0xFFB8B3A3),
    sheetLine: Color(0xFFDDD9CC),
    segmentOn: Color(0xFFFAF9F5),
    segmentShadow: Color(0x00000000),
    switchOff: Color(0xFFE6E2D6),
    chipFill: Color(0xFFE6E2D6),
    swatchBorder: Color(0x14000000),
    swatchBorderStrong: Color(0x1A000000),
    scrimSoft: Color(0x66000000),
    noticeBg: Color(0xFFFBE3E6),
    noticeFg: Color(0xFF9B1C3A),
    noticeInk: Color(0xFF141413),
    noteDot: Color(0xFFB5651D),
    meetDot: Color(0xFFB5651D),
    calTask: Color(0xFF9C4A2B),
    calMeet: Color(0xFFB5651D),
    calEvent: Color(0xFF2E7D5B),
    viewerBg: Color(0xFF141413),
    onViewer: Color(0xB3FFFFFF),
    onDanger: Color(0xFFFFFFFF),
    onMedia: Color(0xFFFFFFFF),
    qrPaper: Color(0xFFFFFFFF),
    whatsapp: Color(0xFF2E7D5B),
    radioOff: Color(0xFFB8B3A3),
    onTint: Color(0xFF141413),
    skeleton: Color(0x14000000),
    logoLeaves: [Color(0xFF9C4A2B), Color(0xFFB5651D), Color(0xFFD9825F), Color(0xFFE6B8A2)],
    knob: Color(0xFFFAF9F5),
  );

  static const dark = YoncaPalette(
    bg: Color(0xFF1F1E1B),
    text: Color(0xFFF0EEE6),
    text2: Color(0xFFA8A59B),
    glass: Color(0xFF2A2926),
    glassBorder: Color(0xFF45433D),
    primary: Color(0xFFD9825F),
    onPrimary: Color(0xFF1F1E1B),
    primaryContainer: Color(0xFF363430),
    onPrimaryContainer: Color(0xFFD6D3C8),
    outline: Color(0xFFA8A59B),
    track: Color(0xFF363430),
    navBar: Color(0xFF2A2926),
    error: Color(0xFFFFB4BE),
    errorContainer: Color(0xFF4A2229),
    onErrorContainer: Color(0xFFFFB4BE),
    sheet: Color(0xFF2A2926),
    scrim: Color.fromRGBO(0, 0, 0, .6),
    toast: Color(0xFFF0EEE6),
    toastText: Color(0xFF1F1E1B),
    blobOpacity: 0,
    header: Color(0xFF1F1E1B),
    onHeader: Color(0xFFF0EEE6),
    headerSoft: Color(0xFF2A2926),
    accent: Color(0xFFD9825F),
    onAccent: Color(0xFF1F1E1B),
    leaves: [Color(0xFFD9825F), Color(0xFFE0A15A), Color(0xFF5FBF92), Color(0xFFA8A59B)],
    hotBg: Color(0xFF4A2229),
    hotFg: Color(0xFFFFB4BE),
    warmBg: Color(0xFF4A3612),
    warmFg: Color(0xFFF5CD7A),
    coldBg: Color(0xFF1E3A57),
    coldFg: Color(0xFFA6CFF5),
    leadBg: Color(0xFF352A4F),
    leadFg: Color(0xFFC9B8F0),
    supplierBg: Color(0xFF4A3414),
    supplierFg: Color(0xFFF2C48A),
    surface2: Color(0xFF363430),
    separator: Color(0xFF45433D),
    avBg: Color(0xFF363430),
    avFg: Color(0xFFD6D3C8),
    wonBg: Color(0xFF1C4030),
    wonFg: Color(0xFF9FDDB8),
    handle: Color(0xFF5A574F),
    sheetLine: Color(0xFF45433D),
    segmentOn: Color(0xFF2A2926),
    segmentShadow: Color(0x00000000),
    switchOff: Color(0xFF363430),
    chipFill: Color(0xFF363430),
    swatchBorder: Color(0x14000000),
    swatchBorderStrong: Color(0x1A000000),
    scrimSoft: Color(0x66000000),
    noticeBg: Color(0xFF4A2229),
    noticeFg: Color(0xFFFFB4BE),
    noticeInk: Color(0xFFF0EEE6),
    noteDot: Color(0xFFE0A15A),
    meetDot: Color(0xFFE0A15A),
    calTask: Color(0xFFD9825F),
    calMeet: Color(0xFFE0A15A),
    calEvent: Color(0xFF5FBF92),
    viewerBg: Color(0xFF141413),
    onViewer: Color(0xB3FFFFFF),
    onDanger: Color(0xFFFFFFFF),
    onMedia: Color(0xFFFFFFFF),
    qrPaper: Color(0xFFFFFFFF),
    whatsapp: Color(0xFF2E7D5B),
    radioOff: Color(0xFF5A574F),
    onTint: Color(0xFF141413),
    skeleton: Color(0x14FFFFFF),
    logoLeaves: [Color(0xFFD9825F), Color(0xFFE0A15A), Color(0xFFD9825F), Color(0xFFA8A59B)],
    knob: Color(0xFFF0EEE6),
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
        leadBg: leadBg,
        leadFg: leadFg,
        supplierBg: supplierBg,
        supplierFg: supplierFg,
        surface2: surface2,
        separator: separator,
        avBg: avBg,
        avFg: avFg,
        wonBg: wonBg,
        wonFg: wonFg,
        handle: handle,
        sheetLine: sheetLine,
        segmentOn: segmentOn,
        segmentShadow: segmentShadow,
        switchOff: switchOff,
        chipFill: chipFill,
        swatchBorder: swatchBorder,
        swatchBorderStrong: swatchBorderStrong,
        scrimSoft: scrimSoft,
        noticeBg: noticeBg,
        noticeFg: noticeFg,
        noticeInk: noticeInk,
        noteDot: noteDot,
        meetDot: meetDot,
        calTask: calTask,
        calMeet: calMeet,
        calEvent: calEvent,
        viewerBg: viewerBg,
        onViewer: onViewer,
        onDanger: onDanger,
        onMedia: onMedia,
        qrPaper: qrPaper,
        whatsapp: whatsapp,
        radioOff: radioOff,
        onTint: onTint,
        skeleton: skeleton,
        logoLeaves: logoLeaves,
        knob: knob,
      );

  @override
  YoncaPalette lerp(ThemeExtension<YoncaPalette>? other, double t) =>
      t < .5 ? this : (other as YoncaPalette? ?? this);
}

extension YoncaPaletteContext on BuildContext {
  YoncaPalette get palette => Theme.of(this).extension<YoncaPalette>()!;
}
