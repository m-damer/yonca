import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yonca/data/activities_repository.dart';
import 'package:yonca/data/app_database.dart';
import 'package:yonca/data/contacts_repository.dart';
import 'package:yonca/data/deals_repository.dart';
import 'package:yonca/data/timeline_builder.dart';
import 'package:yonca/domain/activity_models.dart';
import 'package:yonca/domain/contact_models.dart';
import 'package:yonca/domain/deal_models.dart';
import 'package:yonca/features/reports/timeline_report.dart';
import 'package:yonca/l10n/app_localizations.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting('en'));

  test('timeline lists every interaction newest first and marks voice notes', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final contacts = ContactsRepository(db);
    final acts = ActivitiesRepository(db);
    final deals = DealsRepository(db);
    final cid = await contacts.save(const ContactInput(firstName: 'Sara', lastName: 'Ali'));
    final outcome = (await acts.outcomes()).first;
    await acts.save(ActivityInput(type: ActivityType.call, contactId: cid, occurredAt: DateTime(2026, 10, 1, 9), direction: 'out', durationMinutes: 5, outcomeId: outcome.id));
    await acts.save(ActivityInput(
        type: ActivityType.note, contactId: cid, occurredAt: DateTime(2026, 10, 3, 10), title: 'Idea', description: 'Wants a quote', voicePath: '/x/a.m4a', voiceMs: 42000));
    final stage = (await deals.openStages()).first;
    final did = await deals.saveDeal(DealInput(title: 'Panels', contactId: cid, stageId: stage.id, amount: 10));
    await deals.moveDeal(did, (await deals.openStages()).last.id);

    final t = (await TimelineBuilder(contacts: contacts, activities: acts, deals: deals).build([cid])).single;
    final kinds = t.entries.map((e) => e.kind).toSet();
    expect(kinds, containsAll({TlKind.added, TlKind.call, TlKind.note, TlKind.dealCreated}));
    for (var i = 1; i < t.entries.length; i++) {
      expect(t.entries[i - 1].at.isBefore(t.entries[i].at), isFalse);
    }
    final note = t.entries.firstWhere((e) => e.kind == TlKind.note);
    expect(note.hasVoice, isTrue);

    final l = lookupAppLocalizations(const Locale('en'));
    final text = describeEntry(l, 'en', note);
    expect(text.head, 'Idea');
    expect(text.lines, contains('Wants a quote'));
    expect(text.lines.any((x) => x.contains('0:42') && x.contains('audio not included')), isTrue);
    final csv = timelineCsv(l, 'en', [t]);
    expect(csv.length, 1 + 1 + t.entries.length);
    expect(csv.first.length, csv.last.length);
  });
}
