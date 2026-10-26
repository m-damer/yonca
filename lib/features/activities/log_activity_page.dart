import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/activities_repository.dart';
import '../../data/app_database.dart';
import '../../data/contacts_repository.dart';
import '../../domain/activity_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'activity_labels.dart';
import 'contact_picker.dart';
import 'voice.dart';

const _imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp'];

bool isImageName(String name) => _imageExtensions.contains(p.extension(name).replaceFirst('.', '').toLowerCase());

/// Log activity (design S13) for a new activity, or edit activity [id] (with Delete).
/// [contactId] locks the contact. Pops with the saved activity id, or -1 when deleted.
class LogActivityPage extends StatefulWidget {
  const LogActivityPage({
    super.key,
    required this.activities,
    required this.contacts,
    this.contactId,
    this.id,
    this.initialType = ActivityType.call,
  });
  final ActivitiesRepository activities;
  final ContactsRepository contacts;
  final int? contactId;
  final int? id;
  final ActivityType initialType;

  @override
  State<LogActivityPage> createState() => _LogActivityPageState();
}

class _LogActivityPageState extends State<LogActivityPage> {
  late ActivityType _type = widget.initialType;
  int? _contactId;
  String _contactName = '';
  DateTime _when = DateTime.now();
  String _direction = 'out';
  String _channel = 'whatsapp';
  int? _outcomeId;
  final _duration = TextEditingController();
  final _place = TextEditingController();
  final _map = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  VoiceResult? _voice;
  final _files = <ActivityFileInput>[];
  List<Outcome> _outcomes = const [];
  bool _loading = true;
  bool _saving = false;
  bool _recording = false;
  String? _problem;
  String _initial = '';

