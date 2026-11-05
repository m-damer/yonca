import 'package:flutter/material.dart';

/// YONCA design tokens: every size, radius, space and fixed colour the UI uses lives in this file
/// (colours that change between light and dark live in palette.dart). Screens never write a raw
/// number or colour for these; change one value here and the whole app follows.

/// Type scale: font sizes by role. Pair with a weight (w400 body, w500 emphasis, w600 titles and buttons).
abstract final class AppFont {
  /// Captions, helper text, timestamps, chips, filter pills, tab labels, avatar initials.
  static const double tiny = 12;
  static const double badge = 12;
  static const double meta = 12;

  /// Names, titles, row labels, field values, body text, buttons.
  static const double label = 14;
  static const double body = 14;
  static const double bodyL = 14;
  static const double subtitle = 14;

  /// Header: screen titles, big names and amounts inside a screen.
  static const double lead = 18;
  static const double title = 18;
  static const double pageTitle = 18;

  /// Big titles on full-screen pages (onboarding, permission, about), in steps of 4.
  static const double headline = 24;
  static const double display = 28;

  /// Money amount at the top of a deal.
  static const double amount = 32;
  static const double hero = 56;

  /// Alarm clock time.
  static const double clock = 72;
}

/// Line height as a multiple of the font size.
abstract final class AppLine {
  static const double tight = 1.2;
  static const double snug = 1.3;

  /// Default for body text.
  static const double normal = 1.4;
  static const double relaxed = 1.5;
  static const double loose = 1.6;

  /// Large display text that sits on several lines.
  static const double airy = 2.0;
}

/// Corner radii.
abstract final class AppRadius {
  /// Handles, small marks.
  static const double xxs = 2;

  /// Step bars, small marks.
  static const double xs = 4;

  /// Selected segment inside a segmented control, small tiles.
  static const double sm = 12;

  /// Cards, rows, fields, buttons, icon buttons (the default).
  static const double md = 16;

  /// Sheets, dialogs.
  static const double lg = 16;

  /// Large tiles.
  static const double xl = 16;

  /// Chips, filter pills, toggles.
  static const double pill = 999;
}

/// Spacing scale (padding, gaps): a 4-point grid.
abstract final class AppSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double x3 = 28;
  static const double x4 = 32;
  static const double x5 = 40;
  static const double x7 = 56;

  /// Bottom padding of scrolling lists, so the last row clears the floating button.
  static const double fabClear = 152;
}

/// Icon sizes.
abstract final class AppIcon {
  static const double xs = 12;
  static const double sm = 16;

  /// Default in rows and buttons.
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 28;
  static const double xxl = 32;
  static const double x3 = 40;
}

/// Heights of tappable controls (buttons, search fields, rows) and widths of compact buttons.
abstract final class AppControl {
  static const double sm = 32;

  /// Filter pills and chips.
  static const double chip = 36;
  /// Square holder of an icon (settings rows, list rows, sheets).
  static const double tile = 40;
  static const double md = 44;
  static const double lg = 48;
  static const double xl = 56;

  /// Large icon tile (empty states, permission and onboarding screens).
  static const double hero = 80;

  /// Width of the small button in a header (Save, Back).
  static const double btnS = 80;
  static const double btnM = 120;
  static const double btnL = 160;
}

/// Colours of tags (picked by index), the same in light and dark.
abstract final class AppTint {
  /// Twelve pastels about 30 degrees of hue apart (red, orange, yellow, lime, green, teal, cyan, blue, indigo,
  /// purple, pink, slate), so no two read as the same colour. All light enough for [tagInk] text on top.
  static const tags = [
    Color(0xFFF2A7A0),
    Color(0xFFF5C28A),
    Color(0xFFF2E08A),
    Color(0xFFD3E69A),
    Color(0xFF9FDBA8),
    Color(0xFF94DCD0),
    Color(0xFF9BD9EE),
    Color(0xFF9DBDF2),
    Color(0xFFB4AEF0),
    Color(0xFFD9A8EE),
    Color(0xFFF2A8CC),
    Color(0xFFB8BEC4),
  ];

  /// The ten colours a deal stage can have, all different: neutral, blue, yellow, purple, orange, green, red,
  /// teal, pink, indigo. Won is always index 5 (green) and Lost index 6 (red). Pastels on light, deep tones on
  /// dark, so the normal text colour reads on both.
  static const stagesLight = [
    Color(0xFFE3DED6),
    Color(0xFFB5DDF0),
    Color(0xFFF3E7A8),
    Color(0xFFD4C4F0),
    Color(0xFFF6D3A8),
    Color(0xFFCDE6B0),
    Color(0xFFF4C2BE),
    Color(0xFFB3E2D6),
    Color(0xFFF3C0DA),
    Color(0xFFBCCBF3),
  ];
  static const stagesDark = [
    Color(0xFF3A3733),
    Color(0xFF2F4A5E),
    Color(0xFF5A4E22),
    Color(0xFF483A62),
    Color(0xFF5E4126),
    Color(0xFF2F4F3A),
    Color(0xFF5E2E2E),
    Color(0xFF275049),
    Color(0xFF5E3249),
    Color(0xFF363E6A),
  ];

  /// Text on a tag-coloured chip: the tag colours are the same in light and dark, so the ink is too.
  static const tagInk = Color(0xFF2B2622);
}

/// Colours of the printed report (PDF): fixed, because paper is always white.
abstract final class PrintInk {
  static const ink = Color(0xFF16211B);
  static const soft = Color(0xFF5B6B62);
  static const divider = Color(0xFFD1D1D6);
  static const paper = Colors.white;
}
