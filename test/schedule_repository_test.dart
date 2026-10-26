import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/data/app_database.dart';
import 'package:yonca/data/contacts_repository.dart';
import 'package:yonca/data/schedule_repository.dart';
import 'package:yonca/domain/contact_models.dart';
import 'package:yonca/domain/schedule_models.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late ContactsRepository contacts;
  late ScheduleRepository repo;
  var now = DateTime(2026, 10, 10, 12);
  var changes = 0;

  setUp(() {
    now = DateTime(2026, 10, 10, 12);
    changes = 0;
    db = AppDatabase(NativeDatabase.memory());
    contacts = ContactsRepository(db);
    repo = ScheduleRepository(db, clock: () => now, onChanged: () async => changes++);
  });
  tearDown(() => db.close());

  test('next occurrence: monthly clamps to the end of a short month', () {
    expect(nextOccurrence(DateTime(2026, 1, 31, 9), Repeat.monthly), DateTime(2026, 2, 28, 9));
    expect(nextOccurrence(DateTime(2026, 12, 15), Repeat.monthly), DateTime(2027, 1, 15));
    expect(nextOccurrence(DateTime(2026, 10, 30), Repeat.weekly), DateTime(2026, 11, 6));
    expect(nextOccurrence(DateTime(2026, 10, 31), Repeat.daily), DateTime(2026, 11, 1));
  });

  test('a task needs a title; saving reads back and calls onChanged', () async {
    expect(() => repo.saveTask(TaskInput(title: ' ', dueAt: now)), throwsA(isA<ScheduleValidationException>()));
    final cid = await contacts.save(const ContactInput(firstName: 'Sara', lastName: 'Ali'));
    final id = await repo.saveTask(TaskInput(title: 'Send quote', contactId: cid, dueAt: DateTime(2026, 10, 12, 15, 30), hasTime: true));
    final t = (await repo.getTask(id))!;
    expect(t.title, 'Send quote');
    expect(t.contactId, cid);
    expect(changes, 1);
    await repo.saveTask(TaskInput(title: 'Send quote now', dueAt: DateTime(2026, 10, 12, 18, 45)), id: id);
    expect((await repo.getTask(id))!.title, 'Send quote now');
    expect((await repo.getTask(id))!.dueAt.day, 12);
    await repo.deleteTask(id);
    expect(await repo.getTask(id), isNull);
  });

  test('date-only tasks are overdue only after the day ends', () async {
    await repo.saveTask(TaskInput(title: 'Today', dueAt: DateTime(2026, 10, 10, 22)));
    await repo.saveTask(TaskInput(title: 'Yesterday', dueAt: DateTime(2026, 10, 9)));
    await repo.saveTask(TaskInput(title: 'Earlier today', dueAt: DateTime(2026, 10, 10, 8), hasTime: true));
    final o = await repo.overdueTasks();
    expect(o.map((i) => i.title), ['Yesterday', 'Earlier today']);
  });

  test('completing a repeating task makes the next one; reopen and done list work', () async {
    final id = await repo.saveTask(TaskInput(title: 'Weekly call', dueAt: DateTime(2026, 10, 10, 10), hasTime: true, repeat: Repeat.weekly));
    final next = await repo.completeTask(id);
    expect(next, isNotNull);
    expect((await repo.getTask(next!))!.dueAt, DateTime(2026, 10, 17, 10));
    expect((await repo.doneTasks()).map((i) => i.id), [id]);
    expect(await repo.completeTask(id), isNull);
    await repo.reopenTask(id);
    expect((await repo.getTask(id))!.doneAt, isNull);
  });

  test('snooze moves the reminder and pushes a past due time forward', () async {
    final id = await repo.saveTask(TaskInput(title: 'Call', dueAt: DateTime(2026, 10, 10, 9), hasTime: true));
    await repo.snoozeTask(id, DateTime(2026, 10, 10, 13));
    final t = (await repo.getTask(id))!;
    expect(t.dueAt, DateTime(2026, 10, 10, 13));
    expect(repo.taskReminderAt(t), DateTime(2026, 10, 10, 13));
  });

  test('a meeting keeps its contacts in order, warns on overlap, and repeats weekly', () async {
    final a = await contacts.save(const ContactInput(firstName: 'A'));
    final b = await contacts.save(const ContactInput(firstName: 'B'));
    expect(() => repo.saveMeeting(MeetingInput(title: '', startAt: now)), throwsA(isA<ScheduleValidationException>()));
    final id = await repo.saveMeeting(MeetingInput(
        title: 'Demo', contactIds: [b, a, b], startAt: DateTime(2026, 10, 12, 10), durationMinutes: 60, repeat: Repeat.weekly));
    final m = (await repo.getMeeting(id))!;
    expect(m.contactIds, [b, a]);
    expect(m.contactNames, ['B', 'A']);
    expect((await repo.overlapping(DateTime(2026, 10, 12, 10, 30), 30)).map((x) => x.id), [id]);
    expect(await repo.overlapping(DateTime(2026, 10, 12, 11), 30), isEmpty);
    expect(await repo.overlapping(DateTime(2026, 10, 12, 10, 30), 30, excludeId: id), isEmpty);
    final items = await repo.itemsBetween(DateTime(2026, 10, 1), DateTime(2026, 11, 1));
    expect(items.where((i) => i.kind == ScheduleKind.meeting).map((i) => i.at.day), [12, 19, 26]);
    expect(items.first.contactLabel, 'B +1');
    final onlyA = await repo.itemsBetween(DateTime(2026, 10, 1), DateTime(2026, 11, 1), contactId: a);
    expect(onlyA.length, 3);
    await repo.setMeetingStatus(id, 'cancelled');
    expect((await repo.itemsBetween(DateTime(2026, 10, 1), DateTime(2026, 11, 1))).first.cancelled, isTrue);
  });

  test('yearly events show up every year from the first date on', () async {
    final cid = await contacts.save(ContactInput(
        firstName: 'Sara', events: [EventInput(title: 'Birthday', date: DateTime(1990, 10, 20))]));
    final items = await repo.itemsBetween(DateTime(2026, 10, 1), DateTime(2026, 11, 1));
    expect(items.single.kind, ScheduleKind.event);
    expect(items.single.at, DateTime(2026, 10, 20));
    expect(items.single.contactIds, [cid]);
    expect(await repo.itemsBetween(DateTime(2026, 11, 1), DateTime(2026, 12, 1)), isEmpty);
  });

  test('pending reminders: tasks before due, date-only at 9, meetings, events; done and past are skipped', () async {
    await repo.saveTask(TaskInput(title: 'Timed', dueAt: DateTime(2026, 10, 11, 10), hasTime: true, reminderMinutes: 30, alarm: true));
    await repo.saveTask(TaskInput(title: 'Dateonly', dueAt: DateTime(2026, 10, 12), reminderMinutes: 0, alarm: false));
    await repo.saveTask(TaskInput(title: 'No reminder', dueAt: DateTime(2026, 10, 13, 9), hasTime: true, reminderMinutes: null));
    await repo.saveTask(TaskInput(title: 'Past', dueAt: DateTime(2026, 10, 10, 9), hasTime: true));
    final doneId = await repo.saveTask(TaskInput(title: 'Done', dueAt: DateTime(2026, 10, 14, 9), hasTime: true));
    await repo.completeTask(doneId);
    await repo.saveMeeting(MeetingInput(title: 'Meet', startAt: DateTime(2026, 10, 15, 14), reminderMinutes: 15));
    final list = await repo.pendingReminders(now);
    expect(list.map((r) => r.title), ['Timed', 'Dateonly', 'Meet']);
    expect(list[0].at, DateTime(2026, 10, 11, 9, 30));
    expect(list[0].alarm, isTrue);
    expect(list[1].at, DateTime(2026, 10, 12, 9));
    expect(list[1].alarm, isFalse);
    expect(list[2].at, DateTime(2026, 10, 15, 13, 45));
    expect(list.map((r) => r.id).toSet().length, 3);
  });
}
