import 'dart:convert';

import 'package:flutter/material.dart';

import 'core/format.dart';
import 'data/activities_repository.dart';
import 'data/app_database.dart';
import 'domain/contact_models.dart';
import 'domain/deal_models.dart';
import 'data/contacts_repository.dart';
import 'data/deals_repository.dart';
import 'data/fields_repository.dart';
import 'data/stats_repository.dart';
import 'data/reminders.dart';
import 'data/schedule_repository.dart';
import 'data/update_service.dart';
import 'l10n/app_localizations.dart';

/// A tapped notification or alarm: [kind] is `task` or `meeting`.
class AlarmRequest {
  const AlarmRequest(this.kind, this.id, this.alarm);
  final String kind;
  final int id;
  final bool alarm;
}

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
  static const keyAccentCustom = 'accent.custom';
  static const keyBackupLast = 'backup.last';
  static const keyBackupSize = 'backup.size';
  static const keyBackupRemind = 'backup.remind';
  static const keyHighContrast = 'highContrast';
  static const keyOnboarded = 'onboarded';
  static const keyMainCurrency = 'currency.main';
  static const keySystemFont = 'systemArabicFont';
  static const keyArabicFont = 'arabicFont';
  static const keyLevant = 'levantMonths';
  static const keyIndic = 'indicDigits';
  static const keyQuietOn = 'quietOn';
  static const keyQuietFrom = 'quietFrom';
  static const keyQuietTo = 'quietTo';
  static const keyQuietAlarms = 'quietSilenceAlarms';
  static const keyWeeklyUpdate = 'weeklyUpdate';
  static const keyLastUpdateCheck = 'lastUpdateCheck';
  static const keyNotifiedVersion = 'notifiedVersion';
  static const keyUpdateAvailable = 'updateAvailable';
  static const keyAckAlarms = 'ackAlarms';
  static const keyBellRead = 'bellRead';
  static const keyBellCleared = 'bellCleared';
  static const keyHomeHidden = 'homeHidden';
  static const keyInactHot = 'inactHot';
  static const keyInactWarm = 'inactWarm';
  static const keyInactCold = 'inactCold';
  static const _prefKeys = [
    keySystemFont, keyArabicFont, keyLevant, keyIndic, keyQuietOn, keyQuietFrom, keyQuietTo, keyQuietAlarms,
    keyWeeklyUpdate, keyLastUpdateCheck, keyNotifiedVersion, keyUpdateAvailable, keyAckAlarms, keyBellRead, keyBellCleared,
    keyHomeHidden, keyInactHot, keyInactWarm, keyInactCold, keyAccentCustom,
    keyBackupLast, keyBackupSize, keyBackupRemind,
  ];

  final Map<String, String> _prefs = {};

  /// A saved plain choice, or null.
  String? pref(String key) => _prefs[key];

  bool flag(String key, {bool def = false}) {
    final v = _prefs[key];
    return v == null || v.isEmpty ? def : v == '1';
  }

  Future<void> setPref(String key, String value) async {
    _prefs[key] = value;
    Look.levantMonths = flag(keyLevant, def: true);
    notifyListeners();
    await _db?.putSetting(key, value);
    if (key.startsWith('quiet')) await _resync();
  }

  Future<void> setFlag(String key, bool value) => setPref(key, value ? '1' : '0');

  /// The font family choice: `noto`, `cairo`, `plex` or `system` (the phone's own font).
  String get arabicFont {
    final v = pref(keyArabicFont);
    if (v == 'noto' || v == 'cairo' || v == 'plex' || v == 'system') return v!;
    return flag(keySystemFont) ? 'system' : 'noto';
  }

  bool get systemArabicFont => arabicFont == 'system';
  bool get levantMonths => flag(keyLevant, def: true);
  bool get indicDigits => flag(keyIndic);
  bool get quietHoursOn => flag(keyQuietOn);

  /// Minutes after midnight; defaults 22:00 to 08:00.
  int get quietFrom => int.tryParse(pref(keyQuietFrom) ?? '') ?? 22 * 60;
  int get quietTo => int.tryParse(pref(keyQuietTo) ?? '') ?? 8 * 60;
  bool get silenceAlarmsInQuiet => flag(keyQuietAlarms);
  /// Home sections the user switched off.
  Set<String> get homeHidden {
    final v = pref(keyHomeHidden) ?? '';
    return v.isEmpty ? <String>{} : v.split(',').toSet();
  }

  /// Days without activity before a contact of this rating shows under Needs attention.
  int inactiveDays(Rating r) => switch (r) {
        Rating.hot => int.tryParse(pref(keyInactHot) ?? '') ?? 7,
        Rating.warm => int.tryParse(pref(keyInactWarm) ?? '') ?? 14,
        _ => int.tryParse(pref(keyInactCold) ?? '') ?? 30,
      };

  /// Puts every setting back to its default. Contacts, deals and other data are not touched.
  Future<void> resetSettings() async {
    for (final k in [
      keySystemFont, keyArabicFont, keyLevant, keyIndic, keyQuietOn, keyQuietFrom, keyQuietTo, keyQuietAlarms,
      keyWeeklyUpdate, keyHomeHidden, keyInactHot, keyInactWarm, keyInactCold, keyAccentCustom,
    ]) {
      await setPref(k, '');
    }
    await setAccent(-1);
    await setHighContrast(false);
    await setThemeMode(ThemeMode.system);
    await setMainCurrency('USD');
  }

  bool get weeklyUpdateCheck => flag(keyWeeklyUpdate, def: true);

  /// True when [t] falls inside the quiet hours (which may cross midnight).
  bool isQuiet(DateTime t) {
    if (!quietHoursOn) return false;
    final m = t.hour * 60 + t.minute;
    final a = quietFrom, b = quietTo;
    if (a == b) return false;
    return a < b ? (m >= a && m < b) : (m >= a || m < b);
  }

  /// Reads the saved choices; missing or unknown values fall back to English and the phone's theme.
  static Future<AppController> restore(AppDatabase db) async {
    final lang = await db.getSetting(keyLanguage);
    final mode = await db.getSetting(keyThemeMode);
    final accent = await db.getSetting(keyAccent);
    final contrast = await db.getSetting(keyHighContrast);
    final onboarded = await db.getSetting(keyOnboarded);
    final cur = await db.getSetting(keyMainCurrency);
    if (cur != null && cur.isNotEmpty) defaultDealCurrency = cur;
    final prefs = <String, String>{};
    for (final k in _prefKeys) {
      final v = await db.getSetting(k);
      if (v != null) prefs[k] = v;
    }
    final controller = AppController(
      locale: Locale(lang == 'ar' ? 'ar' : 'en'),
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == mode,
        orElse: () => ThemeMode.system,
      ),
      database: db,
      accent: int.tryParse(accent ?? '') ?? -1,
      highContrast: contrast == '1',
      onboarded: onboarded == '1',
      reminders: NotificationReminders(),
    );
    controller._prefs.addAll(prefs);
    Look.levantMonths = controller.levantMonths;
    controller.startReminders();
    return controller;
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

  /// Which alarm or reminder was tapped; the shell shows it and clears it.
  final ValueNotifier<AlarmRequest?> alarmRequest = ValueNotifier(null);

  /// When each alarm was last seen: `task:12` or `meeting:3` to milliseconds.
  Map<String, int> get ackedAlarms {
    final raw = pref(keyAckAlarms);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  /// Marks an alarm as seen so it no longer counts as missed.
  Future<void> ackAlarm(String kind, int id, {DateTime? now}) async {
    final map = ackedAlarms;
    map['$kind:$id'] = (now ?? DateTime.now()).millisecondsSinceEpoch;
    if (map.length > 200) {
      final keep = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      map
        ..clear()
        ..addEntries(keep.take(150));
    }
    await setPref(keyAckAlarms, jsonEncode(map));
  }

  void _configureReminders() {
    final l = lookupAppLocalizations(_locale);
    _reminders.configure(ReminderCallbacks(
      onAction: (action, taskId) async {
        final s = schedule;
        if (s == null) return;
        if (action == 'done') {
          await s.completeTask(taskId);
        } else if (action == 'snooze') {
          await s.snoozeTask(taskId, DateTime.now().add(const Duration(hours: 1)));
        }
      },
      onOpen: (kind, id, alarm) {
        ackAlarm(kind, id);
        alarmRequest.value = AlarmRequest(kind, id, alarm);
      },
      shouldSilence: (at, alarm) => isQuiet(at) && (!alarm || silenceAlarmsInQuiet),
      doneLabel: l.done,
      snoozeLabel: l.snooze,
    ));
  }

  /// Rebuilds the phone's reminders from the database (at start and after every change).
  void startReminders() {
    _configureReminders();
    () async {
      try {
        await _reminders.requestPermissions();
        await _resync();
        await _reminders.handleLaunch();
      } catch (_) {}
      await maybeCheckUpdates();
    }();
  }

  /// Once a week, looks for a newer version and sends one quiet notification per version.
  Future<void> maybeCheckUpdates({UpdateService? service, DateTime? now}) async {
    if (_db == null || !weeklyUpdateCheck) return;
    final t = now ?? DateTime.now();
    final last = int.tryParse(pref(keyLastUpdateCheck) ?? '');
    if (last != null && t.difference(DateTime.fromMillisecondsSinceEpoch(last)) < const Duration(days: 7)) return;
    try {
      final info = await (service ?? UpdateService()).check();
      await setPref(keyLastUpdateCheck, '${t.millisecondsSinceEpoch}');
      await setPref(keyUpdateAvailable, info?.version ?? '');
      if (info != null && pref(keyNotifiedVersion) != info.version) {
        await setPref(keyNotifiedVersion, info.version);
        final l = lookupAppLocalizations(_locale);
        await _reminders.showNow(900001, l.notifUpdateTitle, l.notifUpdateBody(info.version));
      }
    } catch (_) {
      // Offline or GitHub unreachable: try again at the next start.
    }
  }

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  int get accent => _accent;

  /// When the last backup file was made, or null.
  DateTime? get lastBackup {
    final v = int.tryParse(pref(keyBackupLast) ?? '');
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  int get lastBackupBytes => int.tryParse(pref(keyBackupSize) ?? '') ?? 0;
  bool get backupRemind => flag(keyBackupRemind, def: true);

  Future<void> markBackup(int bytes) async {
    await setPref(keyBackupLast, '${DateTime.now().millisecondsSinceEpoch}');
    await setPref(keyBackupSize, '$bytes');
  }

  /// True when reminders are on and the last backup is over 14 days old. The first time this is asked,
  /// today becomes the starting point so a new install is not nagged at once.
  bool get backupDue {
    if (!backupRemind) return false;
    final last = lastBackup;
    if (last == null) {
      final now = '${DateTime.now().millisecondsSinceEpoch}';
      _prefs[keyBackupLast] = now;
      _db?.putSetting(keyBackupLast, now);
      return false;
    }
    return DateTime.now().difference(last).inDays >= 14;
  }

  /// The colour typed in Appearance > Custom, if any.
  Color? get customAccent {
    final v = int.tryParse(pref(keyAccentCustom) ?? '');
    return v == null ? null : Color(v);
  }

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

  String get mainCurrency => defaultDealCurrency;

  Future<void> setMainCurrency(String code) async {
    defaultDealCurrency = code;
    notifyListeners();
    await _db?.putSetting(keyMainCurrency, code);
  }

  /// Asks Android for permission to show reminders (onboarding, last step).
  Future<void> allowNotifications() async {
    try {
      await _reminders.requestPermissions();
    } catch (_) {}
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
    _configureReminders();
    await _db?.putSetting(keyLanguage, value.languageCode);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (value == _themeMode) return;
    _themeMode = value;
    notifyListeners();
    await _db?.putSetting(keyThemeMode, value.name);
  }
}
