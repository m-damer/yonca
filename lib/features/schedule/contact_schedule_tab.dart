import 'package:flutter/material.dart';

import '../../data/contacts_repository.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/state_views.dart';
import '../../theme/palette.dart';
import 'schedule_widgets.dart';

/// The Schedule tab of a contact: their overdue and upcoming tasks, meetings and events, then done tasks.
class ContactScheduleTab extends StatefulWidget {
  const ContactScheduleTab({super.key, required this.schedule, required this.contacts, required this.contactId});
  final ScheduleRepository schedule;
  final ContactsRepository contacts;
  final int contactId;

  @override
  State<ContactScheduleTab> createState() => _ContactScheduleTabState();
}

class _ContactScheduleTabState extends State<ContactScheduleTab> {
  List<ScheduleItem>? _overdue;
  List<ScheduleItem> _upcoming = const [];
  List<ScheduleItem> _done = const [];

  @override
  void initState() {
    super.initState();
    widget.schedule.revision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.schedule.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final s = widget.schedule;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final overdue = await s.overdueTasks(contactId: widget.contactId);
    final upcoming = await s.itemsBetween(start, start.add(const Duration(days: 366)), contactId: widget.contactId, includeDone: false);
    final done = await s.doneTasks(contactId: widget.contactId);
    if (!mounted) return;
    setState(() {
      _overdue = overdue;
      _upcoming = upcoming;
      _done = done;
    });
  }

  Future<void> _open(ScheduleItem i) =>
      openScheduleItem(context, item: i, schedule: widget.schedule, contacts: widget.contacts);

  Future<void> _toggle(ScheduleItem i) => i.done ? widget.schedule.reopenTask(i.id) : widget.schedule.completeTask(i.id);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final overdue = _overdue;
    if (overdue == null) return const LoadingView();
    if (overdue.isEmpty && _upcoming.isEmpty && _done.isEmpty) {
      return EmptyState(icon: Icons.event_available_outlined, title: l.nothingScheduled, body: l.nothingScheduledBody);
    }
    Widget header(String t, {Color? color}) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        );
    Widget row(ScheduleItem i) => ScheduleRow(
          item: i,
          showDate: true,
          onTap: () => _open(i),
          onToggle: i.kind == ScheduleKind.task ? () => _toggle(i) : null,
        );
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
      if (overdue.isNotEmpty) ...[header(l.sectionOverdue, color: p.error), ...overdue.map(row)],
      if (_upcoming.isNotEmpty) ...[header(l.sectionUpcoming), ..._upcoming.map(row)],
      if (_done.isNotEmpty) ...[header(l.sectionDone), ..._done.map(row)],
    ]);
  }
}
