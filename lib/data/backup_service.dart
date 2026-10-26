import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// What is stored on the phone, for the "storage use" card.
class StorageUse {
  const StorageUse({required this.databaseBytes, required this.fileBytes, required this.fileCount});
  final int databaseBytes;
  final int fileBytes;
  final int fileCount;
  int get total => databaseBytes + fileBytes;
}

class BackupException implements Exception {
  const BackupException(this.problem);
  final String problem;
  @override
  String toString() => problem;
}

/// Backup file (a zip of the database and every attached file), restore and delete-everything.
/// A restore is staged in a folder and applied the next time the app starts, before the database opens.
class BackupService {
  BackupService(this.docs, {this.flush});

  /// The app's documents folder (where the database and attached files live).
  final Directory docs;

  /// Called before a backup so SQLite writes everything into the main file.
  final Future<void> Function()? flush;

  static const dbName = 'yonca.sqlite';
  static const pendingName = 'restore_pending';
  static const manifestName = 'backup.json';

  bool _skip(String relative) {
    final top = p.split(relative).first;
    return top == pendingName || relative.endsWith('-wal') || relative.endsWith('-shm') || relative.endsWith('-journal');
  }

  Iterable<File> _files() sync* {
    if (!docs.existsSync()) return;
    for (final e in docs.listSync(recursive: true, followLinks: false)) {
      if (e is File && !_skip(p.relative(e.path, from: docs.path))) yield e;
    }
  }

  Future<StorageUse> storageUse() async {
    var db = 0, other = 0, count = 0;
    for (final f in _files()) {
      final rel = p.relative(f.path, from: docs.path);
      final len = f.lengthSync();
      if (rel == dbName) {
        db = len;
      } else {
        other += len;
        count++;
      }
    }
    return StorageUse(databaseBytes: db, fileBytes: other, fileCount: count);
  }

  /// Writes the backup zip into [outDir] and returns it.
  Future<File> createBackup(Directory outDir, {DateTime? now}) async {
    await flush?.call();
    final t = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final out = File(p.join(outDir.path, 'yonca-backup-${t.year}-${two(t.month)}-${two(t.day)}.zip'));
    if (out.existsSync()) out.deleteSync();
    final enc = ZipFileEncoder()..create(out.path);
    enc.addArchiveFile(ArchiveFile.string(manifestName, jsonEncode({'app': 'yonca', 'createdAt': t.toIso8601String()})));
    for (final f in _files()) {
      await enc.addFile(f, p.relative(f.path, from: docs.path));
    }
    await enc.close();
    return out;
  }

  /// Checks the zip and unpacks it into the pending folder. The restore happens at the next start.
  Future<void> stageRestore(File zip) async {
    final archive = ZipDecoder().decodeBytes(zip.readAsBytesSync());
    final names = archive.files.map((f) => f.name).toSet();
    if (!names.contains(manifestName) || !names.contains(dbName)) throw const BackupException('not_a_backup');
    final List<int> manifestBytes = archive.files.firstWhere((f) => f.name == manifestName).content;
    final info = jsonDecode(utf8.decode(manifestBytes));
    if (info is! Map || info['app'] != 'yonca') throw const BackupException('not_a_backup');
    final pending = Directory(p.join(docs.path, pendingName));
    if (pending.existsSync()) pending.deleteSync(recursive: true);
    pending.createSync(recursive: true);
    for (final f in archive.files) {
      if (!f.isFile || f.name == manifestName) continue;
      // Never write outside the pending folder.
      final target = p.normalize(p.join(pending.path, f.name));
      if (!p.isWithin(pending.path, target)) continue;
      final List<int> bytes = f.content;
      File(target)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    }
  }

  bool get hasPendingRestore => Directory(p.join(docs.path, pendingName)).existsSync();

  /// Replaces the current data with the staged backup. Call before the database is opened.
  /// Returns true when a restore was applied.
  bool applyPendingRestore() {
    final pending = Directory(p.join(docs.path, pendingName));
    if (!pending.existsSync() || !File(p.join(pending.path, dbName)).existsSync()) {
      if (pending.existsSync()) pending.deleteSync(recursive: true);
      return false;
    }
    for (final f in _files().toList()) {
      f.deleteSync();
    }
    for (final e in pending.listSync(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      final dest = File(p.join(docs.path, p.relative(e.path, from: pending.path)));
      dest.parent.createSync(recursive: true);
      e.copySync(dest.path);
    }
    pending.deleteSync(recursive: true);
    return true;
  }

  /// Deletes every attached file (the database rows are cleared by the caller).
  void deleteAttachedFiles() {
    for (final f in _files().toList()) {
      if (p.relative(f.path, from: docs.path) != dbName) f.deleteSync();
    }
  }
}
