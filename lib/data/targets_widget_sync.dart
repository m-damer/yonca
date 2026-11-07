import 'dart:io' show Platform;

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../app_controller.dart';
import '../domain/stats_models.dart';
import '../features/stats/stats_labels.dart';
import '../l10n/app_localizations.dart';

/// How a target is going: the share done, days left, and the words for it ("On track · 3 days left").
({double frac, int daysLeft, String status, bool reached}) targetStanding(AppLocalizations l, TargetValue t, double value, DateTime end, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final daysLeft = end.difference(today).inDays.clamp(0, 400);
  final totalDays = t.period == StatsPeriod.month ? 30 : 7;
  final elapsed = ((totalDays - daysLeft) / totalDays).clamp(0.0, 1.0);
  final frac = (value / t.value).clamp(0.0, 1.0).toDouble();
  final reached = value >= t.value;
  final status = reached ? l.targetDone : (frac >= elapsed * 0.9 ? l.targetOnTrack : l.targetBehind);
  return (frac: frac, daysLeft: daysLeft, status: status, reached: reached);
}

/// Writes the targets for the phone's Targets widget and asks Android to redraw it.
/// Shows up to three targets, minus the ones turned off in Home settings.
Future<void> syncTargetsWidget(AppController c, AppLocalizations l) async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return;
  final st = c.stats;
  if (st == null) return;
  try {
    final hidden = c.widgetTargetsHidden;
    final all = await st.progress(weekStart: c.weekStart ?? DateTime.saturday);
    final rows = [for (final r in all) if (!hidden.contains(r.$1.metric.name)) r].take(3).toList();
    final nf = NumberFormat.decimalPattern('en');
    await HomeWidget.saveWidgetData<bool>('tw_rtl', c.locale.languageCode == 'ar');
    await HomeWidget.saveWidgetData<String>('tw_title', l.targetPerfTitle);
    await HomeWidget.saveWidgetData<String>('tw_empty', all.isEmpty ? l.widgetTargetsEmpty : l.widgetTargetsAllOff);
    await HomeWidget.saveWidgetData<int>('tw_count', rows.length);
    for (final (i, r) in rows.indexed) {
      final (t, value, end) = r;
      final s = targetStanding(l, t, value, end);
      await HomeWidget.saveWidgetData<String>('tw_${i}_label', metricLabel(l, t.metric));
      await HomeWidget.saveWidgetData<String>('tw_${i}_value', '${nf.format(value)} / ${nf.format(t.value)}');
      await HomeWidget.saveWidgetData<int>('tw_${i}_pct', (s.frac * 100).round());
      await HomeWidget.saveWidgetData<String>('tw_${i}_status', s.reached ? s.status : '${s.status} · ${l.targetDaysLeft(s.daysLeft)}');
      await HomeWidget.saveWidgetData<int>('tw_${i}_metric', t.metric.index);
    }
    await HomeWidget.updateWidget(androidName: 'TargetsWidgetProvider');
  } catch (_) {
    // No widget on this platform (tests, desktop).
  }
}
