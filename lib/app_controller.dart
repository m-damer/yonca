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
  AppController({Locale? locale, ThemeMode? themeMode, AppDatabase? database, Reminders? reminders, int accent = 0, bool highContrast = false, bool onboarded = true})
      : _accent = accent,
        _highContrast = highContrast,
        _onboarded = onboarded,
        _reminders = reminders ?? const NoReminders(),
        _locale = locale ?? const Locale('en'),
        _themeMode = themeMode ?? ThemeMode.system,
        _db = database;

  static const keyLanguage = 'language';
  static const keyThemeMode = 'themeMode';
  static const keyAccent = 'accent';
  static const keyHighContrast = 'highContrast';
  static const keyOnboarded = 'onboarded';

  /// Reads the saved choices; missing or unknown values fall back to English and the phone's theme.
  static Future<AppController> restore(AppDatabase db) async {
    final lang = await db.getSetting(keyLanguage);
    final mode = await db.getSetting(keyThemeMode);
    final accent = await db.getSetting(keyAccent);
    final contrast = await db.getSetting(keyHighContrast);
    final onboarded = await db.getSetting(keyOnboarded);
    return AppController(
      locale: Locale(lang == 'ar' ? 'ar' : 'en'),
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == mode,
        orElse: () => ThemeMode.system,
      ),
      database: db,
      accent: int.tryParse(accent ?? '') ?? 0,
      highContrast: contrast == '1',
      onboarded: onboarded == '1',
      reminders: NotificationReminders(),
    )..startReminders();
  }

  final AppDatabase? _db;
  final Reminders _reminders;
  Locale _locale;
  int _accent;
  bool _highContrast;
  bool _onboarded;
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

  /// The database, for screens that read or write plain settings.
  AppDatabase? get database => _db;

  /// Numbers for Stats, targets and Home; null when the app runs without a database.
  late final StatsRepository? stats = (_db == null ? null : StatsRepository(_db));

  Future<void> _resync() async {
    final s = schedule;
    if (s != null) await _reminders.resync(s);
  }

  /// Rebuilds the phone's reminders from the database (at start and after every change).
  void startReminders() {
    _reminders.configure(
      onAction: (action, taskId) async {
        final s = schedule;
        if (s == null) return;
        if (action == 'done') {
          await s.completeTask(taskId);
        } else if (action == 'snooze') {
          await s.snoozeTask(taskId, DateTime.now().add(const Duration(hours: 1)));
        }
      },
      doneLabel: _locale.languageCode == 'ar' ? 'تم' : 'Done',
      snoozeLabel: _locale.languageCode == 'ar' ? 'تأجيل' : 'Snooze',
    );
    () async {
      try {
        await _reminders.requestPermissions();
        await _resync();
      } catch (_) {}
    }();
  }

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  int get accent => _accent;
  bool get highContrast => _highContrast;
  bool get onboarded => _onboarded;

  Future<void> setAccent(int value) async {
    if (value == _accent) return;
    _accent = value;
    notifyListeners();
    await _db?.putSetting(keyAccent, '$value');
  }

  Future<void> setHighContrast(bool value) async {
    if (value == _highContrast) return;
    _highContrast = value;
    notifyListeners();
    await _db?.putSetting(keyHighContrast, value ? '1' : '0');
  }

  Future<void> completeOnboarding() async {
    _onboarded = true;
    notifyListeners();
    await _db?.putSetting(keyOnboarded, '1');
  }

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
