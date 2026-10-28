import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'package:path_provider/path_provider.dart';

import '../app_controller.dart';
import 'backup_service.dart';
import 'drive_backup.dart';
import 'open_database.dart';

/// Makes backups for the Backup page and for the automatic backup on start.
class BackupRunner {
  BackupRunner(this.c, {DriveBackup? drive}) : drive = drive ?? DriveBackup();
  final AppController c;
  final DriveBackup drive;

  Future<BackupService> service() async {
    final docs = await getApplicationDocumentsDirectory();
    final db = c.database;
    return BackupService(docs, flush: db == null ? null : () => db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)'));
  }

  Future<File> makeFile({String? password}) async {
    final svc = await service();
    final tmp = await getTemporaryDirectory();
    final n = (await c.contacts?.list())?.length ?? 0;
    return svc.createBackup(tmp, contacts: n, password: password);
  }

  /// Makes a backup and uploads it to Drive. [progress] goes from 0 to 1.
  Future<void> toDrive({void Function(double)? progress}) async {
    progress?.call(.1);
    final f = await makeFile();
    progress?.call(.5);
    try {
      await drive.upload(f);
      progress?.call(.95);
      await c.markDriveBackup(f.lengthSync());
      progress?.call(1);
    } finally {
      try {
        f.deleteSync();
      } catch (_) {}
    }
  }

  /// On start: backs up to Drive when the schedule says it is time, and the network allows it.
  /// Returns true when a backup was made.
  Future<bool> autoIfDue({DateTime? now}) async {
    if (c.driveEmail == null || c.autoBackup == 'off') return false;
    final t = now ?? DateTime.now();
    final last = c.lastDriveBackup;
    final days = c.autoBackup == 'daily' ? 1 : 7;
    if (last != null && t.difference(last).inHours < days * 24 - 1) return false;
    try {
      if (!await DriveBackup.online()) return false;
      if (c.wifiOnly && !await DriveBackup.onWifi()) return false;
      if (await drive.restore() == null) return false;
      await toDrive();
      return true;
    } catch (_) {
      return false;
    }
  }
}

const _alarmId = 7302;

/// Runs in the background (even when the app is closed): backs up to Drive when it is due.
@pragma('vm:entry-point')
Future<void> backupAlarmCallback() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final db = await openAppDatabase();
    final c = await AppController.restoreQuiet(db);
    final done = await BackupRunner(c).autoIfDue();
    if (done) {
      final ar = c.locale.languageCode == 'ar';
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      await plugin.show(
        7301,
        ar ? 'تم حفظ النسخة على Drive' : 'Backup saved to Drive',
        null,
        const NotificationDetails(
          android: AndroidNotificationDetails('yonca_system', 'App updates', channelDescription: 'New versions of YONCA.', importance: Importance.low, priority: Priority.low),
        ),
      );
    }
    await db.close();
  } catch (_) {}
}

/// Keeps the background job in step with the Backup page settings.
class BackupScheduler {
  static bool _ready = false;

  static Future<void> sync(AppController c) async {
    try {
      if (!_ready) {
        await AndroidAlarmManager.initialize();
        _ready = true;
      }
      if (c.driveEmail == null || c.autoBackup == 'off') {
        await AndroidAlarmManager.cancel(_alarmId);
        return;
      }
      await AndroidAlarmManager.periodic(
        const Duration(hours: 12),
        _alarmId,
        backupAlarmCallback,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    } catch (_) {}
  }
}
