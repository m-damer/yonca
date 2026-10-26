import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Key-value app settings (language, theme). Domain tables arrive with M1.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Settings, Contacts, ContactPhones, ContactRoles, Tags, ContactTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Each schema change adds a step here and a migration test.
          if (from < 2) {
            await m.createTable(contacts);
            await m.createTable(contactPhones);
            await m.createTable(contactRoles);
            await m.createTable(tags);
            await m.createTable(contactTags);
          } else if (from < 3) {
            await m.addColumn(contacts, contacts.emailLabel);
            await m.addColumn(contacts, contacts.websiteLabel);
            await m.addColumn(contacts, contacts.addressLabel);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> putSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
}
