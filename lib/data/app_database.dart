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

@DriftDatabase(tables: [Settings, Contacts, ContactPhones, ContactEntries, ContactRoles, Tags, ContactTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 5;

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
          if (from >= 2 && from < 5) {
            await m.addColumn(contacts, contacts.prefix);
            await m.addColumn(contacts, contacts.department);
          }
          if (from < 4) {
            await m.createTable(contactEntries);
            // Move the old single email, website and address into the new table.
            for (final kind in ['email', 'website', 'address']) {
              await customStatement(
                  'INSERT INTO contact_entries (contact_id, kind, value, label, map_link, position) '
                  "SELECT id, '$kind', $kind, ${kind}_label, '', 0 FROM contacts WHERE $kind <> ''");
            }
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
