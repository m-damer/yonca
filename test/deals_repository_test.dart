import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/data/app_database.dart';
import 'package:yonca/data/contacts_repository.dart';
import 'package:yonca/data/deals_repository.dart';
import 'package:yonca/domain/contact_models.dart';
import 'package:yonca/domain/deal_models.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late ContactsRepository contacts;
  late DealsRepository repo;
  var now = DateTime(2026, 10, 10, 12);

  setUp(() {
    now = DateTime(2026, 10, 10, 12);
    db = AppDatabase(NativeDatabase.memory());
    contacts = ContactsRepository(db);
    repo = DealsRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  test('default stages: Lead, Quote, Talks, then fixed Won and Lost', () async {
    final s = await repo.stages();
    expect(s.map((x) => x.key), ['lead', 'quote', 'talks', 'won', 'lost']);
    expect(s.map((x) => x.kind), ['open', 'open', 'open', 'won', 'lost']);
    expect((await repo.stages()).length, 5);
  });

  test('stage editing: add, rename, limit of 8, reorder, delete moves deals', () async {
    final open = await repo.openStages();
    final id = await repo.addStage('Visit', 3);
    await repo.renameStage(id, 'On site');
    expect((await repo.openStages()).last.name, 'On site');
    expect(() => repo.addStage('', 1), throwsA(isA<DealValidationException>()));
    for (var i = 0; i < 4; i++) {
      await repo.addStage('S$i', i);
    }
    expect(() => repo.addStage('Too many', 0), throwsA(isA<DealValidationException>()));
    expect((await repo.openStages()).length, 8);
    final order = (await repo.openStages()).map((s) => s.id).toList().reversed.toList();
    await repo.reorderOpenStages(order);
    expect((await repo.openStages()).first.id, order.first);
    expect(() => repo.renameStage((await repo.stageOfKind(StageKind.won)).id, 'x'), throwsA(isA<DealValidationException>()));

    final cid = await contacts.save(const ContactInput(firstName: 'Sara'));
    final d = await repo.saveDeal(DealInput(title: 'Panels', contactId: cid, stageId: open.first.id));
    expect(() => repo.removeStage(open.first.id), throwsA(isA<DealValidationException>()));
    await repo.removeStage(open.first.id, moveTo: open[1].id);
    expect((await repo.getDeal(d))!.stage.id, open[1].id);
  });

  test('a deal needs a title and a contact; it starts with a history row', () async {
    final lead = (await repo.openStages()).first;
    expect(() => repo.saveDeal(DealInput(title: ' ', contactId: 1, stageId: lead.id)), throwsA(isA<DealValidationException>()));
    expect(() => repo.saveDeal(DealInput(title: 'A', contactId: null, stageId: lead.id)), throwsA(isA<DealValidationException>()));
    final cid = await contacts.save(const ContactInput(firstName: 'Sara', lastName: 'Ali'));
    final id = await repo.saveDeal(DealInput(
        title: 'Offer 112', contactId: cid, amount: 1500, currency: 'USD', stageId: lead.id, expectedClose: DateTime(2026, 10, 1)));
    final item = (await repo.getDeal(id))!;
    expect(item.contactName, 'Sara Ali');
    expect(item.pastClose, isTrue);
    expect(item.daysInStage, 0);
    expect((await repo.history(id)).single.fromName, isNull);
    now = DateTime(2026, 10, 15, 12);
    expect((await repo.getDeal(id))!.daysInStage, 5);
  });

  test('moving, winning (Lead becomes Client), losing and reopening write history', () async {
    final open = await repo.openStages();
    final cid = await contacts.save(const ContactInput(firstName: 'Sara', roles: [Role.lead]));
    final id = await repo.saveDeal(DealInput(title: 'D', contactId: cid, amount: 100, stageId: open.first.id));
    await repo.moveDeal(id, open[1].id);
    expect((await repo.getDeal(id))!.stage.id, open[1].id);
    await repo.winDeal(id, finalAmount: 90, date: DateTime(2026, 10, 9));
    var item = (await repo.getDeal(id))!;
    expect(item.kind, StageKind.won);
    expect(item.deal.amount, 90);
    expect(item.deal.closedAt, DateTime(2026, 10, 9));
    expect((await contacts.get(cid))!.roles, [Role.client]);
    await repo.moveDeal(id, open.first.id);
    item = (await repo.getDeal(id))!;
    expect(item.isOpen, isTrue);
    expect(item.deal.closedAt, isNull);
    await repo.loseDeal(id, reason: 'price', note: ' too high ');
    item = (await repo.getDeal(id))!;
    expect(item.kind, StageKind.lost);
    expect(item.deal.lostReason, 'price');
    expect(item.deal.lostNote, 'too high');
    expect((await repo.history(id)).length, 5);
    expect(() => repo.moveDeal(id, item.stage.id), throwsA(isA<DealValidationException>()));
  });

  test('summaries total per currency and skip deals without an amount', () async {
    final open = await repo.openStages();
    final cid = await contacts.save(const ContactInput(firstName: 'A'));
    await repo.saveDeal(DealInput(title: '1', contactId: cid, amount: 100, stageId: open.first.id));
    await repo.saveDeal(DealInput(title: '2', contactId: cid, amount: 50, stageId: open.first.id));
    await repo.saveDeal(DealInput(title: '3', contactId: cid, amount: 2000000, currency: 'SYP', stageId: open.first.id));
    await repo.saveDeal(DealInput(title: '4', contactId: cid, stageId: open.first.id));
    final s = (await repo.summaries()).first;
    expect(s.count, 4);
    expect(s.totals, {'USD': 150.0, 'SYP': 2000000.0});
  });

  test('list sorts by expected close, search by title or contact, documents and delete', () async {
    final open = await repo.openStages();
    final cid = await contacts.save(const ContactInput(firstName: 'Omar'));
    final a = await repo.saveDeal(DealInput(title: 'Late', contactId: cid, stageId: open.first.id, expectedClose: DateTime(2026, 12, 1)));
    final b = await repo.saveDeal(DealInput(title: 'Soon', contactId: cid, stageId: open.first.id, expectedClose: DateTime(2026, 11, 1)));
    final c = await repo.saveDeal(DealInput(title: 'None', contactId: cid, stageId: open.first.id));
    expect((await repo.listDeals(stageId: open.first.id)).map((i) => i.deal.id), [b, a, c]);
    expect((await repo.listDeals(query: 'omar')).length, 3);
    expect((await repo.listDeals(query: 'soo')).single.deal.id, b);
    expect((await repo.listDeals(contactId: cid + 1)), isEmpty);
    await repo.saveDocument(a, reference: 'INV-1', amount: 10, date: DateTime(2026, 10, 1), path: '/x/y.pdf', name: 'y.pdf');
    expect((await repo.documents(a)).single.reference, 'INV-1');
    expect(await repo.deleteDeal(a), ['/x/y.pdf']);
    expect(await repo.getDeal(a), isNull);
    expect(await repo.documents(a), isEmpty);
  });
}
