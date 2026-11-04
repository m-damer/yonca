import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yonca/data/app_database.dart';
import 'package:yonca/data/contacts_repository.dart';
import 'package:yonca/data/path_rebase.dart';
import 'package:yonca/domain/contact_models.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory root;
  late Directory docs;
  late AppDatabase db;
  late ContactsRepository repo;

  setUp(() {
    root = Directory.systemTemp.createTempSync('yonca_rebase');
    docs = Directory(p.join(root.path, 'new', 'app_flutter'))..createSync(recursive: true);
    Directory(p.join(docs.path, 'contact_photos')).createSync();
    File(p.join(docs.path, 'contact_photos', 'a.jpg')).writeAsStringSync('a');
    File(p.join(docs.path, 'contact_photos', 'profile_1.jpg')).writeAsStringSync('p');
    db = AppDatabase(NativeDatabase.memory());
    repo = ContactsRepository(db);
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  test('a path from another install is pointed at the same file in this documents folder', () {
    final top = {'contact_photos'};
    expect(PathRebase.fixed('/data/user/0/old.package/app_flutter/contact_photos/a.jpg', docs, top), p.join(docs.path, 'contact_photos', 'a.jpg'));
    // Already working, or not in the backup: left alone.
    expect(PathRebase.fixed(p.join(docs.path, 'contact_photos', 'a.jpg'), docs, top), isNull);
    expect(PathRebase.fixed('/data/user/0/old.package/app_flutter/contact_photos/missing.jpg', docs, top), isNull);
  });

  test('contact photo, profile picture and QR logo are all repaired once', () async {
    final id = await repo.save(const ContactInput(firstName: 'Sara', photoPath: '/data/user/0/old.package/app_flutter/contact_photos/a.jpg'));
    await db.putSetting('profile.photo', '/data/user/0/old.package/app_flutter/contact_photos/profile_1.jpg');
    await db.putSetting('qr.saved', jsonEncode([{'id': 1, 'logo': '/data/user/0/old.package/app_flutter/contact_photos/a.jpg'}]));
    final n = await PathRebase.run(db, docs);
    expect(n, 3);
    expect((await repo.get(id))!.contact.photoPath, p.join(docs.path, 'contact_photos', 'a.jpg'));
    expect(await db.getSetting('profile.photo'), p.join(docs.path, 'contact_photos', 'profile_1.jpg'));
    expect(jsonDecode((await db.getSetting('qr.saved'))!)[0]['logo'], p.join(docs.path, 'contact_photos', 'a.jpg'));
    // Second run in the same folder does nothing.
    expect(await PathRebase.run(db, docs), 0);
  });

  test('a backup folder that does not exist on this phone is forgotten', () async {
    await db.putSetting('backup.localDir', '/storage/emulated/0/NoSuchFolder');
    await db.putSetting('backup.autoLocal', 'daily');
    await PathRebase.run(db, docs);
    expect(await db.getSetting('backup.localDir'), '');
    expect(await db.getSetting('backup.autoLocal'), 'off');
  });
}
