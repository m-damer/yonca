import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/fields_repository.dart';
import '../../domain/field_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../schedule/schedule_labels.dart';

/// Shows the custom field values of a contact or deal, with an Edit button. Hidden when no fields exist.
class FieldValuesCard extends StatefulWidget {
  const FieldValuesCard({super.key, required this.fields, required this.scope, required this.ownerId});
  final FieldsRepository fields;
  final FieldScope scope;
  final int ownerId;

  @override
  State<FieldValuesCard> createState() => _FieldValuesCardState();
}

class _FieldValuesCardState extends State<FieldValuesCard> {
  List<CustomField> _fields = const [];
  Map<int, String> _values = const {};

  @override
  void initState() {
    super.initState();
    widget.fields.revision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.fields.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final f = await widget.fields.fields(widget.scope);
    final v = await widget.fields.values(widget.scope, widget.ownerId);
    if (mounted) {
      setState(() {
        _fields = f;
        _values = v;
      });
    }
  }

  String _show(BuildContext context, AppLocalizations l, CustomField f, String v) => fieldValueText(context, l, f, v);

  @override
  Widget build(BuildContext context) {
    if (_fields.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(l.customFieldsCard, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => FieldValuesPage(fields: widget.fields, scope: widget.scope, ownerId: widget.ownerId),
              )),
              child: Text(l.editValues),
            ),
          ]),
          for (final f in _fields)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 4, child: Text(f.name, style: TextStyle(color: p.text2))),
                Expanded(
                  flex: 5,
                  child: (_values[f.id] ?? '').isEmpty
                      ? Text(f.required ? l.fieldMissing : '—', style: TextStyle(color: f.required ? p.error : p.text2))
                      : Text(_show(context, l, f, _values[f.id]!)),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// The custom-field inputs of one contact or deal, without a page around them. [FieldInputsState.save]
/// writes the values for an owner (for a new record, after it has been created).
class FieldInputs extends StatefulWidget {
  const FieldInputs({super.key, required this.fields, required this.scope, this.ownerId, this.onLoaded, this.onChanged});
  final FieldsRepository fields;
  final FieldScope scope;
  final int? ownerId;
  final VoidCallback? onLoaded;
  final VoidCallback? onChanged;

  @override
  State<FieldInputs> createState() => FieldInputsState();
}

class FieldInputsState extends State<FieldInputs> {
  List<CustomField> _fields = const [];
  final _values = <int, String>{};
  final _controllers = <int, TextEditingController>{};
  bool loaded = false;

  bool get isEmpty => loaded && _fields.isEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _fields = await widget.fields.fields(widget.scope);
    if (widget.ownerId != null) _values.addAll(await widget.fields.values(widget.scope, widget.ownerId!));
    for (final f in _fields) {
      final t = fieldTypeFromName(f.type);
      if (t == FieldType.text || t == FieldType.number) {
        _controllers[f.id] = TextEditingController(text: _values[f.id] ?? '')..addListener(() => widget.onChanged?.call());
      }
    }
    loaded = true;
    if (mounted) setState(() {});
    widget.onLoaded?.call();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Everything typed so far, as one string (used to tell whether the form changed).
  String get signature => _fields.map((f) => '${f.id}=${_controllers[f.id]?.text ?? _values[f.id] ?? ''}').join('|');

  /// True when a required field is still empty.
  bool get missingRequired => _fields.any((f) => f.required && (_controllers[f.id]?.text ?? _values[f.id] ?? '').trim().isEmpty && fieldTypeFromName(f.type) != FieldType.bool);

  Future<void> save(int ownerId) async {
    if (!loaded || _fields.isEmpty) return;
    final out = <int, String>{};
    for (final f in _fields) {
      out[f.id] = _controllers[f.id]?.text ?? _values[f.id] ?? '';
    }
    await widget.fields.setValues(widget.scope, ownerId, out);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final f in _fields) ...[_input(l, f), const SizedBox(height: 12)],
    ]);
  }

  void _set(int id, String v) {
    setState(() => _values[id] = v);
    widget.onChanged?.call();
  }

  Widget _input(AppLocalizations l, CustomField f) {
    final label = f.required ? '${f.name} *' : f.name;
    switch (fieldTypeFromName(f.type)) {
      case FieldType.text:
        return GlassField(controller: _controllers[f.id]!, label: label);
      case FieldType.number:
        return GlassField(
          controller: _controllers[f.id]!,
          label: f.unit.isEmpty ? label : '$label (${f.unit})',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        );
      case FieldType.date:
        final d = DateTime.tryParse(_values[f.id] ?? '');
        return GlassSelectField(
          label: label,
          value: d == null ? ' ' : formatDay(context, d),
          onTap: () async {
            final r = await showDatePicker(context: context, initialDate: d ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100));
            if (r != null) _set(f.id, DateTime(r.year, r.month, r.day).toIso8601String());
          },
        );
      case FieldType.bool:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: _values[f.id] == '1',
          onChanged: (v) => _set(f.id, v ? '1' : '0'),
        );
      case FieldType.choice:
        final options = f.options.split('\n').where((o) => o.isNotEmpty).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in options)
              PillChip(
                label: o,
                selected: _values[f.id] == o,
                check: true,
                onTap: () => _set(f.id, _values[f.id] == o ? '' : o),
              ),
          ]),
        ]);
    }
  }
}

/// Edit all custom field values of one contact or deal.
class FieldValuesPage extends StatefulWidget {
  const FieldValuesPage({super.key, required this.fields, required this.scope, required this.ownerId});
  final FieldsRepository fields;
  final FieldScope scope;
  final int ownerId;

  @override
  State<FieldValuesPage> createState() => _FieldValuesPageState();
}

class _FieldValuesPageState extends State<FieldValuesPage> {
  final _inputs = GlobalKey<FieldInputsState>();
  bool _loaded = false;

  Future<void> _save() async {
    final nav = Navigator.of(context);
    await _inputs.currentState?.save(widget.ownerId);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(children: [
              GlassIconButton(icon: Icons.close, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              Expanded(child: Text(l.customFieldsCard, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: pal.onHeader))),
              SizedBox(width: 77.5, child: PillButton(label: l.save, height: 44, accent: true, onPressed: _loaded ? _save : null)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: [
              FieldInputs(
                key: _inputs,
                fields: widget.fields,
                scope: widget.scope,
                ownerId: widget.ownerId,
                onLoaded: () {
                  if (mounted) setState(() => _loaded = true);
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A stored custom field value as it is shown to the person (Yes/No, a date, a number with its unit).
String fieldValueText(BuildContext context, AppLocalizations l, CustomField f, String v) {
  switch (fieldTypeFromName(f.type)) {
    case FieldType.bool:
      return v == '1' ? l.yesLabel : l.noLabel;
    case FieldType.date:
      final d = DateTime.tryParse(v);
      return d == null ? v : formatDay(context, d);
    case FieldType.number:
      return f.unit.isEmpty ? v : '$v ${f.unit}';
    default:
      return v;
  }
}
