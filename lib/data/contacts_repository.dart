import 'package:drift/drift.dart';

import '../core/text_normalize.dart';
import '../domain/contact_models.dart';
import 'app_database.dart';

/// All reads and writes of contacts, phones, roles and tags.
class ContactsRepository {
  ContactsRepository(this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;

  /// Sets the status line by hand; null or empty goes back to the automatic line.
  Future<void> setStatusOverride(int id, String? text) async {
    final v = (text ?? '').trim();
    await (db.update(db.contacts)..where((t) => t.id.equals(id)))
        .write(ContactsCompanion(statusOverride: Value(v.isEmpty ? null : v)));
  }

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
        await (db.delete(db.contactEvents)..where((t) => t.contactId.equals(id))).go();
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
      var epos = 0;
      for (final e in input.events) {
        if (e.title.trim().isEmpty) continue;
        await db.into(db.contactEvents).insert(ContactEventsCompanion.insert(
              contactId: contactId,
              title: e.title.trim(),
              date: e.date,
              yearly: Value(e.yearly),
              position: Value(epos++),
            ));
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

  /// Groups of contacts that share a phone number (two or more contacts each), largest group first.
  Future<List<List<ContactSummary>>> duplicateGroups() async {
    final rows = await db.select(db.contactPhones).get();
    final parent = <int, int>{};
    int find(int x) {
      var r = x;
      while ((parent[r] ?? r) != r) {
        r = parent[r]!;
      }
      parent[x] = r;
      return r;
    }

    final byNumber = <String, int>{};
    for (final r in rows) {
      parent.putIfAbsent(r.contactId, () => r.contactId);
      if (r.normalized.isEmpty) continue;
      final other = byNumber[r.normalized];
      if (other == null) {
        byNumber[r.normalized] = r.contactId;
      } else {
        parent[find(r.contactId)] = find(other);
      }
    }
    final groups = <int, List<int>>{};
    for (final id in parent.keys) {
      (groups[find(id)] ??= []).add(id);
    }
    final all = {for (final s in await _loadAll()) s.contact.id: s};
    final out = [
      for (final g in groups.values)
        if (g.length > 1) [for (final id in g..sort()) if (all[id] != null) all[id]!],
    ]..removeWhere((g) => g.length < 2);
    out.sort((a, b) => b.length.compareTo(a.length));
    return out;
  }

  /// Applies one change to many contacts: set a rating, add a role, add a tag.
  Future<void> bulkEdit(List<int> ids, {Rating? rating, Role? addRole, String? addTag}) async {
    for (final id in ids) {
      final s = await get(id);
      if (s == null) continue;
      final i = s.toInput();
      await save(
        ContactInput(
          firstName: i.firstName, lastName: i.lastName, company: i.company, prefix: i.prefix, nickname: i.nickname,
          jobTitle: i.jobTitle, department: i.department, emails: i.emails, websites: i.websites, addresses: i.addresses,
          events: i.events, requirements: i.requirements, temporaryNote: i.temporaryNote,
          rating: rating ?? i.rating, photoPath: i.photoPath, phones: i.phones,
          roles: addRole == null ? i.roles : {...i.roles, addRole}.toList(),
          tags: addTag == null ? i.tags : {...i.tags, addTag}.toList(),
        ),
        id: id,
      );
    }
  }

  /// Merges [otherIds] into [primaryId]: phones, emails, events, roles and tags are combined,
  /// empty fields are filled from the others, and activities, tasks, meetings, deals and
  /// custom field values move to the primary contact. The others are deleted.
  Future<void> merge(int primaryId, List<int> otherIds) async {
    final primary = await get(primaryId);
    if (primary == null) return;
    final others = <ContactSummary>[];
    for (final id in otherIds) {
      final s = await get(id);
      if (s != null && id != primaryId) others.add(s);
    }
    if (others.isEmpty) return;
    var p = primary.toInput();
    for (final o in others) {
      final x = o.toInput();
      final seenPhones = {for (final ph in p.phones) normalizePhone(ph.countryCode, ph.number)};
      final newPhones = [for (final ph in x.phones) if (seenPhones.add(normalizePhone(ph.countryCode, ph.number))) ph];
      List<EntryInput> union(List<EntryInput> a, List<EntryInput> b) {
        final seen = {for (final e in a) e.value.trim().toLowerCase()};
        return [...a, for (final e in b) if (seen.add(e.value.trim().toLowerCase())) e];
      }

      String pick(String a, String b) => a.trim().isEmpty ? b : a;
      p = ContactInput(
        firstName: pick(p.firstName, x.firstName),
        lastName: pick(p.lastName, x.lastName),
        company: pick(p.company, x.company),
        prefix: pick(p.prefix, x.prefix),
        nickname: pick(p.nickname, x.nickname),
        jobTitle: pick(p.jobTitle, x.jobTitle),
        department: pick(p.department, x.department),
        emails: union(p.emails, x.emails),
        websites: union(p.websites, x.websites),
        addresses: union(p.addresses, x.addresses),
        events: [...p.events, for (final e in x.events) if (!p.events.any((q) => q.title == e.title && q.date == e.date)) e],
        requirements: p.requirements.trim().isEmpty
            ? x.requirements
            : (x.requirements.trim().isEmpty || p.requirements.contains(x.requirements) ? p.requirements : '${p.requirements}\n${x.requirements}'),
        temporaryNote: pick(p.temporaryNote, x.temporaryNote),
        rating: p.rating == Rating.none ? x.rating : p.rating,
        photoPath: p.photoPath ?? x.photoPath,
        phones: [...p.phones, ...newPhones],
        roles: {...p.roles, ...x.roles}.toList(),
        tags: {...p.tags, ...x.tags}.toList(),
      );
    }
    await save(p, id: primaryId);
    await db.transaction(() async {
      for (final o in others) {
        final oid = o.contact.id;
        await (db.update(db.activities)..where((t) => t.contactId.equals(oid))).write(ActivitiesCompanion(contactId: Value(primaryId)));
        await (db.update(db.tasks)..where((t) => t.contactId.equals(oid))).write(TasksCompanion(contactId: Value(primaryId)));
        await (db.update(db.deals)..where((t) => t.contactId.equals(oid))).write(DealsCompanion(contactId: Value(primaryId)));
        final inMeetings = await (db.select(db.meetingContacts)..where((t) => t.contactId.equals(primaryId))).get();
        final have = {for (final m in inMeetings) m.meetingId};
        for (final m in await (db.select(db.meetingContacts)..where((t) => t.contactId.equals(oid))).get()) {
          if (have.contains(m.meetingId)) {
            await (db.delete(db.meetingContacts)..where((t) => t.meetingId.equals(m.meetingId) & t.contactId.equals(oid))).go();
          } else {
            await (db.update(db.meetingContacts)..where((t) => t.meetingId.equals(m.meetingId) & t.contactId.equals(oid)))
                .write(MeetingContactsCompanion(contactId: Value(primaryId)));
          }
        }
        // Custom field values of contact fields: keep the primary's, move the rest.
        final fieldIds = [for (final f in await (db.select(db.customFields)..where((t) => t.scope.equals('contact'))).get()) f.id];
        final mine = {for (final v in await (db.select(db.customFieldValues)..where((t) => t.ownerId.equals(primaryId) & t.fieldId.isIn(fieldIds))).get()) v.fieldId};
        for (final v in await (db.select(db.customFieldValues)..where((t) => t.ownerId.equals(oid) & t.fieldId.isIn(fieldIds))).get()) {
          if (mine.contains(v.fieldId)) {
            await (db.delete(db.customFieldValues)..where((t) => t.fieldId.equals(v.fieldId) & t.ownerId.equals(oid))).go();
          } else {
            await (db.update(db.customFieldValues)..where((t) => t.fieldId.equals(v.fieldId) & t.ownerId.equals(oid)))
                .write(CustomFieldValuesCompanion(ownerId: Value(primaryId)));
          }
        }
        await (db.delete(db.contacts)..where((t) => t.id.equals(oid))).go();
      }
      final last = await (db.select(db.activities)
            ..where((t) => t.contactId.equals(primaryId))
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
            ..limit(1))
          .getSingleOrNull();
      await (db.update(db.contacts)..where((t) => t.id.equals(primaryId)))
          .write(ContactsCompanion(lastActivityAt: Value(last?.occurredAt)));
    });
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
    int? stageId,
    ContactSort sort = ContactSort.recentActivity,
    bool arabicFirst = false,
  }) async {
    final now = _clock();
    final words = normalizeText(query).split(' ').where((w) => w.isNotEmpty).toList();
    final inStage = stageId == null
        ? null
        : {for (final d in await (db.select(db.deals)..where((t) => t.stageId.equals(stageId))).get()) d.contactId};
    var items = await _loadAll();
    items = items.where((s) {
      if (inStage != null && !inStage.contains(s.contact.id)) return false;
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
    int? stageId,
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
          db.deals,
        })
        .watch()
        .asyncMap((_) => list(
              query: query,
              rating: rating,
              role: role,
              tagId: tagId,
              inactiveForDays: inactiveForDays,
              stageId: stageId,
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

  /// How many contacts carry each tag (by tag id).
  Future<Map<int, int>> tagCounts() async {
    final out = <int, int>{};
    for (final r in await db.select(db.contactTags).get()) {
      out[r.tagId] = (out[r.tagId] ?? 0) + 1;
    }
    return out;
  }

  /// Creates a tag (or returns the existing one with the same name).
  Future<int> addTag(String name, int colorIndex) async {
    final key = normalizeText(name);
    final existing = await (db.select(db.tags)..where((t) => t.nameKey.equals(key))).getSingleOrNull();
    if (existing != null) return existing.id;
    return db.into(db.tags).insert(TagsCompanion.insert(name: name.trim(), nameKey: key, colorIndex: Value(colorIndex)));
  }

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
      ...i.events.map((e) => e.title),
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
    final events = await (db.select(db.contactEvents)
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
    final eventsBy = <int, List<ContactEvent>>{};
    for (final e in events) {
      (eventsBy[e.contactId] ??= []).add(e);
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
          events: eventsBy[c.id] ?? const [],
          roles: [...(rolesBy[c.id] ?? const <Role>[])]..sort((a, b) => a.index.compareTo(b.index)),
          tags: tagsBy[c.id] ?? const [],
        ),
    ];
  }
}
