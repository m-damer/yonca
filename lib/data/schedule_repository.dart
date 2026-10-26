import 'package:drift/drift.dart';

import '../domain/contact_models.dart';
import '../domain/schedule_models.dart';
import 'app_database.dart';

/// Tasks, meetings and events (the calendar items). Writes call [onChanged] so reminders can be rebuilt.
class ScheduleRepository {
  ScheduleRepository(this.db, {DateTime Function()? clock, this.onChanged}) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;

  /// Called after any change to a task, meeting or event.
  Future<void> Function()? onChanged;

  Future<void> _changed() async {
    final cb = onChanged;
    if (cb != null) {
      try {
        await cb();
      } catch (_) {}
    }
  }

  // ---- tasks ----

  Future<int> saveTask(TaskInput input, {int? id}) async {
    if (input.problem() != null) throw ScheduleValidationException(input.problem()!);
    final due = input.hasTime
        ? input.dueAt
        : DateTime(input.dueAt.year, input.dueAt.month, input.dueAt.day);
    final fields = TasksCompanion(
      title: Value(input.title.trim()),
      contactId: Value(input.contactId),
      dueAt: Value(due),
      hasTime: Value(input.hasTime),
      priority: Value(input.priority.name),
      reminderMinutes: Value(input.reminderMinutes),
      alarm: Value(input.alarm),
      repeat: Value(input.repeat.name),
      description: Value(input.description.trim()),
      snoozedUntil: const Value(null),
    );
    final int out;
    if (id == null) {
      out = await db.into(db.tasks).insert(fields.copyWith(createdAt: Value(_clock())));
    } else {
      await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(fields);
      out = id;
    }
    await _changed();
    return out;
  }

