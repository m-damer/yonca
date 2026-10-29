import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import '../../domain/deal_models.dart';
import '../../core/format.dart';

import '../../app_controller.dart';
import '../../domain/stats_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../deals/deal_widgets.dart';
import 'stats_labels.dart';
import 'targets_page.dart';

/// Stats (design S24): one scrolling page of cards for a week or a month.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  StatsPeriod _period = StatsPeriod.month;
  late DateTime _start = periodStart(DateTime.now(), _period);
  PeriodStats? _cur;
  PeriodStats? _prev;
  List<(TargetValue, double, DateTime)> _targets = const [];
  List<StageSummary> _pipeline = const [];
  bool _custom = false;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = widget.controller.stats;
    if (s == null) return;
    late DateTime from, to, prevFrom;
    if (_custom && _range != null) {
      from = _range!.start;
      to = DateTime(_range!.end.year, _range!.end.month, _range!.end.day + 1);
      prevFrom = from.subtract(to.difference(from));
    } else {
      from = _start;
      to = periodEnd(_start, _period);
      prevFrom = shiftPeriod(_start, _period, -1);
    }
    final cur = await s.stats(from, to);
    final prev = await s.stats(prevFrom, from);
    final targets = await s.progress();
    final pipe = await widget.controller.deals?.summaries() ?? const <StageSummary>[];
    if (mounted) {
      setState(() {
        _cur = cur;
        _prev = prev;
        _targets = targets;
        _pipeline = [for (final x in pipe) if (x.stage.kind == 'open') x];
      });
    }
  }

  void _setPeriod(StatsPeriod p) {
    setState(() {
      _custom = false;
      _period = p;
      _start = periodStart(DateTime.now(), p);
    });
    _load();
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range ?? DateTimeRange(start: DateTime(now.year, now.month, now.day - 13), end: DateTime(now.year, now.month, now.day)),
    );
    if (r == null) return;
    setState(() {
      _custom = true;
      _range = r;
    });
    _load();
  }

  void _shift(int n) {
    if (_custom && _range != null) {
      final days = _range!.duration.inDays + 1;
      final s = _range!.start;
      final e = _range!.end;
      setState(() => _range = DateTimeRange(start: DateTime(s.year, s.month, s.day + n * days), end: DateTime(e.year, e.month, e.day + n * days)));
    } else {
      setState(() => _start = shiftPeriod(_start, _period, n));
    }
    _load();
  }

  String _label(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    if (_custom && _range != null) return '${dfmt(DateFormat.MMMd(locale), _range!.start)} – ${dfmt(DateFormat.MMMd(locale), _range!.end)}';
    if (_period == StatsPeriod.month) return dfmt(DateFormat.yMMMM(locale), _start);
    final end = periodEnd(_start, _period).subtract(const Duration(days: 1));
    return '${dfmt(DateFormat.MMMd(locale), _start)} – ${dfmt(DateFormat.MMMd(locale), end)}';
  }

  /// Label and value on one line, an optional note below, an optional 4px bar, then a 16px gap.
  Widget _line(String label, String value, YoncaPalette pal, {String? sub, double? frac, bool bar = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, height: 21 / 15))),
          Text(value, style: const TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w600)),
        ]),
        if (sub != null) Text(sub, style: TextStyle(fontSize: 12.5, height: 17.5 / 12.5, color: pal.text2)),
        if (bar && frac != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: frac, minHeight: 4, backgroundColor: pal.track, color: pal.primary),
          ),
        ],
      ]),
    );
  }

  Widget _row(String label, num value, num? before, YoncaPalette pal, num maxValue) {
    final l = AppLocalizations.of(context);
    final frac = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0).toDouble();
    String? sub;
    if (before != null) {
      final d = value - before;
      final delta = '${d > 0 ? '+' : ''}${formatNumber(d.toDouble())}';
      if (_period == StatsPeriod.month && !_custom) {
        final prevMonth = dfmt(DateFormat.MMMM(Localizations.localeOf(context).toString()), shiftPeriod(_start, _period, -1));
        sub = l.statVsMonth(delta, prevMonth);
      } else {
        sub = l.statVsPrevious(delta);
      }
    }
    return _line(label, formatNumber(value.toDouble()), pal, sub: sub, frac: frac);
  }

  Widget _periodBar(AppLocalizations l, YoncaPalette pal) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget seg(String label, bool on, VoidCallback tap, int flex) => Expanded(
          flex: flex,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: tap,
            child: Container(
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? (dark ? const Color(0xFF48484A) : pal.glass) : null,
                borderRadius: BorderRadius.circular(6),
                boxShadow: on ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 2, offset: Offset(0, 1))] : null,
              ),
              child: Text(label, style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: on ? pal.text : pal.text2)),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        seg(l.periodWeek, !_custom && _period == StatsPeriod.week, () => _setPeriod(StatsPeriod.week), 140),
        seg(l.periodMonth, !_custom && _period == StatsPeriod.month, () => _setPeriod(StatsPeriod.month), 96),
        seg(l.periodCustom, _custom, _pickCustom, 96),
      ]),
    );
  }

  Widget _navCard(YoncaPalette pal) {
    return Row(children: [
      GlassIconButton(icon: Icons.chevron_left, onTap: () => _shift(-1)),
      const SizedBox(width: 12),
      Expanded(
        child: InkWell(
          onTap: _custom ? _pickCustom : null,
          child: Text(_label(context), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, height: 25.2 / 18, fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(width: 12),
      GlassIconButton(icon: Icons.chevron_right, onTap: () => _shift(1)),
    ]);
  }

  Widget _card(String title, List<Widget> children, {(String, VoidCallback)? action}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 17, height: 23.8 / 17, fontWeight: FontWeight.w600))),
              if (action != null)
                GestureDetector(onTap: action.$2, child: Text(action.$1, style: TextStyle(fontSize: 13, color: context.palette.primary))),
            ]),
            const SizedBox(height: 12),
            ...children,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final c = _cur, b = _prev;
    final repo = widget.controller.stats;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(children: [
              GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              Expanded(child: Text(l.statsTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: pal.onHeader))),
            ]),
          ),
          Expanded(
            child: c == null || b == null
                ? const SizedBox.shrink()
                : ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 40), children: [
                    _periodBar(l, pal),
                    const SizedBox(height: 12),
                    _navCard(pal),
                    const SizedBox(height: 12),
                    if (_targets.isNotEmpty)
                      _card(l.targetsTitle, [
                        for (final t in _targets) TargetBar(target: t.$1, value: t.$2, end: t.$3),
                      ], action: repo == null ? null : (l.setTargets, () async {
                        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TargetsPage(stats: repo, onChanged: widget.controller.resyncReminders)));
                        await _load();
                      })),
                    _card(l.statsActivity, () {
                      final m = [c.calls, c.visits, c.meetings, c.messages, b.calls, b.visits, b.meetings, b.messages].reduce((x, y) => x > y ? x : y);
                      return [
                        _row(l.metricCalls, c.calls, b.calls, pal, m),
                        _row(l.metricVisits, c.visits, b.visits, pal, m),
                        _row(l.metricMeetings, c.meetings, b.meetings, pal, m),
                        _row(l.metricMessages, c.messages, b.messages, pal, m),
                      ];
                    }()),
                    _card(l.statsDeals, [
                      _line(l.statWon, '${c.dealsWon}', pal,
                          sub: '${l.statWinRate}: ${c.dealsWon + c.dealsLost == 0 ? '—' : l.statWinRateValue(c.dealsWon, c.dealsWon + c.dealsLost)}', bar: false),
                      if (c.valueWon.isEmpty) _line(l.statValueWon, '—', pal, bar: false),
                      for (var k = 0; k < c.valueWon.length; k++)
                        _line(k == 0 ? l.statValueWon : '', formatMoney(context, c.valueWon.values.elementAt(k), c.valueWon.keys.elementAt(k)), pal, bar: false),
                      if (c.avgDaysToWin != null) _line(l.statAvgDays, '${c.avgDaysToWin!.round()}', pal, bar: false),
                    ]),
                    if (_pipeline.any((x) => x.count > 0))
                      _card(l.statsPipeline, () {
                        double amount(StageSummary x) => x.totals.values.fold(0.0, (a, v) => a + v);
                        final m = _pipeline.map(amount).fold<double>(0, (a, v) => v > a ? v : a);
                        return [
                          for (final x in _pipeline)
                            _line(
                              stageLabel(l, x.stage),
                              x.totals.isEmpty ? '${x.count}' : x.totals.entries.map((e) => formatMoney(context, e.value, e.key)).join(' · '),
                              pal,
                              frac: m <= 0 ? 0 : (amount(x) / m).clamp(0.0, 1.0),
                            ),
                        ];
                      }()),
                    if (c.lostReasons.isNotEmpty)
                      _card(l.statsLostReasons, [
                        for (final e in c.lostReasons.entries)
                          _row(lostReasonLabel(l, e.key), e.value, null, pal, c.dealsLost),
                      ]),
                    _card(l.statsFollowUp, () {
                      final m = [c.tasksDoneOnTime, c.tasksDoneLate, c.tasksOverdue].reduce((x, y) => x > y ? x : y);
                      return [
                        _row(l.statDoneOnTime, c.tasksDoneOnTime, b.tasksDoneOnTime, pal, m),
                        _row(l.statDoneLate, c.tasksDoneLate, b.tasksDoneLate, pal, m),
                        _row(l.statOverdue, c.tasksOverdue, b.tasksOverdue, pal, m),
                      ];
                    }()),
                    _card(l.statsContacts, [_row(l.statNewContacts, c.newContacts, b.newContacts, pal, c.newContacts > b.newContacts ? c.newContacts : b.newContacts)]),
                  ]),
          ),
        ]),
      ),
    );
  }
}

