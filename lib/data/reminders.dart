import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'schedule_repository.dart';

/// What the app wants to hear back from notifications.
class ReminderCallbacks {
  const ReminderCallbacks({
    required this.onAction,
    required this.onOpen,
    required this.shouldSilence,
    required this.doneLabel,
    required this.snoozeLabel,
    this.hideDetails = _never,
  });

  static bool _never() => false;

  /// True when notifications must not show their text on the lock screen.
  final bool Function() hideDetails;

  /// A Done or Snooze button on a task notification.
  final Future<void> Function(String action, int taskId) onAction;

  /// A notification (or alarm) was tapped or launched the app. [kind] is `task` or `meeting`.
  final void Function(String kind, int id, bool alarm) onOpen;

  /// True when a reminder at [at] must make no sound (quiet hours).
  final bool Function(DateTime at, bool alarm) shouldSilence;
  final String doneLabel;
  final String snoozeLabel;
}

/// Which permissions the phone has granted.
class ReminderPermissions {
  const ReminderPermissions({required this.notifications, required this.exactAlarms});
  final bool notifications;
  final bool exactAlarms;
}

/// Schedules the phone's notifications and alarms from the database.
abstract class Reminders {
  /// Cancels everything and schedules what is still ahead.
  Future<void> resync(ScheduleRepository repo);

  /// Asks Android for permission to show notifications (and exact alarms).
  Future<void> requestPermissions();

  /// What the phone currently allows.
  Future<ReminderPermissions> permissions();

  /// Sets what the notification buttons and taps do.
  void configure(ReminderCallbacks callbacks);

  /// Delivers the tap that started the app, if a notification did.
  Future<void> handleLaunch();

  /// Shows a quiet notification now (for example "an update is available").
  Future<void> showNow(int id, String title, String body);
}

/// Used in tests and when no database is open.
class NoReminders implements Reminders {
  const NoReminders();
  @override
  Future<void> resync(ScheduleRepository repo) async {}
  @override
  Future<void> requestPermissions() async {}
  @override
  Future<ReminderPermissions> permissions() async => const ReminderPermissions(notifications: true, exactAlarms: true);
  @override
  void configure(ReminderCallbacks callbacks) {}
  @override
  Future<void> handleLaunch() async {}
  @override
  Future<void> showNow(int id, String title, String body) async {}
}

/// Android notifications through flutter_local_notifications. Alarms use the alarm channel with a
/// full-screen intent; plain reminders use a normal channel. At most [maxScheduled] are kept.
class NotificationReminders implements Reminders {
  NotificationReminders() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;
  ReminderCallbacks? _cb;
  static const maxScheduled = 200;

  @override
  void configure(ReminderCallbacks callbacks) => _cb = callbacks;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Payload format: `kind:id:alarm`, for example `task:12:1`.
  static String payloadFor(String kind, int id, bool alarm) => '$kind:$id:${alarm ? 1 : 0}';

  void _handle(String? action, String? payload) {
    final cb = _cb;
    if (cb == null || payload == null) return;
    final parts = payload.split(':');
    if (parts.length < 3) return;
    final id = int.tryParse(parts[1]);
    if (id == null) return;
    if (action == 'done' || action == 'snooze') {
      if (parts[0] == 'task') cb.onAction(action!, id);
      return;
    }
    cb.onOpen(parts[0], id, parts[2] == '1');
  }

  void _response(NotificationResponse r) => _handle(r.actionId, r.payload);

  @override
  Future<void> handleLaunch() async {
    await _init();
    final d = await _plugin.getNotificationAppLaunchDetails();
    final r = d?.notificationResponse;
    if (d != null && d.didNotificationLaunchApp && r != null) _handle(r.actionId, r.payload);
  }

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: _response,
    );
    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      'yonca_alarms',
      'Alarms',
      description: 'Strong alerts for tasks and meetings.',
      importance: Importance.max,
    ));
    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      'yonca_reminders',
      'Reminders',
      description: 'Reminders for tasks, meetings and events.',
      importance: Importance.high,
    ));
    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      'yonca_system',
      'App updates',
      description: 'New versions of YONCA.',
      importance: Importance.low,
    ));
    _ready = true;
  }

  @override
  Future<void> requestPermissions() async {
    await _init();
    await _android?.requestNotificationsPermission();
    await _android?.requestExactAlarmsPermission();
  }

  @override
  Future<ReminderPermissions> permissions() async {
    await _init();
    final n = await _android?.areNotificationsEnabled();
    final e = await _android?.canScheduleExactNotifications() ?? false;
    return ReminderPermissions(notifications: n ?? false, exactAlarms: e);
  }

  @override
  Future<void> showNow(int id, String title, String body) async {
    await _init();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails('yonca_system', 'App updates', channelDescription: 'New versions of YONCA.', importance: Importance.low, priority: Priority.low),
      ),
    );
  }

  List<AndroidNotificationAction> _actions() => [
        AndroidNotificationAction('done', _cb?.doneLabel ?? 'Done', showsUserInterface: true, cancelNotification: true),
        AndroidNotificationAction('snooze', _cb?.snoozeLabel ?? 'Snooze', showsUserInterface: true, cancelNotification: true),
      ];

  NotificationDetails _details(bool alarm, {required bool task, required bool silent}) => NotificationDetails(
        android: alarm && !silent
            ? AndroidNotificationDetails(
                'yonca_alarms',
                'Alarms',
                channelDescription: 'Strong alerts for tasks and meetings.',
                importance: Importance.max,
                priority: Priority.high,
                category: AndroidNotificationCategory.alarm,
                fullScreenIntent: true,
                audioAttributesUsage: AudioAttributesUsage.alarm,
                visibility: (_cb?.hideDetails() ?? false) ? NotificationVisibility.private : NotificationVisibility.public,
                actions: task ? _actions() : null,
              )
            : AndroidNotificationDetails(
                'yonca_reminders',
                'Reminders',
                channelDescription: 'Reminders for tasks, meetings and events.',
                importance: Importance.high,
                priority: Priority.high,
                visibility: (_cb?.hideDetails() ?? false) ? NotificationVisibility.private : NotificationVisibility.public,
                playSound: !silent,
                enableVibration: !silent,
                silent: silent,
                actions: task ? _actions() : null,
              ),
      );

  @override
  Future<void> resync(ScheduleRepository repo) async {
    await _init();
    await _plugin.cancelAll();
    final now = DateTime.now();
    final specs = await repo.pendingReminders(now);
    final canExact = await _android?.canScheduleExactNotifications() ?? false;
    for (final s in specs.take(maxScheduled)) {
      // tz.local is not set up, so schedule in UTC from the time difference.
      final when = tz.TZDateTime.now(tz.UTC).add(s.at.difference(now));
      final silent = _cb?.shouldSilence(s.at, s.alarm) ?? false;
      final alarmMode = s.alarm && !silent;
      await _plugin.zonedSchedule(
        s.id,
        s.title,
        s.body.isEmpty ? null : s.body,
        when,
        _details(s.alarm, task: s.kind == 'task', silent: silent),
        androidScheduleMode: alarmMode
            ? AndroidScheduleMode.alarmClock
            : (canExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle),
        payload: s.kind == 'event' ? null : payloadFor(s.kind, s.refId, s.alarm),
      );
    }
  }
}
