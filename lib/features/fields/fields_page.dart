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
              GlassField(controller: name, maxLength: 30, label: l.fieldNameLabel),
              const SizedBox(height: 16),
              Text(l.fieldTypeLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in FieldType.values)
                  PillChip(label: fieldTypeLabel(l, t), selected: type == t, onTap: () => setS(() => type = t)),
              ]),
              if (type == FieldType.number) ...[const SizedBox(height: 12), GlassField(controller: unit, label: l.fieldUnit)],
              if (type == FieldType.choice)
                ...[const SizedBox(height: 12), GlassField(controller: options, maxLines: 5, label: l.fieldOptions)],
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.fieldRequired), value: required, onChanged: (v) => setS(() => required = v)),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.fieldShowInReports), value: reports, onChanged: (v) => setS(() => reports = v)),
            ]),
          ),
          actions: [
            if (field != null)
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop(false);
                  await widget.fields.archive(field.id, !field.archived);
                  await _reload();
                },
                child: Text(field.archived ? l.restoreField : l.archiveField),
              ),
            if (field != null)
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop(false);
                  _delete(field);
                },
                child: Text(l.delete, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ),
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
    Widget dots() => SizedBox(
          width: 11,
          height: 15,
          child: Wrap(spacing: 3, runSpacing: 3, children: [
            for (var i = 0; i < 6; i++) Container(width: 4, height: 4, decoration: BoxDecoration(color: const Color(0xFFC7C7CC), borderRadius: BorderRadius.circular(2))),
          ]),
        );
    Widget tile(CustomField f, {int? index}) => Material(
          key: ValueKey(f.id),
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _edit(scope, field: f),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              child: Row(children: [
                index == null ? dots() : ReorderableDragStartListener(index: index, child: dots()),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.name, style: TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w500, decoration: f.archived ? TextDecoration.lineThrough : null)),
                    Text([fieldTypeLabel(l, fieldTypeFromName(f.type)), f.required ? l.fieldRequired : l.fieldOptional].join(' · '),
                        style: TextStyle(fontSize: 13, height: 18.2 / 13, color: pal.text2)),
                  ]),
                ),
                Icon(Icons.chevron_right, size: 22, color: pal.text),
              ]),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(children: [
          Expanded(child: SectionLabel(title)),
          Text(l.targetOf('${active.length}', '$maxFieldsPerScope'), style: TextStyle(fontSize: 13, height: 18.2 / 13, color: pal.text2)),
        ]),
      ),
      if (active.isEmpty)
        Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(l.noCustomFields, style: TextStyle(color: pal.text2)))
      else
        GlassCard(
          padding: EdgeInsets.zero,
          child: ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (from, to) async {
              final ids = [for (final f in active) f.id];
              if (to > from) to -= 1;
              ids.insert(to, ids.removeAt(from));
              await widget.fields.reorder(ids);
              await _reload();
            },
            children: [for (var i = 0; i < active.length; i++) tile(active[i], index: i)],
          ),
        ),
      const SizedBox(height: 10),
      PillButton(label: l.newField, icon: Icons.add, outlined: true, height: 48, onPressed: () => _edit(scope)),
      if (archived.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 8), child: Text(l.archivedFields, style: TextStyle(color: pal.text2))),
        GlassCard(padding: EdgeInsets.zero, child: Column(children: [for (final f in archived) tile(f)])),
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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(children: [
              GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              Expanded(child: Text(l.customFieldsTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: pal.onHeader))),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
              _section(l, pal, FieldScope.contact, l.contactFieldsSection),
              _section(l, pal, FieldScope.deal, l.dealFieldsSection),
            ]),
          ),
        ]),
      ),
    );
  }
}