/// "12 of 20" with a bar, days left and a neutral status (never red).
class TargetBar extends StatelessWidget {
  const TargetBar({super.key, required this.target, required this.value, required this.end});
  final TargetValue target;
  final double value;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final now = DateTime.now();
    final daysLeft = end.difference(DateTime(now.year, now.month, now.day)).inDays.clamp(0, 400);
    final frac = (value / target.value).clamp(0.0, 1.0).toDouble();
    final totalDays = target.period == StatsPeriod.month ? 30 : 7;
    final elapsed = ((totalDays - daysLeft) / totalDays).clamp(0.0, 1.0);
    final money = target.metric == Metric.valueWonUsd || target.metric == Metric.valueWonSyp;
    final nf = NumberFormat.decimalPattern('en');
    final status = value >= target.value ? l.targetDone : (frac >= elapsed * 0.9 ? l.targetOnTrack : l.targetBehind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(metricLabel(l, target.metric), style: const TextStyle(fontSize: 15, height: 21 / 15))),
          Text(money ? '${nf.format(value)} / ${nf.format(target.value)}' : l.targetOf(formatNumber(value), formatNumber(target.value)), style: const TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w600)),
        ]),
        Text('$status · ${l.targetDaysLeft(daysLeft)}', style: TextStyle(fontSize: 12.5, height: 17.5 / 12.5, color: pal.text2)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: frac, minHeight: 4, backgroundColor: pal.track, color: pal.primary),
        ),
      ]),
    );
  }
}
