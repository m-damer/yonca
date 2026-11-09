import 'dart:io' show Platform;

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../app_controller.dart';
import '../domain/contact_models.dart';
import '../domain/deal_models.dart';
import '../domain/schedule_models.dart';
import '../features/contacts/contact_widgets.dart' show initialsOf;
import '../features/deals/deal_widgets.dart' show stageLabel;
import '../l10n/app_localizations.dart';

String _hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Writes the data for the Needs attention, Pipeline, Next up and Quick actions widgets, then redraws them.
Future<void> syncExtraWidgets(AppController c, AppLocalizations l) async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return;
  try {
    await HomeWidget.saveWidgetData<bool>('tw_rtl', c.locale.languageCode == 'ar');
    await _attention(c, l);
    await _pipeline(c, l);
    await _nextUp(c, l);
    await HomeWidget.saveWidgetData<String>('qw_l1', l.newContact);
    await HomeWidget.saveWidgetData<String>('qw_l2', l.shortcutNewTask);
    await HomeWidget.saveWidgetData<String>('qw_l3', l.shortcutSearch);
    await HomeWidget.saveWidgetData<String>('qw_l4', l.scanQr);
    for (final n in const ['AttentionWidgetProvider', 'PipelineWidgetProvider', 'NextUpWidgetProvider', 'QuickWidgetProvider', 'TodayWidgetProvider']) {
      await HomeWidget.updateWidget(androidName: n);
    }
  } catch (_) {
    // No widget on this platform (tests, desktop).
  }
}

Future<void> _attention(AppController c, AppLocalizations l) async {
  final repo = c.contacts;
  await HomeWidget.saveWidgetData<String>('aw_title', l.sectionNeedsAttention);
  await HomeWidget.saveWidgetData<String>('aw_empty', l.widgetAttentionEmpty);
  if (repo == null) {
    await HomeWidget.saveWidgetData<int>('aw_count', 0);
    return;
  }
  final least = [Rating.hot, Rating.warm, Rating.cold, Rating.none].map(c.inactiveDays).reduce((a, b) => a < b ? a : b);
  final idle = c.inactivityOff ? const <ContactSummary>[] : await repo.list(inactiveForDays: least, sort: ContactSort.needsAttention);
  final now = DateTime.now();
  final due = <(ContactSummary, int)>[];
  for (final x in idle) {
    if (x.isIncomplete) continue;
    final days = now.difference(x.contact.lastActivityAt ?? x.contact.createdAt).inDays;
    if (days >= c.inactiveDays(ratingFromName(x.contact.rating))) due.add((x, days));
  }
  final rows = due.take(3).toList();
  await HomeWidget.saveWidgetData<int>('aw_count', rows.length);
  await HomeWidget.saveWidgetData<String>('aw_total', due.length > 3 ? '${due.length}' : '');
  for (final (i, r) in rows.indexed) {
    final (x, days) = r;
    await HomeWidget.saveWidgetData<String>('aw_${i}_ini', initialsOf(x.displayName));
    await HomeWidget.saveWidgetData<String>('aw_${i}_name', x.displayName);
    await HomeWidget.saveWidgetData<String>('aw_${i}_sub', l.widgetQuiet(days));
    await HomeWidget.saveWidgetData<String>('aw_${i}_id', '${x.contact.id}');
    await HomeWidget.saveWidgetData<String>('aw_${i}_phone', x.phones.isEmpty ? '' : x.phones.first.number);
  }
}

