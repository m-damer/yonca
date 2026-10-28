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

@DriftDatabase(tables: [Settings, Contacts, ContactPhones, ContactEntries, ContactEvents, Outcomes, Activities, ActivityFiles, Tasks, TaskFiles, Meetings, MeetingContacts, DealStages, Deals, DealStageHistory, DealDocuments, CustomFields, CustomFieldValues, Targets, ContactRoles, Tags, ContactTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Clears every table except the settings (language, theme). Attached files are removed by the caller.
  Future<void> deleteAllData() async {
    await transaction(() async {
      for (final t in allTables.toList().reversed) {
        if (t.actualTableName == 'settings') continue;
        await delete(t).go();
      }
    });
  }

  @override
  int get schemaVersion => 12;

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
          if (from < 6) {
            await m.createTable(contactEvents);
          }
          if (from < 12) {
            await m.createTable(taskFiles);
          }
          if (from < 11) {
            await m.createTable(targets);
          }
          if (from < 10) {
            await m.createTable(customFields);
            await m.createTable(customFieldValues);
          }
          if (from < 9) {
            await m.createTable(dealStages);
            await m.createTable(deals);
            await m.createTable(dealStageHistory);
            await m.createTable(dealDocuments);
          }
          if (from < 8) {
            await m.createTable(tasks);
            await m.createTable(meetings);
            await m.createTable(meetingContacts);
          }
          if (from < 7) {
            await m.createTable(outcomes);
            await m.createTable(activities);
            await m.createTable(activityFiles);
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
