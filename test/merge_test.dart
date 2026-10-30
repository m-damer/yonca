import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/data/activities_repository.dart';
import 'package:yonca/data/app_database.dart';
import 'package:yonca/data/contacts_repository.dart';
import 'package:yonca/data/deals_repository.dart';
import 'package:yonca/domain/activity_models.dart';
import 'package:yonca/domain/contact_models.dart';
import 'package:yonca/domain/deal_models.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('duplicate groups find contacts that share a number, even across formats', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ContactsRepository(db);
    final a = await repo.save(const ContactInput(firstName: 'Sara', phones: [PhoneInput(number: '0944 123 456')]));
    final b = await repo.save(const ContactInput(firstName: 'S.', phones: [PhoneInput(number: '+963 944 123 456', countryCode: '')]));
    await repo.save(const ContactInput(firstName: 'Other', phones: [PhoneInput(number: '0999 000 111')]));
    final groups = await repo.duplicateGroups();
    expect(groups.length, 1);
    expect(groups.single.map((s) => s.contact.id).toSet(), {a, b});
  });

  test('merge combines details and moves activities and deals, then removes the others', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ContactsRepository(db);
    final acts = ActivitiesRepository(db);
    final deals = DealsRepository(db);
    final a = await repo.save(const ContactInput(firstName: 'Sara', phones: [PhoneInput(number: '0944 123 456')], tags: ['Solar']));
    final b = await repo.save(const ContactInput(
      firstName: 'Sara',
      lastName: 'Ali',
      company: 'Sun Co',
      phones: [PhoneInput(number: '0944 123 456'), PhoneInput(number: '0933 111 222')],
      emails: [EntryInput(value: 'sara@example.com')],
      tags: ['Solar', 'VIP'],
      roles: [Role.client],
    ));
    final outcome = (await acts.outcomes()).first;
    await acts.save(ActivityInput(type: ActivityType.call, contactId: b, occurredAt: DateTime(2026, 10, 1), direction: 'out', outcomeId: outcome.id));
    final stage = (await deals.openStages()).first;
    await deals.saveDeal(DealInput(title: 'Panels', contactId: b, stageId: stage.id));

    await repo.merge(a, [b]);
    expect(await repo.get(b), isNull);
    final m = (await repo.get(a))!;
    expect(m.contact.lastName, 'Ali');
    expect(m.contact.company, 'Sun Co');
    expect(m.phones.length, 2);
    expect(m.emails.single.value, 'sara@example.com');
    expect(m.tags.map((t) => t.name).toSet(), {'Solar', 'VIP'});
    expect(m.roles, [Role.client]);
    expect((await acts.list(contactId: a)).length, 1);
    expect((await deals.listDeals(contactId: a)).single.deal.title, 'Panels');
    expect(m.contact.lastActivityAt, DateTime(2026, 10, 1));
    expect(await repo.duplicateGroups(), isEmpty);
  });

  test('duplicate pairs give a reason, and a hidden pair moves to the hidden list', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ContactsRepository(db);
    final a = await repo.save(const ContactInput(firstName: 'Lina', lastName: 'Haddad'));
    final b = await repo.save(const ContactInput(firstName: 'Lina', lastName: 'H.'));
    await repo.save(const ContactInput(firstName: 'Omar', lastName: 'Saleh', emails: [EntryInput(value: 'o@x.com')]));
    await repo.save(const ContactInput(firstName: 'Zed', lastName: 'Other', emails: [EntryInput(value: 'O@x.com')]));
    final pairs = await repo.duplicatePairs();
    expect(pairs.map((p) => p.reason).toSet(), {'name', 'email'});
    await repo.setPairHidden(a, b, true);
    expect((await repo.duplicatePairs()).length, 1);
    expect((await repo.duplicatePairs(hidden: true)).length, 1);
  });
}
