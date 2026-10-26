import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Temporary M0 diagnostic: do exact alarms and full-screen alerts work on this phone?
/// Replaced by the real reminders in M3.
class AlarmTester {
  AlarmTester() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const channelId = 'alarm_test';

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      channelId,
      'Alarm test',
      description: 'Checks that alarms reach the phone while it is locked.',
      importance: Importance.max,
    ));
    _ready = true;
  }

  Future<bool> requestNotifications() async =>
      await _android?.requestNotificationsPermission() ?? false;

  Future<bool> requestExactAlarms() async =>
      await _android?.requestExactAlarmsPermission() ?? false;

  Future<bool> requestFullScreen() async =>
      await _android?.requestFullScreenIntentPermission() ?? false;

  Future<Map<String, bool>> status() async => {
        'Notifications allowed': await _android?.areNotificationsEnabled() ?? false,
        'Exact alarms allowed': await _android?.canScheduleExactNotifications() ?? false,
      };

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Alarm test',
          channelDescription: 'Checks that alarms reach the phone while it is locked.',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
        ),
      );

  /// [alarmClock] true uses the strongest Android alarm type; false uses a normal exact
  /// alarm that battery saving can delay. Returns the local time the alert is due.
  Future<DateTime> schedule({required Duration after, required bool alarmClock}) async {
    final when = tz.TZDateTime.now(tz.UTC).add(after);
    await _plugin.zonedSchedule(
      alarmClock ? 1 : 2,
      alarmClock ? 'YONCA alarm test (alarm-clock type)' : 'YONCA alarm test (exact type)',
      'If you see this on the lock screen, alarms work on this phone.',
      when,
      _details,
      androidScheduleMode:
          alarmClock ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.exactAllowWhileIdle,
    );
    return DateTime.now().add(after);
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}

class AlarmTestPage extends StatefulWidget {
  const AlarmTestPage({super.key});

  @override
  State<AlarmTestPage> createState() => _AlarmTestPageState();
}

class _AlarmTestPageState extends State<AlarmTestPage> {
  final AlarmTester _t = AlarmTester();
  Map<String, bool> _status = {};
  final List<String> _log = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _run(() async {
      await _t.init();
      _status = await _t.status();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      _error = null;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() {});
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _schedule(Duration after, bool alarmClock) async {
    final at = await _t.schedule(after: after, alarmClock: alarmClock);
    _log.insert(0, '${alarmClock ? "Alarm-clock type" : "Exact type"} set for ${_hm(at)}');
  }

  Widget _permission(String label, Future<bool> Function() ask) => OutlinedButton(
        onPressed: () => _run(() async {
          await ask();
          _status = await _t.status();
        }),
        child: Text(label),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alarm test (temporary)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '1. Tap the three permission buttons and allow each one.\n'
            '2. Tap "Alarm clock in 2 min", lock the phone and put it down.\n'
            '3. Note the time the alert appears on the lock screen, and whether it makes a sound.\n'
            '4. Repeat with "Exact in 2 min", then again with the app swiped away from recent apps.\n'
            '5. Tell Claude what happened, and the phone brand and model.',
          ),
          const SizedBox(height: 16),
          for (final e in _status.entries)
            ListTile(
              dense: true,
              leading: Icon(e.value ? Icons.check_circle : Icons.cancel,
                  color: e.value ? Colors.green : Colors.red),
              title: Text(e.key),
            ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _permission('Allow notifications', _t.requestNotifications),
            _permission('Allow exact alarms', _t.requestExactAlarms),
            _permission('Allow full-screen alerts', _t.requestFullScreen),
          ]),
          const Divider(height: 32),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(
                onPressed: () => _run(() => _schedule(const Duration(minutes: 2), true)),
                child: const Text('Alarm clock in 2 min')),
            FilledButton(
                onPressed: () => _run(() => _schedule(const Duration(minutes: 2), false)),
                child: const Text('Exact in 2 min')),
            FilledButton.tonal(
                onPressed: () => _run(() => _schedule(const Duration(minutes: 10), true)),
                child: const Text('Alarm clock in 10 min')),
            TextButton(
                onPressed: () => _run(() async {
                      await _t.cancelAll();
                      _log.insert(0, 'All alarms cancelled');
                    }),
                child: const Text('Cancel all')),
          ]),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 16),
          for (final l in _log) Text(l),
        ],
      ),
    );
  }
}
