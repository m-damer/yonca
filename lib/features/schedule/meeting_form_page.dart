import 'package:flutter/material.dart';

import '../../data/contacts_repository.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../activities/contact_picker.dart';
import 'schedule_fields.dart';
import 'schedule_labels.dart';

/// New or edit meeting. [contactId] pre-selects one attendee. Pops with the meeting id, or -1 when deleted.
class MeetingFormPage extends StatefulWidget {
  const MeetingFormPage({super.key, required this.schedule, required this.contacts, this.contactId, this.id, this.day});
  final ScheduleRepository schedule;
  final ContactsRepository contacts;
  final int? contactId;
  final int? id;

  /// Day to start on for a new meeting.
  final DateTime? day;

  @override
  State<MeetingFormPage> createState() => _MeetingFormPageState();
}

class _MeetingFormPageState extends State<MeetingFormPage> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _link = TextEditingController();
  final _description = TextEditingController();
  final _duration = TextEditingController(text: '60');
  final _attendees = <(int, String)>[];
  late DateTime _start = _defaultStart(widget.day);
  MeetingType _type = MeetingType.inPerson;
  int? _reminder = 60;
  bool _alarm = true;
  Repeat _repeat = Repeat.none;
  bool _loading = true;
  bool _saving = false;
  String? _problem;
  String _initial = '';
  String _overlap = '';

  static DateTime _defaultStart(DateTime? day) {
    final n = DateTime.now().add(const Duration(hours: 1));
    if (day != null) return DateTime(day.year, day.month, day.day, n.hour);
    return DateTime(n.year, n.month, n.day, n.hour);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.id;
    if (id != null) {
      final m = await widget.schedule.getMeeting(id);
      if (m != null) {
        final x = m.meeting;
        _title.text = x.title;
        _place.text = x.place;
        _link.text = x.link;
        _description.text = x.description;
        _duration.text = '${x.durationMinutes}';
        _start = x.startAt;
        _type = meetingTypeFromName(x.type);
        _reminder = x.reminderMinutes;
        _alarm = x.alarm;
        _repeat = repeatFromName(x.repeat);
        for (var i = 0; i < m.contactIds.length; i++) {
          _attendees.add((m.contactIds[i], m.contactNames[i]));
        }
      }
    } else if (widget.contactId != null) {
      final s = await widget.contacts.get(widget.contactId!);
      if (s != null) _attendees.add((widget.contactId!, s.displayName));
    }
    _initial = _signature();
    await _checkOverlap();
    if (mounted) setState(() => _loading = false);
  }

  int get _minutes => int.tryParse(_duration.text.trim()) ?? 60;

  String _signature() => [
        _title.text, _place.text, _link.text, _description.text, _duration.text, _start.toIso8601String(), _type.name,
        _reminder, _alarm, _repeat.name, _attendees.map((a) => a.$1).join(','),
      ].join('|');

  bool get _dirty => !_loading && _signature() != _initial;

  @override
  void dispose() {
    for (final c in [_title, _place, _link, _description, _duration]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _checkOverlap() async {
    final list = await widget.schedule.overlapping(_start, _minutes <= 0 ? 1 : _minutes, excludeId: widget.id);
    final text = list.isEmpty ? '' : list.first.title;
    if (mounted && text != _overlap) setState(() => _overlap = text);
  }

  Future<void> _addAttendee() async {
    final l = AppLocalizations.of(context);
    if (_attendees.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.maxAttendees)));
      return;
    }
    final c = await pickContact(context, widget.contacts);
    if (c == null || c.id == null) return;
    if (_attendees.any((a) => a.$1 == c.id)) return;
    setState(() => _attendees.add((c.id!, c.name)));
  }

  MeetingInput _input() => MeetingInput(
        title: _title.text,
        contactIds: [for (final a in _attendees) a.$1],
        startAt: _start,
        durationMinutes: _minutes <= 0 ? 60 : _minutes,
        type: _type,
        place: _type == MeetingType.inPerson ? _place.text : '',
        link: _type == MeetingType.video ? _link.text : '',
        description: _description.text,
        reminderMinutes: _reminder,
        alarm: _alarm,
        repeat: _repeat,
      );

  Future<void> _save() async {
    if (_saving) return;
    final input = _input();
    final problem = input.problem();
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _saving = true);
    final id = await widget.schedule.saveMeeting(input, id: widget.id);
    _initial = _signature();
    if (mounted) Navigator.of(context).pop(id);
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteMeetingTitle),
        content: Text(l.deleteMeetingBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true || widget.id == null) return;
    await widget.schedule.deleteMeeting(widget.id!);
    _initial = _signature();
    nav.pop(-1);
  }

  Future<bool> _confirmDiscard() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.discardTitle),
        content: Text(l.discardBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.keepEditing)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.discard)),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) {
          _initial = _signature();
          nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GlassBackdrop(
          child: _loading
              ? const SafeArea(child: LoadingView())
              : Column(children: [
                  HeaderBand(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Row(children: [
                      GlassIconButton(icon: Icons.close, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(widget.id == null ? l.meetingNew : l.meetingEdit,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: pal.onHeader)),
                      ),
                      SizedBox(width: 77.5, child: PillButton(label: l.save, height: 44, accent: true, onPressed: _saving ? null : _save)),
                    ]),
                  ),
                  Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(24, 31, 24, 40), children: _content(l, pal))),
                ]),
        ),
      ),
    );
  }

  bool _customDuration = false;

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d == null || !mounted) return;
    setState(() => _start = DateTime(d.year, d.month, d.day, _start.hour, _start.minute));
    await _checkOverlap();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (t == null || !mounted) return;
    setState(() => _start = DateTime(_start.year, _start.month, _start.day, t.hour, t.minute));
    await _checkOverlap();
  }

  String _durationText(AppLocalizations l) {
    final m = _minutes;
    return m >= 60 ? (m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} min') : '$m min';
  }

  Future<void> _customDurationSheet() async {
    final l = AppLocalizations.of(context);
    final h = TextEditingController(text: '${_minutes ~/ 60}');
    final m = TextEditingController(text: '${_minutes % 60}');
    final ok = await showGlassSheet<bool>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final total = (int.tryParse(h.text) ?? 0) * 60 + (int.tryParse(m.text) ?? 0);
          final end = _start.add(Duration(minutes: total));
          return SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SheetTitle(l.customDurTitle),
              Row(children: [
                Expanded(child: GlassField(controller: h, label: l.hoursLabel, keyboardType: TextInputType.number, autofocus: true, maxLength: 2, onChanged: (_) => setS(() {}))),
                const SizedBox(width: 10),
                Expanded(child: GlassField(controller: m, label: l.minutesLabel, keyboardType: TextInputType.number, maxLength: 2, onChanged: (_) => setS(() {}))),
              ]),
              Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 12), child: Text(l.endsAtLabel(formatClock(ctx, end)), style: TextStyle(fontSize: 13, height: 26.2 / 13, color: ctx.palette.text2))),
              SheetButtons(secondary: l.cancel, onSecondary: () => Navigator.of(ctx).pop(false), primary: l.setBtn, onPrimary: total <= 0 ? null : () => Navigator.of(ctx).pop(true)),
            ]),
          );
        },
      ),
    );
    final total = (int.tryParse(h.text) ?? 0) * 60 + (int.tryParse(m.text) ?? 0);
    if (ok == true && total > 0 && mounted) {
      setState(() {
        _customDuration = true;
        _duration.text = '$total';
      });
      await _checkOverlap();
    }
  }

  List<Widget> _content(AppLocalizations l, YoncaPalette pal) {
    final presets = <(int, String)>[(15, l.dur15), (30, l.dur30), (60, l.dur60), (120, l.dur120)];
    final isPreset = presets.any((x) => x.$1 == _minutes);
    final showCustom = _customDuration || !isPreset;
    return [
        GlassField(
          controller: _title,
          label: l.fieldTaskTitle,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (_problem != null) setState(() => _problem = null);
          },
        ),
        if (_problem == 'title')
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(l.errTitleRequired, style: TextStyle(color: pal.error, fontSize: 13)),
          ),
        SectionLabel(l.fieldAttendees, padding: const EdgeInsets.fromLTRB(0, 16, 0, 8)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in _attendees)
            AttendeeChip(
              name: a.$2,
              onRemove: widget.contactId == a.$1 && widget.id == null ? null : () => setState(() => _attendees.remove(a)),
            ),
          GestureDetector(
            onTap: _addAttendee,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: pal.primary)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 22, color: pal.primary),
                const SizedBox(width: 6),
                Text(l.addShort, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: pal.text)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 27),
        Row(children: [
          Expanded(
            flex: 193,
            child: GlassSelectField(label: l.fieldDate, value: formatDayShort(context, _start), onTap: _pickDate, trailing: const SizedBox.shrink()),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 139,
            child: GlassSelectField(label: l.fieldStart, value: formatClock(context, _start), onTap: _pickTime, trailing: const SizedBox.shrink()),
          ),
        ]),
        if (_overlap.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: pal.errorContainer, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 22, color: pal.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(child: Text(l.overlapWarning(_overlap), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: pal.onErrorContainer, fontSize: 14))),
            ]),
          ),
        SectionLabel(l.durationTitle, padding: const EdgeInsets.fromLTRB(0, 16, 0, 8)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in presets)
            PillChip(
              label: d.$2,
              selected: !showCustom && _minutes == d.$1,
              onTap: () {
                setState(() {
                  _customDuration = false;
                  _duration.text = '${d.$1}';
                });
                _checkOverlap();
              },
            ),
          PillChip(label: showCustom && !presets.any((x) => x.$1 == _minutes) ? _durationText(l) : l.durCustom, selected: showCustom, onTap: _customDurationSheet),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in MeetingType.values)
            PillChip(
              label: meetingTypeLabel(l, t),
              icon: meetingTypeIcon(t),
              selected: _type == t,
              onTap: () => setState(() => _type = t),
            ),
        ]),
        const SizedBox(height: 29),
        if (_type == MeetingType.inPerson)
          GlassField(controller: _place, label: l.fieldPlace, textCapitalization: TextCapitalization.words, trailing: Icon(Icons.location_on_outlined, color: pal.text)),
        if (_type == MeetingType.video)
          GlassField(controller: _link, label: l.fieldLink, keyboardType: TextInputType.url, textDirection: TextDirection.ltr),
        const SizedBox(height: 15),
        ReminderFields(
          hasTime: true,
          minutes: _reminder,
          alarm: _alarm,
          onMinutes: (v) => setState(() => _reminder = v),
          onAlarm: (v) => setState(() => _alarm = v),
        ),
        const SizedBox(height: 15),
        RepeatSelect(value: _repeat, onChanged: (r) => setState(() => _repeat = r)),
        const SizedBox(height: 15),
        GlassField(
          controller: _description,
          label: l.fieldDescription,
          hint: l.optionalHint,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
        ),
        if (widget.id != null) ...[
          const SizedBox(height: 24),
          TextButton(
            onPressed: _delete,
            child: Text(l.delete, style: TextStyle(color: pal.error, fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ],
      ];
  }
}
