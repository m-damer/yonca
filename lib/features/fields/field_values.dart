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

  String _show(BuildContext context, AppLocalizations l, CustomField f, String v) {
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
  List<CustomField> _fields = const [];
  final _values = <int, String>{};
  final _controllers = <int, TextEditingController>{};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _fields = await widget.fields.fields(widget.scope);
    _values.addAll(await widget.fields.values(widget.scope, widget.ownerId));
    for (final f in _fields) {
      final t = fieldTypeFromName(f.type);
      if (t == FieldType.text || t == FieldType.number) _controllers[f.id] = TextEditingController(text: _values[f.id] ?? '');
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    final out = <int, String>{};
    for (final f in _fields) {
      out[f.id] = _controllers[f.id]?.text ?? _values[f.id] ?? '';
    }
    await widget.fields.setValues(widget.scope, widget.ownerId, out);
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(children: [
              GlassIconButton(icon: Icons.close, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 14),
              Expanded(child: Text(l.customFieldsCard, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: pal.onHeader))),
              SizedBox(width: 88, child: PillButton(label: l.save, height: 44, accent: true, onPressed: _loaded ? _save : null)),
            ]),
          ),
          Expanded(
            child: !_loaded
                ? const SizedBox.shrink()
                : ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: [
                    for (final f in _fields) ...[_input(l, f), const SizedBox(height: 12)],
                  ]),
          ),
        ]),
      ),
    );
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
            if (r != null) setState(() => _values[f.id] = DateTime(r.year, r.month, r.day).toIso8601String());
          },
        );
      case FieldType.bool:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: _values[f.id] == '1',
          onChanged: (v) => setState(() => _values[f.id] = v ? '1' : '0'),
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
                onTap: () => setState(() => _values[f.id] = _values[f.id] == o ? '' : o),
              ),
          ]),
        ]);
    }
  }
}
