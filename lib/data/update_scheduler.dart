import 'dart:ui' show DartPluginRegistrant;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';

import '../app_controller.dart';
import 'open_database.dart';
import 'reminders.dart';
import 'update_manager.dart';

const _updateAlarmId = 7304;

/// Runs in the background (even when the app is closed): looks for a new version, tells the person with a
/// phone notification, and downloads it when automatic download is on.
@pragma('vm:entry-point')
Future<void> updateAlarmCallback() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final db = await openAppDatabase();
    final c = await AppController.restoreQuiet(db);
    final notes = NotificationReminders();
    await c.maybeCheckUpdates(reminders: notes, manager: UpdateManager(c, notes), wait: true);
    await db.close();
  } catch (_) {}
}

/// Keeps the background update check in step with the settings.
class UpdateScheduler {
  static Future<void> sync(AppController c) async {
    try {
      await AndroidAlarmManager.initialize();
      if (!c.weeklyUpdateCheck && !c.autoUpdateDownload) {
        await AndroidAlarmManager.cancel(_updateAlarmId);
        return;
      }
      await AndroidAlarmManager.periodic(
        const Duration(hours: 6),
        _updateAlarmId,
        updateAlarmCallback,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    } catch (_) {}
  }
}
