import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'backup_crypto.dart';

/// What is stored on the phone, for the "storage use" card.
class StorageUse {
  const StorageUse({required this.databaseBytes, required this.fileBytes, required this.fileCount, this.photos = 0, this.voice = 0});
  final int photos;
  final int voice;
  int get others => fileCount - photos - voice;
  final int databaseBytes;
  final int fileBytes;
  final int fileCount;
  int get total => databaseBytes + fileBytes;
}

/// What a backup says about itself.
class BackupMeta {
  const BackupMeta({required this.createdAt, required this.contacts});
  final DateTime createdAt;
  final int contacts;
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
    var db = 0, other = 0, count = 0, photos = 0, voice = 0;
    for (final f in _files()) {
      final rel = p.relative(f.path, from: docs.path);
      final len = f.lengthSync();
      if (rel == dbName) {
        db = len;
      } else {
        other += len;
        count++;
        final ext = p.extension(rel).toLowerCase();
        if (const ['.jpg', '.jpeg', '.png', '.webp', '.heic'].contains(ext)) photos++;
        if (const ['.m4a', '.aac', '.mp3', '.wav', '.ogg', '.opus', '.3gp'].contains(ext)) voice++;
      }
    }
    return StorageUse(databaseBytes: db, fileBytes: other, fileCount: count, photos: photos, voice: voice);
  }

  /// Writes the backup zip into [outDir] and returns it.
  Future<File> createBackup(Directory outDir, {DateTime? now, String? password, int contacts = 0, void Function(double)? onProgress}) async {
    await flush?.call();
    final t = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final out = File(p.join(outDir.path, 'yonca-backup-${t.year}-${two(t.month)}-${two(t.day)}.zip'));
    if (out.existsSync()) out.deleteSync();
    final enc = ZipFileEncoder()..create(out.path);
    enc.addArchiveFile(ArchiveFile.string(manifestName, jsonEncode({'app': 'yonca', 'createdAt': t.toIso8601String(), 'contacts': contacts})));
    final files = _files().toList();
    for (var i = 0; i < files.length; i++) {
      await enc.addFile(files[i], p.relative(files[i].path, from: docs.path));
      onProgress?.call(.85 * (i + 1) / files.length);
    }
    await enc.close();
    onProgress?.call(.9);
    if (password != null && password.isNotEmpty) {
      final plain = out.readAsBytesSync();
      final locked = File(p.join(outDir.path, '${p.basenameWithoutExtension(out.path)}.yonca'));
      if (locked.existsSync()) locked.deleteSync();
      locked.writeAsBytesSync(BackupCrypto.encrypt(plain, password));
      out.deleteSync();
      onProgress?.call(1);
      return locked;
    }
    onProgress?.call(1);
    return out;
  }

  /// Like [createBackup], but the zipping and the encryption run in another isolate, so the screen
  /// stays smooth. [onProgress] goes from 0 to 1.
  Future<File> createBackupInBackground(Directory outDir, {DateTime? now, String? password, int contacts = 0, void Function(double)? onProgress}) async {
    await flush?.call();
    final messages = ReceivePort();
    final errors = ReceivePort();
    final done = Completer<File>();
    messages.listen((m) {
      if (m is double) {
        onProgress?.call(m);
      } else if (m is String && !done.isCompleted) {
        done.complete(File(m));
      }
    });
    errors.listen((_) {
      if (!done.isCompleted) done.completeError(const BackupException('failed'));
    });
    final isolate = await Isolate.spawn(
      _backupEntry,
      <Object?>[messages.sendPort, docs.path, outDir.path, password, contacts, (now ?? DateTime.now()).millisecondsSinceEpoch],
      onError: errors.sendPort,
    );
    try {
      return await done.future;
    } finally {
      messages.close();
      errors.close();
      isolate.kill();
    }
  }

  /// True when the file is password protected.
  bool needsPassword(File f) {
    final raf = f.openSync();
    try {
      return BackupCrypto.isEncrypted(raf.readSync(8));
    } finally {
      raf.closeSync();
    }
  }

  /// Reads the manifest of a backup (decrypting it first when needed).
  Future<BackupMeta> inspect(File zip, {String? password}) async {
    final archive = _open(zip, password);
    final f = archive.files.where((x) => x.name == manifestName);
    if (f.isEmpty) throw const BackupException('not_a_backup');
    final List<int> raw = f.first.content;
    final info = jsonDecode(utf8.decode(raw));
    if (info is! Map || info['app'] != 'yonca') throw const BackupException('not_a_backup');
    return BackupMeta(
      createdAt: DateTime.tryParse('${info['createdAt']}') ?? zip.lastModifiedSync(),
      contacts: (info['contacts'] as num?)?.toInt() ?? 0,
    );
  }

  Archive _open(File zip, String? password) {
    var bytes = zip.readAsBytesSync();
    if (BackupCrypto.isEncrypted(bytes)) {
      if (password == null) throw const BackupException('password_needed');
      final plain = BackupCrypto.decrypt(bytes, password);
      if (plain == null) throw const BackupException('wrong_password');
      bytes = plain;
    }
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const BackupException('not_a_backup');
    }
  }

  /// Checks the zip and unpacks it into the pending folder. The restore happens at the next start.
  Future<void> stageRestore(File zip, {String? password}) async {
    final archive = _open(zip, password);
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

/// Runs in the background isolate of [BackupService.createBackupInBackground].
Future<void> _backupEntry(List<Object?> a) async {
  final send = a[0]! as SendPort;
  final svc = BackupService(Directory(a[1]! as String));
  final file = await svc.createBackup(
    Directory(a[2]! as String),
    password: a[3] as String?,
    contacts: a[4]! as int,
    now: DateTime.fromMillisecondsSinceEpoch(a[5]! as int),
    onProgress: send.send,
  );
  send.send(file.path);
}