  Future<Task?> getTask(int id) => (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> deleteTask(int id) async {
    await (db.delete(db.tasks)..where((t) => t.id.equals(id))).go();
    await _changed();
  }

  /// Marks the task done. A repeating task creates the next one; its id is returned.
  Future<int?> completeTask(int id) async {
    final t = await getTask(id);
    if (t == null || t.doneAt != null) return null;
    int? next;
    await db.transaction(() async {
      await (db.update(db.tasks)..where((x) => x.id.equals(id)))
          .write(TasksCompanion(doneAt: Value(_clock()), snoozedUntil: const Value(null)));
      final r = repeatFromName(t.repeat);
      if (r != Repeat.none) {
        next = await db.into(db.tasks).insert(TasksCompanion.insert(
              title: t.title,
              contactId: Value(t.contactId),
              dueAt: nextOccurrence(t.dueAt, r),
              hasTime: Value(t.hasTime),
              priority: Value(t.priority),
              reminderMinutes: Value(t.reminderMinutes),
              alarm: Value(t.alarm),
              repeat: Value(t.repeat),
              description: Value(t.description),
              createdAt: _clock(),
            ));
      }
    });
    await _changed();
    return next;
  }

  Future<void> reopenTask(int id) async {
    await (db.update(db.tasks)..where((x) => x.id.equals(id))).write(const TasksCompanion(doneAt: Value(null)));
    await _changed();
  }

  /// Moves the reminder to [until]. If [until] is after the due time, the due time moves too.
  Future<void> snoozeTask(int id, DateTime until) async {
    final t = await getTask(id);
    if (t == null) return;
    final later = until.isAfter(t.dueAt);
    await (db.update(db.tasks)..where((x) => x.id.equals(id))).write(TasksCompanion(
      snoozedUntil: Value(until),
      dueAt: later
          ? Value(t.hasTime ? until : DateTime(until.year, until.month, until.day))
          : const Value.absent(),
    ));
    await _changed();
  }

  // ---- meetings ----

  Future<int> saveMeeting(MeetingInput input, {int? id}) async {
    if (input.problem() != null) throw ScheduleValidationException(input.problem()!);
    final out = await db.transaction(() async {
      final fields = MeetingsCompanion(
        title: Value(input.title.trim()),
        startAt: Value(input.startAt),
        durationMinutes: Value(input.durationMinutes),
        type: Value(input.type.name),
        place: Value(input.place.trim()),
        link: Value(input.link.trim()),
        description: Value(input.description.trim()),
        reminderMinutes: Value(input.reminderMinutes),
        alarm: Value(input.alarm),
        repeat: Value(input.repeat.name),
      );
      final int mid;
      if (id == null) {
        mid = await db.into(db.meetings).insert(fields.copyWith(createdAt: Value(_clock())));
      } else {
        await (db.update(db.meetings)..where((t) => t.id.equals(id))).write(fields);
        mid = id;
        await (db.delete(db.meetingContacts)..where((t) => t.meetingId.equals(id))).go();
      }
      final seen = <int>{};
      var pos = 0;
      for (final c in input.contactIds) {
        if (!seen.add(c)) continue;
        await db.into(db.meetingContacts)
            .insert(MeetingContactsCompanion.insert(meetingId: mid, contactId: c, position: Value(pos++)));
      }
      return mid;
    });
    await _changed();
    return out;
  }

  Future<MeetingItem?> getMeeting(int id) async {
    final m = await (db.select(db.meetings)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (m == null) return null;
    final names = await _meetingContacts([id]);
    final list = names[id] ?? const [];
    return MeetingItem(meeting: m, contactIds: [for (final c in list) c.$1], contactNames: [for (final c in list) c.$2]);
  }

  Future<void> deleteMeeting(int id) async {
    await (db.delete(db.meetings)..where((t) => t.id.equals(id))).go();
    await _changed();
  }

  Future<void> setMeetingStatus(int id, String status) async {
    await (db.update(db.meetings)..where((t) => t.id.equals(id))).write(MeetingsCompanion(status: Value(status)));
    await _changed();
  }

  /// Other scheduled meetings that overlap the given time (the "This overlaps with X" warning).
  Future<List<Meeting>> overlapping(DateTime start, int minutes, {int? excludeId}) async {
    final end = start.add(Duration(minutes: minutes));
    final all = await (db.select(db.meetings)..where((t) => t.status.equals('scheduled'))).get();
    return [
      for (final m in all)
        if (m.id != excludeId &&
            m.startAt.isBefore(end) &&
            m.startAt.add(Duration(minutes: m.durationMinutes)).isAfter(start))
          m,
    ];
  }

  Future<Map<int, List<(int, String)>>> _meetingContacts(Iterable<int> meetingIds) async {
    if (meetingIds.isEmpty) return {};
    final links = await (db.select(db.meetingContacts)
          ..where((t) => t.meetingId.isIn(meetingIds))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    final cs = await (db.select(db.contacts)..where((t) => t.id.isIn(links.map((l) => l.contactId)))).get();
    final names = {for (final c in cs) c.id: contactDisplayName(c)};
    final out = <int, List<(int, String)>>{};
    for (final l in links) {
      (out[l.meetingId] ??= []).add((l.contactId, names[l.contactId] ?? ''));
    }
    return out;
  }

  // ---- calendar items ----

  bool _isOverdue(Task t, DateTime now) {
    if (t.doneAt != null) return false;
    return t.hasTime ? t.dueAt.isBefore(now) : t.dueAt.isBefore(DateTime(now.year, now.month, now.day));
  }

  ScheduleItem _taskItem(Task t, Map<int, String> names, DateTime now) => ScheduleItem(
        kind: ScheduleKind.task,
        id: t.id,
        title: t.title,
        at: t.dueAt,
        hasTime: t.hasTime,
        contactIds: [if (t.contactId != null) t.contactId!],
        contactNames: [if (t.contactId != null && names[t.contactId] != null) names[t.contactId]!],
        done: t.doneAt != null,
        overdue: _isOverdue(t, now),
        priority: priorityFromName(t.priority),
      );

  Future<Map<int, String>> _names() async {
    final cs = await db.select(db.contacts).get();
    return {for (final c in cs) c.id: contactDisplayName(c)};
  }

  /// Everything with a time in [from, to): tasks, meetings (repeats expanded) and events (yearly expanded).
  Future<List<ScheduleItem>> itemsBetween(DateTime from, DateTime to, {int? contactId, bool includeDone = true}) async {
    final now = _clock();
    final names = await _names();
    final out = <ScheduleItem>[];

    final tq = db.select(db.tasks)..where((t) => t.dueAt.isBiggerOrEqualValue(from) & t.dueAt.isSmallerThanValue(to));
    if (contactId != null) tq.where((t) => t.contactId.equals(contactId));
    for (final t in await tq.get()) {
      if (!includeDone && t.doneAt != null) continue;
      out.add(_taskItem(t, names, now));
    }

    final meetings = await db.select(db.meetings).get();
    final mc = await _meetingContacts(meetings.map((m) => m.id));
    for (final m in meetings) {
      final cs = mc[m.id] ?? const <(int, String)>[];
      if (contactId != null && !cs.any((c) => c.$1 == contactId)) continue;
      final r = repeatFromName(m.repeat);
      var at = m.startAt;
      var guard = 0;
      while (at.isBefore(to) && guard++ < 800) {
        if (!at.isBefore(from)) {
          out.add(ScheduleItem(
            kind: ScheduleKind.meeting,
            id: m.id,
            title: m.title,
            at: at,
            contactIds: [for (final c in cs) c.$1],
            contactNames: [for (final c in cs) c.$2],
            meetingType: meetingTypeFromName(m.type),
            cancelled: m.status == 'cancelled',
            done: m.status == 'held',
            endAt: at.add(Duration(minutes: m.durationMinutes)),
          ));
        }
        if (r == Repeat.none) break;
        at = nextOccurrence(at, r);
      }
    }

    final evq = db.select(db.contactEvents).join([innerJoin(db.contacts, db.contacts.id.equalsExp(db.contactEvents.contactId))]);
    if (contactId != null) evq.where(db.contactEvents.contactId.equals(contactId));
    for (final row in await evq.get()) {
      final e = row.readTable(db.contactEvents);
      final c = row.readTable(db.contacts);
      final dates = <DateTime>[];
      if (e.yearly) {
        for (var y = from.year; y <= to.year; y++) {
          if (y >= e.date.year) dates.add(DateTime(y, e.date.month, e.date.day));
        }
      } else {
        dates.add(DateTime(e.date.year, e.date.month, e.date.day));
      }
      for (final d in dates) {
        if (!d.isBefore(from) && d.isBefore(to)) {
          out.add(ScheduleItem(
            kind: ScheduleKind.event,
            id: e.id,
            title: e.title,
            at: d,
            hasTime: false,
            contactIds: [c.id],
            contactNames: [contactDisplayName(c)],
          ));
        }
      }
    }
    if (!includeDone) out.removeWhere((i) => i.done);
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  /// Open tasks past their due time, oldest first.
  Future<List<ScheduleItem>> overdueTasks({int? contactId}) async {
    final now = _clock();
    final names = await _names();
    final q = db.select(db.tasks)..where((t) => t.doneAt.isNull());
    if (contactId != null) q.where((t) => t.contactId.equals(contactId));
    final list = [for (final t in await q.get()) if (_isOverdue(t, now)) _taskItem(t, names, now)];
    list.sort((a, b) => a.at.compareTo(b.at));
    return list;
  }

  /// Completed tasks, newest first.
  Future<List<ScheduleItem>> doneTasks({int? contactId, int limit = 50}) async {
    final now = _clock();
    final names = await _names();
    final q = db.select(db.tasks)
      ..where((t) => t.doneAt.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.doneAt)])
      ..limit(limit);
    if (contactId != null) q.where((t) => t.contactId.equals(contactId));
    return [for (final t in await q.get()) _taskItem(t, names, now)];
  }

  // ---- reminders ----

  /// When the task's reminder is due, or null when it has none.
  DateTime? taskReminderAt(Task t) {
    if (t.snoozedUntil != null) return t.snoozedUntil;
    final m = t.reminderMinutes;
    if (m == null) return null;
    if (!t.hasTime) return DateTime(t.dueAt.year, t.dueAt.month, t.dueAt.day, dateOnlyReminderHour);
    return t.dueAt.subtract(Duration(minutes: m));
  }

  /// Every notification or alarm still ahead of [now], for the reminder service to schedule.
  Future<List<ReminderSpec>> pendingReminders(DateTime now) async {
    final out = <ReminderSpec>[];
    final names = await _names();
    for (final t in await (db.select(db.tasks)..where((x) => x.doneAt.isNull())).get()) {
      final at = taskReminderAt(t);
      if (at == null || !at.isAfter(now)) continue;
      out.add(ReminderSpec(
        id: t.id * 3,
        at: at,
        title: t.title,
        body: t.contactId != null ? (names[t.contactId] ?? '') : '',
        alarm: t.alarm,
      ));
    }
    final meetings = await (db.select(db.meetings)..where((x) => x.status.equals('scheduled'))).get();
    final mc = await _meetingContacts(meetings.map((m) => m.id));
    for (final m in meetings) {
      final m0 = m.reminderMinutes;
      if (m0 == null) continue;
      final r = repeatFromName(m.repeat);
      var start = m.startAt;
      var guard = 0;
      while (!start.subtract(Duration(minutes: m0)).isAfter(now) && r != Repeat.none && guard++ < 800) {
        start = nextOccurrence(start, r);
      }
      final at = start.subtract(Duration(minutes: m0));
      if (!at.isAfter(now)) continue;
      out.add(ReminderSpec(
        id: m.id * 3 + 1,
        at: at,
        title: m.title,
        body: [for (final c in mc[m.id] ?? const <(int, String)>[]) c.$2].join(', '),
        alarm: m.alarm,
      ));
    }
    final evs = await db.select(db.contactEvents).join([innerJoin(db.contacts, db.contacts.id.equalsExp(db.contactEvents.contactId))]).get();
    for (final row in evs) {
      final e = row.readTable(db.contactEvents);
      final c = row.readTable(db.contacts);
      DateTime? next;
      for (var y = now.year; y <= now.year + 1; y++) {
        final d = e.yearly ? DateTime(y, e.date.month, e.date.day, dateOnlyReminderHour) : DateTime(e.date.year, e.date.month, e.date.day, dateOnlyReminderHour);
        if (d.isAfter(now) && (e.yearly ? y >= e.date.year : true)) {
          next = d;
          break;
        }
      }
      if (next == null) continue;
      out.add(ReminderSpec(id: e.id * 3 + 2, at: next, title: e.title, body: contactDisplayName(c), alarm: false));
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}
