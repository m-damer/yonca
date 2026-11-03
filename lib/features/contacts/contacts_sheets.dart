import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../deals/deal_widgets.dart';
import '../fields/field_filter.dart';
import '../../domain/field_models.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/multi_select.dart';
import '../../theme/palette.dart';
import 'contact_widgets.dart';
import '../../theme/tokens.dart';

/// The filters chosen in the filter sheet; null means "any".
class ContactFilters {
  const ContactFilters({this.rating, this.role, this.tagIds = const {}, this.inactiveDays, this.stageId, this.field});
  final Rating? rating;

  /// One custom-field condition (the field equals a value).
  final FieldFilter? field;
  final Role? role;
  final Set<int> tagIds;
  final int? inactiveDays;
  final int? stageId;

  bool get isActive => rating != null || role != null || tagIds.isNotEmpty || inactiveDays != null || stageId != null || field != null;
  int get count => [rating, role, inactiveDays, stageId, field].where((e) => e != null).length + tagIds.length;

  /// A copy with one filter replaced; pass the matching `no…` flag to clear it.
  ContactFilters copy({
    Rating? rating,
    Role? role,
    Set<int>? tagIds,
    int? inactiveDays,
    int? stageId,
    bool noRating = false,
    bool noRole = false,
    bool noInactive = false,
    bool noStage = false,
    FieldFilter? field,
    bool noField = false,
  }) =>
      ContactFilters(
        rating: noRating ? null : (rating ?? this.rating),
        role: noRole ? null : (role ?? this.role),
        tagIds: tagIds ?? this.tagIds,
        inactiveDays: noInactive ? null : (inactiveDays ?? this.inactiveDays),
        stageId: noStage ? null : (stageId ?? this.stageId),
        field: noField ? null : (field ?? this.field),
      );
}

/// Sort options in the order the design lists them.
const sortOptions = [
  ContactSort.recentActivity,
  ContactSort.name,
  ContactSort.recentlyAdded,
  ContactSort.ratingHot,
  ContactSort.longestIdle,
];

String sortLabel(AppLocalizations l, ContactSort s) => switch (s) {
      ContactSort.recentActivity => l.sortRecentActivity,
      ContactSort.name => l.sortName,
      ContactSort.recentlyAdded => l.sortRecentlyAdded,
      ContactSort.ratingHot => l.sortRatingHot,
      ContactSort.longestIdle || ContactSort.needsAttention => l.sortLongestIdle,
    };

Future<ContactSort?> showSortSheet(BuildContext context, ContactSort current) {
  final l = AppLocalizations.of(context);
  return showGlassSheet<ContactSort>(
    context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(l.sortTitle),
        for (var i = 0; i < sortOptions.length; i++)
          SheetItem(
            first: i == 0,
            title: sortLabel(l, sortOptions[i]),
            bold: sortOptions[i] == current,
            selected: sortOptions[i] == current,
            onTap: () => Navigator.of(ctx).pop(sortOptions[i]),
          ),
      ],
    ),
  );
}

