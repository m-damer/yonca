import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/data/app_database.dart';
import 'package:yonca/data/contacts_repository.dart';
import 'package:yonca/domain/contact_models.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late ContactsRepository repo;
  var now = DateTime(2026, 10, 26, 12);

  setUp(() {
    now = DateTime(2026, 10, 26, 12);
    db = AppDatabase(NativeDatabase.memory());
    repo = ContactsRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  test('a contact needs a first name, last name or company', () async {
    expect(() => repo.save(const ContactInput()), throwsA(isA<ContactValidationException>()));
    expect(await repo.save(const ContactInput(company: 'Al-Noor Trading')), isPositive);
  });

  test('saves and reads back phones, roles and tags', () async {
    final id = await repo.save(const ContactInput(
      firstName: 'Ahmad',
      lastName: 'Khoury',
      nickname: 'Abu Omar',
      company: 'Al-Noor Trading',
      rating: Rating.hot,
      phones: [
        PhoneInput(number: '0944 123 456', isWhatsApp: true),
        PhoneInput(number: '011 555 1234', label: 'work'),
      ],
      roles: [Role.client, Role.lead],
      tags: ['Solar', 'VIP'],
    ));
    final c = (await repo.get(id))!;
    expect(c.displayName, 'Ahmad Khoury');
    expect(c.contact.rating, 'hot');
    expect(c.phones.map((p) => p.number), ['0944 123 456', '011 555 1234']);
    expect(c.phones.first.isWhatsApp, isTrue);
    expect(c.roles, [Role.lead, Role.client]);
    expect(c.tags.map((t) => t.name), ['Solar', 'VIP']);
  });

  test('a company-only contact shows the company as its name', () async {
    final id = await repo.save(const ContactInput(company: 'Al-Noor Trading'));
    expect((await repo.get(id))!.displayName, 'Al-Noor Trading');
  });

  test('editing replaces phones, roles and tags', () async {
    final id = await repo.save(const ContactInput(
      firstName: 'Lina',
      phones: [PhoneInput(number: '0933 111 222')],
      roles: [Role.lead],
      tags: ['Old'],
    ));
    await repo.save(
      const ContactInput(
        firstName: 'Lina',
        phones: [PhoneInput(number: '0933 999 888')],
        roles: [Role.supplier],
        tags: ['New'],
      ),
      id: id,
    );
    final c = (await repo.get(id))!;
    expect(c.phones.map((p) => p.number), ['0933 999 888']);
    expect(c.roles, [Role.supplier]);
    expect(c.tags.map((t) => t.name), ['New']);
    expect((await repo.list()).length, 1);
  });

  test('tag names are shared across contacts, ignoring case', () async {
    await repo.save(const ContactInput(firstName: 'A', tags: ['Solar']));
    await repo.save(const ContactInput(firstName: 'B', tags: ['solar']));
    expect((await repo.allTags()).length, 1);
    expect((await repo.list(tagId: (await repo.allTags()).first.id)).length, 2);
  });

  test('deleting a contact removes its phones, roles and tag links', () async {
    final id = await repo.save(const ContactInput(
      firstName: 'Omar',
      phones: [PhoneInput(number: '0955 000 111')],
      roles: [Role.client],
      tags: ['X'],
    ));
    await repo.delete(id);
    expect(await db.select(db.contactPhones).get(), isEmpty);
    expect(await db.select(db.contactRoles).get(), isEmpty);
    expect(await db.select(db.contactTags).get(), isEmpty);
    expect(await repo.get(id), isNull);
  });

  group('duplicate phone', () {
    test('finds the existing contact however the number is typed', () async {
      final id = await repo.save(const ContactInput(
        firstName: 'Ahmad',
        phones: [PhoneInput(number: '0944 123 456')],
      ));
      expect((await repo.findByPhone('+963', '+963944123456'))?.contact.id, id);
      expect((await repo.findByPhone('+963', '٠٩٤٤١٢٣٤٥٦'))?.contact.id, id);
      expect(await repo.findByPhone('+90', '0944 123 456'), isNull);
    });
    test('ignores the contact being edited', () async {
      final id = await repo.save(const ContactInput(
        firstName: 'Ahmad',
        phones: [PhoneInput(number: '0944 123 456')],
      ));
      expect(await repo.findByPhone('+963', '0944 123 456', excludeId: id), isNull);
    });
  });

  group('search', () {
    setUp(() async {
      await repo.save(const ContactInput(
        firstName: 'أحمد',
        lastName: 'خوري',
        company: 'شركة النور',
        emails: [EntryInput(value: 'ahmad@noor.com')],
        requirements: 'UPS 20 kVA',
        phones: [PhoneInput(number: '0944 123 456')],
        tags: ['شمسي'],
      ));
      await repo.save(const ContactInput(firstName: 'Lina', lastName: 'Haddad', company: 'Haddad Electric'));
    });

    test('Arabic spellings match each other', () async {
      expect((await repo.list(query: 'احمد')).length, 1);
      expect((await repo.list(query: 'شركه النور')).length, 1);
    });
    test('matches name, company, email, phone, requirements and tag', () async {
      for (final q in ['خوري', 'noor', 'AHMAD@', '123 456', '٠٩٤٤', 'kva', 'شمسي']) {
        expect((await repo.list(query: q)).length, 1, reason: q);
      }
    });
    test('all words must match', () async {
      expect((await repo.list(query: 'lina haddad')).length, 1);
      expect((await repo.list(query: 'lina khoury')).length, 0);
    });
  });

  group('filters and counts', () {
    setUp(() async {
      await repo.save(const ContactInput(firstName: 'H', rating: Rating.hot, roles: [Role.client]));
      await repo.save(const ContactInput(firstName: 'W', rating: Rating.warm, roles: [Role.lead]));
      await repo.save(const ContactInput(firstName: 'U'));
    });
    test('rating tabs and counts', () async {
      expect((await repo.list(rating: Rating.hot)).single.displayName, 'H');
      final counts = await repo.ratingCounts();
      expect(counts[Rating.hot], 1);
      expect(counts[Rating.warm], 1);
      expect(counts[Rating.cold], 0);
      expect(counts[Rating.none], 1);
    });
    test('role filter', () async {
      expect((await repo.list(role: Role.lead)).single.displayName, 'W');
    });
    test('no activity for X days', () async {
      now = DateTime(2026, 11, 10, 12);
      expect((await repo.list(inactiveForDays: 14)).length, 3);
      expect((await repo.list(inactiveForDays: 30)).length, 0);
    });
  });

  group('sorting', () {
    test('by name, ignoring the article and grouping by script', () async {
      for (final n in ['Omar', 'النور', 'Ali', 'باسل', 'أحمد']) {
        await repo.save(ContactInput(firstName: n));
      }
      final ar = await repo.list(sort: ContactSort.name, arabicFirst: true);
      expect(ar.map((e) => e.displayName), ['أحمد', 'باسل', 'النور', 'Ali', 'Omar']);
      final en = await repo.list(sort: ContactSort.name);
      expect(en.map((e) => e.displayName), ['Ali', 'Omar', 'أحمد', 'باسل', 'النور']);
    });

    test('recently added puts the newest first', () async {
      await repo.save(const ContactInput(firstName: 'First'));
      now = now.add(const Duration(hours: 1));
      await repo.save(const ContactInput(firstName: 'Second'));
      final l = await repo.list(sort: ContactSort.recentlyAdded);
      expect(l.map((e) => e.displayName), ['Second', 'First']);
    });

    test('rating sort puts Hot first and longest idle sort puts the oldest first', () async {
      await repo.save(const ContactInput(firstName: 'ColdOne', rating: Rating.cold));
      now = DateTime(2026, 11, 2, 12);
      await repo.save(const ContactInput(firstName: 'HotOne', rating: Rating.hot));
      final byRating = await repo.list(sort: ContactSort.ratingHot);
      expect(byRating.map((e) => e.displayName), ['HotOne', 'ColdOne']);
      final idle = await repo.list(sort: ContactSort.longestIdle);
      expect(idle.first.displayName, 'ColdOne');
    });

    test('a contact with only a phone number is allowed and shows the number', () async {
      final id = await repo.save(const ContactInput(phones: [PhoneInput(number: '0944 123 456')]));
      final s = (await repo.get(id))!;
      expect(s.isIncomplete, isTrue);
      expect(s.displayName, '0944 123 456');
    });

    test('needs attention puts the most overdue first, by rating limit', () async {
      await repo.save(const ContactInput(firstName: 'HotOld', rating: Rating.hot));
      await repo.save(const ContactInput(firstName: 'ColdOld', rating: Rating.cold));
      now = DateTime(2026, 11, 20, 12); // 25 days idle: Hot is 18 over, Cold is not overdue
      await repo.save(const ContactInput(firstName: 'Fresh', rating: Rating.hot));
      final l = await repo.list(sort: ContactSort.needsAttention);
      expect(l.first.displayName, 'HotOld');
      expect(l.last.displayName, 'Fresh');
    });
  });

  test('the list stream emits again after a change', () async {
    final stream = repo.watchList();
    final emissions = <int>[];
    final sub = stream.listen((l) => emissions.add(l.length));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.save(const ContactInput(firstName: 'New'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();
    expect(emissions.first, 0);
    expect(emissions.last, 1);
  });

  test('a version 2 database gains labels, and its email, website and address move to the new table', () async {
    final old = AppDatabase(NativeDatabase.memory(setup: (raw) {
      raw.execute('CREATE TABLE settings ("key" TEXT NOT NULL PRIMARY KEY, "value" TEXT NOT NULL)');
      raw.execute(
          'CREATE TABLE contacts (id INTEGER PRIMARY KEY AUTOINCREMENT, first_name TEXT NOT NULL DEFAULT \'\', '
          'last_name TEXT NOT NULL DEFAULT \'\', company TEXT NOT NULL DEFAULT \'\', nickname TEXT NOT NULL DEFAULT \'\', '
          'job_title TEXT NOT NULL DEFAULT \'\', email TEXT NOT NULL DEFAULT \'\', website TEXT NOT NULL DEFAULT \'\', '
          'address TEXT NOT NULL DEFAULT \'\', requirements TEXT NOT NULL DEFAULT \'\', '
          'temporary_note TEXT NOT NULL DEFAULT \'\', rating TEXT NOT NULL DEFAULT \'none\', photo_path TEXT NULL, '
          'status_override TEXT NULL, sort_key TEXT NOT NULL DEFAULT \'\', search_text TEXT NOT NULL DEFAULT \'\', '
          'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, last_activity_at INTEGER NULL)');
      raw.execute("INSERT INTO contacts (first_name, email, address, created_at, updated_at) VALUES ('Old', 'a@b.com', 'Damascus', 0, 0)");
      raw.execute('PRAGMA user_version = 2');
    }));
    addTearDown(old.close);
    final rows = await old.select(old.contacts).get();
    expect(rows.single.firstName, 'Old');
    expect(rows.single.emailLabel, 'work');
    final entries = await (old.select(old.contactEntries)..orderBy([(t) => OrderingTerm.asc(t.kind)])).get();
    expect(entries.map((e) => '${e.kind}:${e.value}'), ['address:Damascus', 'email:a@b.com']);
  });

  test('several emails, websites and addresses (with a map link) are saved and read back', () async {
    final id = await repo.save(const ContactInput(
      firstName: 'Sara',
      emails: [EntryInput(value: 'a@x.com'), EntryInput(value: 'b@x.com', label: 'home')],
      websites: [EntryInput(value: 'x.com'), EntryInput(value: 'y.com', label: 'other')],
      addresses: [EntryInput(value: 'Street 1', mapLink: 'https://maps.app.goo.gl/abc'), EntryInput(value: 'Street 2')],
    ));
    var s = (await repo.get(id))!;
    expect(s.emails.map((e) => e.value), ['a@x.com', 'b@x.com']);
    expect(s.emails.last.label, 'home');
    expect(s.websites.length, 2);
    expect(s.addresses.first.mapLink, 'https://maps.app.goo.gl/abc');
    expect(s.addresses.last.mapLink, '');
    expect((await repo.list(query: 'b@x.com')).length, 1);
    await repo.save(const ContactInput(firstName: 'Sara', emails: [EntryInput(value: 'c@x.com')]), id: id);
    s = (await repo.get(id))!;
    expect(s.emails.map((e) => e.value), ['c@x.com']);
    expect(s.addresses, isEmpty);
  });

  test('prefix and department are saved, read back and searchable', () async {
    final id = await repo.save(const ContactInput(firstName: 'Sara', prefix: 'Dr.', department: 'Procurement'));
    final c = (await repo.get(id))!.contact;
    expect(c.prefix, 'Dr.');
    expect(c.department, 'Procurement');
    expect((await repo.list(query: 'procurement')).length, 1);
  });

  test('events are saved in order, read back, replaced on edit and searchable', () async {
    final id = await repo.save(ContactInput(firstName: 'Omar', events: [
      EventInput(title: 'Birthday', date: DateTime(1990, 5, 17)),
      EventInput(title: 'Contract signed', date: DateTime(2025, 2, 3), yearly: false),
      EventInput(title: '  ', date: DateTime(2020, 1, 1)),
    ]));
    final ev = (await repo.get(id))!.events;
    expect(ev.map((e) => e.title), ['Birthday', 'Contract signed']);
    expect(ev.first.date, DateTime(1990, 5, 17));
    expect(ev.last.yearly, isFalse);
    expect((await repo.list(query: 'birthday')).length, 1);
    await repo.save(ContactInput(firstName: 'Omar', events: [EventInput(title: 'Name day', date: DateTime(2000, 6, 1))]), id: id);
    expect((await repo.get(id))!.events.map((e) => e.title), ['Name day']);
  });

  test('a database from the first release gains the contact tables', () async {
    final old = AppDatabase(NativeDatabase.memory(setup: (raw) {
      raw.execute('CREATE TABLE settings ("key" TEXT NOT NULL PRIMARY KEY, "value" TEXT NOT NULL)');
      raw.execute("INSERT INTO settings VALUES ('language','ar')");
      raw.execute('PRAGMA user_version = 1');
    }));
    addTearDown(old.close);
    expect(await old.getSetting('language'), 'ar');
    final r = ContactsRepository(old);
    final id = await r.save(const ContactInput(firstName: 'After upgrade'));
    expect((await r.get(id))!.displayName, 'After upgrade');
  });
}
