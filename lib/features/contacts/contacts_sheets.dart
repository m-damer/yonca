import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../deals/deal_widgets.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';
import 'contact_widgets.dart';

/// The filters chosen in the filter sheet; null means "any".
class ContactFilters {
  const ContactFilters({this.rating, this.role, this.tagId, this.inactiveDays, this.stageId});
  final Rating? rating;
  final Role? role;
  final int? tagId;
  final int? inactiveDays;
  final int? stageId;

  bool get isActive => rating != null || role != null || tagId != null || inactiveDays != null || stageId != null;
  int get count => [rating, role, tagId, inactiveDays, stageId].where((e) => e != null).length;

  /// A copy with one filter replaced; pass the matching `no…` flag to clear it.
  ContactFilters copy({
    Rating? rating,
    Role? role,
    int? tagId,
    int? inactiveDays,
    int? stageId,
    bool noRating = false,
    bool noRole = false,
    bool noTag = false,
    bool noInactive = false,
    bool noStage = false,
  }) =>
      ContactFilters(
        rating: noRating ? null : (rating ?? this.rating),
        role: noRole ? null : (role ?? this.role),
        tagId: noTag ? null : (tagId ?? this.tagId),
        inactiveDays: noInactive ? null : (inactiveDays ?? this.inactiveDays),
        stageId: noStage ? null : (stageId ?? this.stageId),
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
  required Future<int> Function(ContactFilters) countFor,
}) {
  final l = AppLocalizations.of(context);
  var f = current;
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
                  onTap: () => set(const ContactFilters()),
                  child: Text(l.filterReset, style: TextStyle(color: p.primary, fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
              SectionLabel(l.filterRating, padding: const EdgeInsets.fromLTRB(0, 10, 0, 8)),
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
              SectionLabel(l.filterRole, padding: const EdgeInsets.fromLTRB(0, 14, 0, 8)),
              ChipRow(chips: [
                for (final r in Role.values)
                  PillChip(
                    label: roleLabel(l, r),
                    selected: f.role == r,
                    check: true,
                    onTap: () => set(f.role == r ? f.copy(noRole: true) : f.copy(role: r)),
                  ),
              ]),
              if (tags.isNotEmpty) ...[
                SectionLabel(l.filterTag, padding: const EdgeInsets.fromLTRB(0, 14, 0, 8)),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in tags)
                    PillChip(
                      label: t.name,
                      selected: f.tagId == t.id,
                      onTap: () => set(f.tagId == t.id ? f.copy(noTag: true) : f.copy(tagId: t.id)),
                    ),
                ]),
              ],
              if (stages.isNotEmpty) ...[
                SectionLabel(l.filterStage, padding: const EdgeInsets.fromLTRB(0, 14, 0, 8)),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final st in stages)
                    PillChip(
                      label: stageLabel(l, st),
                      selected: f.stageId == st.id,
                      onTap: () => set(f.stageId == st.id ? f.copy(noStage: true) : f.copy(stageId: st.id)),
                    ),
                ]),
              ],
              SectionLabel(l.filterInactive, padding: const EdgeInsets.fromLTRB(0, 14, 0, 8)),
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
              const SizedBox(height: 20),
              FutureBuilder<int>(
                key: ValueKey('${f.rating}${f.role}${f.tagId}${f.inactiveDays}${f.stageId}'),
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
