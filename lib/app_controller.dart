import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'data/contacts_repository.dart';

/// App-wide choices (language, theme), saved in the local database when one is given.
class AppController extends ChangeNotifier {
  AppController({Locale? locale, ThemeMode? themeMode, AppDatabase? database})
      : _locale = locale ?? const Locale('en'),
        _themeMode = themeMode ?? ThemeMode.system,
        _db = database;

  static const keyLanguage = 'language';
  static const keyThemeMode = 'themeMode';

  /// Reads the saved choices; missing or unknown values fall back to English and the phone's theme.
  static Future<AppController> restore(AppDatabase db) async {
    final lang = await db.getSetting(keyLanguage);
    final mode = await db.getSetting(keyThemeMode);
    return AppController(
      locale: Locale(lang == 'ar' ? 'ar' : 'en'),
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == mode,
        orElse: () => ThemeMode.system,
      ),
      database: db,
    );
  }

  final AppDatabase? _db;
  Locale _locale;
  ThemeMode _themeMode;

  /// Contact storage; null when the app runs without a database (some tests).
  late final ContactsRepository? contacts = (_db == null ? null : ContactsRepository(_db));

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;

  Future<void> setLocale(Locale value) async {
    if (value == _locale) return;
    _locale = value;
    notifyListeners();
    await _db?.putSetting(keyLanguage, value.languageCode);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (value == _themeMode) return;
    _themeMode = value;
    notifyListeners();
    await _db?.putSetting(keyThemeMode, value.name);
  }
}
