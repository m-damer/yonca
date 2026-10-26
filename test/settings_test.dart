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
    expect(buildPalette(Brightness.dark, accent: 99).primary, buildPalette(Brightness.dark, accent: 4).primary);
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
    expect(find.text('High contrast'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'lang');
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('High contrast'), findsNothing);
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
