import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';
import 'backup_service.dart';
import 'path_rebase.dart';

/// Opens the on-phone database file. All data stays on the phone.
Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  // A restore chosen in the last session is applied now, before the database opens.
  final restored = BackupService(dir).applyPendingRestore();
  final file = File(p.join(dir.path, 'yonca.sqlite'));
  final db = AppDatabase(NativeDatabase.createInBackground(file));
  // A restored phone goes straight to Home, whatever the backup says about first-run screens.
  if (restored) await db.putSetting('onboarded', '1');
  // Stored file paths follow the current folder (after a restore, an app id change or another phone).
  try {
    await PathRebase.run(db, dir);
  } catch (_) {}
  return db;
}
