import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../domain/activity_models.dart';
import '../../domain/contact_models.dart';
import '../../domain/deal_models.dart';
import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../activities/activity_card.dart';
import '../activities/log_activity_page.dart';
import '../contacts/contact_row.dart';
import '../deals/deal_widgets.dart';
import '../schedule/schedule_labels.dart';
import '../schedule/schedule_widgets.dart';
import '../search/search_page.dart';

/// Home (design S01): greeting, quick actions, what is due, who needs attention, pipeline, recent activity.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.controller, required this.onOpenContact, required this.onGoTab, required this.onNewContact});
  final AppController controller;
  final void Function(int contactId) onOpenContact;

  /// Switches the bottom bar to a tab index.
  final void Function(int index) onGoTab;
  final VoidCallback onNewContact;

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  List<ScheduleItem> _overdue = const [];
  List<ScheduleItem> _today = const [];
  List<ScheduleItem> _soon = const [];
  List<ContactSummary> _attention = const [];
  List<ContactSummary> _recent = const [];
  List<StageSummary> _pipeline = const [];
  List<ActivityItem> _activity = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.controller.schedule?.revision.addListener(reload);
    widget.controller.deals?.revision.addListener(reload);
    reload();
  }

  @override
  void dispose() {
    widget.controller.schedule?.revision.removeListener(reload);
    widget.controller.deals?.revision.removeListener(reload);
    super.dispose();
  }

  Future<void> reload() async {
    final c = widget.controller;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final s = c.schedule;
    final overdue = await s?.overdueTasks() ?? const <ScheduleItem>[];
    final week = await s?.itemsBetween(start, start.add(const Duration(days: 4)), includeDone: false) ?? const <ScheduleItem>[];
    final end = start.add(const Duration(days: 1));
    final attention = await c.contacts?.list(inactiveForDays: 14, sort: ContactSort.needsAttention) ?? const <ContactSummary>[];
    final recent = await c.contacts?.list(sort: ContactSort.recentActivity) ?? const <ContactSummary>[];
    final pipeline = await c.deals?.summaries() ?? const <StageSummary>[];
    final acts = await c.activities?.list(limit: 3) ?? const <ActivityItem>[];
    if (!mounted) return;
    setState(() {
      _overdue = overdue;
      _today = [for (final i in week) if (i.at.isBefore(end)) i];
      _soon = [for (final i in week) if (!i.at.isBefore(end)) i];
      _attention = attention.take(3).toList();
      _recent = recent.take(4).toList();
      _pipeline = [for (final p in pipeline) if (p.stage.kind == 'open') p];
      _activity = acts;
      _loaded = true;
    });
  }

  Widget _title(String t, {VoidCallback? onAll, Color? color}) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(children: [
        Expanded(child: Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color))),
        if (onAll != null) TextButton(onPressed: onAll, child: Text(l.seeAll)),
      ]),
    );
  }

  Future<void> _openItem(ScheduleItem i) async {
    final c = widget.controller;
    await openScheduleItem(context, item: i, schedule: c.schedule!, contacts: c.contacts!, onOpenContact: widget.onOpenContact);
    await reload();
  }

  Future<void> _toggle(ScheduleItem i) async {
    final s = widget.controller.schedule!;
    if (i.done) {
      await s.reopenTask(i.id);
    } else {
      await s.completeTask(i.id);
    }
  }

  Widget _row(ScheduleItem i, {bool date = false}) =>
      ScheduleRow(item: i, showDate: date, onTap: () => _openItem(i), onToggle: i.kind == ScheduleKind.task ? () => _toggle(i) : null);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final c = widget.controller;
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? l.greetMorning : (hour < 18 ? l.greetAfternoon : l.greetEvening);
    final clear = _overdue.isEmpty && _today.isEmpty;
    return Column(children: [
      HeaderBand(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(greet, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: pal.onHeader))),
            GlassIconButton(
              icon: Icons.search,
              onHeader: true,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SearchPage(controller: c))),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            _loaded && !clear ? l.homeSummary(_today.length, _overdue.length) : formatDay(context, DateTime.now()),
            style: TextStyle(fontSize: 14, color: pal.onHeader.withValues(alpha: .85)),
          ),
        ]),
      ),
      Expanded(
        child: !_loaded
            ? const SizedBox.shrink()
            : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
                SizedBox(
                  height: 44,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    PillChip(label: l.qaContact, icon: Icons.person_add_alt, onTap: widget.onNewContact),
                    const SizedBox(width: 8),
                    if (c.activities != null && c.contacts != null)
                      PillChip(
                        label: l.logActivity,
                        icon: Icons.history_edu_outlined,
                        onTap: () async {
                          await Navigator.of(context).push<int>(MaterialPageRoute(
                            builder: (_) => LogActivityPage(activities: c.activities!, contacts: c.contacts!),
                          ));
                          await reload();
                        },
                      ),
                    const SizedBox(width: 8),
                    if (c.schedule != null && c.contacts != null)
                      PillChip(
                        label: l.addTask,
                        icon: Icons.check_circle_outline,
                        onTap: () => showAddSheet(context, schedule: c.schedule!, contacts: c.contacts!),
                      ),
                    const SizedBox(width: 8),
                    PillChip(label: l.navDeals, icon: Icons.paid_outlined, onTap: () => widget.onGoTab(3)),
                  ]),
                ),
                if (clear && _soon.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: GlassCard(child: Row(children: [
                      Icon(Icons.check_circle_outline, color: pal.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l.homeAllClear, style: const TextStyle(fontWeight: FontWeight.w600))),
                    ])),
                  ),
                if (_overdue.isNotEmpty) ...[_title(l.sectionOverdue, color: pal.error), ..._overdue.take(5).map((i) => _row(i, date: true))],
                if (_today.isNotEmpty) ...[_title(l.sectionToday), ..._today.map(_row)],
                if (_soon.isNotEmpty) ...[_title(l.sectionSoon, onAll: () => widget.onGoTab(2)), ..._soon.take(4).map((i) => _row(i, date: true))],
                if (_attention.isNotEmpty) ...[
                  _title(l.sectionNeedsAttention),
                  for (final s in _attention)
                    Material(type: MaterialType.transparency, child: ContactRow(summary: s, onTap: () => widget.onOpenContact(s.contact.id))),
                ],
                if (_recent.isNotEmpty) ...[
                  _title(l.sectionRecentContacts, onAll: () => widget.onGoTab(1)),
                  for (final s in _recent)
                    Material(type: MaterialType.transparency, child: ContactRow(summary: s, onTap: () => widget.onOpenContact(s.contact.id))),
                ],
                if (c.deals != null) ...[
                  _title(l.sectionPipeline, onAll: () => widget.onGoTab(3)),
                  if (_pipeline.every((p) => p.count == 0))
                    Text(l.noOpenDeals, style: TextStyle(color: pal.text2))
                  else
                    GlassCard(
                      child: Column(children: [
                        for (final p in _pipeline)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              CircleAvatar(radius: 6, backgroundColor: stageTintColor(context, p.stage.tint)),
                              const SizedBox(width: 10),
                              Expanded(child: Text('${stageLabel(l, p.stage)} · ${p.count}')),
                              Text(
                                [for (final e in p.totals.entries) formatMoney(context, e.value, e.key)].join('  '),
                                style: TextStyle(color: pal.text2, fontSize: 13),
                              ),
                            ]),
                          ),
                      ]),
                    ),
                ],
                if (_activity.isNotEmpty) ...[
                  _title(l.sectionRecentActivity),
                  for (final a in _activity)
                    ActivityCard(
                      item: a,
                      onTap: () async {
                        await showActivitySheet(context, item: a, activities: c.activities!, contacts: c.contacts!);
                        await reload();
                      },
                    ),
                ],
              ]),
      ),
    ]);
  }
}