  bool get _contactLocked => widget.contactId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _outcomes = await widget.activities.outcomes();
    final id = widget.id;
    if (id != null) {
      final item = await widget.activities.get(id);
      if (item != null) {
        final a = item.activity;
        _type = item.type;
        _contactId = a.contactId;
        _contactName = item.contactName ?? '';
        _when = a.occurredAt;
        _direction = a.direction.isEmpty ? (_type == ActivityType.message ? 'sent' : 'out') : a.direction;
        _channel = a.channel.isEmpty ? 'whatsapp' : a.channel;
        _outcomeId = a.outcomeId;
        _duration.text = a.durationMinutes?.toString() ?? '';
        _place.text = a.place;
        _map.text = a.mapLink;
        _title.text = a.title;
        _description.text = a.description;
        if (a.voicePath != null) _voice = VoiceResult(a.voicePath!, a.voiceMs);
        _files.addAll([for (final f in item.files) ActivityFileInput(path: f.path, name: f.name, isImage: f.isImage)]);
        // An outcome archived later still shows on the old activity.
        if (item.outcome != null && !_outcomes.any((o) => o.id == item.outcome!.id)) {
          _outcomes = [..._outcomes, item.outcome!];
        }
      }
    } else if (widget.contactId != null) {
      _contactId = widget.contactId;
      final s = await widget.contacts.get(widget.contactId!);
      _contactName = s?.displayName ?? '';
    }
    _applyTypeDefaults();
    _initial = _signature();
    if (mounted) setState(() => _loading = false);
  }

  void _applyTypeDefaults() {
    if (_type == ActivityType.message && !const ['sent', 'received'].contains(_direction)) _direction = 'sent';
    if (_type == ActivityType.call && !const ['in', 'out'].contains(_direction)) _direction = 'out';
  }

  String _signature() => [
        _type.name, _contactId, _when.toIso8601String(), _direction, _channel, _outcomeId, _duration.text,
        _place.text, _map.text, _title.text, _description.text, _voice?.path, _files.map((f) => f.path).join(','),
      ].join('|');

  bool get _dirty => !_loading && _signature() != _initial;

  @override
  void dispose() {
    for (final c in [_duration, _place, _map, _title, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  ActivityInput _input() => ActivityInput(
        type: _type,
        contactId: _contactId,
        occurredAt: _when,
        direction: switch (_type) {
          ActivityType.call || ActivityType.message => _direction,
          _ => '',
        },
        durationMinutes: _type == ActivityType.call ? int.tryParse(_duration.text.trim()) : null,
        place: _type == ActivityType.visit ? _place.text : '',
        mapLink: _type == ActivityType.visit ? _map.text : '',
        channel: _type == ActivityType.message ? _channel : '',
        outcomeId: _type == ActivityType.note ? null : _outcomeId,
        title: _type == ActivityType.note ? _title.text : '',
        description: _description.text,
        voicePath: _type == ActivityType.note ? _voice?.path : null,
        voiceMs: _type == ActivityType.note ? (_voice?.durationMs ?? 0) : 0,
        files: List.of(_files),
      );

  Future<void> _save() async {
    if (_saving) return;
    final input = _input();
    final problem = input.problem();
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _saving = true);
    final id = await widget.activities.save(input, id: widget.id);
    _initial = _signature();
    if (mounted) Navigator.of(context).pop(id);
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

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteActivityTitle),
        content: Text(l.deleteActivityBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true || widget.id == null) return;
    final paths = await widget.activities.delete(widget.id!);
    for (final path in paths) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    _initial = _signature();
    nav.pop(-1);
  }

  Future<void> _pickContact() async {
    final c = await pickContact(context, widget.contacts, allowNone: _type == ActivityType.note);
    if (c == null) return;
    setState(() {
      _contactId = c.id;
      _contactName = c.id == null ? '' : c.name;
      _problem = null;
    });
  }

  Future<void> _pickWhen() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (!mounted) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, t?.hour ?? _when.hour, t?.minute ?? _when.minute));
  }

  Future<void> _addFiles() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'activity_files'))..createSync(recursive: true);
    final added = <ActivityFileInput>[];
    for (final f in res.files) {
      final src = f.path;
      if (src == null) continue;
      final dest = p.join(folder.path, '${DateTime.now().microsecondsSinceEpoch}_${f.name}');
      await File(src).copy(dest);
      added.add(ActivityFileInput(path: dest, name: f.name, isImage: isImageName(f.name)));
    }
    if (mounted) setState(() => _files.addAll(added));
  }

  void _chooseType(ActivityType t) {
    setState(() {
      _type = t;
      _problem = null;
      if (t == ActivityType.message) _direction = 'sent';
      if (t == ActivityType.call) _direction = 'out';
      if (t != ActivityType.note && _contactId == null) _contactName = '';
    });
  }

  Widget _choice(List<(String, String)> options, String value, ValueChanged<String> onPick) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in options)
            PillChip(label: o.$2, selected: value == o.$1, check: true, onTap: () => onPick(o.$1)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    return PopScope(
      canPop: !_dirty && !_recording,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) {
          _initial = _signature();
          _recording = false;
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
                        child: Text(widget.id == null ? l.logActivity : l.editActivity,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: pal.onHeader)),
                      ),
                      SizedBox(
                        width: 88,
                        child: PillButton(label: l.save, height: 44, accent: true, onPressed: _saving ? null : _save),
                      ),
                    ]),
                  ),
                  Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: _content(l, pal))),
                ]),
        ),
      ),
    );
  }

  List<Widget> _content(AppLocalizations l, YoncaPalette pal) {
    final needsOutcome = _type == ActivityType.call || _type == ActivityType.visit;
    Widget error(String key, String text) => _problem == key
        ? Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(text, style: TextStyle(color: pal.error, fontSize: 13)))
        : const SizedBox.shrink();
    return [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final t in ActivityType.values)
          PillChip(
            label: activityTypeLabel(l, t),
            icon: activityTypeIcon(t),
            selected: _type == t,
            onTap: widget.id == null ? () => _chooseType(t) : null,
          ),
      ]),
      const SizedBox(height: 16),
      GlassSelectField(
        label: l.fieldContact,
        value: _contactId != null ? _contactName : (_type == ActivityType.note ? l.generalNote : ' '),
        onTap: _contactLocked ? () {} : _pickContact,
      ),
      error('contact', l.errContactRequired),
      const SizedBox(height: 12),
      GlassSelectField(label: l.fieldWhen, value: formatWhen(context, _when), onTap: _pickWhen),
      const SizedBox(height: 12),
      if (_type == ActivityType.call) ...[
        _choice([('out', l.dirOutgoing), ('in', l.dirIncoming)], _direction, (v) => setState(() => _direction = v)),
        const SizedBox(height: 12),
        GlassField(controller: _duration, label: l.fieldDuration, keyboardType: TextInputType.number, hint: l.optionalHint),
        const SizedBox(height: 12),
      ],
      if (_type == ActivityType.visit) ...[
        GlassField(controller: _place, label: l.fieldPlace, textCapitalization: TextCapitalization.words),
        const SizedBox(height: 12),
        GlassField(
          controller: _map,
          label: l.fieldMapLink,
          hint: l.mapLinkHint,
          keyboardType: TextInputType.url,
          textDirection: TextDirection.ltr,
        ),
        const SizedBox(height: 12),
      ],
      if (_type == ActivityType.message) ...[
        _choice([('whatsapp', l.actionWhatsApp), ('email', l.actionEmail)], _channel, (v) => setState(() => _channel = v)),
        const SizedBox(height: 12),
        _choice([('sent', l.dirSent), ('received', l.dirReceived)], _direction, (v) => setState(() => _direction = v)),
        const SizedBox(height: 12),
      ],
      if (_type == ActivityType.note) ...[
        GlassField(
          controller: _title,
          label: l.fieldNoteTitle,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (_problem == 'title') setState(() => _problem = null);
          },
        ),
        error('title', l.errTitleRequired),
        const SizedBox(height: 12),
        GlassField(
          controller: _description,
          label: l.fieldNoteText,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
        ),
        SectionLabel(l.voiceNote),
        VoiceRecorderField(
          value: _voice,
          onChanged: (v) => setState(() => _voice = v),
          onRecordingChanged: (r) => setState(() => _recording = r),
        ),
      ] else ...[
        SectionLabel(needsOutcome ? l.fieldOutcome : '${l.fieldOutcome} · ${l.optionalHint}'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in _outcomes)
            PillChip(
              label: outcomeLabel(l, o),
              selected: _outcomeId == o.id,
              check: true,
              onTap: () => setState(() {
                _outcomeId = _outcomeId == o.id ? null : o.id;
                _problem = null;
              }),
            ),
        ]),
        error('outcome', l.errOutcomeRequired),
        const SizedBox(height: 16),
        GlassField(
          controller: _description,
          label: l.fieldDescription,
          maxLines: 4,
          hint: l.optionalHint,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
      SectionLabel(l.attachments),
      for (var i = 0; i < _files.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(_files[i].isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined, color: pal.primary),
          title: Text(_files[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            tooltip: l.removeFile,
            icon: Icon(Icons.remove_circle_outline, color: pal.error.withValues(alpha: .8)),
            onPressed: () => setState(() => _files.removeAt(i)),
          ),
        ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(onPressed: _addFiles, icon: const Icon(Icons.attach_file), label: Text(l.addFile)),
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
}
