import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../core/format.dart';

import '../../data/contacts_repository.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'schedule_labels.dart';
import 'schedule_widgets.dart';

enum _View { agenda, week, month, tasks }

/// Calendar tab: Agenda, Month and Tasks views over tasks, meetings and contact events.
class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key, required this.schedule, required this.contacts, this.onOpenContact});
  final ScheduleRepository? schedule;
  final ContactsRepository? contacts;
  final void Function(int contactId)? onOpenContact;

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  _View _view = _View.agenda;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = dayOnly(DateTime.now());
  DateTime? _weekStart;
  List<ScheduleItem> _weekItems = const [];
  bool _loading = true;

  List<ScheduleItem> _overdue = const [];
  List<ScheduleItem> _upcoming = const [];
  List<ScheduleItem> _monthItems = const [];
  List<ScheduleItem> _openTasks = const [];
  List<ScheduleItem> _done = const [];

  @override
  void initState() {
    super.initState();
    widget.schedule?.revision.addListener(_reload);
    if (widget.schedule == null) {
      _loading = false;
    } else {
      _reload();
    }
  }

  @override
  void dispose() {
    widget.schedule?.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final s = widget.schedule;
    if (s == null) return;
    final today = dayOnly(DateTime.now());
    final overdue = await s.overdueTasks();
    final upcoming = await s.itemsBetween(today, today.add(const Duration(days: 90)), includeDone: false);
    final monthItems = await s.itemsBetween(_month, DateTime(_month.year, _month.month + 1));
    if (!mounted) return;
    final ws = _weekStart ?? _startOfWeek(DateTime.now());
    final weekItems = await s.itemsBetween(ws, ws.add(const Duration(days: 7)));
    final open = await s.itemsBetween(DateTime(2000), DateTime(2100), includeDone: false);
    final done = await s.doneTasks();
    if (!mounted) return;
    setState(() {
      _overdue = overdue;
      _upcoming = upcoming;
      _monthItems = monthItems;
      _weekItems = weekItems;
      _weekStart = ws;
      _openTasks = [for (final i in open) if (i.kind == ScheduleKind.task && !i.overdue) i];
      _done = done;
      _loading = false;
    });
  }

  DateTime _startOfWeek(DateTime d) {
    final first = MaterialLocalizations.of(context).firstDayOfWeekIndex; // 0 = Sunday
    final back = (d.weekday % 7 - first + 7) % 7;
    final day = dayOnly(d);
    return DateTime(day.year, day.month, day.day - back);
  }

  Future<void> _open(ScheduleItem i) async {
    final s = widget.schedule, c = widget.contacts;
    if (s == null || c == null) return;
    await openScheduleItem(context, item: i, schedule: s, contacts: c, onOpenContact: widget.onOpenContact);
  }

  Future<void> _toggle(ScheduleItem i) async {
    final s = widget.schedule;
    if (s == null) return;
    if (i.done) {
      await s.reopenTask(i.id);
    } else {
      await s.completeTask(i.id);
    }
  }

  Widget _row(ScheduleItem i, {bool showDate = false}) =>
      ScheduleRow(item: i, showDate: showDate, onTap: () => _open(i), onToggle: i.kind == ScheduleKind.task ? () => _toggle(i) : null);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    return Column(children: [
      HeaderBand(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.navCalendar, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: pal.onHeader)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final v in _View.values)
              PillChip(
                label: switch (v) { _View.agenda => l.viewAgenda, _View.week => l.viewWeek, _View.month => l.viewMonth, _View.tasks => l.viewTasks },
                selected: _view == v,
                onTap: () => setState(() => _view = v),
              ),
          ]),
        ]),
      ),
      Expanded(
        child: _loading
            ? const SizedBox.shrink()
            : switch (_view) {
                _View.agenda => _agenda(l, pal),
                _View.week => _weekView(l, pal),
                _View.month => _monthView(l, pal),
                _View.tasks => _tasks(l, pal),
              },
      ),
    ]);
  }

  EdgeInsets get _pad => const EdgeInsets.fromLTRB(16, 16, 16, 120);

  Widget _header(String text, {Color? color}) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _agenda(AppLocalizations l, YoncaPalette pal) {
    if (_overdue.isEmpty && _upcoming.isEmpty) {
      return EmptyState(icon: Icons.event_available_outlined, title: l.nothingScheduled, body: l.nothingScheduledBody);
    }
    final today = dayOnly(DateTime.now());
    final children = <Widget>[];
    if (_overdue.isNotEmpty) {
      children.add(_header(l.sectionOverdue, color: pal.error));
      children.addAll(_overdue.map((i) => _row(i, showDate: true)));
    }
    DateTime? last;
    for (final i in _upcoming) {
      final d = dayOnly(i.at);
      if (last != d) {
        last = d;
        children.add(_header(d == today ? '${l.sectionToday} · ${formatDay(context, d)}' : formatDay(context, d)));
      }
      children.add(_row(i));
    }
    return ListView(padding: _pad, children: children);
  }

  Widget _weekView(AppLocalizations l, YoncaPalette pal) {
    final start = _weekStart ?? _startOfWeek(DateTime.now());
    final today = dayOnly(DateTime.now());
    void move(int days) {
      setState(() => _weekStart = DateTime(start.year, start.month, start.day + days));
      _reload();
    }

    final end = DateTime(start.year, start.month, start.day + 6);
    return ListView(padding: _pad, children: [
      Row(children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => move(-7)),
        Expanded(
          child: Center(
            child: Text('${formatDay(context, start)} – ${formatDay(context, end)}',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => move(7)),
      ]),
      for (var k = 0; k < 7; k++) ...[
        _header(
          () {
            final d = DateTime(start.year, start.month, start.day + k);
            return d == today ? '${l.sectionToday} · ${formatDay(context, d)}' : formatDay(context, d);
          }(),
        ),
        ...() {
          final d = DateTime(start.year, start.month, start.day + k);
          final items = _weekItems.where((i) => dayOnly(i.at) == d).toList();
          return items.isEmpty
              ? [Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(l.nothingThisDay, style: TextStyle(color: pal.text2)))]
              : items.map(_row).toList();
        }(),
      ],
    ]);
  }

  Widget _tasks(AppLocalizations l, YoncaPalette pal) {
    if (_overdue.isEmpty && _openTasks.isEmpty && _done.isEmpty) {
      return EmptyState(icon: Icons.checklist_outlined, title: l.nothingScheduled, body: l.nothingScheduledBody);
    }
    return ListView(padding: _pad, children: [
      if (_overdue.isNotEmpty) ...[_header(l.sectionOverdue, color: pal.error), ..._overdue.map((i) => _row(i, showDate: true))],
      if (_openTasks.isNotEmpty) ...[_header(l.sectionUpcoming), ..._openTasks.map((i) => _row(i, showDate: true))],
      if (_done.isNotEmpty) ...[_header(l.sectionDone), ..._done.map((i) => _row(i, showDate: true))],
    ]);
  }

  Widget _monthView(AppLocalizations l, YoncaPalette pal) {
    final locale = Localizations.localeOf(context).toString();
    final first = _month;
    final days = DateTime(first.year, first.month + 1, 0).day;
    final startDay = MaterialLocalizations.of(context).firstDayOfWeekIndex; // 0 = Sunday
    final lead = (first.weekday % 7 - startDay + 7) % 7;
    final byDay = <int, List<ScheduleItem>>{};
    for (final i in _monthItems) {
      (byDay[i.at.day] ??= []).add(i);
    }
    final dayItems = _monthItems.where((i) => dayOnly(i.at) == _selected).toList();
    final today = dayOnly(DateTime.now());
    final weekdays = [
      for (var k = 0; k < 7; k++) DateFormat.E(locale).format(DateTime(2023, 1, 1 + (startDay + k) % 7)),
    ];
    Widget cell(int? day) {
      if (day == null) return const SizedBox.shrink();
      final date = DateTime(first.year, first.month, day);
      final sel = date == _selected;
      final count = byDay[day]?.length ?? 0;
      return InkWell(
        customBorder: const CircleBorder(),
        onTap: () => setState(() => _selected = date),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: sel ? pal.primary : null,
            border: date == today && !sel ? Border.all(color: pal.primary, width: 1.5) : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$day', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: sel ? pal.onPrimary : pal.text)),
            SizedBox(
              height: 6,
              child: count == 0
                  ? null
                  : Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: sel ? pal.onPrimary : pal.accent),
                    ),
            ),
          ]),
        ),
      );
    }

    final cells = <int?>[for (var k = 0; k < lead; k++) null, for (var d = 1; d <= days; d++) d];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return ListView(padding: _pad, children: [
      Row(children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() => _month = DateTime(_month.year, _month.month - 1));
            _reload();
          },
        ),
        Expanded(
          child: Center(
            child: Text(dfmt(DateFormat.yMMMM(locale), first), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() => _month = DateTime(_month.year, _month.month + 1));
            _reload();
          },
        ),
      ]),
      Row(children: [
        for (final w in weekdays)
          Expanded(child: Center(child: Text(w, style: TextStyle(fontSize: 12, color: pal.text2)))),
      ]),
      const SizedBox(height: 4),
      for (var r = 0; r < cells.length ~/ 7; r++)
        Row(children: [
          for (var c = 0; c < 7; c++) Expanded(child: AspectRatio(aspectRatio: 1, child: cell(cells[r * 7 + c]))),
        ]),
      _header(formatDay(context, _selected)),
      if (dayItems.isEmpty)
        Padding(padding: const EdgeInsets.all(16), child: Text(l.nothingThisDay, style: TextStyle(color: pal.text2)))
      else
        ...dayItems.map(_row),
    ]);
  }
}
