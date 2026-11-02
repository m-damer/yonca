import 'package:flutter/material.dart';

import '../../shared/ds.dart';

import '../../data/app_database.dart';
import '../../data/fields_repository.dart';
import '../../domain/field_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'field_labels.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

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
              const SizedBox(height: AppSpace.lg),
              Text(l.fieldTypeLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpace.sm),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in FieldType.values)
                  PillChip(label: fieldTypeLabel(l, t), selected: type == t, onTap: () => setS(() => type = t)),
              ]),
              if (type == FieldType.number) ...[const SizedBox(height: AppSpace.md), GlassField(controller: unit, label: l.fieldUnit)],
              if (type == FieldType.choice)
                ...[const SizedBox(height: AppSpace.md), GlassField(controller: options, maxLines: 5, label: l.fieldOptions)],
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
            DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
            DialogConfirm(l.save, onPressed: () => Navigator.of(ctx).pop(true)),
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
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.delete, onPressed: () => Navigator.of(ctx).pop(true), danger: true),
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
    Widget tile(CustomField f, {int? index}) => Material(
          key: ValueKey(f.id),
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _edit(scope, field: f),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
              child: Row(children: [
                index == null ? const DragDots() : DragHandle(index: index),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.name, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, fontWeight: FontWeight.w500, decoration: f.archived ? TextDecoration.lineThrough : null)),
                    Text([fieldTypeLabel(l, fieldTypeFromName(f.type)), f.required ? l.fieldRequired : l.fieldOptional].join(' · '),
                        style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: pal.text2)),
                  ]),
                ),
                Icon(Lu.chevronRight, size: AppIcon.lg, color: pal.text),
              ]),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(right: AppSpace.xs),
        child: Row(children: [
          Expanded(child: SectionLabel(title)),
          Text(l.targetOf('${active.length}', '$maxFieldsPerScope'), style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: pal.text2)),
        ]),
      ),
      if (active.isEmpty)
        Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.sm), child: Text(l.noCustomFields, style: TextStyle(color: pal.text2)))
      else
        GlassCard(
          padding: EdgeInsets.zero,
          child: ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorderItem: (from, to) async {
              final ids = [for (final f in active) f.id];
              ids.insert(to, ids.removeAt(from));
              await widget.fields.reorder(ids);
              await _reload();
            },
            children: [for (var i = 0; i < active.length; i++) tile(active[i], index: i)],
          ),
        ),
      const SizedBox(height: AppSpace.md),
      PillButton(label: l.newField, icon: Lu.plus, outlined: true, height: AppControl.lg, onPressed: () => _edit(scope)),
      if (archived.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.md, AppSpace.xs, AppSpace.sm), child: Text(l.archivedFields, style: TextStyle(color: pal.text2))),
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
          PageHeader(title: l.customFieldsTitle),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.x5), children: [
              _section(l, pal, FieldScope.contact, l.contactFieldsSection),
              _section(l, pal, FieldScope.deal, l.dealFieldsSection),
            ]),
          ),
        ]),
      ),
    );
  }
}
