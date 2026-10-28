import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yonca/data/backup_service.dart';

void main() {
  late Directory root;
  late Directory docs;

  setUp(() {
    root = Directory.systemTemp.createTempSync('yonca_backup_test');
    docs = Directory(p.join(root.path, 'docs'))..createSync();
    File(p.join(docs.path, 'yonca.sqlite')).writeAsStringSync('db-v1');
    File(p.join(docs.path, 'yonca.sqlite-wal')).writeAsStringSync('wal');
    Directory(p.join(docs.path, 'activity_files')).createSync();
    File(p.join(docs.path, 'activity_files', 'a.txt')).writeAsStringSync('hello');
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('storage use counts the database and the attached files, not the journal files', () async {
    final u = await BackupService(docs).storageUse();
    expect(u.databaseBytes, 5);
    expect(u.fileBytes, 5);
    expect(u.fileCount, 1);
  });

  test('backup, change data, stage the restore and apply it on start', () async {
    var flushed = false;
    final svc = BackupService(docs, flush: () async => flushed = true);
    final zip = await svc.createBackup(root, now: DateTime(2026, 10, 27));
    expect(flushed, isTrue);
    expect(p.basename(zip.path), 'yonca-backup-2026-10-27.zip');

    File(p.join(docs.path, 'yonca.sqlite')).writeAsStringSync('db-v2');
    File(p.join(docs.path, 'activity_files', 'a.txt')).deleteSync();
    File(p.join(docs.path, 'new.txt')).writeAsStringSync('x');

    await svc.stageRestore(zip);
    expect(svc.hasPendingRestore, isTrue);
    expect(File(p.join(docs.path, 'yonca.sqlite')).readAsStringSync(), 'db-v2');

    expect(svc.applyPendingRestore(), isTrue);
    expect(File(p.join(docs.path, 'yonca.sqlite')).readAsStringSync(), 'db-v1');
    expect(File(p.join(docs.path, 'activity_files', 'a.txt')).readAsStringSync(), 'hello');
    expect(File(p.join(docs.path, 'new.txt')).existsSync(), isFalse);
    expect(svc.hasPendingRestore, isFalse);
    expect(svc.applyPendingRestore(), isFalse);
  });

  test('a zip that is not a backup is refused', () async {
    final other = Directory(p.join(root.path, 'other'))..createSync();
    File(p.join(other.path, 'x.txt')).writeAsStringSync('x');
    final svc = BackupService(other);
    final zip = await svc.createBackup(root, now: DateTime(2026, 1, 1));
    // No database inside: staging must refuse it.
    expect(() => BackupService(docs).stageRestore(zip), throwsA(isA<BackupException>()));
  });

  test('deleteAttachedFiles keeps the database', () {
    BackupService(docs).deleteAttachedFiles();
    expect(File(p.join(docs.path, 'yonca.sqlite')).existsSync(), isTrue);
    expect(File(p.join(docs.path, 'activity_files', 'a.txt')).existsSync(), isFalse);
  });

  test('a password protected backup restores with the right password only', () async {
    final svc = BackupService(docs);
    final f = await svc.createBackup(root, now: DateTime(2026, 10, 27), password: 'secret');
    expect(p.basename(f.path), 'yonca-backup-2026-10-27.yonca');
    expect(svc.needsPassword(f), isTrue);
    await expectLater(svc.stageRestore(f), throwsA(isA<BackupException>().having((e) => e.problem, 'problem', 'password_needed')));
    await expectLater(svc.stageRestore(f, password: 'nope'), throwsA(isA<BackupException>().having((e) => e.problem, 'problem', 'wrong_password')));
    await svc.stageRestore(f, password: 'secret');
    expect(svc.hasPendingRestore, isTrue);
  });
}
