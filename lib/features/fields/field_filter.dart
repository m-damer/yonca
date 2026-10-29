import 'package:flutter/material.dart';

import '../../data/fields_repository.dart';
import '../../domain/field_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';

/// A chosen custom-field condition for the Contacts list: the field equals [value].
class FieldFilter {
  const FieldFilter({required this.fieldId, required this.name, required this.value, required this.label});
  final int fieldId;
  final String name;

  /// What is stored in the database ('1' / '0' for yes / no).
  final String value;

  /// What the person sees.
  final String label;
}

/// Asks for a contact field, then a value. Returns null when cancelled.
Future<FieldFilter?> pickFieldFilter(BuildContext context, FieldsRepository fields) async {
  final l = AppLocalizations.of(context);
  final list = await fields.fields(FieldScope.contact);
  if (!context.mounted) return null;
  final field = await showGlassSheet<dynamic>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(l.filterFieldPick, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      ),
      if (list.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(l.filterFieldNone, style: TextStyle(color: ctx.palette.text2))),
      for (final f in list)
        Material(
          type: MaterialType.transparency,
          child: ListTile(title: Text(f.name), onTap: () => Navigator.of(ctx).pop(f)),
        ),
    ]),
  );
  if (field == null || !context.mounted) return null;
  final type = fieldTypeFromName(field.type as String);
  final id = field.id as int;
  final name = field.name as String;
  if (type == FieldType.bool) {
    final yes = await showGlassSheet<bool>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Material(type: MaterialType.transparency, child: ListTile(title: Text(l.yesLabel), onTap: () => Navigator.of(ctx).pop(true))),
        Material(type: MaterialType.transparency, child: ListTile(title: Text(l.noLabel), onTap: () => Navigator.of(ctx).pop(false))),
      ]),
    );
    if (yes == null) return null;
    return FieldFilter(fieldId: id, name: name, value: yes ? '1' : '0', label: yes ? l.yesLabel : l.noLabel);
  }
  if (type == FieldType.choice) {
    final options = (field.options as String).split('\n').where((e) => e.trim().isNotEmpty).toList();
    final picked = await showGlassSheet<String>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final o in options)
          Material(type: MaterialType.transparency, child: ListTile(title: Text(o), onTap: () => Navigator.of(ctx).pop(o))),
      ]),
    );
    if (picked == null) return null;
    return FieldFilter(fieldId: id, name: name, value: picked, label: picked);
  }
  final controller = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(name),
      content: GlassField(controller: controller, autofocus: true, label: l.filterFieldValue),
      actions: [
        DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop()),
        DialogConfirm(l.filterFieldApply, onPressed: () => Navigator.of(ctx).pop(controller.text.trim())),
      ],
    ),
  );
  controller.dispose();
  if (text == null || text.isEmpty) return null;
  return FieldFilter(fieldId: id, name: name, value: text, label: text);
}
