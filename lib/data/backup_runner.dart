import 'dart:async';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'package:path_provider/path_provider.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import 'reminders.dart';
import 'system_channel.dart';
import 'backup_service.dart';
import 'drive_backup.dart';
import 'open_database.dart';

/// Why a local backup could not be saved. [code] is `nofolder`, `permission` or `write`.
class LocalBackupException implements Exception {
  const LocalBackupException(this.code, [this.detail = '']);
  final String code;
  final String detail;
  @override
  String toString() => 'LocalBackupException($code${detail.isEmpty ? '' : ': $detail'})';
}

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

  /// Makes a backup file and saves it in the phone folder the person chose. [progress] goes from 0 to 1.
  /// Keeps the newest [keep] YONCA backups in that folder and leaves every other file alone.
  Future<({String name, int bytes, String dir})> toLocal({void Function(double)? progress, int keep = 7}) async {
    final dir = c.localDir;
    if (dir == null) throw const LocalBackupException('nofolder');
    if (!await SystemChannel.canManageStorage()) throw const LocalBackupException('permission');
    progress?.call(0);
    final f = await makeFile(onProgress: (v) => progress?.call(v * .8));
    progress?.call(.8);
    try {
      final d = Directory(dir);
      if (!await d.exists()) await d.create(recursive: true);
      final name = f.uri.pathSegments.last;
      final dest = File('${d.path}/$name');
      final total = f.lengthSync();
      var done = 0;
      final sink = dest.openWrite();
      try {
        await for (final chunk in f.openRead()) {
          sink.add(chunk);
          done += chunk.length;
          if (total > 0) progress?.call(.8 + .18 * done / total);
        }
      } finally {
        await sink.close();
      }
      if (await dest.length() != total) throw const FileSystemException('The saved file is smaller than the backup');
      try {
        final mine = [
          for (final e in d.listSync())
            if (e is File && RegExp(r'yonca-backup-\d{4}-\d{2}-\d{2}\.(zip|yonca)$').hasMatch(e.uri.pathSegments.last)) e,
        ]..sort((a, b) => b.uri.pathSegments.last.compareTo(a.uri.pathSegments.last));
        for (final old in mine.skip(keep)) {
          old.deleteSync();
        }
      } catch (_) {}
      await c.markLocalBackup(total);
      progress?.call(1);
      return (name: name, bytes: total, dir: dir);
    } on FileSystemException catch (e) {
      final text = '${e.message} ${e.osError?.message ?? ''}'.toLowerCase();
      final denied = e.osError?.errorCode == 13 || e.osError?.errorCode == 1 || text.contains('permission denied') || text.contains('not permitted');
      throw LocalBackupException(denied ? 'permission' : 'write', '${e.message}${e.osError == null ? '' : ' (${e.osError!.message})'}');
    } finally {
      try {
        f.deleteSync();
      } catch (_) {}
    }
  }

  /// True when local backups are on, a folder is chosen and the schedule says it is time.
  bool localDue({DateTime? now}) {
    if (c.localDir == null || c.autoLocal == 'off') return false;
    final last = c.lastLocalBackup;
    final days = c.autoLocal == 'daily' ? 1 : 7;
    return last == null || (now ?? DateTime.now()).difference(last).inHours >= days * 24 - 1;
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
  int doneId = 7301,
  int failedId = 7303,
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
    if (doneTitle != null) await notes.showNow(doneId, doneTitle, doneBody ?? '', backup: true);
    return r;
  } catch (_) {
    await notes.endProgress(id);
    if (failedTitle != null) await notes.showNow(failedId, failedTitle, failedBody ?? '', backup: true);
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

/// The automatic local backup, with the same progress and result notifications as Drive.
Future<bool> autoLocalBackupWithNotice(BackupRunner r, Reminders notes) async {
  if (!r.localDue()) return false;
  final l = lookupAppLocalizations(r.c.locale);
  try {
    final res = await runWithNotice(
      notes: notes,
      id: 7306,
      title: l.notifLocalRunning,
      work: (p) => r.toLocal(progress: p),
      failedTitle: l.notifLocalFailed,
      failedBody: l.notifLocalFailedBody,
      doneId: 7307,
      failedId: 7308,
    );
    await notes.showNow(7307, l.notifLocalDone, l.notifLocalDoneBody(res.dir.split('/').where((e) => e.isNotEmpty).lastOrNull ?? res.dir), backup: true);
    return true;
  } catch (_) {
    return false;
  }
}

/// Runs in the background (even when the app is closed): backs up to Drive when it is due.
@pragma('vm:entry-point')
Future<void> backupAlarmCallback() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final db = await openAppDatabase();
    final c = await AppController.restoreQuiet(db);
    final notes = NotificationReminders();
    await autoBackupWithNotice(BackupRunner(c), notes);
    await autoLocalBackupWithNotice(BackupRunner(c), notes);
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
      final driveOn = c.driveEmail != null && c.autoBackup != 'off';
      final localOn = c.localDir != null && c.autoLocal != 'off';
      if (!driveOn && !localOn) {
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
