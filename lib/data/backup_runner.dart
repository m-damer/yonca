import 'dart:async';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'package:path_provider/path_provider.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import 'reminders.dart';
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

  Future<File> makeFile({String? password, void Function(double)? onProgress}) async {
    final svc = await service();
    final tmp = await getTemporaryDirectory();
    final n = (await c.contacts?.list())?.length ?? 0;
    return svc.createBackupInBackground(tmp, contacts: n, password: password, onProgress: onProgress);
  }

  /// Makes a backup and uploads it to Drive. [progress] goes from 0 to 1. Returns the file name and size.
  Future<({String name, int bytes})> toDrive({void Function(double)? progress}) async {
    progress?.call(0);
    // Making the file is the first 60% of the bar; uploading it is the rest.
    final f = await makeFile(onProgress: (v) => progress?.call(v * .6));
    progress?.call(.6);
    final info = (name: f.uri.pathSegments.last, bytes: f.lengthSync());
    try {
      await drive.upload(f, onProgress: (v) => progress?.call(.6 + v * .38));
      progress?.call(.98);
      await c.markDriveBackup(info.bytes);
      progress?.call(1);
      return info;
    } finally {
      try {
        f.deleteSync();
      } catch (_) {}
    }
  }

  /// On start: backs up to Drive when the schedule says it is time, and the network allows it.
  /// Returns true when a backup was made.
  Future<bool> autoIfDue({DateTime? now, VoidCallback? onStart, void Function(double)? progress, void Function(Object)? onError}) async {
    if (c.driveEmail == null || c.autoBackup == 'off') return false;
    final t = now ?? DateTime.now();
    final last = c.lastDriveBackup;
    final days = c.autoBackup == 'daily' ? 1 : 7;
    if (last != null && t.difference(last).inHours < days * 24 - 1) return false;
    try {
      if (!await DriveBackup.online()) return false;
      if (c.wifiOnly && !await DriveBackup.onWifi()) return false;
      if (await drive.restore() == null) return false;
      onStart?.call();
      await toDrive(progress: progress);
      return true;
    } catch (e) {
      onError?.call(e);
      return false;
    }
  }
}

const _alarmId = 7302;

/// Runs [work] with a progress notification on the phone and, when [doneTitle] / [failedTitle] are given,
/// a notification for the result. Used by the manual Drive backup and restore so they show in the
/// notification shade when the person leaves the screen or the app.
Future<T> runWithNotice<T>({
  required Reminders notes,
  required int id,
  required String title,
  required Future<T> Function(void Function(double) progress) work,
  String? doneTitle,
  String? doneBody,
  String? failedTitle,
  String? failedBody,
}) async {
  var last = -1;
  unawaited(notes.startProgress(id, title));
  try {
    final r = await work((v) {
      final p = (v * 100).floor();
      if (p != last) {
        last = p;
        unawaited(notes.updateProgress(id, title, p));
      }
    });
    await notes.endProgress(id);
    if (doneTitle != null) await notes.showNow(7301, doneTitle, doneBody ?? '', backup: true);
    return r;
  } catch (_) {
    await notes.endProgress(id);
    if (failedTitle != null) await notes.showNow(7303, failedTitle, failedBody ?? '', backup: true);
    rethrow;
  }
}

/// Runs the automatic Drive backup when it is due, with a progress notification while it works and a
/// notification when it is saved (or could not finish). Used at app start and by the background job.
Future<bool> autoBackupWithNotice(BackupRunner r, Reminders notes) async {
  final l = lookupAppLocalizations(r.c.locale);
  const progressId = 7300;
  var started = false;
  var lastPercent = -1;
  final ok = await r.autoIfDue(
    onStart: () {
      started = true;
      unawaited(notes.startProgress(progressId, l.notifBackupRunning));
    },
    progress: (v) {
      final p = (v * 100).floor();
      if (started && p != lastPercent) {
        lastPercent = p;
        unawaited(notes.updateProgress(progressId, l.notifBackupRunning, p));
      }
    },
  );
  if (!started) return false;
  await notes.endProgress(progressId);
  if (ok) {
    await notes.showNow(7301, l.notifBackupDone, l.notifBackupDoneBody, backup: true);
  } else {
    await notes.showNow(7303, l.notifBackupFailed, l.notifBackupFailedBody, backup: true);
  }
  return ok;
}

/// Runs in the background (even when the app is closed): backs up to Drive when it is due.
@pragma('vm:entry-point')
Future<void> backupAlarmCallback() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final db = await openAppDatabase();
    final c = await AppController.restoreQuiet(db);
    await autoBackupWithNotice(BackupRunner(c), NotificationReminders());
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
