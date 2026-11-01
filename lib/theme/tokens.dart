import 'package:flutter/material.dart';

/// YONCA design tokens: every size, radius, space and fixed colour the UI uses lives in this file
/// (colours that change between light and dark live in palette.dart). Screens never write a raw
/// number or colour for these; change one value here and the whole app follows.

/// Type scale: font sizes by role. Pair with a weight (w400 body, w500 emphasis, w600 titles and buttons).
abstract final class AppFont {
  static const double nano = 10.5;
  static const double tiny = 11;
  static const double tiny2 = 11.5;

  /// Badges, chips, counters, small labels.
  static const double badge = 12;
  static const double hint = 12.5;

  /// Secondary lines: subtitles, captions, helper text.
  static const double meta = 13;
  static const double meta2 = 13.5;
  static const double label = 14;

  /// Default reading size: rows, fields, buttons.
  static const double body = 15;
  static const double bodyL = 16;
  static const double subtitle = 17;
  static const double lead = 18;
  static const double lead2 = 19;
  static const double title = 20;

  /// Page titles in the top bar.
  static const double pageTitle = 22;
  static const double headline = 24;
  static const double headline2 = 26;

  /// Big titles (onboarding, permission screens).
  static const double display = 28;

  /// Money amount at the top of a deal.
  static const double amount = 34;
  static const double hero = 56;

  /// Alarm clock time.
  static const double clock = 72;
}

/// Corner radii.
abstract final class AppRadius {
  static const double hair = 1;
  static const double xxs = 3;

  /// Badges and small chips.
  static const double xs = 4;
  static const double xs2 = 5;

  /// Buttons and chips.
  static const double sm = 6;

  /// Cards, rows, fields (the default).
  static const double md = 8;
  static const double md2 = 9;

  /// Sheets, large tiles.
  static const double lg = 12;
  static const double lg2 = 15;
  static const double xl = 16;
}

/// Spacing scale (padding, gaps). Odd values that match the design pixel for pixel stay as numbers.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
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
