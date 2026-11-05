import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/data/activities_repository.dart';
import 'package:yonca/data/app_database.dart';
import 'package:yonca/data/contacts_repository.dart';
import 'package:yonca/data/deals_repository.dart';
import 'package:yonca/domain/deal_models.dart';
import 'package:yonca/domain/activity_models.dart';
import 'package:yonca/domain/contact_models.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late ContactsRepository contacts;
  late ActivitiesRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    contacts = ContactsRepository(db);
    repo = ActivitiesRepository(db);
  });
  tearDown(() => db.close());

  test('built-in outcomes are created once, in order', () async {
    final a = await repo.outcomes();
    expect(a.map((o) => o.key), defaultOutcomeKeys);
    expect((await repo.outcomes()).length, 4);
  });

  test('a call needs a contact and an outcome, a note needs a title', () async {
    final when = DateTime(2026, 10, 1, 9);
    expect(ActivityInput(type: ActivityType.call, occurredAt: when).problem(), 'contact');
    expect(ActivityInput(type: ActivityType.call, contactId: 1, occurredAt: when).problem(), 'outcome');
    expect(ActivityInput(type: ActivityType.note, occurredAt: when).problem(), 'title');
    expect(ActivityInput(type: ActivityType.note, title: 'Idea', occurredAt: when).problem(), isNull);
    expect(ActivityInput(type: ActivityType.message, contactId: 1, occurredAt: when).problem(), isNull);
    expect(() => repo.save(ActivityInput(type: ActivityType.call, occurredAt: when)),
        throwsA(isA<ActivityValidationException>()));
  });

  test('saving reads back with outcome, contact name and files, and moves the contact last activity', () async {
    final cid = await contacts.save(const ContactInput(firstName: 'Sara', lastName: 'Ali'));
    final outcome = (await repo.outcomes()).first;
    final when = DateTime(2026, 10, 5, 14, 30);
    final id = await repo.save(ActivityInput(
      type: ActivityType.call,
      contactId: cid,
      occurredAt: when,
      direction: 'out',
      durationMinutes: 12,
      outcomeId: outcome.id,
      description: 'Asked for a quote',
      files: const [ActivityFileInput(path: '/x/a.pdf', name: 'a.pdf'), ActivityFileInput(path: '/x/b.jpg', name: 'b.jpg', isImage: true)],
    ));
    final item = (await repo.get(id))!;
    expect(item.type, ActivityType.call);
    expect(item.contactName, 'Sara Ali');
    expect(item.outcome!.id, outcome.id);
    expect(item.activity.durationMinutes, 12);
    expect(item.files.map((f) => f.name), ['a.pdf', 'b.jpg']);
    expect((await contacts.get(cid))!.contact.lastActivityAt, when);
    final files = await repo.filesOfContact(cid);
    expect(files.length, 2);
  });

  test('list is newest first and filters by contact, type and no contact', () async {
    final a = await contacts.save(const ContactInput(firstName: 'A'));
    final b = await contacts.save(const ContactInput(firstName: 'B'));
    final o = (await repo.outcomes()).first.id;
    await repo.save(ActivityInput(type: ActivityType.call, contactId: a, occurredAt: DateTime(2026, 1, 1), outcomeId: o));
    await repo.save(ActivityInput(type: ActivityType.visit, contactId: b, occurredAt: DateTime(2026, 1, 3), outcomeId: o));
    await repo.save(ActivityInput(type: ActivityType.note, title: 'General', occurredAt: DateTime(2026, 1, 2)));
    expect((await repo.list()).map((i) => i.type), [ActivityType.visit, ActivityType.note, ActivityType.call]);
    expect((await repo.list(contactId: a)).length, 1);
    expect((await repo.list(types: {ActivityType.note})).single.contactName, isNull);
    expect((await repo.list(noContactOnly: true)).single.activity.title, 'General');
    expect((await repo.list(limit: 2)).length, 2);
    expect((await repo.list(limit: 2, offset: 2)).length, 1);
  });

  test('editing replaces files; deleting returns paths and recomputes last activity', () async {
    final cid = await contacts.save(const ContactInput(firstName: 'C'));
    final o = (await repo.outcomes()).first.id;
    final early = await repo.save(ActivityInput(type: ActivityType.call, contactId: cid, occurredAt: DateTime(2026, 2, 1), outcomeId: o));
    final late = await repo.save(ActivityInput(
      type: ActivityType.note,
      contactId: cid,
      title: 'Voice',
      occurredAt: DateTime(2026, 3, 1),
      voicePath: '/v/1.m4a',
      voiceMs: 4000,
      files: const [ActivityFileInput(path: '/x/f.pdf', name: 'f.pdf')],
    ));
    expect((await contacts.get(cid))!.contact.lastActivityAt, DateTime(2026, 3, 1));
    await repo.save(
        ActivityInput(type: ActivityType.note, contactId: cid, title: 'Voice', occurredAt: DateTime(2026, 3, 1), voicePath: '/v/1.m4a', voiceMs: 4000),
        id: late);
    expect((await repo.get(late))!.files, isEmpty);
    final paths = await repo.delete(late);
    expect(paths, ['/v/1.m4a']);
    expect(await repo.get(late), isNull);
    expect((await contacts.get(cid))!.contact.lastActivityAt, DateTime(2026, 2, 1));
    await repo.delete(early);
    expect((await contacts.get(cid))!.contact.lastActivityAt, isNull);
  });

  test('deleting a contact removes its activities', () async {
    final cid = await contacts.save(const ContactInput(firstName: 'D'));
    await repo.save(ActivityInput(type: ActivityType.message, contactId: cid, channel: 'whatsapp', direction: 'sent', occurredAt: DateTime(2026, 5, 1)));
    await contacts.delete(cid);
    expect(await repo.list(), isEmpty);
  });

  test('outcome list: add, rename, reorder, delete or archive, restore defaults, limit', () async {
    final base = await repo.outcomes();
    final extra = await repo.addOutcome('  Send quote ');
    expect((await repo.outcomes()).last.name, 'Send quote');
    expect(() => repo.addOutcome(''), throwsA(isA<ActivityValidationException>()));
    expect(() => repo.addOutcome('x' * 31), throwsA(isA<ActivityValidationException>()));

    await repo.renameOutcome(base.first.id, 'Hot lead');
    final renamed = (await repo.outcomes()).firstWhere((o) => o.id == base.first.id);
    expect(renamed.name, 'Hot lead');
    expect(renamed.key, isNull);

    final ids = (await repo.outcomes()).map((o) => o.id).toList().reversed.toList();
    await repo.reorderOutcomes(ids);
    expect((await repo.outcomes()).map((o) => o.id), ids);

    // an outcome that activities use is archived, an unused one is deleted
    final cid = await contacts.save(const ContactInput(firstName: 'E'));
    await repo.save(ActivityInput(type: ActivityType.call, contactId: cid, occurredAt: DateTime(2026, 1, 1), outcomeId: extra));
    expect(await repo.removeOutcome(extra), isFalse);
    expect((await repo.outcomes()).any((o) => o.id == extra), isFalse);
    expect((await repo.get((await repo.list()).first.activity.id))!.outcome!.name, 'Send quote');
    expect(await repo.removeOutcome(base[1].id), isTrue);

    await repo.restoreDefaultOutcomes();
    final keys = (await repo.outcomes()).map((o) => o.key).whereType<String>().toSet();
    expect(keys, containsAll(defaultOutcomeKeys.where((k) => k != 'interested')));
    expect(keys.contains('needsTime'), isTrue);

    for (var i = 0; i < 20; i++) {
      try {
        await repo.addOutcome('N$i');
      } on ActivityValidationException {
        break;
      }
    }
    expect((await repo.outcomes()).length, maxActiveOutcomes);
  });

  test('a contact timeline shows its deal created, moved, won and lost, and not other contacts', () async {
    final deals = DealsRepository(db);
    final sara = await contacts.save(const ContactInput(firstName: 'Sara'));
    final omar = await contacts.save(const ContactInput(firstName: 'Omar'));
    final stages = await deals.stages();
    final open = stages.where((s) => s.kind == 'open').toList();
    final a = await deals.saveDeal(DealInput(title: 'UPS 10 kVA', contactId: sara, stageId: open.first.id, amount: 5000));
    await deals.moveDeal(a, open[1].id);
    await deals.winDeal(a);
    final b = await deals.saveDeal(DealInput(title: 'Solar kit', contactId: sara, stageId: open.first.id));
    await deals.loseDeal(b, reason: 'noResponse');
    await deals.saveDeal(DealInput(title: 'Other deal', contactId: omar, stageId: open.first.id));

    final mine = await repo.systemEvents(since: DateTime(2000), contactId: sara);
    final kinds = mine.where((e) => e.title != 'Sara').map((e) => '${e.title}:${e.kind.name}').toList();
    expect(kinds, containsAll(['UPS 10 kVA:dealCreated', 'UPS 10 kVA:dealMoved', 'UPS 10 kVA:dealWon', 'Solar kit:dealCreated', 'Solar kit:dealLost']));
    expect(mine.any((e) => e.title == 'Other deal'), isFalse);
    expect(mine.firstWhere((e) => e.kind == SystemEventKind.dealCreated && e.title == 'UPS 10 kVA').amount, 5000);

    final all = await repo.systemEvents(since: DateTime(2000));
    expect(all.any((e) => e.title == 'Other deal' && e.contactName == 'Omar'), isTrue);
  });

  test('contacts added within two minutes of each other are one "N contacts added" event', () async {
    var now = DateTime(2026, 11, 5, 9);
    final timed = ContactsRepository(db, clock: () => now);
    final ids = <int>[];
    for (final name in ['Ann', 'Ben', 'Cy']) {
      ids.add(await timed.save(ContactInput(firstName: name)));
      now = now.add(const Duration(seconds: 20));
    }
    now = DateTime(2026, 11, 5, 11);
    final later = await timed.save(const ContactInput(firstName: 'Dina'));

    final added = (await repo.systemEvents(since: DateTime(2000))).where((e) => e.kind == SystemEventKind.contactAdded).toList();
    expect(added.length, 2);
    expect(added.first.title, 'Dina');
    expect(added.first.isBatch, isFalse);
    expect(added.first.contactId, later);
    expect(added.last.isBatch, isTrue);
    expect(added.last.contactIds.toSet(), ids.toSet());
    expect(added.last.contactIds.first, ids.last, reason: 'newest first');

    // One contact's own timeline never shows a batch.
    final mine = await repo.systemEvents(since: DateTime(2000), contactId: ids.first);
    expect(mine.where((e) => e.kind == SystemEventKind.contactAdded).single.isBatch, isFalse);

    final listed = await timed.byIds(added.last.contactIds);
    expect(listed.map((s) => s.contact.id), added.last.contactIds);
  });
}
