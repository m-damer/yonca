import 'package:drift/drift.dart';

import '../core/text_normalize.dart';
import '../domain/contact_models.dart';
import 'app_database.dart';

/// All reads and writes of contacts, phones, roles and tags.
class ContactsRepository {
  ContactsRepository(this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;

  /// Creates a contact, or replaces all fields of contact [id]. Returns the contact id.
  Future<int> save(ContactInput input, {int? id}) async {
    input.validate();
    return db.transaction(() async {
      final now = _clock();
      final phones = <(PhoneInput, String)>[
        for (final p in input.phones)
          if (p.number.trim().isNotEmpty) (p, normalizePhone(p.countryCode, p.number)),
      ];
      final tagIds = <int>{};
      final tagNames = <String>[];
      for (final name in input.tags) {
        if (name.trim().isEmpty) continue;
        tagIds.add(await _tagId(name));
        tagNames.add(name.trim());
      }
      final name = '${input.firstName} ${input.lastName}'.trim();
      final sortName = name.isNotEmpty
          ? name
          : input.company.trim().isNotEmpty
              ? input.company
              : (phones.isEmpty ? '' : phones.first.$1.number);
      final search = _searchText(input, phones.map((p) => p.$2).toList(), tagNames);

      final fields = ContactsCompanion(
        firstName: Value(input.firstName.trim()),
        lastName: Value(input.lastName.trim()),
        company: Value(input.company.trim()),
        prefix: Value(input.prefix.trim()),
        nickname: Value(input.nickname.trim()),
        jobTitle: Value(input.jobTitle.trim()),
        department: Value(input.department.trim()),
        email: const Value(''),
        website: const Value(''),
        address: const Value(''),
        requirements: Value(input.requirements.trim()),
        temporaryNote: Value(input.temporaryNote.trim()),
        rating: Value(input.rating.name),
        photoPath: Value(input.photoPath),
        sortKey: Value(sortKeyOf(sortName)),
        searchText: Value(search),
        updatedAt: Value(now),
      );

      final int contactId;
      if (id == null) {
        contactId = await db.into(db.contacts).insert(fields.copyWith(createdAt: Value(now)));
      } else {
        await (db.update(db.contacts)..where((t) => t.id.equals(id))).write(fields);
        contactId = id;
        await (db.delete(db.contactPhones)..where((t) => t.contactId.equals(id))).go();
        await (db.delete(db.contactEntries)..where((t) => t.contactId.equals(id))).go();
        await (db.delete(db.contactRoles)..where((t) => t.contactId.equals(id))).go();
        await (db.delete(db.contactTags)..where((t) => t.contactId.equals(id))).go();
      }

      for (var i = 0; i < phones.length; i++) {
        final (p, normalized) = phones[i];
        await db.into(db.contactPhones).insert(ContactPhonesCompanion.insert(
              contactId: contactId,
              number: p.number.trim(),
              normalized: normalized,
              countryCode: Value(p.countryCode),
              label: Value(p.label),
              isWhatsApp: Value(p.isWhatsApp),
              position: Value(i),
            ));
      }
      var pos = 0;
      for (final (kind, list) in [
        ('email', input.emails),
        ('website', input.websites),
        ('address', input.addresses),
      ]) {
        for (final e in list) {
          if (e.value.trim().isEmpty) continue;
          await db.into(db.contactEntries).insert(ContactEntriesCompanion.insert(
                contactId: contactId,
                kind: kind,
                value: e.value.trim(),
                label: Value(e.label),
                mapLink: Value(kind == 'address' ? e.mapLink.trim() : ''),
                position: Value(pos++),
              ));
        }
      }
      for (final r in input.roles.toSet()) {
        await db.into(db.contactRoles).insert(
            ContactRolesCompanion.insert(contactId: contactId, role: r.name));
      }
      for (final t in tagIds) {
        await db.into(db.contactTags).insert(
            ContactTagsCompanion.insert(contactId: contactId, tagId: t));
      }
      return contactId;
    });
  }

  Future<void> delete(int id) =>
      (db.delete(db.contacts)..where((t) => t.id.equals(id))).go();

  Future<ContactSummary?> get(int id) async {
    final all = await _loadAll();
    for (final c in all) {
      if (c.contact.id == id) return c;
    }
    return null;
  }

  /// The contact that already has this phone number, if any (the duplicate warning).
  Future<ContactSummary?> findByPhone(String countryCode, String number, {int? excludeId}) async {
    final normalized = normalizePhone(countryCode, number);
    if (normalized.isEmpty) return null;
    final rows = await (db.select(db.contactPhones)
          ..where((t) => t.normalized.equals(normalized)))
        .get();
    for (final r in rows) {
      if (r.contactId != excludeId) return get(r.contactId);
    }
    return null;
  }

  /// Contacts matching all the given filters, in the given order.
  /// [query] words must all appear (Arabic-aware) in the contact's searchable text.
  Future<List<ContactSummary>> list({
    String query = '',
    Rating? rating,
    Role? role,
    int? tagId,
    int? inactiveForDays,
    ContactSort sort = ContactSort.recentActivity,
    bool arabicFirst = false,
  }) async {
    final now = _clock();
    final words = normalizeText(query).split(' ').where((w) => w.isNotEmpty).toList();
    var items = await _loadAll();
    items = items.where((s) {
      final c = s.contact;
      if (rating != null && ratingFromName(c.rating) != rating) return false;
      if (role != null && !s.roles.contains(role)) return false;
      if (tagId != null && !s.tags.any((t) => t.id == tagId)) return false;
      if (inactiveForDays != null && _daysIdle(c, now) < inactiveForDays) return false;
      for (final w in words) {
        if (!c.searchText.contains(w)) return false;
      }
      return true;
    }).toList();

    int byDate(DateTime a, DateTime b) => b.compareTo(a);
    switch (sort) {
      case ContactSort.name:
        items.sort((a, b) {
          final r = compareSortKeys(a.contact.sortKey, b.contact.sortKey, arabicFirst: arabicFirst);
          return r != 0 ? r : a.contact.id.compareTo(b.contact.id);
        });
      case ContactSort.recentlyAdded:
        items.sort((a, b) => byDate(a.contact.createdAt, b.contact.createdAt));
      case ContactSort.recentActivity:
        items.sort((a, b) => byDate(_lastTouch(a.contact), _lastTouch(b.contact)));
      case ContactSort.ratingHot:
        int rank(Contact c) => switch (ratingFromName(c.rating)) {
              Rating.hot => 0,
              Rating.warm => 1,
              Rating.cold => 2,
              Rating.none => 3,
            };
        items.sort((a, b) {
          final r = rank(a.contact).compareTo(rank(b.contact));
          return r != 0 ? r : byDate(_lastTouch(a.contact), _lastTouch(b.contact));
        });
      case ContactSort.longestIdle:
        items.sort((a, b) => _lastTouch(a.contact).compareTo(_lastTouch(b.contact)));
      case ContactSort.needsAttention:
        items.sort((a, b) {
          final r = _overdueDays(b.contact, now).compareTo(_overdueDays(a.contact, now));
          return r != 0 ? r : _lastTouch(a.contact).compareTo(_lastTouch(b.contact));
        });
    }
    return items;
  }

  /// Live version of [list]: emits again whenever contacts, phones, roles or tags change.
  Stream<List<ContactSummary>> watchList({
    String query = '',
    Rating? rating,
    Role? role,
    int? tagId,
    int? inactiveForDays,
    ContactSort sort = ContactSort.recentActivity,
    bool arabicFirst = false,
  }) {
    return db
        .customSelect('SELECT 1', readsFrom: {
          db.contacts,
          db.contactPhones,
          db.contactEntries,
          db.contactRoles,
          db.tags,
          db.contactTags,
        })
        .watch()
        .asyncMap((_) => list(
              query: query,
              rating: rating,
              role: role,
              tagId: tagId,
              inactiveForDays: inactiveForDays,
              sort: sort,
              arabicFirst: arabicFirst,
            ));
  }

  /// Number of contacts per rating tab; the All count is the sum.
  Future<Map<Rating, int>> ratingCounts() async {
    final counts = {for (final r in Rating.values) r: 0};
    for (final c in await db.select(db.contacts).get()) {
      final r = ratingFromName(c.rating);
      counts[r] = counts[r]! + 1;
    }
    return counts;
  }

  Future<List<Tag>> allTags() =>
      (db.select(db.tags)..orderBy([(t) => OrderingTerm.asc(t.nameKey)])).get();

  // ---- internals ----

  DateTime _lastTouch(Contact c) => c.lastActivityAt ?? c.createdAt;

  int _daysIdle(Contact c, DateTime now) => now.difference(_lastTouch(c)).inDays;

  int _overdueDays(Contact c, DateTime now) {
    final limit = inactivityDays[ratingFromName(c.rating)]!;
    final over = _daysIdle(c, now) - limit;
    return over > 0 ? over : 0;
  }

  Future<int> _tagId(String name) async {
    final key = normalizeText(name);
    final existing = await (db.select(db.tags)..where((t) => t.nameKey.equals(key))).getSingleOrNull();
    if (existing != null) return existing.id;
    final count = (await db.select(db.tags).get()).length;
    return db.into(db.tags).insert(TagsCompanion.insert(name: name.trim(), nameKey: key, colorIndex: Value(count % 8)));
  }

  String _searchText(ContactInput i, List<String> phoneDigits, List<String> tagNames) {
    final parts = <String>[
      i.firstName,
      i.lastName,
      i.nickname,
      i.company,
      i.jobTitle,
      i.department,
      ...i.emails.map((e) => e.value),
      ...i.websites.map((e) => e.value),
      ...i.addresses.map((e) => e.value),
      i.requirements,
      i.temporaryNote,
      ...i.phones.map((p) => p.number),
      ...phoneDigits,
      ...tagNames,
    ];
    return parts.map(normalizeText).where((p) => p.isNotEmpty).join(' ');
  }

  Future<List<ContactSummary>> _loadAll() async {
    final contacts = await db.select(db.contacts).get();
    final phones = await (db.select(db.contactPhones)
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    final entries = await (db.select(db.contactEntries)
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    final roles = await db.select(db.contactRoles).get();
    final tagRows = await (db.select(db.contactTags).join([
      innerJoin(db.tags, db.tags.id.equalsExp(db.contactTags.tagId)),
    ])
          ..orderBy([OrderingTerm.asc(db.tags.nameKey)]))
        .get();

    final phonesBy = <int, List<ContactPhone>>{};
    for (final p in phones) {
      (phonesBy[p.contactId] ??= []).add(p);
    }
    final entriesBy = <int, List<ContactEntry>>{};
    for (final e in entries) {
      (entriesBy[e.contactId] ??= []).add(e);
    }
    final rolesBy = <int, List<Role>>{};
    for (final r in roles) {
      final role = Role.values.where((x) => x.name == r.role);
      if (role.isNotEmpty) (rolesBy[r.contactId] ??= []).add(role.first);
    }
    final tagsBy = <int, List<Tag>>{};
    for (final row in tagRows) {
      (tagsBy[row.readTable(db.contactTags).contactId] ??= []).add(row.readTable(db.tags));
    }
    return [
      for (final c in contacts)
        ContactSummary(
          contact: c,
          phones: phonesBy[c.id] ?? const [],
          entries: entriesBy[c.id] ?? const [],
          roles: [...(rolesBy[c.id] ?? const <Role>[])]..sort((a, b) => a.index.compareTo(b.index)),
          tags: tagsBy[c.id] ?? const [],
        ),
    ];
  }
}
