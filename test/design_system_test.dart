import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the design system honest: screens use tokens (lib/theme/tokens.dart, lib/theme/palette.dart),
/// never raw sizes, radii or colours. If this fails, add the value to the tokens instead of the screen.
void main() {
  final files = [
    for (final e in Directory('lib').listSync(recursive: true))
      if (e is File && e.path.endsWith('.dart') && !e.path.contains('/l10n/') && !e.path.startsWith('lib/theme/') && !e.path.startsWith('lib/diagnostics/')) e,
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

  test('colours come from the palette', () {
    expect(find(RegExp(r'Color\(0x|Colors\.(white|black|red|green|blue|grey|orange|yellow)\b')), isEmpty);
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
