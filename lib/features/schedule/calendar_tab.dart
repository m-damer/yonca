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
import '../activities/contact_picker.dart';
import 'schedule_labels.dart';
import 'schedule_widgets.dart';

enum _View { month, week, agenda }

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
  int? _contactFilter;
  String? _contactFilterName;
  DateTime _agendaStart = dayOnly(DateTime.now());
  List<ScheduleItem> _agendaItems = const [];

  List<ScheduleItem> _overdue = const [];
  List<ScheduleItem> _monthItems = const [];

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
    final monthItems = await s.itemsBetween(_month, DateTime(_month.year, _month.month + 1));
    if (!mounted) return;
    final ws = _weekStart ?? _startOfWeek(DateTime.now());
    final weekItems = await s.itemsBetween(ws, ws.add(const Duration(days: 7)));
    final agenda = await s.itemsBetween(_agendaStart, _agendaStart.add(const Duration(days: 14)), includeDone: _showDone);
    if (!mounted) return;
    setState(() {
      _overdue = overdue;
      _monthItems = monthItems;
      _weekItems = weekItems;
      _weekStart = ws;
      _agendaItems = agenda;
      _loading = false;
    });
  }

  /// The week start the user chose in Settings, or the language's own.
  int get _firstDay => Look.weekStart ?? MaterialLocalizations.of(context).firstDayOfWeekIndex;
  int? _usedStart;

  DateTime _startOfWeek(DateTime d) {
    final first = _firstDay; // 0 = Sunday
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
    if (_contactFilter != null && !i.contactIds.contains(_contactFilter)) return false;
    return switch (i.kind) {
      ScheduleKind.task => _showTasks,
      ScheduleKind.meeting => _showMeetings,
      ScheduleKind.event => _showEvents,
    };
  }

  List<ScheduleItem> _f(List<ScheduleItem> l) => [for (final i in l) if (_keep(i)) i];

  bool get _filtered => !_showTasks || !_showMeetings || !_showEvents || _showDone || _contactFilter != null;

  void _step(int dir) {
    if (_view == _View.month) {
      setState(() => _month = DateTime(_month.year, _month.month + dir));
    } else if (_view == _View.week) {
      final st = _weekStart ?? _startOfWeek(DateTime.now());
      setState(() => _weekStart = DateTime(st.year, st.month, st.day + 7 * dir));
    } else {
      setState(() => _agendaStart = _agendaStart.add(Duration(days: 14 * dir)));
    }
    _reload();
  }

  String _viewName(AppLocalizations l, _View v) => switch (v) { _View.agenda => l.viewAgenda, _View.week => l.viewWeek, _View.month => l.viewMonth };

  Widget _navBtn(YoncaPalette pal, IconData icon, VoidCallback onTap) => GlassIconButton(icon: icon, size: 40, radius: 8, onTap: onTap);

  Widget _header2(AppLocalizations l, YoncaPalette pal) {
    final locale = Localizations.localeOf(context).toString();
    final String title;
    if (_view == _View.month) {
      title = dfmt(DateFormat.yMMMM(locale), _month);
    } else if (_view == _View.week) {
      final st = _weekStart ?? _startOfWeek(DateTime.now());
      final en = DateTime(st.year, st.month, st.day + 6);
      title = st.month == en.month
          ? l.timeRange(dfmt(DateFormat.d(locale), st), dfmt(DateFormat.MMMd(locale), en))
          : l.timeRange(dfmt(DateFormat.MMMd(locale), st), dfmt(DateFormat.MMMd(locale), en));
    } else {
      title = l.calNext14;
    }
    final month = _view == _View.month;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(children: [
        _navBtn(pal, Icons.chevron_left, () => _step(-1)),
        const SizedBox(width: 6),
        Expanded(child: Center(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, height: 25.2 / 18, fontWeight: FontWeight.w600, color: pal.onHeader)))),
        const SizedBox(width: 6),
        _navBtn(pal, Icons.chevron_right, () => _step(1)),
        if (!month) ...[
          const SizedBox(width: 6),
          GlassIconButton(icon: Icons.filter_alt_outlined, size: 40, radius: 8, filled: _filtered, tooltip: l.calFilterTitle, onTap: _openFilter),
        ],
        SizedBox(width: month ? 12 : 6),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _openViewSheet,
          child: Container(
            height: 40,
            padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 8, 0),
            decoration: BoxDecoration(color: pal.glass, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_viewName(l, _view), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: pal.text)),
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down, size: 22, color: pal.text),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _chip(YoncaPalette pal, String label, bool on, VoidCallback onTap, {bool check = true}) => InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: EdgeInsetsDirectional.only(start: on && check ? 10 : 12, end: 12),
          decoration: BoxDecoration(color: on ? pal.primary : pal.surface2, borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (on && check) ...[Icon(Icons.check, size: 22, color: pal.onPrimary), const SizedBox(width: 4)],
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: on ? pal.onPrimary : pal.text)),
          ]),
        ),
      );

  Widget _filterRow(AppLocalizations l, YoncaPalette pal) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          _chip(pal, l.viewTasks, _showTasks, () => setState(() => _showTasks = !_showTasks)),
          const SizedBox(width: 6),
          _chip(pal, l.calChipMeetings, _showMeetings, () => setState(() => _showMeetings = !_showMeetings)),
          const SizedBox(width: 6),
          _chip(pal, l.calChipEvents, _showEvents, () => setState(() => _showEvents = !_showEvents)),
          const SizedBox(width: 6),
          _chip(pal, l.calChipDone, _showDone, () {
            setState(() => _showDone = !_showDone);
            _reload();
          }),
        ]),
      );

  Widget _overdueBanner(AppLocalizations l, YoncaPalette pal) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Material(
          color: pal.errorContainer,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() {
              _view = _View.agenda;
              _agendaStart = dayOnly(DateTime.now());
            }),
            child: SizedBox(
              height: 42,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 22, color: pal.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l.calOverdueBanner(_overdue.length), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: pal.onErrorContainer))),
                  Text(l.calShow, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: pal.onErrorContainer)),
                ]),
              ),
            ),
          ),
        ),
      );

  Future<void> _openViewSheet() async {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final v = await showGlassSheet<_View>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 12), child: Text(l.viewSheetTitle, style: const TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600))),
        for (final (i, e) in [(_View.month, Icons.calendar_today_outlined), (_View.week, Icons.schedule), (_View.agenda, Icons.swap_vert)].indexed) ...[
          if (i > 0) Divider(height: 1, thickness: 1, indent: 68, color: pal.separator),
          InkWell(
            onTap: () => Navigator.pop(ctx, e.$1),
            child: SizedBox(
              height: 68,
              child: Row(children: [
                const SizedBox(width: 8),
                Container(width: 40, height: 40, decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(8)), child: Icon(e.$2, size: 22, color: pal.primary)),
                const SizedBox(width: 12),
                Expanded(child: Text(_viewName(l, e.$1), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
                _view == e.$1
                    ? Container(width: 24, height: 24, decoration: BoxDecoration(color: pal.primary, shape: BoxShape.circle), child: Icon(Icons.check, size: 16, color: pal.onPrimary))
                    : Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: pal.separator, width: 2))),
                const SizedBox(width: 8),
              ]),
            ),
          ),
        ],
      ]),
    );
    if (v != null) {
      setState(() => _view = v);
      _reload();
    }
  }

  Future<void> _openFilter() async {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    var tasks = _showTasks, meetings = _showMeetings, events = _showEvents, done = _showDone;
    var contact = _contactFilter;
    var contactName = _contactFilterName;
    final repo = widget.contacts;
    final applied = await showGlassSheet<bool>(
      context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        Widget label(String t, double top) => Padding(padding: EdgeInsets.fromLTRB(4, top, 4, 10), child: Text(t.toUpperCase(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: pal.text2)));
        Widget toggle(String t, bool on, VoidCallback f) => PillChip(label: t, selected: on, onTap: () => setS(f));
        return SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 0), child: Text(l.calFilterTitle, style: const TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600))),
            label(l.calFilterShow, 20),
            Wrap(spacing: 8, runSpacing: 8, children: [
              toggle(l.viewTasks, tasks, () => tasks = !tasks),
              toggle(l.calChipMeetings, meetings, () => meetings = !meetings),
              toggle(l.calChipEvents, events, () => events = !events),
              toggle(l.calChipDone, done, () => done = !done),
            ]),
            label(l.calFilterContact, 20),
            GlassPickerField(
              label: l.calFilterContact,
              value: contactName ?? l.calAnyContact,
              onTap: () async {
                if (repo == null) return;
                final c = await pickContact(ctx, repo, allowNone: true);
                if (c == null) return;
                setS(() {
                  contact = c.id;
                  contactName = c.id == null ? null : c.name;
                });
              },
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setS(() {
                    tasks = meetings = events = true;
                    done = false;
                    contact = null;
                    contactName = null;
                  }),
                  child: Text(l.filterClear, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: pal.primary)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: PillButton(label: l.calApply, onPressed: () => Navigator.pop(ctx, true))),
            ]),
          ]),
        );
      }),
    );
    if (applied != true || !mounted) return;
    setState(() {
      _showTasks = tasks;
      _showMeetings = meetings;
      _showEvents = events;
      _showDone = done;
      _contactFilter = contact;
      _contactFilterName = contactName;
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final startNow = _firstDay;
    if (_usedStart != startNow) {
      final firstBuild = _usedStart == null;
      _usedStart = startNow;
      if (!firstBuild) {
        _weekStart = null;
        WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
      }
    }
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    return Column(children: [
      HeaderBand(padding: EdgeInsets.zero, child: _header2(l, pal)),
      if (_view == _View.month) _filterRow(l, pal),
      if (_view == _View.month && !_loading && _overdue.isNotEmpty && _showTasks) _overdueBanner(l, pal),
      Expanded(
        child: _loading
            ? const SizedBox.shrink()
            : switch (_view) {
                _View.agenda => _agenda(l, pal),
                _View.week => _weekView(l, pal),
                _View.month => _monthView(l, pal),
              },
      ),
    ]);
  }

  Widget _row(ScheduleItem i) => ScheduleRow(item: i, plain: true, flat: true, onTap: () => _open(i));

  Widget _group(List<ScheduleItem> items) {
    final pal = context.palette;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var k = 0; k < items.length; k++) ...[
          if (k > 0) Divider(height: 1, thickness: 1, indent: 66, color: pal.separator),
          _row(items[k]),
        ],
      ]),
    );
  }

  Widget _dayTitle(String text, {double top = 14}) => Padding(
        padding: EdgeInsets.fromLTRB(4, top, 4, 10),
        child: Text(text, style: const TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w600)),
      );

  Widget _agenda(AppLocalizations l, YoncaPalette pal) {
    final today = dayOnly(DateTime.now());
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final byDay = <DateTime, List<ScheduleItem>>{};
    for (final i in _f(_agendaItems)) {
      (byDay[dayOnly(i.at)] ??= []).add(i);
    }
    // Overdue tasks sit on today while the window starts today.
    if (_agendaStart == today && _showTasks) {
      final od = [for (final i in _overdue) if (_contactFilter == null || i.contactIds.contains(_contactFilter)) i];
      if (od.isNotEmpty) byDay[today] = [...od, ...?byDay[today]];
    }
    if (byDay.isEmpty) return EmptyState(icon: Icons.event_available_outlined, title: l.nothingScheduled, body: l.nothingScheduledBody);
    final days = byDay.keys.toList()..sort();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), children: [
      for (final d in days) ...[
        _dayTitle(d == today ? '${l.sectionToday} · ${formatDayShort(context, d)}' : (d == tomorrow ? '${l.quickTomorrow} · ${formatDayShort(context, d)}' : formatDayShort(context, d))),
        _group(byDay[d]!),
      ],
    ]);
  }

  static const _taskBlue = Color(0xFF0062CC);
  static const _meetBlue = Color(0xFF004A99);
  static const _eventGreen = Color(0xFF2E7D5B);

  Widget _weekView(AppLocalizations l, YoncaPalette pal) {
    final locale = Localizations.localeOf(context).toString();
    final start = _weekStart ?? _startOfWeek(DateTime.now());
    final today = dayOnly(DateTime.now());
    final items = _f(_weekItems);
    var h0 = 8, h1 = 13;
    for (final i in items) {
      if (!i.hasTime || i.kind == ScheduleKind.event) continue;
      if (i.at.hour < h0) h0 = i.at.hour;
      final end = i.endAt ?? i.at.add(const Duration(hours: 1));
      final eh = end.minute > 0 ? end.hour + 1 : end.hour;
      if (eh - 1 > h1) h1 = (eh - 1).clamp(0, 23);
    }
    const rowH = 44.0;
    const gutter = 26.0;
    final hours = [for (var h = h0; h <= h1 + 1; h++) h];
    final selDay = _selected;
    Color blockColor(ScheduleItem i) => switch (i.kind) {
          ScheduleKind.task => _taskBlue,
          ScheduleKind.meeting => _meetBlue,
          ScheduleKind.event => _eventGreen,
        };
    return LayoutBuilder(builder: (context, c) {
      final colW = (c.maxWidth - 32 - 10 - gutter) / 7;
      final gridTop = 0.0;
      Widget dayHead(int k) {
        final d = DateTime(start.year, start.month, start.day + k);
        final sel = d == selDay, isToday = d == today;
        return SizedBox(
          width: colW,
          child: Column(children: [
            Text(dfmt(DateFormat.E(locale), d), style: TextStyle(fontSize: 11, height: 15.4 / 11, fontWeight: FontWeight.w600, color: pal.text2)),
            const SizedBox(height: 4),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _selected = d),
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: sel ? pal.primary : null, border: isToday && !sel ? Border.all(color: pal.primary, width: 2) : null),
                child: Text('${d.day}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sel ? pal.onPrimary : pal.text)),
              ),
            ),
          ]),
        );
      }

      final gridH = rowH * (hours.length - 1) + 52;
      return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 120), children: [
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(5 + gutter, 10, 5, 6),
              child: Row(children: [for (var k = 0; k < 7; k++) dayHead(k)]),
            ),
            SizedBox(
              height: gridH,
              child: Stack(children: [
                for (var k = 0; k < hours.length; k++) ...[
                  Positioned(left: 0, right: 0, top: k * rowH + gridTop, child: Divider(height: 1, thickness: 1, color: pal.separator)),
                  Positioned(left: 0, top: k * rowH + 2, child: Padding(padding: const EdgeInsets.only(left: 0), child: Text(hours[k].toString().padLeft(2, '0'), style: TextStyle(fontSize: 10.5, color: pal.text2)))),
                ],
                for (final i in items)
                  if (i.hasTime && i.kind != ScheduleKind.event)
                    () {
                      final dIdx = dayOnly(i.at).difference(start).inDays;
                      if (dIdx < 0 || dIdx > 6) return const SizedBox.shrink();
                      final end = i.endAt ?? i.at.add(const Duration(hours: 1));
                      final mins = end.difference(i.at).inMinutes.clamp(30, 24 * 60);
                      final top = (i.at.hour - h0) * rowH + i.at.minute / 60 * rowH;
                      return Positioned(
                        left: gutter + 5 + dIdx * colW + 1.5,
                        top: top,
                        width: colW - 3,
                        height: mins / 60 * rowH - 3,
                        child: InkWell(
                          onTap: () => _open(i),
                          child: Container(decoration: BoxDecoration(color: blockColor(i), borderRadius: BorderRadius.circular(8))),
                        ),
                      );
                    }(),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Row(children: [
            for (final e in [(l.viewTasks, _taskBlue), (l.calChipMeetings, _meetBlue), (l.calChipEvents, _eventGreen)]) ...[
              Container(width: 10, height: 10, decoration: BoxDecoration(color: e.$2, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Text(e.$1, style: TextStyle(fontSize: 12.5, color: pal.text2)),
              const SizedBox(width: 14),
            ],
          ]),
        ),
        _dayTitle(formatDayShort(context, _selected), top: 14),
        ...() {
          final day = items.where((i) => dayOnly(i.at) == _selected).toList();
          return day.isEmpty ? [Padding(padding: const EdgeInsets.all(8), child: Text(l.nothingThisDay, style: TextStyle(color: pal.text2)))] : [_group(day)];
        }(),
      ]);
    });
  }

  Widget _dots(YoncaPalette pal, List<ScheduleItem> items, bool sel) {
    final kinds = [for (final k in ScheduleKind.values) if (items.any((i) => i.kind == k)) k];
    Widget dot(ScheduleKind k) => switch (k) {
          ScheduleKind.task => Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: pal.primary)),
          ScheduleKind.meeting => Container(width: 5, height: 5, decoration: BoxDecoration(color: const Color(0xFFB5651D), borderRadius: BorderRadius.circular(1))),
          ScheduleKind.event => Transform.rotate(angle: 0.785398, child: Container(width: 5, height: 5, color: _eventGreen)),
        };
    return SizedBox(
      height: 7,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
        for (var k = 0; k < kinds.length; k++) ...[if (k > 0) const SizedBox(width: 3), dot(kinds[k])],
      ]),
    );
  }

  Widget _monthView(AppLocalizations l, YoncaPalette pal) {
    final locale = Localizations.localeOf(context).toString();
    final first = _month;
    final days = DateTime(first.year, first.month + 1, 0).day;
    final startDay = _firstDay; // 0 = Sunday
    final lead = (first.weekday % 7 - startDay + 7) % 7;
    final byDay = <int, List<ScheduleItem>>{};
    final monthItems = _f(_monthItems);
    for (final i in monthItems) {
      (byDay[i.at.day] ??= []).add(i);
    }
    final dayItems = monthItems.where((i) => dayOnly(i.at) == _selected).toList();
    final today = dayOnly(DateTime.now());
    final weekdays = [for (var k = 0; k < 7; k++) dfmt(DateFormat.E(locale), DateTime(2023, 1, 1 + (startDay + k) % 7))];
    Widget cell(DateTime date) {
      final inMonth = date.month == first.month;
      final sel = date == _selected;
      final isToday = date == today;
      return InkWell(
        customBorder: const CircleBorder(),
        onTap: inMonth ? () => setState(() => _selected = date) : null,
        child: SizedBox(
          height: 52,
          child: Column(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: sel ? pal.primary : null, border: isToday && !sel ? Border.all(color: pal.primary, width: 2) : null),
              child: Text('${date.day}', style: TextStyle(fontSize: 14, fontWeight: sel || isToday ? FontWeight.w600 : FontWeight.w400, color: sel ? pal.onPrimary : (inMonth ? pal.text : pal.text2.withValues(alpha: .6)))),
            ),
            const SizedBox(height: 2),
            if (inMonth && (byDay[date.day]?.isNotEmpty ?? false)) _dots(pal, byDay[date.day]!, sel),
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
    return ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 120), children: [
      GlassCard(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
        child: Column(children: [
          Row(children: [
            for (final w in weekdays) Expanded(child: Center(child: Text(w, style: TextStyle(fontSize: 11, height: 15.4 / 11, fontWeight: FontWeight.w600, color: pal.text2)))),
          ]),
          const SizedBox(height: 2),
          for (var r = 0; r < cells.length ~/ 7; r++) Row(children: [for (var c = 0; c < 7; c++) Expanded(child: cell(cells[r * 7 + c]))]),
        ]),
      ),
      _dayTitle(formatDayShort(context, _selected), top: 16),
      if (dayItems.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(l.nothingThisDay, style: TextStyle(color: pal.text2))) else _group(dayItems),
    ]);
  }
}
