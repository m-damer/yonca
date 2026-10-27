import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/app_controller.dart';
import 'package:yonca/main.dart';
import 'package:yonca/features/settings/settings_page.dart';
import 'package:yonca/theme/theme.dart';

void main() {
  test('palette is fixed blue; high contrast darkens text', () {
    final light = buildPalette(Brightness.light);
    final dark = buildPalette(Brightness.dark);
    final strong = buildPalette(Brightness.light, highContrast: true);
    expect(light.primary, const Color(0xFF0062CC));
    expect(dark.primary, const Color(0xFF409CFF));
    expect(dark.bg, const Color(0xFF000000));
    expect(strong.text, const Color(0xFF000000));
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
