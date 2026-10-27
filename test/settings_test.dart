import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/app_controller.dart';
import 'package:yonca/main.dart';
import 'package:yonca/features/settings/settings_page.dart';
import 'package:yonca/theme/theme.dart';

void main() {
  test('accent and high contrast change the palette', () {
    final base = buildPalette(Brightness.light);
    final blue = buildPalette(Brightness.light, accent: 2);
    final strong = buildPalette(Brightness.light, highContrast: true);
    expect(blue.primary, isNot(base.primary));
    expect(strong.text, const Color(0xFF000000));
    // Follow my phone with no phone colours falls back to warm brown; a custom colour is used when given.
    expect(buildPalette(Brightness.light, accent: -1).primary, accentChoices[accentFallback].$1);
    expect(buildPalette(Brightness.light, accent: accentCustom, custom: const Color(0xFF1F6FAE)).primary, const Color(0xFF1F6FAE));
    expect(readableAccent(const Color(0xFFFFEE88)), isNot(const Color(0xFFFFEE88)));
  });

  testWidgets('settings search filters the rows', (tester) async {
    final c = AppController();
    await tester.pumpWidget(YoncaApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'lang');
    await tester.pumpAndSettle();
    expect(find.text('Language and region'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No setting matches'), findsOneWidget);
  });

  testWidgets('first run shows onboarding until finished', (tester) async {
    final c = AppController(onboarded: false);
    await tester.pumpWidget(YoncaApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to YONCA'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(c.onboarded, isTrue);
    expect(find.text('Welcome to YONCA'), findsNothing);
  });
}
