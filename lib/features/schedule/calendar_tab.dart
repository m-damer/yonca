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
  _View _view = _View.month;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = dayOnly(DateTime.now());
  DateTime? _weekStart;
  List<ScheduleItem> _weekItems = const [];
  bool _loading = true;
  bool _showTasks = true;
  bool _showMeetings = true;
  bool _showEvents = true;
  bool _showDone = false;

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

  bool _keep(ScheduleItem i) {
    if (i.done && !_showDone) return false;
    return switch (i.kind) {
      ScheduleKind.task => _showTasks,
      ScheduleKind.meeting => _showMeetings,
      ScheduleKind.event => _showEvents,
    };
  }

  List<ScheduleItem> _f(List<ScheduleItem> l) => [for (final i in l) if (_keep(i)) i];

  List<ScheduleItem> get _fOverdue => _showTasks ? _overdue : const [];
  List<ScheduleItem> get _fUpcoming => _f(_upcoming);
  List<ScheduleItem> get _fMonth => _f(_monthItems);
  List<ScheduleItem> get _fWeek => _f(_weekItems);
  List<ScheduleItem> get _fOpen => _showTasks ? _openTasks : const [];
  List<ScheduleItem> get _fDone => _showDone ? _done : const [];

  void _step(int dir) {
    if (_view == _View.month) {
      setState(() => _month = DateTime(_month.year, _month.month + dir));
    } else if (_view == _View.week) {
      final st = _weekStart ?? _startOfWeek(DateTime.now());
      setState(() => _weekStart = DateTime(st.year, st.month, st.day + 7 * dir));
    }
    _reload();
  }

  Widget _header2(AppLocalizations l, YoncaPalette pal) {
    final locale = Localizations.localeOf(context).toString();
    final stepping = _view == _View.month || _view == _View.week;
    String title;
    if (_view == _View.month) {
      title = dfmt(DateFormat.yMMMM(locale), _month);
    } else if (_view == _View.week) {
      final st = _weekStart ?? _startOfWeek(DateTime.now());
      title = '${dfmt(DateFormat.MMMd(locale), st)} – ${dfmt(DateFormat.MMMd(locale), DateTime(st.year, st.month, st.day + 6))}';
    } else {
      title = l.navCalendar;
    }
    String viewName(_View v) => switch (v) { _View.agenda => l.viewAgenda, _View.week => l.viewWeek, _View.month => l.viewMonth, _View.tasks => l.viewTasks };
    return Row(children: [
      if (stepping) GlassIconButton(icon: Icons.chevron_left, onHeader: true, size: 40, onTap: () => _step(-1)),
      Expanded(
        child: Text(title, textAlign: stepping ? TextAlign.center : TextAlign.start, style: TextStyle(fontSize: stepping ? 20 : 26, fontWeight: FontWeight.w600, color: pal.onHeader)),
      ),
      if (stepping) GlassIconButton(icon: Icons.chevron_right, onHeader: true, size: 40, onTap: () => _step(1)),
      const SizedBox(width: 8),
      PopupMenuButton<_View>(
        onSelected: (v) => setState(() => _view = v),
        itemBuilder: (_) => [for (final v in _View.values) PopupMenuItem(value: v, child: Text(viewName(v)))],
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: pal.onHeader.withValues(alpha: .14), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(viewName(_view), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: pal.onHeader)),
            Icon(Icons.keyboard_arrow_down, size: 18, color: pal.onHeader),
          ]),
        ),
      ),
    ]);
  }

  Widget _filterRow(AppLocalizations l, YoncaPalette pal) => SizedBox(
        height: 36,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          PillChip(dense: true, label: l.viewTasks, selected: _showTasks, check: true, onTap: () => setState(() => _showTasks = !_showTasks)),
          const SizedBox(width: 6),
          PillChip(dense: true, label: l.calChipMeetings, selected: _showMeetings, check: true, onTap: () => setState(() => _showMeetings = !_showMeetings)),
          const SizedBox(width: 6),
          PillChip(dense: true, label: l.calChipEvents, selected: _showEvents, check: true, onTap: () => setState(() => _showEvents = !_showEvents)),
          const SizedBox(width: 6),
          PillChip(dense: true, label: l.calChipDone, selected: _showDone, onTap: () => setState(() => _showDone = !_showDone)),
        ]),
      );

  Widget _overdueBanner(AppLocalizations l, YoncaPalette pal) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: pal.errorContainer,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _view = _View.tasks),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: pal.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(child: Text(l.calOverdueBanner(_overdue.length), style: TextStyle(fontWeight: FontWeight.w600, color: pal.onErrorContainer))),
                Text(l.calShow, style: TextStyle(fontWeight: FontWeight.w600, color: pal.onErrorContainer)),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    return Column(children: [
      HeaderBand(
        child: _header2(l, pal),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(children: [
          _filterRow(l, pal),
          if (!_loading && _overdue.isNotEmpty && _view != _View.tasks) ...[const SizedBox(height: 8), _overdueBanner(l, pal)],
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
        child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _agenda(AppLocalizations l, YoncaPalette pal) {
    if (_fOverdue.isEmpty && _fUpcoming.isEmpty) {
      return EmptyState(icon: Icons.event_available_outlined, title: l.nothingScheduled, body: l.nothingScheduledBody);
    }
    final today = dayOnly(DateTime.now());
    final children = <Widget>[];
    if (_fOverdue.isNotEmpty) {
      children.add(_header(l.sectionOverdue, color: pal.error));
      children.addAll(_fOverdue.map((i) => _row(i, showDate: true)));
    }
    DateTime? last;
    for (final i in _fUpcoming) {
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
    return ListView(padding: _pad, children: [
      for (var k = 0; k < 7; k++) ...[
        _header(
          () {
            final d = DateTime(start.year, start.month, start.day + k);
            return d == today ? '${l.sectionToday} · ${formatDay(context, d)}' : formatDay(context, d);
          }(),
        ),
        ...() {
          final d = DateTime(start.year, start.month, start.day + k);
          final items = _fWeek.where((i) => dayOnly(i.at) == d).toList();
          return items.isEmpty
              ? [Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(l.nothingThisDay, style: TextStyle(color: pal.text2)))]
              : items.map(_row).toList();
        }(),
      ],
    ]);
  }

  Widget _tasks(AppLocalizations l, YoncaPalette pal) {
    if (_fOverdue.isEmpty && _fOpen.isEmpty && _fDone.isEmpty) {
      return EmptyState(icon: Icons.checklist_outlined, title: l.nothingScheduled, body: l.nothingScheduledBody);
    }
    return ListView(padding: _pad, children: [
      if (_fOverdue.isNotEmpty) ...[_header(l.sectionOverdue, color: pal.error), ..._fOverdue.map((i) => _row(i, showDate: true))],
      if (_fOpen.isNotEmpty) ...[_header(l.sectionUpcoming), ..._fOpen.map((i) => _row(i, showDate: true))],
      if (_fDone.isNotEmpty) ...[_header(l.sectionDone), ..._fDone.map((i) => _row(i, showDate: true))],
    ]);
  }

  Widget _monthView(AppLocalizations l, YoncaPalette pal) {
    final locale = Localizations.localeOf(context).toString();
    final first = _month;
    final days = DateTime(first.year, first.month + 1, 0).day;
    final startDay = MaterialLocalizations.of(context).firstDayOfWeekIndex; // 0 = Sunday
    final lead = (first.weekday % 7 - startDay + 7) % 7;
    final byDay = <int, List<ScheduleItem>>{};
    for (final i in _fMonth) {
      (byDay[i.at.day] ??= []).add(i);
    }
    final dayItems = _fMonth.where((i) => dayOnly(i.at) == _selected).toList();
    final today = dayOnly(DateTime.now());
    final weekdays = [
      for (var k = 0; k < 7; k++) dfmt(DateFormat.E(locale), DateTime(2023, 1, 1 + (startDay + k) % 7)),
    ];
    Widget cell(DateTime date) {
      final inMonth = date.month == first.month;
      final day = date.day;
      final sel = date == _selected;
      final count = inMonth ? (byDay[day]?.length ?? 0) : 0;
      return InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: inMonth ? () => setState(() => _selected = date) : null,
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: sel ? pal.primary : null,
            border: date == today && !sel ? Border.all(color: pal.primary, width: 1.5) : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$day', style: TextStyle(fontSize: 14, fontWeight: sel || date == today ? FontWeight.w600 : FontWeight.w400, color: sel ? pal.onPrimary : (inMonth ? pal.text : pal.text2.withValues(alpha: .5)))),
            SizedBox(
              height: 6,
              child: count == 0
                  ? null
                  : Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: sel ? pal.onPrimary : pal.accent),
                    ),
            ),
          ]),
        ),
      );
    }

    final cells = <DateTime>[
      for (var k = lead; k > 0; k--) DateTime(first.year, first.month, 1 - k),
      for (var d = 1; d <= days; d++) DateTime(first.year, first.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(DateTime(first.year, first.month, days + (cells.length - lead - days) + 1));
    }
    return ListView(padding: _pad, children: [
      GlassCard(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        child: Column(children: [
          Row(children: [
            for (final w in weekdays)
              Expanded(child: Center(child: Text(w, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pal.text2)))),
          ]),
          const SizedBox(height: 4),
          for (var r = 0; r < cells.length ~/ 7; r++)
            Row(children: [
              for (var c = 0; c < 7; c++) Expanded(child: AspectRatio(aspectRatio: 1.15, child: cell(cells[r * 7 + c]))),
            ]),
        ]),
      ),
      _header(formatDayShort(context, _selected)),
      if (dayItems.isEmpty)
        Padding(padding: const EdgeInsets.all(16), child: Text(l.nothingThisDay, style: TextStyle(color: pal.text2)))
      else
        ...dayItems.map(_row),
    ]);
  }
}