Future<void> _pipeline(AppController c, AppLocalizations l) async {
  await HomeWidget.saveWidgetData<String>('pw_title', l.widgetPipelineTitle);
  await HomeWidget.saveWidgetData<String>('pw_empty', l.widgetPipelineEmpty);
  final sums = await c.deals?.summaries() ?? const <StageSummary>[];
  final open = [for (final s in sums) if (s.stage.kind == 'open') s];
  final deals = open.fold<int>(0, (a, s) => a + s.count);
  if (deals == 0) {
    await HomeWidget.saveWidgetData<bool>('pw_has', false);
    await HomeWidget.saveWidgetData<String>('pw_deals', '');
    return;
  }
  String cur = c.mainCurrency;
  if (!open.any((s) => s.totals.containsKey(cur))) {
    cur = open.expand((s) => s.totals.keys).firstOrNull ?? cur;
  }
  double amount(StageSummary s) => (s.totals[cur] ?? 0).toDouble();
  final total = open.fold<double>(0, (a, s) => a + amount(s));
  await HomeWidget.saveWidgetData<bool>('pw_has', true);
  await HomeWidget.saveWidgetData<String>('pw_deals', l.widgetDeals(deals));
  await HomeWidget.saveWidgetData<String>('pw_value', '${NumberFormat.decimalPattern('en').format(total.round())} $cur');
  // Three biggest stages by value; everything else is grouped into the last segment.
  final ranked = [...open]..sort((a, b) => amount(b).compareTo(amount(a)));
  final top = ranked.where((s) => s.count > 0).take(3).toList();
  var cum = 0.0;
  for (var i = 0; i < 3; i++) {
    if (i < top.length && total > 0) cum += amount(top[i]);
    final pct = total > 0 ? (cum / total * 100).round().clamp(0, 100) : 0;
    await HomeWidget.saveWidgetData<int>('pw_b${i + 1}', i < top.length ? pct : 0);
    await HomeWidget.saveWidgetData<String>('pw_leg${i + 1}', i < top.length ? '${stageLabel(l, top[i].stage)} ${top[i].count}' : '');
  }
  await HomeWidget.saveWidgetData<int>('pw_b4', total > 0 ? 100 : 0);
}

Future<void> _nextUp(AppController c, AppLocalizations l) async {
  final s = c.schedule;
  final now = DateTime.now();
  ScheduleItem? next;
  if (s != null) {
    final items = await s.itemsBetween(now.subtract(const Duration(minutes: 5)), now.add(const Duration(days: 14)), includeDone: false);
    final sorted = [...items]..sort((a, b) => a.at.compareTo(b.at));
    next = sorted.firstOrNull;
  }
  if (next == null) {
    await HomeWidget.saveWidgetData<String>('nw_when', l.widgetNextTitle);
    await HomeWidget.saveWidgetData<String>('nw_title', l.widgetNextNothing);
    await HomeWidget.saveWidgetData<String>('nw_sub', '');
    await HomeWidget.saveWidgetData<String>('nw_phone', '');
    await HomeWidget.saveWidgetData<String>('nw_link', '');
    return;
  }
  final mins = next.at.difference(now).inMinutes;
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(next.at.year, next.at.month, next.at.day);
  String when;
  if (next.hasTime && mins >= 0 && mins < 60) {
    when = l.widgetNextInMin(mins);
  } else if (day == today) {
    when = next.hasTime ? l.widgetNextToday(_hhmm(next.at)) : l.widgetNextToday('');
  } else {
    when = '${day.day}/${day.month}${next.hasTime ? ' ${_hhmm(next.at)}' : ''}';
  }
  final names = next.contactNames.isEmpty ? '' : next.contactNames.first;
  String phone = '';
  if (next.contactIds.isNotEmpty) {
    final cs = await c.contacts?.get(next.contactIds.first);
    if (cs != null && cs.phones.isNotEmpty) phone = cs.phones.first.number;
  }
  await HomeWidget.saveWidgetData<String>('nw_when', when);
  await HomeWidget.saveWidgetData<String>('nw_title', next.title);
  await HomeWidget.saveWidgetData<String>('nw_sub', [if (names.isNotEmpty) names, if (next.hasTime) _hhmm(next.at)].join(' · '));
  await HomeWidget.saveWidgetData<String>('nw_phone', phone);
  await HomeWidget.saveWidgetData<String>('nw_link', 'item/${next.kind.name}/${next.id}');
}
