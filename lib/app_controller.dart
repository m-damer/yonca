import 'package:flutter/material.dart';

import 'data/activities_repository.dart';
import 'data/app_database.dart';
import 'data/contacts_repository.dart';
import 'data/deals_repository.dart';
import 'data/fields_repository.dart';
import 'data/stats_repository.dart';
import 'data/reminders.dart';
import 'data/schedule_repository.dart';

/// App-wide choices (language, theme), saved in the local database when one is given.
class AppController extends ChangeNotifier {
  AppController({Locale? locale, ThemeMode? themeMode, AppDatabase? database, Reminders? reminders})
      : _reminders = reminders ?? const NoReminders(),
        _locale = locale ?? const Locale('en'),
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
      reminders: NotificationReminders(),
    )..startReminders();
  }

  final AppDatabase? _db;
  final Reminders _reminders;
  Locale _locale;
  ThemeMode _themeMode;

  /// Contact storage; null when the app runs without a database (some tests).
  late final ContactsRepository? contacts = (_db == null ? null : ContactsRepository(_db));

  /// Activity storage; null when the app runs without a database.
  late final ActivitiesRepository? activities = (_db == null ? null : ActivitiesRepository(_db));

  /// Tasks, meetings and events; null when the app runs without a database.
  late final ScheduleRepository? schedule = (_db == null ? null : ScheduleRepository(_db, onChanged: _resync));

  /// Deals and pipeline stages; null when the app runs without a database.
  late final DealsRepository? deals = (_db == null ? null : DealsRepository(_db));

  /// Custom fields; null when the app runs without a database.
  late final FieldsRepository? fields = (_db == null ? null : FieldsRepository(_db));

  /// Numbers for Stats, targets and Home; null when the app runs without a database.
  late final StatsRepository? stats = (_db == null ? null : StatsRepository(_db));

  Future<void> _resync() async {
    final s = schedule;
    if (s != null) await _reminders.resync(s);
  }

  /// Rebuilds the phone's reminders from the database (at start and after every change).
  void startReminders() {
    () async {
      try {
        await _reminders.requestPermissions();
        await _resync();
      } catch (_) {}
    }();
  }

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
