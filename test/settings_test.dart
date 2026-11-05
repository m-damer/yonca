import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/app_controller.dart';
import 'package:yonca/main.dart';
import 'package:yonca/features/settings/permissions_page.dart';
import 'package:yonca/features/settings/settings_page.dart';
import 'package:yonca/theme/theme.dart';

void main() {
  test('palette is fixed blue; high contrast darkens text', () {
    final light = buildPalette(Brightness.light);
    final dark = buildPalette(Brightness.dark);
    final strong = buildPalette(Brightness.light, highContrast: true);
    expect(light.primary, const Color(0xFF9C4A2B));
    expect(dark.primary, const Color(0xFFD9825F));
    expect(dark.bg, const Color(0xFF1F1E1B));
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

  testWidgets('permissions check lists every permission and offers a test reminder', (tester) async {
    final c = AppController();
    await tester.pumpWidget(YoncaApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permissions check'));
    await tester.pumpAndSettle();
    expect(find.byType(PermissionsPage), findsOneWidget);
    for (final t in ['Install unknown apps', 'Notifications', 'Exact alarms', 'Full-screen alerts', 'Contacts', 'Files for local backup', 'Run in the background']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Send test reminder', skipOffstage: false), findsOneWidget);
  });
}
