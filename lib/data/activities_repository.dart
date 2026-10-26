import 'package:drift/drift.dart';

import '../domain/activity_models.dart';
import '../domain/contact_models.dart';
import 'app_database.dart';

/// All reads and writes of activities, their files and the outcome list.
class ActivitiesRepository {
  ActivitiesRepository(this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;

  // ---- outcomes ----

  /// Adds the built-in outcomes the first time the list is read.
  Future<void> _ensureOutcomes() async {
    final count = await (db.selectOnly(db.outcomes)..addColumns([db.outcomes.id.count()]))
        .map((r) => r.read(db.outcomes.id.count()) ?? 0)
        .getSingle();
    if (count > 0) return;
    for (var i = 0; i < defaultOutcomeKeys.length; i++) {
      await db.into(db.outcomes).insert(OutcomesCompanion.insert(key: Value(defaultOutcomeKeys[i]), position: Value(i)));
    }
  }

  /// Active outcomes in chip order. With [includeArchived] also the archived ones.
  Future<List<Outcome>> outcomes({bool includeArchived = false}) async {
    await _ensureOutcomes();
    final q = db.select(db.outcomes)..orderBy([(t) => OrderingTerm.asc(t.position)]);
    if (!includeArchived) q.where((t) => t.archived.equals(false));
    return q.get();
  }

  // ---- activities ----

  /// Creates an activity, or replaces all fields of activity [id]. Returns its id.
  /// Updates the contact's last activity time.
  Future<int> save(ActivityInput input, {int? id}) async {
    final problem = input.problem();
    if (problem != null) throw ActivityValidationException(problem);
    return db.transaction(() async {
      final now = _clock();
      final fields = ActivitiesCompanion(
        type: Value(input.type.name),
        contactId: Value(input.contactId),
        occurredAt: Value(input.occurredAt),
        direction: Value(input.direction),
        durationMinutes: Value(input.durationMinutes),
        place: Value(input.place.trim()),
        mapLink: Value(input.mapLink.trim()),
        channel: Value(input.channel),
        outcomeId: Value(input.outcomeId),
        title: Value(input.title.trim()),
        description: Value(input.description.trim()),
        voicePath: Value(input.voicePath),
        voiceMs: Value(input.voiceMs),
      );
      final int activityId;
      int? oldContact;
      if (id == null) {
        activityId = await db.into(db.activities).insert(fields.copyWith(createdAt: Value(now)));
      } else {
        final old = await (db.select(db.activities)..where((t) => t.id.equals(id))).getSingleOrNull();
        oldContact = old?.contactId;
        await (db.update(db.activities)..where((t) => t.id.equals(id))).write(fields);
        activityId = id;
        await (db.delete(db.activityFiles)..where((t) => t.activityId.equals(id))).go();
      }
      for (var i = 0; i < input.files.length; i++) {
        final f = input.files[i];
        await db.into(db.activityFiles).insert(ActivityFilesCompanion.insert(
              activityId: activityId,
              path: f.path,
              name: f.name,
              isImage: Value(f.isImage),
              position: Value(i),
            ));
      }
      if (oldContact != null && oldContact != input.contactId) await _refreshLastActivity(oldContact);
      if (input.contactId != null) await _refreshLastActivity(input.contactId!);
      return activityId;
    });
  }

  /// Deletes an activity. Returns the paths of its voice recording and files so the caller can remove them.
  Future<List<String>> delete(int id) async {
    return db.transaction(() async {
      final a = await (db.select(db.activities)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (a == null) return <String>[];
      final files = await (db.select(db.activityFiles)..where((t) => t.activityId.equals(id))).get();
      await (db.delete(db.activities)..where((t) => t.id.equals(id))).go();
      if (a.contactId != null) await _refreshLastActivity(a.contactId!);
      return [if (a.voicePath != null) a.voicePath!, ...files.map((f) => f.path)];
    });
  }

  Future<void> _refreshLastActivity(int contactId) async {
    final latest = await (db.selectOnly(db.activities)
          ..addColumns([db.activities.occurredAt.max()])
          ..where(db.activities.contactId.equals(contactId)))
        .map((r) => r.read(db.activities.occurredAt.max()))
        .getSingle();
    await (db.update(db.contacts)..where((t) => t.id.equals(contactId)))
        .write(ContactsCompanion(lastActivityAt: Value(latest)));
  }

  Future<ActivityItem?> get(int id) async {
    final rows = await _items((q) => q.where((t) => t.id.equals(id)));
    return rows.isEmpty ? null : rows.first;
  }

  /// Newest first. Filters: a contact, types, only activities without a contact, a date range.
  Future<List<ActivityItem>> list({
    int? contactId,
    Set<ActivityType>? types,
    bool noContactOnly = false,
    int? limit,
    int offset = 0,
  }) {
    return _items((q) {
      if (contactId != null) q.where((t) => t.contactId.equals(contactId));
      if (noContactOnly) q.where((t) => t.contactId.isNull());
      if (types != null && types.isNotEmpty) q.where((t) => t.type.isIn([for (final x in types) x.name]));
    }, limit: limit, offset: offset);
  }

  /// Every file attached to the contact's activities, newest first.
  Future<List<ContactFileItem>> filesOfContact(int contactId) async {
    final acts = await (db.select(db.activities)..where((t) => t.contactId.equals(contactId))).get();
    if (acts.isEmpty) return const [];
    final byId = {for (final a in acts) a.id: a};
    final files = await (db.select(db.activityFiles)..where((t) => t.activityId.isIn(byId.keys))).get();
    final items = [for (final f in files) ContactFileItem(file: f, activity: byId[f.activityId]!)];
    items.sort((a, b) => b.activity.occurredAt.compareTo(a.activity.occurredAt));
    return items;
  }

  Future<List<ActivityItem>> _items(void Function(SimpleSelectStatement<$ActivitiesTable, Activity>) filter,
      {int? limit, int offset = 0}) async {
    final q = db.select(db.activities)
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt), (t) => OrderingTerm.desc(t.id)]);
    filter(q);
    if (limit != null) q.limit(limit, offset: offset);
    final acts = await q.get();
    if (acts.isEmpty) return const [];
    final outcomes = {for (final o in await db.select(db.outcomes).get()) o.id: o};
    final contactIds = {for (final a in acts) if (a.contactId != null) a.contactId!};
    final contacts = contactIds.isEmpty
        ? <Contact>[]
        : await (db.select(db.contacts)..where((t) => t.id.isIn(contactIds))).get();
    final names = {for (final c in contacts) c.id: contactDisplayName(c)};
    final files = await (db.select(db.activityFiles)
          ..where((t) => t.activityId.isIn(acts.map((a) => a.id)))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    final filesBy = <int, List<ActivityFile>>{};
    for (final f in files) {
      (filesBy[f.activityId] ??= []).add(f);
    }
    return [
      for (final a in acts)
        ActivityItem(
          activity: a,
          outcome: a.outcomeId == null ? null : outcomes[a.outcomeId],
          contactName: a.contactId == null ? null : names[a.contactId],
          files: filesBy[a.id] ?? const [],
        ),
    ];
  }
}
