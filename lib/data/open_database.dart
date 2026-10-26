import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';
import 'backup_service.dart';

/// Opens the on-phone database file. All data stays on the phone.
Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  // A restore chosen in the last session is applied now, before the database opens.
  BackupService(dir).applyPendingRestore();
  final file = File(p.join(dir.path, 'yonca.sqlite'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}
