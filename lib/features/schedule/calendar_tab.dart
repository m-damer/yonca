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
import '../settings/settings_widgets.dart' show SegControl;
import 'schedule_labels.dart';
import 'schedule_widgets.dart';
import '../../theme/tokens.dart';

enum _View { month, week, agenda }

/// Calendar tab: Agenda, Month and Tasks views over tasks, meetings and contact events.
class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key, required this.schedule, required this.contacts, this.onOpenContact});
  final ScheduleRepository? schedule;
  final ContactsRepository? contacts;
  final void Function(int contactId)? onOpenContact;

  @override
  State<CalendarTab> createState() => CalendarTabState();
}

class CalendarTabState extends State<CalendarTab> {
  _View _view = _View.month;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = dayOnly(DateTime.now());

  /// The day the user is looking at, so Add can start on it.
  DateTime get selectedDay => _selected;
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
    if (i.kind == ScheduleKind.event) {
      await openScheduleItem(context, item: i, schedule: s, contacts: c, onOpenContact: widget.onOpenContact);
    } else {
      await showItemSheet(context, item: i, schedule: s, contacts: c);
    }
  }

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, 0),
      child: Row(children: [
        _navBtn(pal, Icons.chevron_left, () => _step(-1)),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: Center(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.lead, height: AppLine.normal, fontWeight: FontWeight.w600, color: pal.onHeader)))),
        const SizedBox(width: AppSpace.sm),
        _navBtn(pal, Icons.chevron_right, () => _step(1)),
        const SizedBox(width: AppSpace.sm),
        GlassIconButton(icon: Icons.filter_alt_outlined, size: 40, radius: 8, filled: _filtered, tooltip: l.calFilterTitle, onTap: _openFilter),
      ]),
    );
  }

  Widget _overdueBanner(AppLocalizations l, YoncaPalette pal) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
        child: Material(
          color: pal.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => setState(() {
              _view = _View.agenda;
              _agendaStart = dayOnly(DateTime.now());
            }),
            child: SizedBox(
              height: AppControl.md,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, size: AppIcon.lg, color: pal.onErrorContainer),
                  const SizedBox(width: AppSpace.md),
                  Expanded(child: Text(l.calOverdueBanner(_overdue.length), style: TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w500, color: pal.onErrorContainer))),
                  Text(l.calShow, style: TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w600, color: pal.onErrorContainer)),
                ]),
              ),
            ),
          ),
        ),
      );

  Future<void> _openFilter() async {
    final l = AppLocalizations.of(context);
    var tasks = _showTasks, meetings = _showMeetings, events = _showEvents, done = _showDone;
    var contact = _contactFilter;
    var contactName = _contactFilterName;
    final repo = widget.contacts;
    final applied = await showGlassSheet<bool>(
      context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        Widget label(String t, double top) => SectionLabel(t, padding: EdgeInsets.fromLTRB(0, top, 0, AppSpace.sm));
        Widget toggle(String t, bool on, VoidCallback f) => PillChip(label: t, selected: on, onTap: () => setS(f));
        return SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SheetTitle(l.calFilterTitle),
            label(l.calFilterShow, 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              toggle(l.viewTasks, tasks, () => tasks = !tasks),
              toggle(l.calChipMeetings, meetings, () => meetings = !meetings),
              toggle(l.calChipEvents, events, () => events = !events),
              toggle(l.calChipDone, done, () => done = !done),
            ]),
            label(l.calFilterContact, 16),
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
            const SizedBox(height: AppSpace.lg),
            SheetButtons(
              secondary: l.filterClear,
              onSecondary: () => setS(() {
                tasks = meetings = events = true;
                done = false;
                contact = null;
                contactName = null;
              }),
              primary: l.calApply,
              onPrimary: () => Navigator.pop(ctx, true),
            ),
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
      HeaderBand(
        padding: EdgeInsets.zero,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, 0),
            child: SegControl(
              labels: [for (final v in _View.values) _viewName(l, v)],
              selected: _View.values.indexOf(_view),
              onSelect: (i) {
                setState(() => _view = _View.values[i]);
                _reload();
              },
            ),
          ),
          _header2(l, pal),
        ]),
      ),
      if (_view == _View.month && !_loading && _overdue.isNotEmpty && _showTasks) _overdueBanner(l, pal),
      Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() < 300) return;
            // Swiping toward the start of the line goes forward (the other way in right-to-left).
            final rtl = Directionality.of(context) == TextDirection.rtl;
            _step((v < 0) != rtl ? 1 : -1);
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey('$_view${_month.millisecondsSinceEpoch}${_weekStart?.millisecondsSinceEpoch}${_agendaStart.millisecondsSinceEpoch}'),
              child: _loading
                  ? const SizedBox.shrink()
                  : switch (_view) {
                      _View.agenda => _agenda(l, pal),
                      _View.week => _weekView(l, pal),
                      _View.month => _monthView(l, pal),
                    },
            ),
          ),
        ),
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
        padding: EdgeInsets.fromLTRB(AppSpace.xs, top, AppSpace.xs, AppSpace.md),
        child: Text(text, style: const TextStyle(fontSize: AppFont.body, height: AppLine.normal, fontWeight: FontWeight.w600)),
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
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.fabClear), children: [
      for (final d in days) ...[
        _dayTitle(d == today ? '${l.sectionToday} · ${formatDayShort(context, d)}' : (d == tomorrow ? '${l.quickTomorrow} · ${formatDayShort(context, d)}' : formatDayShort(context, d))),
        _group(byDay[d]!),
      ],
    ]);
  }


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
          ScheduleKind.task => context.palette.calTask,
          ScheduleKind.meeting => context.palette.calMeet,
          ScheduleKind.event => context.palette.calEvent,
        };
    return LayoutBuilder(builder: (context, c) {
      final colW = (c.maxWidth - 32 - 10 - gutter) / 7;
      const gridTop = 0.0;
      Widget dayHead(int k) {
        final d = DateTime(start.year, start.month, start.day + k);
        final sel = d == selDay, isToday = d == today;
        return SizedBox(
          width: colW,
          child: Column(children: [
            Text(dfmt(DateFormat.E(locale), d), style: TextStyle(fontSize: AppFont.tiny, height: AppLine.normal, fontWeight: FontWeight.w600, color: pal.text2)),
            const SizedBox(height: AppSpace.xs),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _selected = d),
              child: Container(
                width: 30,
                height: AppControl.sm,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: sel ? pal.primary : null, border: isToday && !sel ? Border.all(color: pal.primary, width: 2) : null),
                child: Text('${d.day}', style: TextStyle(fontSize: AppFont.label, fontWeight: FontWeight.w600, color: sel ? pal.onPrimary : pal.text)),
              ),
            ),
          ]),
        );
      }

      final gridH = rowH * (hours.length - 1) + 52;
      return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.fabClear), children: [
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.xs + gutter, AppSpace.md, AppSpace.xs, AppSpace.sm),
              child: Row(children: [for (var k = 0; k < 7; k++) dayHead(k)]),
            ),
            SizedBox(
              height: gridH,
              child: Stack(children: [
                for (var k = 0; k < hours.length; k++) ...[
                  Positioned(left: 0, right: 0, top: k * rowH + gridTop, child: Divider(height: 1, thickness: 1, color: pal.separator)),
                  Positioned(left: 0, top: k * rowH + 2, child: Padding(padding: const EdgeInsets.only(left: 0), child: Text(hours[k].toString().padLeft(2, '0'), style: TextStyle(fontSize: AppFont.tiny, color: pal.text2)))),
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
                          child: Container(decoration: BoxDecoration(color: blockColor(i), borderRadius: BorderRadius.circular(AppRadius.md))),
                        ),
                      );
                    }(),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.md, AppSpace.xs, 0),
          child: Row(children: [
            for (final e in [(l.viewTasks, context.palette.calTask), (l.calChipMeetings, context.palette.calMeet), (l.calChipEvents, context.palette.calEvent)]) ...[
              Container(width: 10, height: 10, decoration: BoxDecoration(color: e.$2, borderRadius: BorderRadius.circular(AppRadius.xs))),
              const SizedBox(width: AppSpace.sm),
              Text(e.$1, style: TextStyle(fontSize: AppFont.meta, color: pal.text2)),
              const SizedBox(width: AppSpace.lg),
            ],
          ]),
        ),
        _dayTitle(formatDayShort(context, _selected), top: 14),
        ...() {
          final day = items.where((i) => dayOnly(i.at) == _selected).toList();
          return day.isEmpty ? [Padding(padding: const EdgeInsets.all(AppSpace.sm), child: Text(l.nothingThisDay, style: TextStyle(color: pal.text2)))] : [_group(day)];
        }(),
      ]);
    });
  }

  Widget _dots(YoncaPalette pal, List<ScheduleItem> items, bool sel) {
    final kinds = [for (final k in ScheduleKind.values) if (items.any((i) => i.kind == k)) k];
    Widget dot(ScheduleKind k) => switch (k) {
          ScheduleKind.task => Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: pal.primary)),
          ScheduleKind.meeting => Container(width: 5, height: 5, decoration: BoxDecoration(color: pal.meetDot, borderRadius: BorderRadius.circular(AppRadius.xxs))),
          ScheduleKind.event => Transform.rotate(angle: 0.785398, child: Container(width: 5, height: 5, color: context.palette.calEvent)),
        };
    return SizedBox(
      height: 7,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
        for (var k = 0; k < kinds.length; k++) ...[if (k > 0) const SizedBox(width: AppSpace.xs), dot(kinds[k])],
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
          height: AppControl.xl,
          child: Column(children: [
            Container(
              width: 34,
              height: AppControl.sm,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: sel ? pal.primary : null, border: isToday && !sel ? Border.all(color: pal.primary, width: 2) : null),
              child: Text('${date.day}', style: TextStyle(fontSize: AppFont.label, fontWeight: sel || isToday ? FontWeight.w600 : FontWeight.w400, color: sel ? pal.onPrimary : (inMonth ? pal.text : pal.text2.withValues(alpha: .6)))),
            ),
            const SizedBox(height: AppSpace.xs),
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
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.fabClear), children: [
      GlassCard(
        padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.sm, AppSpace.sm, AppSpace.sm),
        child: Column(children: [
          Row(children: [
            for (final w in weekdays) Expanded(child: Center(child: Text(w, style: TextStyle(fontSize: AppFont.tiny, height: AppLine.normal, fontWeight: FontWeight.w600, color: pal.text2)))),
          ]),
          const SizedBox(height: AppSpace.xs),
          for (var r = 0; r < cells.length ~/ 7; r++) Row(children: [for (var c = 0; c < 7; c++) Expanded(child: cell(cells[r * 7 + c]))]),
        ]),
      ),
      _dayTitle(formatDayShort(context, _selected), top: 16),
      if (dayItems.isEmpty) Padding(padding: const EdgeInsets.all(AppSpace.lg), child: Text(l.nothingThisDay, style: TextStyle(color: pal.text2))) else _group(dayItems),
    ]);
  }
}
