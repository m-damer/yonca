enum StatsPeriod { week, month }

/// The numbers a target can be set on.
enum Metric { calls, visits, meetings, messages, newContacts, dealsWon, valueWonUsd, valueWonSyp }

Metric? metricFromName(String s) {
  for (final m in Metric.values) {
    if (m.name == s) return m;
  }
  return null;
}

/// First day of the period that contains [d]. Weeks start on [weekStart] (DateTime.monday..sunday).
DateTime periodStart(DateTime d, StatsPeriod p, {int weekStart = DateTime.saturday}) {
  final day = DateTime(d.year, d.month, d.day);
  if (p == StatsPeriod.month) return DateTime(d.year, d.month);
  final back = (day.weekday - weekStart + 7) % 7;
  return DateTime(day.year, day.month, day.day - back);
}

/// Start of the next period.
DateTime periodEnd(DateTime start, StatsPeriod p) =>
    p == StatsPeriod.month ? DateTime(start.year, start.month + 1) : DateTime(start.year, start.month, start.day + 7);

/// Moves a period start by [n] periods (negative goes back).
DateTime shiftPeriod(DateTime start, StatsPeriod p, int n) =>
    p == StatsPeriod.month ? DateTime(start.year, start.month + n) : DateTime(start.year, start.month, start.day + 7 * n);

class PeriodStats {
  const PeriodStats({
    required this.from,
    required this.to,
    this.calls = 0,
    this.visits = 0,
    this.meetings = 0,
    this.messages = 0,
    this.dealsWon = 0,
    this.dealsLost = 0,
    this.valueWon = const {},
    this.avgDaysToWin,
    this.lostReasons = const {},
    this.tasksDoneOnTime = 0,
    this.tasksDoneLate = 0,
    this.tasksOverdue = 0,
    this.newContacts = 0,
  });
  final DateTime from;
  final DateTime to;
  final int calls;
  final int visits;
  final int meetings;
  final int messages;
  final int dealsWon;
  final int dealsLost;

  /// Value of deals won, per currency (never converted).
  final Map<String, double> valueWon;
  final double? avgDaysToWin;
  final Map<String, int> lostReasons;
  final int tasksDoneOnTime;
  final int tasksDoneLate;
  final int tasksOverdue;
  final int newContacts;

  double valueOf(Metric m) => switch (m) {
        Metric.calls => calls.toDouble(),
        Metric.visits => visits.toDouble(),
        Metric.meetings => meetings.toDouble(),
        Metric.messages => messages.toDouble(),
        Metric.newContacts => newContacts.toDouble(),
        Metric.dealsWon => dealsWon.toDouble(),
        Metric.valueWonUsd => valueWon['USD'] ?? 0,
        Metric.valueWonSyp => valueWon['SYP'] ?? 0,
      };
}

class TargetValue {
  const TargetValue({required this.metric, required this.period, required this.value});
  final Metric metric;
  final StatsPeriod period;
  final double value;
}
