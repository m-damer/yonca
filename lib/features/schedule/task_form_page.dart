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

/// New or edit task. [contactId] pre-fills (and locks) the contact. Pops with the task id, or -1 when deleted.
class TaskFormPage extends StatefulWidget {
  const TaskFormPage({super.key, required this.schedule, required this.contacts, this.contactId, this.id, this.initialTitle = '', this.initialDue});
  final ScheduleRepository schedule;
  final ContactsRepository contacts;
  final int? contactId;
  final int? id;
  final String initialTitle;

  /// Day to start on for a new task.
  final DateTime? initialDue;

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  int? _contactId;
  String _contactName = '';
  DateTime _due = dayOnly(DateTime.now());
  bool _hasTime = false;
  Priority _priority = Priority.normal;
  int? _reminder = 60;
  bool _alarm = true;
  Repeat _repeat = Repeat.none;
  bool _loading = true;
  bool _saving = false;
  String? _problem;
  String _initial = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.id;
    if (id != null) {
      final t = await widget.schedule.getTask(id);
      if (t != null) {
        _title.text = t.title;
        _description.text = t.description;
        _contactId = t.contactId;
        _due = t.dueAt;
        _hasTime = t.hasTime;
        _priority = priorityFromName(t.priority);
        _reminder = t.reminderMinutes;
        _alarm = t.alarm;
        _repeat = repeatFromName(t.repeat);
      }
    } else {
      _contactId = widget.contactId;
      _title.text = widget.initialTitle;
      if (widget.initialDue != null) _due = dayOnly(widget.initialDue!);
    }
    if (_contactId != null) {
      final s = await widget.contacts.get(_contactId!);
      _contactName = s?.displayName ?? '';
    }
    _initial = _signature();
    if (mounted) setState(() => _loading = false);
  }

  String _signature() => [
        _title.text, _description.text, _contactId, _due.toIso8601String(), _hasTime, _priority.name, _reminder, _alarm, _repeat.name,
      ].join('|');

  bool get _dirty => !_loading && _signature() != _initial;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() => _due = DateTime(d.year, d.month, d.day, _hasTime ? _due.hour : 0, _hasTime ? _due.minute : 0));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due));
    if (t == null || !mounted) return;
    setState(() => _due = DateTime(_due.year, _due.month, _due.day, t.hour, t.minute));
  }

  /// Time (optional): choose a time or None.
  Future<void> _chooseTime() async {
    final l = AppLocalizations.of(context);
    final none = await showGlassSheet<bool>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(l.timeNone), trailing: _hasTime ? null : const Icon(Icons.check), onTap: () => Navigator.of(ctx).pop(true)),
        ListTile(title: Text(l.setTime), trailing: _hasTime ? const Icon(Icons.check) : null, onTap: () => Navigator.of(ctx).pop(false)),
      ]),
    );
    if (none == null) return;
    if (none) {
      if (_hasTime) await _toggleTime(false);
    } else if (_hasTime) {
      await _pickTime();
    } else {
      await _toggleTime(true);
    }
  }

  Future<void> _toggleTime(bool on) async {
    setState(() {
      _hasTime = on;
      _due = DateTime(_due.year, _due.month, _due.day, on ? 9 : 0);
      // Reminder choices differ between timed and date-only tasks.
      if (_reminder != null) _reminder = 60;
    });
    if (on) await _pickTime();
  }

  Future<void> _pickContact() async {
    final c = await pickContact(context, widget.contacts, allowNone: true);
    if (c == null) return;
    setState(() {
      _contactId = c.id;
      _contactName = c.id == null ? '' : c.name;
    });
  }

  TaskInput _input() => TaskInput(
        title: _title.text,
        contactId: _contactId,
        dueAt: _due,
        hasTime: _hasTime,
        priority: _priority,
        reminderMinutes: _reminder,
        alarm: _alarm,
        repeat: _repeat,
        description: _description.text,
      );

  Future<void> _save() async {
    if (_saving) return;
    final input = _input();
    final problem = input.problem();
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _saving = true);
    final id = await widget.schedule.saveTask(input, id: widget.id);
    _initial = _signature();
    if (mounted) Navigator.of(context).pop(id);
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteTaskTitle),
        content: Text(l.deleteTaskBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true || widget.id == null) return;
    await widget.schedule.deleteTask(widget.id!);
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Row(children: [
                      GlassIconButton(icon: Icons.close, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(widget.id == null ? l.taskNew : l.taskEdit,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: pal.onHeader)),
                      ),
                      SizedBox(width: 88, child: PillButton(label: l.save, height: 44, accent: true, onPressed: _saving ? null : _save)),
                    ]),
                  ),
                  Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: _content(l, pal))),
                ]),
        ),
      ),
    );
  }

  List<Widget> _content(AppLocalizations l, YoncaPalette pal) => [
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
        const SizedBox(height: 12),
        GlassSelectField(
          label: l.fieldContact,
          value: _contactId != null ? _contactName : ' ',
          onTap: widget.contactId != null ? () {} : _pickContact,
          trailing: widget.contactId != null ? Icon(Icons.lock_outline, size: 22, color: pal.text) : null,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            flex: 5,
            child: GlassSelectField(label: l.fieldDueDate, value: formatDay(context, _due), onTap: _pickDate, trailing: const SizedBox.shrink()),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: GlassSelectField(
              label: l.fieldTimeOptional,
              value: _hasTime ? formatClock(context, _due) : l.timeNone,
              onTap: _chooseTime,
              trailing: const SizedBox.shrink(),
            ),
          ),
        ]),
        SectionLabel(l.fieldPriority),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in Priority.values)
            PillChip(label: priorityLabel(l, p), selected: _priority == p, onTap: () => setState(() => _priority = p)),
        ]),
        const SizedBox(height: 12),
        ReminderFields(
          hasTime: _hasTime,
          minutes: _reminder,
          alarm: _alarm,
          onMinutes: (v) => setState(() => _reminder = v),
          onAlarm: (v) => setState(() => _alarm = v),
        ),
        const SizedBox(height: 12),
        RepeatSelect(value: _repeat, onChanged: (r) => setState(() => _repeat = r)),
        const SizedBox(height: 12),
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
            child: Text(l.delete, style: TextStyle(color: pal.error, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ];
}
