import 'package:flutter/material.dart';

import '../../core/text_normalize.dart';
import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'contact_details_page.dart';
import 'contact_row.dart';
import 'contact_widgets.dart';

/// Contacts tab: search, rating tabs with counts, sort and filter sheets, and the list.
class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key, required this.repo});
  final ContactsRepository? repo;

  @override
  State<ContactsTab> createState() => ContactsTabState();
}

class ContactsTabState extends State<ContactsTab> {
  String _query = '';
  Rating? _rating; // null = All
  ContactSort _sort = ContactSort.recentActivity;
  Role? _role;
  int? _inactive;
  Stream<List<ContactSummary>>? _stream;
  Stream<List<ContactSummary>>? _allStream;
  bool _arabic = false;

  void _rebuildStreams() {
    final repo = widget.repo;
    if (repo == null) return;
    _stream = repo.watchList(
      query: _query,
      rating: _rating,
      role: _role,
      inactiveForDays: _inactive,
      sort: _sort,
      arabicFirst: _arabic,
    );
    _allStream ??= repo.watchList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    if (_stream == null || ar != _arabic) {
      _arabic = ar;
      _rebuildStreams();
    }
  }

  void _update(VoidCallback change) {
    setState(change);
    _rebuildStreams();
  }

  Future<void> _openSort() async {
    final l = AppLocalizations.of(context);
    final labels = {
      ContactSort.name: l.sortName,
      ContactSort.recentlyAdded: l.sortRecentlyAdded,
      ContactSort.recentActivity: l.sortRecentActivity,
      ContactSort.needsAttention: l.sortNeedsAttention,
    };
    final picked = await showModalBottomSheet<ContactSort>(
      context: context,
      backgroundColor: context.palette.sheet,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(l.sortTitle, style: Theme.of(ctx).textTheme.titleLarge),
              ),
            ),
            for (final e in labels.entries)
              ListTile(
                title: Text(e.value),
                trailing: e.key == _sort ? Icon(Icons.check, color: ctx.palette.primary) : null,
                onTap: () => Navigator.of(ctx).pop(e.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) _update(() => _sort = picked);
  }

