import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../app_controller.dart';
import 'backup_service.dart';
import 'drive_backup.dart';

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
  Future<void> autoIfDue({DateTime? now}) async {
    if (c.driveEmail == null || c.autoBackup == 'off') return;
    final t = now ?? DateTime.now();
    final last = c.lastDriveBackup;
    final days = c.autoBackup == 'daily' ? 1 : 7;
    if (last != null && t.difference(last).inHours < days * 24 - 1) return;
    try {
      if (!await DriveBackup.online()) return;
      if (c.wifiOnly && !await DriveBackup.onWifi()) return;
      if (await drive.restore() == null) return;
      await toDrive();
    } catch (_) {}
  }
}
