import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/app_controller.dart';
import 'package:yonca/data/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a saved setting is read back, and saving again replaces it', () async {
    expect(await db.getSetting('x'), isNull);
    await db.putSetting('x', '1');
    await db.putSetting('x', '2');
    expect(await db.getSetting('x'), '2');
  });

  test('a fresh database starts with English and the phone theme', () async {
    final c = await AppController.restore(db);
    expect(c.locale, const Locale('en'));
    expect(c.themeMode, ThemeMode.system);
  });

  test('language and theme choices survive a restart', () async {
    final first = await AppController.restore(db);
    await first.setLocale(const Locale('ar'));
    await first.setThemeMode(ThemeMode.dark);
    final second = await AppController.restore(db);
    expect(second.locale, const Locale('ar'));
    expect(second.themeMode, ThemeMode.dark);
  });

  test('an unknown saved theme falls back to the phone theme', () async {
    await db.putSetting(AppController.keyThemeMode, 'purple');
    final c = await AppController.restore(db);
    expect(c.themeMode, ThemeMode.system);
  });
}
