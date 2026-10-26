import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'schedule_repository.dart';

/// Schedules the phone's notifications and alarms from the database.
abstract class Reminders {
  /// Cancels everything and schedules what is still ahead.
  Future<void> resync(ScheduleRepository repo);

  /// Asks Android for permission to show notifications (and exact alarms).
  Future<void> requestPermissions();

  /// Sets what the Done and Snooze buttons on task notifications do, and their labels.
  void configure({required Future<void> Function(String action, int taskId) onAction, required String doneLabel, required String snoozeLabel});
}

/// Used in tests and when no database is open.
class NoReminders implements Reminders {
  const NoReminders();
  @override
  Future<void> resync(ScheduleRepository repo) async {}
  @override
  Future<void> requestPermissions() async {}
  @override
  void configure({required Future<void> Function(String action, int taskId) onAction, required String doneLabel, required String snoozeLabel}) {}
}

/// Android notifications through flutter_local_notifications. Alarms use the alarm channel with a
/// full-screen intent; plain reminders use a normal channel. At most [maxScheduled] are kept.
class NotificationReminders implements Reminders {
  NotificationReminders() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;
  Future<void> Function(String action, int taskId)? _onAction;
  String _done = 'Done';
  String _snooze = 'Snooze';

  @override
  void configure({required Future<void> Function(String action, int taskId) onAction, required String doneLabel, required String snoozeLabel}) {
    _onAction = onAction;
    _done = doneLabel;
    _snooze = snoozeLabel;
  }

  void _response(NotificationResponse r) {
    final payload = r.payload ?? '';
    final action = r.actionId;
    if (action == null || !payload.startsWith('task:')) return;
    final id = int.tryParse(payload.substring(5));
    if (id != null) _onAction?.call(action, id);
  }
  static const maxScheduled = 200;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

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
    _ready = true;
  }

  @override
  Future<void> requestPermissions() async {
    await _init();
    await _android?.requestNotificationsPermission();
    await _android?.requestExactAlarmsPermission();
  }

  NotificationDetails _details(bool alarm, {bool task = false}) => NotificationDetails(
        android: alarm
            ? AndroidNotificationDetails(
                'yonca_alarms',
                'Alarms',
                channelDescription: 'Strong alerts for tasks and meetings.',
                importance: Importance.max,
                priority: Priority.high,
                category: AndroidNotificationCategory.alarm,
                fullScreenIntent: true,
                audioAttributesUsage: AudioAttributesUsage.alarm,
                visibility: NotificationVisibility.public,
                actions: task ? _actions() : null,
              )
            : AndroidNotificationDetails(
                'yonca_reminders',
                'Reminders',
                channelDescription: 'Reminders for tasks, meetings and events.',
                importance: Importance.high,
                priority: Priority.high,
                actions: task ? _actions() : null,
              ),
      );

  List<AndroidNotificationAction> _actions() => [
        AndroidNotificationAction('done', _done, showsUserInterface: true, cancelNotification: true),
        AndroidNotificationAction('snooze', _snooze, showsUserInterface: true, cancelNotification: true),
      ];

  @override
  Future<void> resync(ScheduleRepository repo) async {
    await _init();
    await _plugin.cancelAll();
    final now = DateTime.now();
    final specs = await repo.pendingReminders(now);
    for (final s in specs.take(maxScheduled)) {
      // tz.local is not set up, so schedule in UTC from the time difference.
      final when = tz.TZDateTime.now(tz.UTC).add(s.at.difference(now));
      final canExact = await _android?.canScheduleExactNotifications() ?? false;
      await _plugin.zonedSchedule(
        s.id,
        s.title,
        s.body.isEmpty ? null : s.body,
        when,
        _details(s.alarm, task: s.id % 3 == 0),
        payload: s.id % 3 == 0 ? 'task:${s.id ~/ 3}' : null,
        androidScheduleMode: s.alarm
            ? AndroidScheduleMode.alarmClock
            : (canExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle),
      );
    }
  }
}
