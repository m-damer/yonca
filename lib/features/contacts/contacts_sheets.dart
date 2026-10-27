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
    builder: (ctx) {
      final p = ctx.palette;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(l.sortTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          for (var i = 0; i < sortOptions.length; i++) ...[
            if (i > 0) Divider(height: 1, color: p.glassBorder),
            InkWell(
              onTap: () => Navigator.of(ctx).pop(sortOptions[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      sortLabel(l, sortOptions[i]),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: sortOptions[i] == current ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                  _Radio(selected: sortOptions[i] == current),
                ]),
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? p.primary : Colors.transparent,
        border: Border.all(color: selected ? p.primary : p.outline, width: 2),
      ),
      child: selected ? Icon(Icons.check, size: 17, color: p.onPrimary) : null,
    );
  }
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
              Row(children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4),
                    child: Text(l.filterTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  ),
                ),
                TextButton(
                  onPressed: () => set(const ContactFilters()),
                  child: Text(l.filterReset, style: TextStyle(color: p.primary, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ]),
              SectionLabel(l.filterRating, padding: const EdgeInsets.fromLTRB(4, 12, 4, 8)),
              Wrap(spacing: 8, runSpacing: 8, children: [
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
              SectionLabel(l.filterRole, padding: const EdgeInsets.fromLTRB(4, 16, 4, 8)),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in Role.values)
                  PillChip(
                    label: roleLabel(l, r),
                    selected: f.role == r,
                    check: true,
                    onTap: () => set(f.role == r ? f.copy(noRole: true) : f.copy(role: r)),
                  ),
              ]),
              if (tags.isNotEmpty) ...[
                SectionLabel(l.filterTag, padding: const EdgeInsets.fromLTRB(4, 16, 4, 8)),
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
                SectionLabel(l.filterStage, padding: const EdgeInsets.fromLTRB(4, 16, 4, 8)),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final st in stages)
                    PillChip(
                      label: stageLabel(l, st),
                      selected: f.stageId == st.id,
                      onTap: () => set(f.stageId == st.id ? f.copy(noStage: true) : f.copy(stageId: st.id)),
                    ),
                ]),
              ],
              SectionLabel(l.filterInactive, padding: const EdgeInsets.fromLTRB(4, 16, 4, 8)),
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
