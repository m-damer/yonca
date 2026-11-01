import 'package:flutter/material.dart';

/// YONCA design tokens: every size, radius, space and fixed colour the UI uses lives in this file
/// (colours that change between light and dark live in palette.dart). Screens never write a raw
/// number or colour for these; change one value here and the whole app follows.

/// Type scale: font sizes by role. Pair with a weight (w400 body, w500 emphasis, w600 titles and buttons).
abstract final class AppFont {
  /// Smallest text: counters, captions.
  static const double tiny = 11;

  /// Badges, chips, small labels.
  static const double badge = 12;

  /// Secondary lines: subtitles, helper text.
  static const double meta = 13;
  static const double label = 14;

  /// Default reading size: rows, fields, buttons.
  static const double body = 15;
  static const double bodyL = 16;
  static const double subtitle = 17;
  static const double lead = 18;
  static const double title = 20;

  /// Page titles in the top bar.
  static const double pageTitle = 22;
  static const double headline = 24;

  /// Big titles (onboarding, permission screens).
  static const double display = 28;

  /// Money amount at the top of a deal.
  static const double amount = 34;
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

  /// Badges and small chips.
  static const double xs = 4;

  /// Buttons and chips.
  static const double sm = 6;

  /// Cards, rows, fields (the default).
  static const double md = 8;

  /// Sheets, dialogs.
  static const double lg = 12;

  /// Large tiles.
  static const double xl = 16;
}

/// Spacing scale (padding, gaps): a 4-point grid.
abstract final class AppSpace {
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
  static const double md = 40;
  static const double lg = 48;
  static const double xl = 56;

  /// Width of the small button in a header (Save, Back).
  static const double btnS = 80;
  static const double btnM = 120;
  static const double btnL = 160;
}

/// Colours of tags (picked by index), the same in light and dark.
abstract final class AppTint {
  static const tags = [
    Color(0xFFF4B8B0),
    Color(0xFFF6CFA3),
    Color(0xFFF3E3A0),
    Color(0xFFC9E4A8),
    Color(0xFFA8DDC4),
    Color(0xFFA5DDE0),
    Color(0xFFA8C8F0),
    Color(0xFFC3BCF0),
    Color(0xFFE0B8EC),
    Color(0xFFF0B6D2),
    Color(0xFFCFC2B2),
    Color(0xFFB9C6CE),
  ];
}

/// Colours of the printed report (PDF): fixed, because paper is always white.
abstract final class PrintInk {
  static const ink = Color(0xFF16211B);
  static const soft = Color(0xFF5B6B62);
  static const divider = Color(0xFFD1D1D6);
  static const paper = Colors.white;
}
