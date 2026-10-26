import 'package:drift/drift.dart';

import '../domain/stats_models.dart';
import 'app_database.dart';

/// Numbers for the Stats screen, the Home summary and the targets.
class StatsRepository {
  StatsRepository(this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() _clock;

  /// Stats for [from, to).
  Future<PeriodStats> stats(DateTime from, DateTime to) async {
    final now = _clock();
    final acts = await (db.select(db.activities)..where((a) => a.occurredAt.isBiggerOrEqualValue(from) & a.occurredAt.isSmallerThanValue(to))).get();
    int count(String t) => acts.where((a) => a.type == t).length;

    final meetings = await (db.select(db.meetings)
          ..where((m) => m.startAt.isBiggerOrEqualValue(from) & m.startAt.isSmallerThanValue(to) & m.status.isNotValue('cancelled')))
        .get();
    final held = meetings.where((m) => m.startAt.isBefore(now) || m.status == 'held').length;

    final stages = {for (final s in await db.select(db.dealStages).get()) s.id: s};
    final deals = await (db.select(db.deals)..where((d) => d.closedAt.isBiggerOrEqualValue(from) & d.closedAt.isSmallerThanValue(to))).get();
    var won = 0, lost = 0;
    final value = <String, double>{};
    final reasons = <String, int>{};
    var winDays = 0.0;
    for (final d in deals) {
      final kind = stages[d.stageId]?.kind;
      if (kind == 'won') {
        won++;
        if (d.amount != null) value[d.currency] = (value[d.currency] ?? 0) + d.amount!;
        winDays += d.closedAt!.difference(d.createdAt).inHours / 24;
      } else if (kind == 'lost') {
        lost++;
        final r = d.lostReason.isEmpty ? 'other' : d.lostReason;
        reasons[r] = (reasons[r] ?? 0) + 1;
      }
    }

    final done = await (db.select(db.tasks)..where((t) => t.doneAt.isBiggerOrEqualValue(from) & t.doneAt.isSmallerThanValue(to))).get();
    var onTime = 0, late = 0;
    for (final t in done) {
      final deadline = t.hasTime ? t.dueAt : DateTime(t.dueAt.year, t.dueAt.month, t.dueAt.day + 1);
      if (!t.doneAt!.isAfter(deadline)) {
        onTime++;
      } else {
        late++;
      }
    }
    final open = await (db.select(db.tasks)..where((t) => t.doneAt.isNull() & t.dueAt.isBiggerOrEqualValue(from) & t.dueAt.isSmallerThanValue(to))).get();
    final overdue = open.where((t) => (t.hasTime ? t.dueAt : DateTime(t.dueAt.year, t.dueAt.month, t.dueAt.day + 1)).isBefore(now)).length;

    final newC = await (db.select(db.contacts)..where((c) => c.createdAt.isBiggerOrEqualValue(from) & c.createdAt.isSmallerThanValue(to))).get();

    return PeriodStats(
      from: from,
      to: to,
      calls: count('call'),
      visits: count('visit'),
      messages: count('message'),
      meetings: held,
      dealsWon: won,
      dealsLost: lost,
      valueWon: value,
      avgDaysToWin: won == 0 ? null : winDays / won,
      lostReasons: reasons,
      tasksDoneOnTime: onTime,
      tasksDoneLate: late,
      tasksOverdue: overdue,
      newContacts: newC.length,
    );
  }

  // ---- targets ----

  Future<List<TargetValue>> targets() async {
    final rows = await db.select(db.targets).get();
    return [
      for (final r in rows)
        if (metricFromName(r.metric) != null)
          TargetValue(metric: metricFromName(r.metric)!, period: r.period == 'month' ? StatsPeriod.month : StatsPeriod.week, value: r.value),
    ];
  }

  /// Sets a target; a null or non-positive [value] removes it.
  Future<void> setTarget(Metric m, StatsPeriod period, double? value) async {
    if (value == null || value <= 0) {
      await (db.delete(db.targets)..where((t) => t.metric.equals(m.name))).go();
    } else {
      await db.into(db.targets).insertOnConflictUpdate(TargetsCompanion.insert(metric: m.name, period: Value(period.name), value: value));
    }
  }

  /// Current progress for each target: (target, value so far in the current period, period end).
  Future<List<(TargetValue, double, DateTime)>> progress({int weekStart = DateTime.saturday}) async {
    final out = <(TargetValue, double, DateTime)>[];
    final now = _clock();
    for (final t in await targets()) {
      final start = periodStart(now, t.period, weekStart: weekStart);
      final end = periodEnd(start, t.period);
      out.add((t, (await stats(start, end)).valueOf(t.metric), end));
    }
    return out;
  }

  /// Past periods of one target, newest first: (period start, value reached).
  Future<List<(DateTime, double)>> history(TargetValue t, {int count = 6, int weekStart = DateTime.saturday}) async {
    final cur = periodStart(_clock(), t.period, weekStart: weekStart);
    final out = <(DateTime, double)>[];
    for (var i = 1; i <= count; i++) {
      final s = shiftPeriod(cur, t.period, -i);
      out.add((s, (await stats(s, periodEnd(s, t.period))).valueOf(t.metric)));
    }
    return out;
  }
}
