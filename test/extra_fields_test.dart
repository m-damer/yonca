import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/data/app_database.dart';
import 'package:yonca/data/contacts_repository.dart';
import 'package:yonca/domain/contact_models.dart';
import 'package:yonca/domain/vcard.dart';


void main() {
  test('middle name, suffix, phonetic, relations and messengers are stored and exported', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ContactsRepository(db);
    final id = await repo.save(const ContactInput(
      firstName: 'Omar',
      middleName: 'Khaled',
      lastName: 'Nasser',
      suffix: 'Jr.',
      phoneticName: 'Oh-mar',
      relations: [EntryInput(value: 'Lina', label: 'spouse')],
      ims: [EntryInput(value: '@omar', label: 'telegram')],
    ));
    final s = (await repo.get(id))!;
    expect(s.contact.middleName, 'Khaled');
    expect(s.displayName, 'Omar Khaled Nasser');
    expect(s.relations.single.label, 'spouse');
    expect(s.ims.single.value, '@omar');
    final back = s.toInput();
    expect(back.suffix, 'Jr.');
    expect(back.phoneticName, 'Oh-mar');
    final card = parseVCards(encodeVCard(s)).single;
    expect(card.middleName, 'Khaled');
    expect(card.suffix, 'Jr.');
  });

  test('enrich adds missing details and tags but keeps what is stored', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ContactsRepository(db);
    final id = await repo.save(const ContactInput(firstName: 'Sara', company: 'Mine', phones: [PhoneInput(number: '911111111')], tags: ['VIP']));
    final changed = await repo.enrich(
      id,
      const ContactInput(firstName: 'Sarah', company: 'Theirs', middleName: 'M', phones: [PhoneInput(number: '911111111')], tags: ['Family'], emails: [EntryInput(value: 'a@b.c')]),
    );
    expect(changed, isTrue);
    final s = (await repo.get(id))!;
    expect(s.contact.firstName, 'Sara');
    expect(s.contact.company, 'Mine');
    expect(s.contact.middleName, 'M');
    expect(s.tags.map((t) => t.name).toSet(), {'VIP', 'Family'});
    expect(s.emails.single.value, 'a@b.c');
    expect(await repo.enrich(id, const ContactInput(firstName: 'Sarah', tags: ['Family'])), isFalse);
  });
}
