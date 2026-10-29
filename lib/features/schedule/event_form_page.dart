import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/format.dart';
import '../../data/contacts_repository.dart';
import '../../data/schedule_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../activities/contact_picker.dart';
import '../settings/settings_widgets.dart' show AppSwitch;

/// New event / Edit event (design K6): a dated event of a contact with its alert.
class EventFormPage extends StatefulWidget {
  const EventFormPage({super.key, required this.schedule, required this.contacts, this.id, this.contactId, this.day});
  final ScheduleRepository schedule;
  final ContactsRepository contacts;
  final int? id;
  final int? contactId;
  final DateTime? day;

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  int? _contactId;
  String _contactName = '';
  int _kind = 3;
  late DateTime _date = widget.day ?? DateTime.now();
  bool _yearly = true;
  bool _alarm = false;
  int? _alertMinutes;
  int _mask = 1;
  bool _loading = false;
  bool _saving = false;
  String? _problem;
  String _initial = '';

  @override
  void initState() {
    super.initState();
    _contactId = widget.contactId;
    if (widget.id != null) _loading = true;
    _load();
  }

  Future<void> _load() async {
    if (widget.id != null) {
      final e = await widget.schedule.getEvent(widget.id!);
      if (e != null) {
        _title.text = e.title;
        _contactId = e.contactId;
        _date = e.date;
        _yearly = e.yearly;
        _alarm = e.alarm;
        _alertMinutes = e.alertMinutes;
        _mask = e.remindMask;
        _note.text = e.note;
        _kind = 3;
      }
    }
    if (_contactId != null) {
      final c = await widget.contacts.get(_contactId!);
      _contactName = c?.displayName ?? '';
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _initial = _signature();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  String _signature() => [_title.text, _contactId, _date.toIso8601String(), _yearly, _alarm, _alertMinutes, _mask, _note.text].join('|');
  bool get _dirty => !_loading && _signature() != _initial;

  List<String> _typeNames(AppLocalizations l) => [l.evBirthday, l.evAnniversary, l.evRenewal, l.evOther];

  Future<void> _pickType() async {
    final l = AppLocalizations.of(context);
    final names = _typeNames(l);
    final v = await showGlassSheet<int>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(l.evType),
        for (var i = 0; i < names.length; i++) SheetItem(first: i == 0, title: names[i], bold: _kind == i, selected: _kind == i, onTap: () => Navigator.of(ctx).pop(i)),
      ]),
    );
    if (v == null) return;
    setState(() {
      final t = _title.text.trim();
      if (t.isEmpty || names.contains(t)) _title.text = v == 3 ? '' : names[v];
      _kind = v;
    });
  }

  Future<void> _pickContact() async {
    final c = await pickContact(context, widget.contacts);
    if (c == null || c.id == null) return;
    setState(() {
      _contactId = c.id;
      _contactName = c.name;
      _problem = null;
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(1900), lastDate: DateTime(2100));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickAlertTime() async {
    final m = _alertMinutes ?? 8 * 60;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60));
    if (t != null) setState(() => _alertMinutes = t.hour * 60 + t.minute);
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = AppLocalizations.of(context);
    if (_title.text.trim().isEmpty) {
      setState(() => _problem = 'title');
      return;
    }
    if (_contactId == null) {
      setState(() => _problem = 'contact');
      return;
    }
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final id = await widget.schedule.saveEvent(
      id: widget.id,
      contactId: _contactId!,
      title: _title.text,
      date: _date,
      yearly: _yearly,
      alarm: _alarm,
      alertMinutes: _alertMinutes,
      remindMask: _mask,
      note: _note.text,
    );
    _initial = _signature();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.eventSaved)));
    nav.pop(id);
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.eventDeleteTitle),
        content: Text(l.eventDeleteBody),
        actions: [
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.delete, danger: true, onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final nav = Navigator.of(context);
    await widget.schedule.deleteEvent(widget.id!);
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
          DialogCancel(l.keepEditing, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.discard, danger: true, onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final locale = Localizations.localeOf(context).toString();
    final names = _typeNames(l);
    final time = _alertMinutes == null ? null : TimeOfDay(hour: _alertMinutes! ~/ 60, minute: _alertMinutes! % 60);
    Widget caps(String t) => SectionLabel(t, padding: const EdgeInsets.fromLTRB(0, 16, 0, 8));
    Widget maskChip(String label, int bit) => PillChip(
          label: label,
          selected: _mask & bit != 0,
          onTap: () => setState(() => _mask = _mask & bit != 0 ? _mask & ~bit : _mask | bit),
        );
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
                      Expanded(child: Text(widget.id == null ? l.eventNew : l.eventEdit, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: pal.onHeader))),
                      SizedBox(width: 77.5, child: PillButton(label: l.save, height: 44, accent: true, onPressed: _saving ? null : _save)),
                    ]),
                  ),
                  Expanded(
                    child: ListView(padding: const EdgeInsets.fromLTRB(24, 31, 24, 40), children: [
                      GlassField(
                        controller: _title,
                        label: l.fieldTaskTitle,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) {
                          if (_problem == 'title') setState(() => _problem = null);
                        },
                      ),
                      if (_problem == 'title') Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(l.errTitleRequired, style: TextStyle(color: pal.error, fontSize: 13))),
                      const SizedBox(height: 15),
                      GlassSelectField(label: l.evType, value: names[_kind], onTap: _pickType),
                      const SizedBox(height: 15),
                      GlassSelectField(
                        label: l.fieldContact,
                        value: _contactId != null ? _contactName : ' ',
                        onTap: widget.contactId != null ? () {} : _pickContact,
                        trailing: widget.contactId != null ? Icon(Icons.lock_outline, size: 22, color: pal.text) : null,
                      ),
                      if (_problem == 'contact') Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(l.errContactRequired, style: TextStyle(color: pal.error, fontSize: 13))),
                      const SizedBox(height: 27),
                      GlassSelectField(
                        label: l.fieldDate,
                        value: dfmt(DateFormat('d MMM', locale), _date),
                        trailing: Icon(Icons.calendar_today_outlined, size: 22, color: pal.text),
                        onTap: _pickDate,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
                        child: Row(children: [
                          Expanded(child: Text(l.evRepeatYear, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                          AppSwitch(value: _yearly, onChanged: (v) => setState(() => _yearly = v)),
                        ]),
                      ),
                      caps(l.alertCaps),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        PillChip(label: l.reminderTypeNotification, selected: !_alarm, onTap: () => setState(() => _alarm = false)),
                        PillChip(label: l.reminderTypeAlarm, selected: _alarm, onTap: () => setState(() => _alarm = true)),
                      ]),
                      const SizedBox(height: 12),
                      GlassSelectField(
                        label: l.alertTimeLabel,
                        value: (time ?? TimeOfDay(hour: widget.schedule.defaultEventMinutes ~/ 60, minute: widget.schedule.defaultEventMinutes % 60)).format(context),
                        trailing: const SizedBox.shrink(),
                        onTap: _pickAlertTime,
                      ),
                      caps(l.alsoRemindCaps),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        maskChip(l.remSameDay, 1),
                        maskChip(l.remDayBefore, 2),
                        maskChip(l.remWeekBefore, 4),
                      ]),
                      const SizedBox(height: 12),
                      GlassField(controller: _note, label: l.fieldDescription, hint: l.optionalHint, maxLines: 4, textCapitalization: TextCapitalization.sentences),
                      if (widget.id != null) ...[
                        const SizedBox(height: 24),
                        TextButton(onPressed: _delete, child: Text(l.delete, style: TextStyle(color: pal.error, fontWeight: FontWeight.w600, fontSize: 15))),
                      ],
                    ]),
                  ),
                ]),
        ),
      ),
    );
  }
}
