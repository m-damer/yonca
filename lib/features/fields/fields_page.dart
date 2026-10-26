import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/fields_repository.dart';
import '../../domain/field_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'field_labels.dart';

/// Custom fields (design S28): contact fields and deal fields, add, edit, archive, delete.
class FieldsPage extends StatefulWidget {
  const FieldsPage({super.key, required this.fields});
  final FieldsRepository fields;

  @override
  State<FieldsPage> createState() => _FieldsPageState();
}

class _FieldsPageState extends State<FieldsPage> {
  Map<FieldScope, List<CustomField>> _all = const {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final r = {for (final s in FieldScope.values) s: await widget.fields.fields(s, includeArchived: true)};
    if (mounted) setState(() => _all = r);
  }

  Future<void> _edit(FieldScope scope, {CustomField? field}) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = TextEditingController(text: field?.name ?? '');
    final unit = TextEditingController(text: field?.unit ?? '');
    final options = TextEditingController(text: field?.options ?? '');
    var type = field == null ? FieldType.text : fieldTypeFromName(field.type);
    var required = field?.required ?? false;
    var reports = field?.showInReports ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(field == null ? l.newField : field.name),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: name, maxLength: 30, decoration: InputDecoration(labelText: l.fieldNameLabel)),
              const SizedBox(height: 8),
              Text(l.fieldTypeLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in FieldType.values)
                  PillChip(label: fieldTypeLabel(l, t), selected: type == t, onTap: () => setS(() => type = t)),
              ]),
              if (type == FieldType.number) TextField(controller: unit, decoration: InputDecoration(labelText: l.fieldUnit)),
              if (type == FieldType.choice)
                TextField(controller: options, maxLines: 5, decoration: InputDecoration(labelText: l.fieldOptions)),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.fieldRequired), value: required, onChanged: (v) => setS(() => required = v)),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.fieldShowInReports), value: reports, onChanged: (v) => setS(() => reports = v)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await widget.fields.save(
        FieldInput(
          scope: scope,
          name: name.text,
          type: type,
          unit: unit.text,
          options: options.text.split('\n'),
          required: required,
          showInReports: reports,
        ),
        id: field?.id,
      );
    } on FieldValidationException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(switch (e.problem) {
          'max' => l.fieldsMax,
          'type_locked' => l.fieldTypeLocked,
          'options' => l.errFieldOptions,
          _ => l.errFieldName,
        }),
      ));
    }
    await _reload();
  }

  Future<void> _delete(CustomField f) async {
    final l = AppLocalizations.of(context);
    final n = await widget.fields.usage(f.id);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteFieldTitle),
        content: Text(l.deleteFieldBody(n)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok == true) {
      await widget.fields.delete(f.id);
      await _reload();
    }
  }

  Widget _section(AppLocalizations l, YoncaPalette pal, FieldScope scope, String title) {
    final list = _all[scope] ?? const <CustomField>[];
    final active = [for (final f in list) if (!f.archived) f];
    final archived = [for (final f in list) if (f.archived) f];
    Widget tile(CustomField f) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                title: Text(f.name, style: TextStyle(decoration: f.archived ? TextDecoration.lineThrough : null)),
                subtitle: Text([fieldTypeLabel(l, fieldTypeFromName(f.type)), if (f.required) l.fieldRequired].join(' · ')),
                onTap: () => _edit(scope, field: f),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'archive') {
                      await widget.fields.archive(f.id, !f.archived);
                      await _reload();
                    } else {
                      await _delete(f);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'archive', child: Text(f.archived ? l.restoreField : l.archiveField)),
                    PopupMenuItem(value: 'delete', child: Text(l.delete)),
                  ],
                ),
              ),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: SectionLabel(title)),
        TextButton.icon(onPressed: () => _edit(scope), icon: const Icon(Icons.add), label: Text(l.newField)),
      ]),
      if (active.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.noCustomFields, style: TextStyle(color: pal.text2))),
      ...active.map(tile),
      if (archived.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 8), child: Text(l.archivedFields, style: TextStyle(color: pal.text2))),
        ...archived.map(tile),
      ],
    ]);
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(children: [
              GlassIconButton(icon: Icons.arrow_back, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 14),
              Expanded(child: Text(l.customFieldsTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: pal.onHeader))),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
              _section(l, pal, FieldScope.contact, l.contactFieldsSection),
              const SizedBox(height: 12),
              _section(l, pal, FieldScope.deal, l.dealFieldsSection),
            ]),
          ),
        ]),
      ),
    );
  }
}
