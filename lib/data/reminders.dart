import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/schedule_models.dart' show ReminderSpec;
import 'schedule_repository.dart';

/// Schedules the phone's notifications and alarms from the database.
abstract class Reminders {
  /// Cancels everything and schedules what is still ahead.
  Future<void> resync(ScheduleRepository repo);

  /// Asks Android for permission to show notifications (and exact alarms).
  Future<void> requestPermissions();
}

/// Used in tests and when no database is open.
class NoReminders implements Reminders {
  const NoReminders();
  @override
  Future<void> resync(ScheduleRepository repo) async {}
  @override
  Future<void> requestPermissions() async {}
}

/// Android notifications through flutter_local_notifications. Alarms use the alarm channel with a
/// full-screen intent; plain reminders use a normal channel. At most [maxScheduled] are kept.
class NotificationReminders implements Reminders {
  NotificationReminders() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;
  static const maxScheduled = 200;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
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

  NotificationDetails _details(bool alarm) => NotificationDetails(
        android: alarm
            ? const AndroidNotificationDetails(
                'yonca_alarms',
                'Alarms',
                channelDescription: 'Strong alerts for tasks and meetings.',
                importance: Importance.max,
                priority: Priority.high,
                category: AndroidNotificationCategory.alarm,
                fullScreenIntent: true,
                audioAttributesUsage: AudioAttributesUsage.alarm,
                visibility: NotificationVisibility.public,
              )
            : const AndroidNotificationDetails(
                'yonca_reminders',
                'Reminders',
                channelDescription: 'Reminders for tasks, meetings and events.',
                importance: Importance.high,
                priority: Priority.high,
              ),
      );

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
        _details(s.alarm),
        androidScheduleMode: s.alarm
            ? AndroidScheduleMode.alarmClock
            : (canExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle),
      );
    }
  }
}
