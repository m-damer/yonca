import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../domain/field_models.dart';
import 'app_database.dart';

/// Custom fields for contacts and deals, and their values.
class FieldsRepository {
  FieldsRepository(this.db);
  final AppDatabase db;

  /// Goes up after every change.
  final ValueNotifier<int> revision = ValueNotifier(0);

  Future<List<CustomField>> fields(FieldScope scope, {bool includeArchived = false}) {
    final q = db.select(db.customFields)
      ..where((t) => t.scope.equals(scope.name))
      ..orderBy([(t) => OrderingTerm.asc(t.position), (t) => OrderingTerm.asc(t.id)]);
    if (!includeArchived) q.where((t) => t.archived.equals(false));
    return q.get();
  }

  Future<int> save(FieldInput input, {int? id}) async {
    if (input.problem() != null) throw FieldValidationException(input.problem()!);
    final options = input.options.map((e) => e.trim()).where((e) => e.isNotEmpty).join('\n');
    final fields = CustomFieldsCompanion(
      scope: Value(input.scope.name),
      name: Value(input.name.trim()),
      type: Value(input.type.name),
      unit: Value(input.type == FieldType.number ? input.unit.trim() : ''),
      options: Value(input.type == FieldType.choice ? options : ''),
      required: Value(input.required),
      showInReports: Value(input.showInReports),
    );
    final int out;
    if (id == null) {
      final all = await this.fields(input.scope, includeArchived: true);
      if (all.where((f) => !f.archived).length >= maxFieldsPerScope) throw const FieldValidationException('max');
      out = await db.into(db.customFields).insert(fields.copyWith(position: Value(all.length)));
    } else {
      // The type cannot change once the field holds data.
      final held = await (db.select(db.customFieldValues)..where((v) => v.fieldId.equals(id))).get();
      final cur = await (db.select(db.customFields)..where((t) => t.id.equals(id))).getSingle();
      if (held.isNotEmpty && cur.type != input.type.name) throw const FieldValidationException('type_locked');
      await (db.update(db.customFields)..where((t) => t.id.equals(id))).write(fields);
      out = id;
    }
    revision.value++;
    return out;
  }

  Future<void> archive(int id, bool archived) async {
    await (db.update(db.customFields)..where((t) => t.id.equals(id))).write(CustomFieldsCompanion(archived: Value(archived)));
    revision.value++;
  }

  /// Deletes the field with all its values.
  Future<void> delete(int id) async {
    await (db.delete(db.customFields)..where((t) => t.id.equals(id))).go();
    revision.value++;
  }

  Future<void> reorder(List<int> ids) async {
    for (var i = 0; i < ids.length; i++) {
      await (db.update(db.customFields)..where((t) => t.id.equals(ids[i]))).write(CustomFieldsCompanion(position: Value(i)));
    }
    revision.value++;
  }

  /// Values of one contact or deal, by field id.
  Future<Map<int, String>> values(FieldScope scope, int ownerId) async {
    final fs = await fields(scope, includeArchived: true);
    final rows = await (db.select(db.customFieldValues)
          ..where((v) => v.ownerId.equals(ownerId) & v.fieldId.isIn(fs.map((f) => f.id))))
        .get();
    return {for (final r in rows) r.fieldId: r.value};
  }

  /// Saves the values of one owner; empty text removes the value.
  Future<void> setValues(FieldScope scope, int ownerId, Map<int, String> values) async {
    await db.transaction(() async {
      for (final e in values.entries) {
        final v = e.value.trim();
        if (v.isEmpty) {
          await (db.delete(db.customFieldValues)..where((t) => t.fieldId.equals(e.key) & t.ownerId.equals(ownerId))).go();
        } else {
          await db.into(db.customFieldValues).insertOnConflictUpdate(
              CustomFieldValuesCompanion.insert(fieldId: e.key, ownerId: ownerId, value: Value(v)));
        }
      }
    });
    revision.value++;
  }

  /// Field names that are required but empty for this owner ("Missing" in the UI).
  Future<List<CustomField>> missingRequired(FieldScope scope, int ownerId) async {
    final fs = await fields(scope);
    final vals = await values(scope, ownerId);
    return [for (final f in fs) if (f.required && (vals[f.id] ?? '').isEmpty) f];
  }

  /// Contact or deal ids whose value for [fieldId] equals [value] (used as a filter).
  Future<Set<int>> ownersWith(int fieldId, String value) async {
    final rows = await (db.select(db.customFieldValues)..where((v) => v.fieldId.equals(fieldId) & v.value.equals(value))).get();
    return {for (final r in rows) r.ownerId};
  }

  /// Number of values stored for a field.
  Future<int> usage(int fieldId) async => (await (db.select(db.customFieldValues)..where((v) => v.fieldId.equals(fieldId))).get()).length;
}
