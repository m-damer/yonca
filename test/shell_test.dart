import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/app_controller.dart';
import 'package:yonca/data/crash_log.dart';
import 'package:yonca/main.dart';

void main() {
  crashDialogTests();
  testWidgets('shows five tabs in English, left to right', (tester) async {
    await tester.pumpWidget(YoncaApp(controller: AppController()));
    await tester.pumpAndSettle();
    for (final t in ['Home', 'Contacts', 'Calendar', 'Deals', 'More']) {
      expect(find.text(t), findsWidgets);
    }
    final ctx = tester.element(find.byType(Scaffold).first);
    expect(Directionality.of(ctx), TextDirection.ltr);
  });

  testWidgets('switches to Arabic and flips to right to left', (tester) async {
    final controller = AppController();
    await tester.pumpWidget(YoncaApp(controller: controller));
    await tester.pumpAndSettle();
    controller.setLocale(const Locale('ar'));
    await tester.pumpAndSettle();
    expect(find.text('الرئيسية'), findsWidgets);
    final ctx = tester.element(find.byType(Scaffold).first);
    expect(Directionality.of(ctx), TextDirection.rtl);
  });

  testWidgets('dark theme uses the dark palette', (tester) async {
    await tester.pumpWidget(YoncaApp(controller: AppController(themeMode: ThemeMode.dark)));
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(ctx).scaffoldBackgroundColor, const Color(0xFF000000));
  });
}

void crashDialogTests() {
  testWidgets('a saved crash report is offered once without widget-tree errors', (tester) async {
    final dir = Directory.systemTemp.createTempSync('yonca_crash');
    addTearDown(() => dir.deleteSync(recursive: true));
    final log = CrashLog(dir);
    log.record('boom', StackTrace.current);
    CrashLog.instance = log;
    addTearDown(() => CrashLog.instance = null);
    await tester.runAsync(() async {});
    await tester.pumpWidget(YoncaApp(controller: AppController()));
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
