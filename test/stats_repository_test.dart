import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/data/activities_repository.dart';
import 'package:yonca/data/app_database.dart';
import 'package:yonca/data/contacts_repository.dart';
import 'package:yonca/data/deals_repository.dart';
import 'package:yonca/data/schedule_repository.dart';
import 'package:yonca/data/stats_repository.dart';
import 'package:yonca/domain/activity_models.dart';
import 'package:yonca/domain/contact_models.dart';
import 'package:yonca/domain/deal_models.dart';
import 'package:yonca/domain/schedule_models.dart';
import 'package:yonca/domain/stats_models.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('periods: weeks start on the chosen day, months on the 1st, shifting works', () {
    // 2026-10-27 is a Tuesday.
    expect(periodStart(DateTime(2026, 10, 27), StatsPeriod.week, weekStart: DateTime.saturday), DateTime(2026, 10, 24));
    expect(periodStart(DateTime(2026, 10, 27), StatsPeriod.week, weekStart: DateTime.monday), DateTime(2026, 10, 26));
    expect(periodStart(DateTime(2026, 10, 24), StatsPeriod.week, weekStart: DateTime.saturday), DateTime(2026, 10, 24));
    expect(periodStart(DateTime(2026, 10, 27), StatsPeriod.month), DateTime(2026, 10));
    expect(periodEnd(DateTime(2026, 12), StatsPeriod.month), DateTime(2027, 1));
    expect(shiftPeriod(DateTime(2026, 1), StatsPeriod.month, -1), DateTime(2025, 12));
    expect(shiftPeriod(DateTime(2026, 10, 24), StatsPeriod.week, 1), DateTime(2026, 10, 31));
  });

  test('stats count activities, meetings, deals, tasks and contacts in a period; targets track them', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026, 10, 27, 12);
    final contacts = ContactsRepository(db, clock: () => now);
    final acts = ActivitiesRepository(db);
    final deals = DealsRepository(db, clock: () => now);
    final schedule = ScheduleRepository(db, clock: () => now);
    final stats = StatsRepository(db, clock: () => now);

    final cid = await contacts.save(const ContactInput(firstName: 'Sara'));
    final outcome = (await acts.outcomes()).first;
    await acts.save(ActivityInput(type: ActivityType.call, contactId: cid, occurredAt: DateTime(2026, 10, 25), direction: 'out', outcomeId: outcome.id));
    await acts.save(ActivityInput(type: ActivityType.call, contactId: cid, occurredAt: DateTime(2026, 10, 26), direction: 'out', outcomeId: outcome.id));
    await acts.save(ActivityInput(type: ActivityType.visit, contactId: cid, occurredAt: DateTime(2026, 9, 1), outcomeId: outcome.id));
    await schedule.saveMeeting(MeetingInput(title: 'Demo', startAt: DateTime(2026, 10, 26, 10)));
    await schedule.saveMeeting(MeetingInput(title: 'Future', startAt: DateTime(2026, 10, 30, 10)));
    final stage = (await deals.openStages()).first;
    final won = await deals.saveDeal(DealInput(title: 'W', contactId: cid, stageId: stage.id, amount: 100));
    await deals.winDeal(won, date: DateTime(2026, 10, 26));
    final lost = await deals.saveDeal(DealInput(title: 'L', contactId: cid, stageId: stage.id));
    await deals.loseDeal(lost, reason: 'price', date: DateTime(2026, 10, 26));
    final t1 = await schedule.saveTask(TaskInput(title: 'ontime', dueAt: DateTime(2026, 10, 27), hasTime: false));
    final t2 = await schedule.saveTask(TaskInput(title: 'late', dueAt: DateTime(2026, 10, 25), hasTime: false));
    await schedule.saveTask(TaskInput(title: 'open overdue', dueAt: DateTime(2026, 10, 25)));
    await schedule.completeTask(t1);
    await schedule.completeTask(t2);

    final from = DateTime(2026, 10, 24), to = DateTime(2026, 10, 31);
    final s = await stats.stats(from, to);
    expect(s.calls, 2);
    expect(s.visits, 0);
    expect(s.meetings, 1);
    expect(s.dealsWon, 1);
    expect(s.dealsLost, 1);
    expect(s.valueWon, {'USD': 100.0});
    expect(s.lostReasons, {'price': 1});
    expect(s.tasksDoneOnTime, 1);
    expect(s.tasksDoneLate, 1);
    expect(s.tasksOverdue, 1);
    expect(s.newContacts, 1);

    await stats.setTarget(Metric.calls, StatsPeriod.week, 5);
    final p = await stats.progress(weekStart: DateTime.saturday);
    expect(p.single.$1.value, 5);
    expect(p.single.$2, 2);
    expect((await stats.history(p.single.$1)).length, 6);
    await stats.setTarget(Metric.calls, StatsPeriod.week, null);
    expect(await stats.targets(), isEmpty);
  });
}
