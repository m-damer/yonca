import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the design system honest: screens use tokens (lib/theme/tokens.dart, lib/theme/palette.dart),
/// never raw sizes, radii or colours. If this fails, add the value to the tokens instead of the screen.
void main() {
  final files = [
    for (final e in Directory('lib').listSync(recursive: true))
      if (e is File && e.path.endsWith('.dart') && !e.path.contains('/l10n/') && !e.path.startsWith('lib/theme/') && !e.path.startsWith('lib/diagnostics/')) e,
  ];

  // Files of the theme folder other than the two token files must not hold a raw colour either.
  final themeFiles = [
    for (final e in Directory('lib/theme').listSync(recursive: true))
      if (e is File && e.path.endsWith('.dart') && !e.path.endsWith('/tokens.dart') && !e.path.endsWith('/palette.dart')) e,
    if (Directory('lib/diagnostics').existsSync())
      for (final e in Directory('lib/diagnostics').listSync(recursive: true))
        if (e is File && e.path.endsWith('.dart')) e,
  ];

  List<String> find(RegExp re) => [
        for (final f in files)
          for (final (i, line) in f.readAsLinesSync().indexed)
            if (!line.trimLeft().startsWith('//') && re.hasMatch(line)) '${f.path}:${i + 1}: ${line.trim()}',
      ];

  test('font sizes come from AppFont', () {
    expect(find(RegExp(r'fontSize: *\d')), isEmpty);
  });

  test('corner radii come from AppRadius', () {
    expect(find(RegExp(r'Radius\.circular\(\d')), isEmpty);
  });

  test('font weights come from AppWeight', () {
    expect(find(RegExp(r'FontWeight\.')), isEmpty);
  });

  test('animation durations and curves come from AppMotion', () {
    expect(find(RegExp(r'duration: *(const )?Duration\(|Curves\.')), isEmpty);
  });

  test('widths, heights, icon sizes and line widths come from the size tokens', () {
    expect(find(RegExp(r'(?<![A-Za-z])(width|height|size|minWidth|minHeight|thickness): *-?[1-9]\d*(\.\d+)?\s*[,)]')), isEmpty);
  });

  test('letter spacing and gaps come from tokens', () {
    expect(find(RegExp(r'letterSpacing: *-?\d|(?<![A-Za-z])(spacing|runSpacing|gap): *\d')), isEmpty);
  });

  final rawColour = RegExp(r'Color\(\s*0x|Color\.from|Colors\.(?!transparent\b)\w+|withOpacity|withValues\(alpha: *[0-9.]');

  test('colours come from the palette', () {
    expect(find(rawColour), isEmpty);
  });

  test('the theme folder and diagnostics keep raw colours in tokens.dart and palette.dart only', () {
    expect([
      for (final f in themeFiles)
        for (final (i, line) in f.readAsLinesSync().indexed)
          if (!line.trimLeft().startsWith('//') && rawColour.hasMatch(line)) '${f.path}:${i + 1}: ${line.trim()}',
    ], isEmpty);
  });

  test('no colour is written into the Android layouts or drawables: they use @color from colors.xml', () {
    final raw = RegExp(r'"#[0-9A-Fa-f]{3,8}"');
    final hits = <String>[
      for (final dir in ['android/app/src/main/res/layout', 'android/app/src/main/res/drawable', 'android/app/src/main/res/drawable-v21'])
        if (Directory(dir).existsSync())
          for (final e in Directory(dir).listSync())
            if (e is File && e.path.endsWith('.xml'))
              for (final (i, line) in e.readAsLinesSync().indexed)
                if (raw.hasMatch(line)) '${e.path}:${i + 1}: ${line.trim()}',
    ];
    expect(hits, isEmpty);
  });

  test('padding and gaps come from AppSpace', () {
    expect(find(RegExp(r'EdgeInsets[A-Za-z.]*\([^()]*(?<![\w.])[1-9]')), isEmpty);
    expect(find(RegExp(r'SizedBox\((width|height): *[1-9]')), isEmpty);
  });

  test('icon sizes come from AppIcon', () {
    expect(find(RegExp(r'\bIcon\([^\n]*size: *\d')), isEmpty);
  });

  test('line heights come from AppLine', () {
    expect(find(RegExp(r'height: *\d+(\.\d+)? */ *\d|height: *1\.\d')), isEmpty);
  });

  test('button and search heights come from AppControl', () {
    expect(find(RegExp(r'(PillButton|SearchPill)\([^\n]*height: *\d')), isEmpty);
  });
}
