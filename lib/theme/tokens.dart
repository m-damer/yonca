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

  /// Text whose box is exactly the font size (counters, big clock digits).
  static const double flat = 1.0;
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

  /// Between xs and sm / between md and lg: tight chip gaps and compact rows.
  static const double x6 = 6;
  static const double x14 = 14;

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

/// Font weights: the only four the app uses.
abstract final class AppWeight {
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semibold = FontWeight.w600;
  static const bold = FontWeight.w700;
}

/// Space between letters, in logical pixels.
abstract final class AppTracking {
  /// Small caps-style labels.
  static const double wide = 1;

  /// The spaced-out YONCA word mark.
  static const double logo = 6;
}

/// Line and border widths.
abstract final class AppStroke {
  /// Dividers, card outlines.
  static const double hairline = 1;
  static const double thin = 1.5;

  /// Selection rings, checkbox and radio outlines, the active tab bar.
  static const double regular = 2;
}

/// Animation timing and curves. Business timers (voice meter tick, splash minimum) are not styling and stay in code.
abstract final class AppMotion {
  /// Small state changes: a chip, a pressed button, a toggle.
  static const fast = Duration(milliseconds: 150);

  /// Moving between pages, scrolling to a row, a bar growing.
  static const normal = Duration(milliseconds: 250);
  static const curve = Curves.easeOut;

  /// How long a snack bar message stays: short notice, normal, and one with an Undo.
  static const toastShort = Duration(seconds: 2);
  static const toast = Duration(seconds: 8);
  static const toastUndo = Duration(seconds: 10);
  static const curveSmooth = Curves.easeInOutCubic;
}

/// Fixed dimensions of marks, swatches, avatars, tiles and logos, named by their size in logical pixels.
/// Components pick the step they need; nothing writes a raw number.
abstract final class AppSize {
  static const double s3 = 3;
  static const double s4 = 4;
  static const double s5 = 5;
  static const double s6 = 6;
  static const double s7 = 7;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s21 = 21;
  static const double s22 = 22;
  static const double s24 = 24;
  static const double s26 = 26;
  static const double s30 = 30;
  static const double s34 = 34;
  static const double s36 = 36;
  static const double s38 = 38;
  static const double s40 = 40;
  static const double s44 = 44;
  static const double s46 = 46;
  static const double s48 = 48;
  static const double s52 = 52;
  static const double s54 = 54;
  static const double s56 = 56;
  static const double s64 = 64;
  static const double s66 = 66;
  static const double s68 = 68;
  static const double s80 = 80;
  static const double s84 = 84;
  static const double s88 = 88;
  static const double s96 = 96;
  static const double s110 = 110;
  static const double s134 = 134;
  static const double s160 = 160;

  /// Count badge: height (14 * 1.4 line plus padding) and minimum width.
  /// Height of the bar chart in the report.
  static const double chartH = 128.4;
  static const double badgeH = 20.8;
  static const double badgeMinW = 23.2;
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

/// Strengths for a colour made see-through (`colour.withValues(alpha: AppAlpha.soft)`): the screens never write a raw number.
abstract final class AppAlpha {
  static const hairline = .08;
  static const faint = .12;
  static const soft = .22;
  static const muted = .35;
  static const disabled = .4;
  static const subdued = .6;
  static const dim = .7;
  static const strong = .8;
  static const high = .85;
}

/// The darker text and outlines of the High contrast setting.
abstract final class AppHighContrast {
  static const textLight = Color(0xFF000000);
  static const textDark = Color(0xFFFFFFFF);
  static const text2Light = Color(0xFF3A3A3C);
  static const text2Dark = Color(0xFFE5E5EA);
  static const outlineLight = Color(0xFF3A3A3C);
  static const outlineDark = Color(0xFFD1D1D6);
  static const borderLight = Color(0xFF636366);
  static const borderDark = Color(0xFF8E8E93);
}

/// The one shadow in the theme (the floating button's), by mode.
abstract final class AppShadow {
  static const light = Color(0x2E000000);
  static const dark = Color(0x80000000);
}

/// The flag drawn next to a Syrian phone number: fixed colours, because a flag is not themed.
abstract final class AppFlag {
  static const green = Color(0xFF007A3D);
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const red = Color(0xFFCE1126);
}

/// Colours of the printed report (PDF): fixed, because paper is always white.
abstract final class PrintInk {
  static const ink = Color(0xFF16211B);
  static const soft = Color(0xFF5B6B62);
  static const divider = Color(0xFFD1D1D6);
  static const paper = Colors.white;
}
