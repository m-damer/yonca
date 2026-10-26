import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/data/app_database.dart';
import 'package:yonca/data/contacts_repository.dart';
import 'package:yonca/data/fields_repository.dart';
import 'package:yonca/domain/contact_models.dart';
import 'package:yonca/domain/field_models.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late FieldsRepository repo;
  late ContactsRepository contacts;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FieldsRepository(db);
    contacts = ContactsRepository(db);
  });
  tearDown(() => db.close());

  test('validation: name length and choice options', () {
    expect(const FieldInput(scope: FieldScope.contact, name: ' ').problem(), 'name');
    expect(FieldInput(scope: FieldScope.contact, name: 'x' * 31).problem(), 'name');
    expect(const FieldInput(scope: FieldScope.contact, name: 'Size', type: FieldType.choice).problem(), 'options');
    expect(const FieldInput(scope: FieldScope.contact, name: 'Size', type: FieldType.choice, options: ['S', 'M']).problem(), isNull);
  });

  test('save, list in order, scopes are separate, max 15', () async {
    await repo.save(const FieldInput(scope: FieldScope.contact, name: 'Region'));
    await repo.save(const FieldInput(scope: FieldScope.deal, name: 'Warranty'));
    expect((await repo.fields(FieldScope.contact)).map((f) => f.name), ['Region']);
    for (var i = 0; i < 14; i++) {
      await repo.save(FieldInput(scope: FieldScope.contact, name: 'F$i'));
    }
    expect(() => repo.save(const FieldInput(scope: FieldScope.contact, name: 'One too many')), throwsA(isA<FieldValidationException>()));
  });

  test('values: set, clear, required check, type locked once used, archive keeps values, delete removes them', () async {
    final cid = await contacts.save(const ContactInput(firstName: 'A'));
    final f = await repo.save(const FieldInput(scope: FieldScope.contact, name: 'Region', required: true));
    expect((await repo.missingRequired(FieldScope.contact, cid)).map((x) => x.id), [f]);
    await repo.setValues(FieldScope.contact, cid, {f: ' North '});
    expect((await repo.values(FieldScope.contact, cid))[f], 'North');
    expect(await repo.missingRequired(FieldScope.contact, cid), isEmpty);
    expect(await repo.ownersWith(f, 'North'), {cid});
    expect(() => repo.save(const FieldInput(scope: FieldScope.contact, name: 'Region', type: FieldType.number), id: f),
        throwsA(isA<FieldValidationException>()));
    await repo.archive(f, true);
    expect(await repo.fields(FieldScope.contact), isEmpty);
    expect((await repo.values(FieldScope.contact, cid))[f], 'North');
    await repo.setValues(FieldScope.contact, cid, {f: ''});
    expect(await repo.usage(f), 0);
    await repo.setValues(FieldScope.contact, cid, {f: 'x'});
    await repo.delete(f);
    expect(await repo.values(FieldScope.contact, cid), isEmpty);
  });
}
