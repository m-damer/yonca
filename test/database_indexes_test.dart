import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yonca/data/app_database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<Set<String>> indexNames(AppDatabase db) async {
    final rows = await db.customSelect("SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'").get();
    return {for (final r in rows) r.read<String>('name')};
  }

  test('a new database has every index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await indexNames(db), AppDatabase.indexes.keys.toSet());
  });

  test('looking up a contact\'s items uses an index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final q in [
      'SELECT * FROM activities WHERE contact_id = 1',
      'SELECT * FROM tasks WHERE contact_id = 1',
      'SELECT * FROM deals WHERE contact_id = 1',
      'SELECT * FROM contact_phones WHERE contact_id = 1',
    ]) {
      final plan = await db.customSelect('EXPLAIN QUERY PLAN $q').get();
      final text = plan.map((r) => r.read<String>('detail')).join(' ');
      expect(text, contains('USING INDEX'), reason: q);
    }
  });

  test('a version 14 database gains the indexes and keeps its data', () async {
    final dir = Directory.systemTemp.createTempSync('yonca_idx');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'old.sqlite'));

    var db = AppDatabase(NativeDatabase(file));
    await db.putSetting('language', 'ar');
    for (final name in AppDatabase.indexes.keys) {
      await db.customStatement('DROP INDEX $name');
    }
    await db.customStatement('PRAGMA user_version = 14');
    expect(await indexNames(db), isEmpty);
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await db.getSetting('language'), 'ar');
    expect(await indexNames(db), AppDatabase.indexes.keys.toSet());
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 15);
  });
}
