import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../domain/stats_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/ds.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/lucide.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import 'stats_labels.dart';
import 'targets_page.dart';

/// One target and how it is going: this period's progress and pace, and the past periods.
/// Opened from a target notification or by tapping a target on Home or Stats.
class TargetPage extends StatefulWidget {
  const TargetPage({super.key, required this.controller, required this.metric});
  final AppController controller;
  final Metric metric;

  @override
  State<TargetPage> createState() => _TargetPageState();
}

class _TargetPageState extends State<TargetPage> {
  TargetValue? _target;
  double _value = 0;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  List<(DateTime, double)> _history = const [];
  bool _loaded = false;

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = c.stats;
    if (st == null) return;
    final ws = c.weekStart ?? DateTime.saturday;
    final t = (await st.targets()).where((t) => t.metric == widget.metric).firstOrNull;
    var value = 0.0;
    var start = DateTime.now();
    var end = start;
    var hist = const <(DateTime, double)>[];
    if (t != null) {
      start = periodStart(DateTime.now(), t.period, weekStart: ws);
      end = periodEnd(start, t.period);
      value = (await st.stats(start, end)).valueOf(t.metric);
      hist = await st.history(t, weekStart: ws);
    }
    if (!mounted) return;
    setState(() {
      _target = t;
      _value = value;
      _start = start;
      _end = end;
      _history = hist;
      _loaded = true;
    });
  }

  Future<void> _edit() async {
    final st = c.stats;
    if (st == null) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => TargetsPage(stats: st, onChanged: c.resyncReminders)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final locale = Localizations.localeOf(context).toString();
    final t = _target;
    final money = widget.metric == Metric.valueWonUsd || widget.metric == Metric.valueWonSyp;
    final nf = NumberFormat.decimalPattern('en');
    String num(double v) => money ? nf.format(v) : formatNumber(v);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(title: metricLabel(l, widget.metric), actions: [GlassIconButton(icon: Lu.pencil, onHeader: true, onTap: _edit)]),
          Expanded(
            child: !_loaded
                ? const LoadingView()
                : t == null
                    ? ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.x5), children: [
                        Text(l.targetPageNone, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, color: pal.text2)),
                        const SizedBox(height: AppSpace.lg),
                        PillButton(label: l.setTargets, height: AppControl.lg, onPressed: _edit),
                      ])
                    : ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.x5), children: [
                        _current(context, l, pal, locale, t, today, num),
                        if (_history.isNotEmpty) ...[
                          SectionLabel(l.targetHistory),
                          GlassCard(
                            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.sm),
                            child: Column(children: [for (final h in _history) _past(pal, locale, t, h, num)]),
                          ),
                        ],
                        const SizedBox(height: AppSpace.xl),
                        PillButton(label: l.setTargets, outlined: true, height: AppControl.lg, onPressed: _edit),
                      ]),
          ),
        ]),
      ),
    );
  }

  Widget _current(BuildContext context, AppLocalizations l, YoncaPalette pal, String locale, TargetValue t, DateTime today, String Function(double) num) {
    final daysLeft = _end.difference(today).inDays.clamp(0, 400);
    final totalDays = _end.difference(_start).inDays.clamp(1, 400);
    final elapsedDays = (totalDays - daysLeft).clamp(1, totalDays);
    final frac = (_value / t.value).clamp(0.0, 1.0).toDouble();
    final timeFrac = ((totalDays - daysLeft) / totalDays).clamp(0.0, 1.0);
    final reached = _value >= t.value;
    final status = reached ? l.targetDone : (frac >= timeFrac * 0.9 ? l.targetOnTrack : l.targetBehind);
    final projected = _value / elapsedDays * totalDays;
    final fmt = DateFormat.MMMd(locale);
    final lastDay = _end.subtract(const Duration(days: 1));
    return GlassCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t.period == StatsPeriod.month ? l.targetMonthly : l.targetWeekly, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: pal.text2)),
        Text('${dfmt(fmt, _start)} – ${dfmt(fmt, lastDay)}', style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: pal.text2)),
        const SizedBox(height: AppSpace.md),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(num(_value), style: TextStyle(fontSize: AppFont.display, height: AppLine.snug, fontWeight: AppWeight.semibold, color: pal.text)),
          const SizedBox(width: AppSpace.sm),
          Text(l.targetOutOf(num(t.value)), style: TextStyle(fontSize: AppFont.bodyL, height: AppLine.normal, color: pal.text2)),
        ]),
        const SizedBox(height: AppSpace.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: LinearProgressIndicator(value: frac, minHeight: AppSize.s8, backgroundColor: pal.track, color: pal.primary),
        ),
        const SizedBox(height: AppSpace.md),
        Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
          TagPill(status, bg: reached ? pal.primaryContainer : null, fg: reached ? pal.onPrimaryContainer : null),
          if (!reached) TagPill(l.targetDaysLeft(daysLeft)),
        ]),
        if (!reached) ...[
          const SizedBox(height: AppSpace.md),
          Text(l.targetToGo(num(t.value - _value)), style: const TextStyle(fontSize: AppFont.body, height: AppLine.normal, fontWeight: AppWeight.medium)),
          if (daysLeft > 0) Text(l.targetProjected(num(projected.floorToDouble())), style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: pal.text2)),
        ],
      ]),
    );
  }

  Widget _past(YoncaPalette pal, String locale, TargetValue t, (DateTime, double) h, String Function(double) num) {
    final met = h.$2 >= t.value;
    final frac = (h.$2 / t.value).clamp(0.0, 1.0).toDouble();
    final label = t.period == StatsPeriod.month ? dfmt(DateFormat.yMMM(locale), h.$1) : dfmt(DateFormat.MMMd(locale), h.$1);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: AppFont.label, height: AppLine.normal, color: pal.text2))),
          if (met) ...[Icon(Lu.check, size: AppIcon.sm, color: pal.primary), const SizedBox(width: AppSpace.xs)],
          Text('${num(h.$2)} / ${num(t.value)}', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: AppFont.label, height: AppLine.normal, fontWeight: AppWeight.medium)),
        ]),
        const SizedBox(height: AppSpace.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xxs),
          child: LinearProgressIndicator(value: frac, minHeight: AppSize.s4, backgroundColor: pal.track, color: met ? pal.primary : pal.text2),
        ),
      ]),
    );
  }
}
