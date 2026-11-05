import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/format.dart';
import '../l10n/app_localizations.dart';
import '../theme/lucide.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'glass_widgets.dart';

/// The app's own date picker: a bottom sheet with a month grid. Follows the week start setting
/// (Saturday in Arabic by default) and the Arabic digits choice. Returns null on Cancel.
Future<DateTime?> pickDate(BuildContext context, {required DateTime initialDate, required DateTime firstDate, required DateTime lastDate}) async {
  final r = await showGlassSheet<List<DateTime>>(
    context,
    builder: (_) => _DateSheet(initial: initialDate, first: firstDate, last: lastDate, range: false),
  );
  return r?.first;
}

/// Same sheet for a range: tap the first day, then the last day.
Future<DateTimeRange?> pickDateRange(BuildContext context, {DateTimeRange? initialDateRange, required DateTime firstDate, required DateTime lastDate}) async {
  final r = await showGlassSheet<List<DateTime>>(
    context,
    builder: (_) => _DateSheet(initial: initialDateRange?.start ?? DateTime.now(), initialEnd: initialDateRange?.end, first: firstDate, last: lastDate, range: true),
  );
  return r == null ? null : DateTimeRange(start: r.first, end: r.last);
}

/// The app's own time picker: three wheels (hour, minute, AM/PM; ص/م in Arabic).
Future<TimeOfDay?> pickTime(BuildContext context, {required TimeOfDay initialTime}) =>
    showGlassSheet<TimeOfDay>(context, builder: (_) => _TimeSheet(initial: initialTime));

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class _DateSheet extends StatefulWidget {
  const _DateSheet({required this.initial, this.initialEnd, required this.first, required this.last, required this.range});
  final DateTime initial;
  final DateTime? initialEnd;
  final DateTime first;
  final DateTime last;
  final bool range;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _start = _clamp(widget.initial);
  late DateTime? _end = widget.range && widget.initialEnd != null ? _clamp(widget.initialEnd!) : null;
  late DateTime _month = DateTime(_start.year, _start.month);
  bool _years = false;
  final _yc = ScrollController();

  @override
  void dispose() {
    _yc.dispose();
    super.dispose();
  }

  DateTime _clamp(DateTime d) {
    final x = _day(d);
    if (x.isBefore(_day(widget.first))) return _day(widget.first);
    if (x.isAfter(_day(widget.last))) return _day(widget.last);
    return x;
  }

  bool _ok(DateTime d) => !d.isBefore(_day(widget.first)) && !d.isAfter(_day(widget.last));

  void _tap(DateTime d) => setState(() {
        if (!widget.range) {
          _start = d;
        } else if (_end != null || d.isBefore(_start)) {
          _start = d;
          _end = null;
        } else {
          _end = d;
        }
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final locale = Localizations.localeOf(context).toString();
    final startDay = Look.weekStart ?? MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final lead = (_month.weekday % 7 - startDay + 7) % 7;
    final daysIn = DateTime(_month.year, _month.month + 1, 0).day;
    final today = _day(DateTime.now());
    final canPrev = DateTime(_month.year, _month.month).isAfter(DateTime(widget.first.year, widget.first.month));
    final canNext = DateTime(_month.year, _month.month).isBefore(DateTime(widget.last.year, widget.last.month));
    const gridH = AppControl.md * 7;

    Widget day(int cell) {
      final n = cell - lead + 1;
      if (n < 1 || n > daysIn) return const SizedBox(height: AppControl.md);
      final d = DateTime(_month.year, _month.month, n);
      final on = d == _start || d == _end;
      final between = _end != null && d.isAfter(_start) && d.isBefore(_end!);
      final enabled = _ok(d);
      return InkWell(
        onTap: enabled ? () => _tap(d) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: AppControl.md,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? p.primary : (between ? p.primaryContainer : null),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: d == today && !on ? Border.all(color: p.primary, width: AppStroke.regular) : null,
          ),
          child: Text('$n', style: TextStyle(fontSize: AppFont.body, fontWeight: on ? AppWeight.semibold : AppWeight.regular, color: on ? p.onPrimary : (enabled ? p.text : p.text2.withValues(alpha: AppAlpha.disabled)))),
        ),
      );
    }

    final years = [for (var y = widget.first.year; y <= widget.last.year; y++) y];
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        GlassIconButton(icon: Lu.chevronLeft, onTap: canPrev && !_years ? () => setState(() => _month = DateTime(_month.year, _month.month - 1)) : () {}),
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() => _years = !_years);
              if (_years) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_yc.hasClients) _yc.jumpTo(((_month.year - widget.first.year - 2).clamp(0, widget.last.year - widget.first.year)) * AppControl.md);
                });
              }
            },
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(dfmt(DateFormat.yMMMM(locale), _month), style: const TextStyle(fontSize: AppFont.lead, fontWeight: AppWeight.semibold)),
                const SizedBox(width: AppSpace.xs),
                Icon(_years ? Lu.chevronUp : Lu.chevronDown, size: AppIcon.md, color: p.text2),
              ]),
            ),
          ),
        ),
        GlassIconButton(icon: Lu.chevronRight, onTap: canNext && !_years ? () => setState(() => _month = DateTime(_month.year, _month.month + 1)) : () {}),
      ]),
      const SizedBox(height: AppSpace.sm),
      SizedBox(
        height: gridH,
        child: _years
            ? ListView.builder(
                controller: _yc,
                itemExtent: AppControl.md,
                itemCount: years.length,
                itemBuilder: (_, i) {
                  final y = years[i];
                  final sel = y == _month.year;
                  return InkWell(
                    onTap: () => setState(() {
                      _month = DateTime(y, _month.month);
                      _years = false;
                    }),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: sel ? p.primary : null, borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: Text('$y', style: TextStyle(fontSize: AppFont.body, fontWeight: sel ? AppWeight.semibold : AppWeight.regular, color: sel ? p.onPrimary : p.text)),
                    ),
                  );
                },
              )
            : Column(children: [
                Row(children: [
                  for (var k = 0; k < 7; k++)
                    Expanded(
                      child: SizedBox(
                        height: AppControl.md,
                        child: Center(child: Text(dfmt(DateFormat.EEEEE(locale), DateTime(2023, 1, 1 + (startDay + k) % 7)), style: TextStyle(fontSize: AppFont.meta, fontWeight: AppWeight.semibold, color: p.text2))),
                      ),
                    ),
                ]),
                for (var w = 0; w < 6; w++) Row(children: [for (var k = 0; k < 7; k++) Expanded(child: day(w * 7 + k))]),
              ]),
      ),
      const SizedBox(height: AppSpace.lg),
      SheetButtons(
        secondary: l.cancel,
        onSecondary: () => Navigator.of(context).pop(),
        primary: l.done,
        onPrimary: widget.range && _end == null ? null : () => Navigator.of(context).pop([_start, if (widget.range) _end!]),
      ),
    ]);
  }
}

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.initial});
  final TimeOfDay initial;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late int _h = widget.initial.hourOfPeriod == 0 ? 12 : widget.initial.hourOfPeriod;
  late int _m = widget.initial.minute;
  late bool _pm = widget.initial.hour >= 12;
  late final _hc = FixedExtentScrollController(initialItem: _h - 1);
  late final _mc = FixedExtentScrollController(initialItem: _m);
  late final _pc = FixedExtentScrollController(initialItem: _pm ? 1 : 0);

  @override
  void dispose() {
    _hc.dispose();
    _mc.dispose();
    _pc.dispose();
    super.dispose();
  }

  Widget _wheel({required FixedExtentScrollController c, required List<String> items, required ValueChanged<int> onChanged, bool loop = true}) {
    final kids = [for (final t in items) Center(child: Text(t, style: const TextStyle(fontSize: AppFont.lead, fontWeight: AppWeight.semibold)))];
    return Expanded(
      child: ListWheelScrollView.useDelegate(
        controller: c,
        itemExtent: AppControl.md,
        diameterRatio: 2,
        overAndUnderCenterOpacity: .35,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (i) => onChanged(((i % items.length) + items.length) % items.length),
        childDelegate: loop ? ListWheelChildLoopingListDelegate(children: kids) : ListWheelChildListDelegate(children: kids),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: AppControl.md * 5,
        child: Stack(alignment: Alignment.center, children: [
          Container(height: AppControl.md, decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.md))),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: [
              _wheel(c: _hc, items: [for (var i = 1; i <= 12; i++) '$i'], onChanged: (i) => _h = i + 1),
              _wheel(c: _mc, items: [for (var i = 0; i < 60; i++) i.toString().padLeft(2, '0')], onChanged: (i) => _m = i),
              _wheel(c: _pc, items: ar ? ['ص', 'م'] : ['AM', 'PM'], loop: false, onChanged: (i) => _pm = i == 1),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: AppSpace.lg),
      SheetButtons(
        secondary: l.cancel,
        onSecondary: () => Navigator.of(context).pop(),
        primary: l.done,
        onPrimary: () => Navigator.of(context).pop(TimeOfDay(hour: (_h % 12) + (_pm ? 12 : 0), minute: _m)),
      ),
    ]);
  }
}