/// Filter sheet. [countFor] gives the live "Show N contacts" number for the chosen filters.
Future<ContactFilters?> showFilterSheet(
  BuildContext context, {
  required ContactFilters current,
  required List<Tag> tags,
  List<DealStage> stages = const [],
  List<CustomField> fields = const [],
  required Future<int> Function(ContactFilters) countFor,
}) {
  final l = AppLocalizations.of(context);
  var f = current;
  CustomField? sel;
  for (final x in fields) {
    if (x.id == current.field?.fieldId) sel = x;
  }
  final valueCtl = TextEditingController(text: current.field != null && sel != null && fieldTypeFromName(sel.type) != FieldType.bool && fieldTypeFromName(sel.type) != FieldType.choice ? current.field!.value : '');
  return showGlassSheet<ContactFilters>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final p = ctx.palette;
        void set(ContactFilters n) => setSheet(() => f = n);
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitle(
                l.filterTitle,
                trailing: InkWell(
                  onTap: () {
                    valueCtl.clear();
                    setSheet(() {
                      sel = null;
                      f = const ContactFilters();
                    });
                  },
                  child: Text(l.filterReset, style: TextStyle(color: p.primary, fontWeight: FontWeight.w600, fontSize: AppFont.body)),
                ),
              ),
              SectionLabel(l.filterRating, padding: const EdgeInsets.fromLTRB(0, AppSpace.md, 0, AppSpace.sm)),
              ChipRow(chips: [
                PillChip(
                  label: l.ratingAll,
                  selected: f.rating == null,
                  onTap: () => set(f.copy(noRating: true)),
                ),
                for (final r in const [Rating.hot, Rating.warm, Rating.cold])
                  PillChip(
                    label: ratingLabel(l, r),
                    icon: ratingIcon(r),
                    selected: f.rating == r,
                    onTap: () => set(f.copy(rating: r)),
                  ),
              ]),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: AppSpace.lg),
                DropdownBox(
                  label: l.filterTag,
                  text: f.tagIds.isEmpty ? l.msSelectValues : l.msNValues(f.tagIds.length),
                  placeholder: f.tagIds.isEmpty,
                  onTap: () async {
                    final r = await showSearchableSelect(
                      ctx,
                      title: l.filterTag,
                      options: [for (final t in tags) PickOption(t.id, t.name)],
                      selected: {...f.tagIds},
                    );
                    if (r != null) set(f.copy(tagIds: r.whereType<int>().toSet()));
                  },
                ),
                if (f.tagIds.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.md),
                  ChipsScrollRow(chips: [
                    for (final t in tags)
                      if (f.tagIds.contains(t.id))
                        PillChip(label: t.name, selected: true, dense: true, onRemove: () => set(f.copy(tagIds: {...f.tagIds}..remove(t.id)))),
                  ]),
                ],
              ],
              if (stages.isNotEmpty) ...[
                SectionLabel(l.filterStage, padding: const EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.sm)),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final st in stages)
                    PillChip(
                      label: stageLabel(l, st),
                      selected: f.stageId == st.id,
                      onTap: () => set(f.stageId == st.id ? f.copy(noStage: true) : f.copy(stageId: st.id)),
                    ),
                ]),
              ],
              SectionLabel(l.filterInactive, padding: const EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.sm)),
              Wrap(spacing: 8, runSpacing: 8, children: [
                PillChip(
                  label: l.filterAny,
                  selected: f.inactiveDays == null,
                  onTap: () => set(f.copy(noInactive: true)),
                ),
                for (final d in const [7, 14, 30])
                  PillChip(
                    label: l.filterDays(d),
                    selected: f.inactiveDays == d,
                    onTap: () => set(f.copy(inactiveDays: d)),
                  ),
              ]),
              if (fields.isNotEmpty) ...[
                const SizedBox(height: AppSpace.lg),
                DropdownBox(
                  label: l.filterByField,
                  text: sel?.name ?? l.filterFieldPick,
                  placeholder: sel == null,
                  onTap: () async {
                    final r = await showSearchableSelect(
                      ctx,
                      title: l.filterFieldPick,
                      options: [for (final x in fields) PickOption(x.id, x.name)],
                      selected: {if (sel != null) sel!.id},
                      multi: false,
                    );
                    if (r == null) return;
                    valueCtl.clear();
                    setSheet(() {
                      sel = r.isEmpty ? null : fields.firstWhere((x) => x.id == r.first);
                      f = f.copy(noField: true);
                    });
                  },
                ),
                if (sel != null) ...[
                  const SizedBox(height: AppSpace.md),
                  Builder(builder: (_) {
                    final x = sel!;
                    final type = fieldTypeFromName(x.type);
                    FieldFilter mk(String v, String label) => FieldFilter(fieldId: x.id, name: x.name, value: v, label: label);
                    if (type == FieldType.bool || type == FieldType.choice) {
                      final opts = type == FieldType.bool
                          ? [('1', l.yesLabel), ('0', l.noLabel)]
                          : [for (final o in x.options.split('\n').where((e) => e.trim().isNotEmpty)) (o, o)];
                      return Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                        PillChip(label: l.ratingAll, selected: f.field == null, onTap: () => set(f.copy(noField: true))),
                        for (final o in opts) PillChip(label: o.$2, selected: f.field?.value == o.$1, onTap: () => set(f.copy(field: mk(o.$1, o.$2)))),
                      ]);
                    }
                    return GlassField(
                      controller: valueCtl,
                      label: l.filterFieldValue,
                      onChanged: (t) {
                        final v = t.trim();
                        set(v.isEmpty ? f.copy(noField: true) : f.copy(field: mk(v, v)));
                      },
                    );
                  }),
                ],
              ],
              const SizedBox(height: AppSpace.xl),
              FutureBuilder<int>(
                key: ValueKey('${f.rating}${f.role}${f.tagIds.join(',')}${f.inactiveDays}${f.stageId}${f.field?.fieldId}${f.field?.value}'),
                future: countFor(f),
                builder: (ctx, snap) => PillButton(
                  label: l.filterShow(snap.data ?? 0),
                  onPressed: () => Navigator.of(ctx).pop(f),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// What the bulk edit sheet hands back; empty groups stay as they are.
class BulkEditChoice {
  const BulkEditChoice({this.tag, this.role, this.rating});
  final String? tag;
  final Role? role;
  final Rating? rating;
  bool get isEmpty => tag == null && role == null && rating == null;
}

/// Bulk edit sheet (design CD8): pick a tag, a role and a rating to apply to the selected contacts.
Future<BulkEditChoice?> showBulkEditSheet(BuildContext context, {required int count, required List<Tag> tags}) {
  final l = AppLocalizations.of(context);
  String? tag;
  Role? role;
  Rating? rating;
  return showGlassSheet<BulkEditChoice>(
    context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final p = ctx.palette;
      return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.bulkTitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, 0),
            child: Text(l.bulkSub(count), style: TextStyle(fontSize: AppFont.body, height: AppLine.loose, color: p.text2)),
          ),
          if (tags.isNotEmpty) ...[
            SectionLabel(l.bulkTag, padding: const EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.sm)),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in tags) PillChip(label: t.name, selected: tag == t.name, onTap: () => setS(() => tag = tag == t.name ? null : t.name)),
            ]),
          ],
          SectionLabel(l.filterRole, padding: const EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.sm)),
          ChipRow(chips: [
            for (final r in Role.values) PillChip(label: roleLabel(l, r), selected: role == r, onTap: () => setS(() => role = role == r ? null : r)),
          ]),
          SectionLabel(l.filterRating, padding: const EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.sm)),
          ChipRow(chips: [
            for (final r in const [Rating.hot, Rating.warm, Rating.cold])
              PillChip(label: ratingLabel(l, r), icon: ratingIcon(r), selected: rating == r, onTap: () => setS(() => rating = rating == r ? null : r)),
          ]),
          const SizedBox(height: AppSpace.lg),
          SheetButtons(
            secondary: l.cancel,
            onSecondary: () => Navigator.of(ctx).pop(),
            primary: l.bulkReview,
            onPrimary: (tag == null && role == null && rating == null) ? null : () => Navigator.of(ctx).pop(BulkEditChoice(tag: tag, role: role, rating: rating)),
          ),
        ]),
      );
    }),
  );
}
