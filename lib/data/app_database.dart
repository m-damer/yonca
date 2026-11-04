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
  int get schemaVersion => 15;

  /// Indexes on the columns the app looks rows up by (the contact an item belongs to, dates, sort keys),
  /// so opening a contact or a list stays fast with tens of thousands of rows. Safe to run again.
  static const indexes = <String, String>{
    'idx_contacts_sort_key': 'contacts(sort_key)',
    'idx_contacts_last_activity': 'contacts(last_activity_at)',
    'idx_contact_phones_contact': 'contact_phones(contact_id)',
    'idx_contact_entries_contact': 'contact_entries(contact_id)',
    'idx_contact_events_contact': 'contact_events(contact_id)',
    'idx_contact_roles_role': 'contact_roles(role)',
    'idx_contact_tags_tag': 'contact_tags(tag_id)',
    'idx_activities_contact': 'activities(contact_id, occurred_at)',
    'idx_activities_occurred': 'activities(occurred_at)',
    'idx_activity_files_activity': 'activity_files(activity_id)',
    'idx_tasks_contact': 'tasks(contact_id)',
    'idx_tasks_due': 'tasks(due_at)',
    'idx_task_files_task': 'task_files(task_id)',
    'idx_meetings_start': 'meetings(start_at)',
    'idx_meeting_contacts_contact': 'meeting_contacts(contact_id)',
    'idx_deals_contact': 'deals(contact_id)',
    'idx_deals_stage': 'deals(stage_id)',
    'idx_deal_history_deal': 'deal_stage_history(deal_id)',
    'idx_deal_documents_deal': 'deal_documents(deal_id)',
    'idx_field_values_owner': 'custom_field_values(owner_id)',
  };

  Future<void> createIndexes() async {
    for (final e in indexes.entries) {
      await customStatement('CREATE INDEX IF NOT EXISTS ${e.key} ON ${e.value}');
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await createIndexes();
        },
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
          if (from >= 2 && from < 14) {
            await m.addColumn(contacts, contacts.middleName);
            await m.addColumn(contacts, contacts.suffix);
            await m.addColumn(contacts, contacts.phoneticName);
          }
          if (from < 12) {
            await m.createTable(taskFiles);
          }
          if (from >= 6 && from < 13) {
            await m.addColumn(contactEvents, contactEvents.alarm);
            await m.addColumn(contactEvents, contactEvents.alertMinutes);
            await m.addColumn(contactEvents, contactEvents.remindMask);
            await m.addColumn(contactEvents, contactEvents.note);
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
          // Always last: every table exists by now, whichever version the database came from.
          if (from < 15) await createIndexes();
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