  Future<void> _openFilter() async {
    final l = AppLocalizations.of(context);
    Role? role = _role;
    int? inactive = _inactive;
    final result = await showModalBottomSheet<({Role? role, int? inactive})>(
      context: context,
      backgroundColor: context.palette.sheet,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.filterTitle, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                Text(l.filterRole, style: TextStyle(color: ctx.palette.text2)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final r in Role.values)
                    FilterChip(
                      label: Text(roleLabel(l, r)),
                      selected: role == r,
                      onSelected: (v) => setSheet(() => role = v ? r : null),
                    ),
                ]),
                const SizedBox(height: 16),
                Text(l.filterInactive, style: TextStyle(color: ctx.palette.text2)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final d in const [7, 14, 30])
                    FilterChip(
                      label: Text(l.filterDays(d)),
                      selected: inactive == d,
                      onSelected: (v) => setSheet(() => inactive = v ? d : null),
                    ),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop((role: null, inactive: null)),
                    child: Text(l.filterClear),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop((role: role, inactive: inactive)),
                    child: Text(l.filterApply),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) {
      _update(() {
        _role = result.role;
        _inactive = result.inactive;
      });
    }
  }

  void openContact(int id) {
    final repo = widget.repo;
    if (repo == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ContactDetailsPage(repo: repo, id: id)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    if (widget.repo == null) {
      return EmptyState(icon: Icons.storage_outlined, title: l.navContacts, body: l.noDatabase);
    }
    final filtersOn = _role != null || _inactive != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => _update(() => _query = v),
                  decoration: InputDecoration(
                    hintText: l.contactsSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: p.glass,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                  ),
                ),
              ),
              IconButton(
                tooltip: l.filterTitle,
                onPressed: _openFilter,
                icon: Icon(filtersOn ? Icons.filter_alt : Icons.filter_alt_outlined,
                    color: filtersOn ? p.primary : null),
              ),
              IconButton(tooltip: l.sortTitle, onPressed: _openSort, icon: const Icon(Icons.sort)),
            ],
          ),
        ),
        StreamBuilder<List<ContactSummary>>(
          stream: _allStream,
          builder: (context, snap) {
            final all = snap.data ?? const <ContactSummary>[];
            int count(Rating? r) =>
                r == null ? all.length : all.where((s) => ratingFromName(s.contact.rating) == r).length;
            return SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final r in <Rating?>[null, Rating.hot, Rating.warm, Rating.cold])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: ChoiceChip(
                        label: Text('${r == null ? l.ratingAll : ratingLabel(l, r)} ${count(r)}'),
                        selected: _rating == r,
                        onSelected: (_) => _update(() => _rating = r),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        Expanded(
          child: StreamBuilder<List<ContactSummary>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) return ErrorView(onRetry: () => _update(() {}));
              if (!snap.hasData) return const LoadingView();
              final items = snap.data!;
              if (items.isEmpty) {
                final none = _query.isEmpty && _rating == null && !filtersOn;
                return EmptyState(
                  icon: Icons.people_outline,
                  title: none ? l.contactsEmptyTitle : l.contactsNoMatch,
                  body: none ? l.contactsEmptyBody : null,
                );
              }
              return _ContactList(
                items: items,
                grouped: _sort == ContactSort.name,
                showRating: _rating == null,
                onOpen: openContact,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One scroll entry: a letter header or a contact row.
class _Entry {
  const _Entry.header(this.section) : summary = null;
  const _Entry.row(this.summary) : section = null;
  final String? section;
  final ContactSummary? summary;
}

const _headerExtent = 36.0;
const _rowExtent = 76.0;

/// The list, with letter headers and a side letter rail when [grouped] (sorted by name).
class _ContactList extends StatefulWidget {
  const _ContactList({required this.items, required this.grouped, required this.showRating, required this.onOpen});
  final List<ContactSummary> items;
  final bool grouped;
  final bool showRating;
  final void Function(int id) onOpen;

  @override
  State<_ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<_ContactList> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Entry> _entries() {
    if (!widget.grouped) return [for (final s in widget.items) _Entry.row(s)];
    final out = <_Entry>[];
    String? last;
    for (final s in widget.items) {
      final sec = sectionOf(s.contact.sortKey);
      if (sec != last) {
        out.add(_Entry.header(sec));
        last = sec;
      }
      out.add(_Entry.row(s));
    }
    return out;
  }

  void _jumpTo(List<_Entry> entries, String section) {
    var offset = 0.0;
    for (final e in entries) {
      if (e.section == section) break;
      offset += e.section != null ? _headerExtent : _rowExtent;
    }
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    _controller.jumpTo(offset.clamp(0.0, max));
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    final sections = [for (final e in entries) if (e.section != null) e.section!];
    final p = context.palette;
    final list = ListView.builder(
      controller: _controller,
      padding: EdgeInsets.fromLTRB(12, 4, widget.grouped ? 28 : 12, 120),
      itemCount: entries.length,
      itemExtentBuilder: (i, _) => entries[i].section != null ? _headerExtent : _rowExtent,
      itemBuilder: (context, i) {
        final e = entries[i];
        if (e.section != null) {
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Text(e.section!, style: TextStyle(color: p.primary, fontWeight: FontWeight.w700)),
            ),
          );
        }
        final s = e.summary!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: ContactRow(
              summary: s,
              showRating: widget.showRating,
              onTap: () => widget.onOpen(s.contact.id),
            ),
          ),
        );
      },
    );
    if (!widget.grouped || sections.length < 2) return list;
    return Stack(
      children: [
        list,
        PositionedDirectional(
          end: 2,
          top: 8,
          bottom: 120,
          child: LayoutBuilder(
            builder: (context, box) {
              void pick(double dy) {
                final i = (dy / box.maxHeight * sections.length).floor().clamp(0, sections.length - 1);
                _jumpTo(entries, sections[i]);
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => pick(d.localPosition.dy),
                onVerticalDragUpdate: (d) => pick(d.localPosition.dy),
                child: SizedBox(
                  width: 24,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final sec in sections)
                        Text(sec, style: TextStyle(fontSize: 10, color: p.text2, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
