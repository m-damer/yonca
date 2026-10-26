import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/data/activities_repository.dart';
import 'package:yonca/data/app_database.dart';
import 'package:yonca/data/contacts_repository.dart';
import 'package:yonca/data/deals_repository.dart';
import 'package:yonca/data/fields_repository.dart';
import 'package:yonca/data/report_builder.dart';
import 'package:yonca/domain/activity_models.dart';
import 'package:yonca/domain/contact_models.dart';
import 'package:yonca/domain/deal_models.dart';
import 'package:yonca/domain/field_models.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('csv escapes commas, quotes and new lines and starts with a BOM', () {
    final csv = toCsv([
      ['Name', 'Note'],
      ['Sara, Ali', 'He said "hi"\nbye'],
    ]);
    expect(csv.startsWith('﻿'), isTrue);
    expect(csv, contains('"Sara, Ali","He said ""hi""\nbye"'));
    expect(csv.contains('\r\n'), isTrue);
  });

  test('builder collects activity counts, open deals and report fields', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final contacts = ContactsRepository(db);
    final acts = ActivitiesRepository(db);
    final deals = DealsRepository(db);
    final fields = FieldsRepository(db);
    final cid = await contacts.save(const ContactInput(firstName: 'Sara', lastName: 'Ali'));
    final outcome = (await acts.outcomes()).first;
    await acts.save(ActivityInput(type: ActivityType.call, contactId: cid, occurredAt: DateTime(2026, 10, 1), direction: 'out', outcomeId: outcome.id));
    await acts.save(ActivityInput(type: ActivityType.note, contactId: cid, occurredAt: DateTime(2026, 10, 3), title: 'Idea'));
    final stage = (await deals.openStages()).first;
    await deals.saveDeal(DealInput(title: 'Panels', contactId: cid, stageId: stage.id, amount: 10));
    final shown = await fields.save(const FieldInput(scope: FieldScope.contact, name: 'Region'));
    final hidden = await fields.save(const FieldInput(scope: FieldScope.contact, name: 'Secret', showInReports: false));
    await fields.setValues(FieldScope.contact, cid, {shown: 'North', hidden: 'x'});
    final b = ReportBuilder(contacts: contacts, activities: acts, deals: deals, fields: fields);
    final r = (await b.build([cid], const ReportOptions())).single;
    expect(r.calls, 1);
    expect(r.notes, 1);
    expect(r.lastActivity, DateTime(2026, 10, 3));
    expect(r.openDeals.single.deal.title, 'Panels');
    expect(r.fieldValues, [('Region', 'North')]);
    final slim = (await b.build([cid], const ReportOptions(history: false, deals: false, fields: false))).single;
    expect(slim.calls, 0);
    expect(slim.openDeals, isEmpty);
    expect(slim.fieldValues, isEmpty);
  });
}
