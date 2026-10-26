import 'package:flutter/material.dart';

import '../../core/text_normalize.dart';
import '../../data/app_database.dart';
import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'contact_details_page.dart';
import 'contact_row.dart';
import 'contact_widgets.dart';
import 'contacts_sheets.dart';

/// Contacts tab (design S05): title and menu, search, count line with filter and sort buttons,
/// one glass card of rows, and a letter rail when sorted by name.
class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key, required this.repo});
  final ContactsRepository? repo;

  @override
  State<ContactsTab> createState() => ContactsTabState();
}

class ContactsTabState extends State<ContactsTab> {
  String _query = '';
  ContactSort _sort = ContactSort.recentActivity;
  ContactFilters _filters = const ContactFilters();
  Stream<List<ContactSummary>>? _stream;
  List<Tag> _tags = const [];
  bool _arabic = false;
  int _lastCount = 0;

  void _rebuildStream() {
    final repo = widget.repo;
    if (repo == null) return;
    _stream = repo.watchList(
      query: _query,
      rating: _filters.rating,
      role: _filters.role,
      tagId: _filters.tagId,
      inactiveForDays: _filters.inactiveDays,
      sort: _sort,
      arabicFirst: _arabic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    if (_stream == null || ar != _arabic) {
      _arabic = ar;
      _rebuildStream();
    }
  }

  void _update(VoidCallback change) {
    setState(change);
    _rebuildStream();
  }

  Future<void> _openSort() async {
    final picked = await showSortSheet(context, _sort);
    if (picked != null) _update(() => _sort = picked);
  }

  Future<void> _openFilter() async {
    final repo = widget.repo;
    if (repo == null) return;
    final tags = await repo.allTags();
    if (!mounted) return;
    final result = await showFilterSheet(
      context,
      current: _filters,
      tags: tags,
      countFor: (f) async => (await repo.list(
        query: _query,
        rating: f.rating,
        role: f.role,
        tagId: f.tagId,
        inactiveForDays: f.inactiveDays,
      ))
          .length,
    );
    if (result != null) {
      _tags = tags;
      _update(() => _filters = result);
    }
  }

  void openContact(int id) {
    final repo = widget.repo;
    if (repo == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ContactDetailsPage(repo: repo, id: id)));
  }

  void _soon() {
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.comingLater)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    if (widget.repo == null) {
      return EmptyState(icon: Icons.storage_outlined, title: l.navContacts, body: l.noDatabase);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(children: [
            Expanded(
              child: Text(l.navContacts,
                  style: const TextStyle(fontSize: 30, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            ),
            PopupMenuButton<int>(
              color: p.sheet,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              onSelected: (_) => _soon(),
              itemBuilder: (_) => [
                for (final (i, e) in [
                  (Icons.qr_code_scanner, l.menuScanQr),
                  (Icons.download_outlined, l.menuImport),
                  (Icons.call_merge, l.menuDuplicates),
                  (Icons.check, l.menuSelect),
                ].indexed)
                  PopupMenuItem<int>(
                    value: i,
                    height: 48,
                    child: Row(children: [
                      Icon(e.$1, color: p.primary, size: 22),
                      const SizedBox(width: 14),
                      Text(e.$2, style: const TextStyle(fontSize: 16)),
                    ]),
                  ),
              ],
              child: const IgnorePointer(child: GlassIconButton(icon: Icons.more_vert, onTap: null)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: p.glass,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: p.glassBorder),
            ),
            child: Row(children: [
              Icon(Icons.search, color: p.text2),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  onChanged: (v) => _update(() => _query = v),
                  style: TextStyle(fontSize: 15, color: p.text),
                  cursorColor: p.primary,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: l.contactsSearchHint,
                    hintStyle: TextStyle(color: p.text2),
                  ),
                ),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(children: [
            Expanded(
              child: Text('${l.contactsCount(_lastCount)} · ${sortLabel(l, _sort)}',
                  style: TextStyle(fontSize: 13, color: p.text2)),
            ),
            GlassIconButton(
              icon: Icons.filter_alt_outlined,
              tooltip: l.filterTitle,
              size: 40,
              radius: 14,
              filled: _filters.isActive,
              onTap: _openFilter,
            ),
            const SizedBox(width: 8),
            GlassIconButton(
              icon: Icons.swap_vert,
              tooltip: l.sortTitle,
              size: 40,
              radius: 14,
              onTap: _openSort,
            ),
          ]),
        ),
        if (_filters.isActive) _activeFilters(l),
        Expanded(
          child: StreamBuilder<List<ContactSummary>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) return ErrorView(onRetry: () => _update(() {}));
              if (!snap.hasData) return const LoadingView();
              final items = snap.data!;
              if (items.length != _lastCount) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _lastCount != items.length) setState(() => _lastCount = items.length);
                });
              }
              if (items.isEmpty) {
                final none = _query.isEmpty && !_filters.isActive;
                return EmptyState(
                  icon: Icons.people_outline,
                  title: none ? l.contactsEmptyTitle : l.contactsNoMatch,
                  body: none ? l.contactsEmptyBody : null,
                );
              }
              return _ContactList(items: items, grouped: _sort == ContactSort.name, onOpen: openContact);
            },
          ),
        ),
      ],
    );
  }

  Widget _activeFilters(AppLocalizations l) {
    final p = context.palette;
    final chips = <Widget>[];
    if (_filters.rating != null) {
      chips.add(PillChip(
        label: ratingLabel(l, _filters.rating!),
        icon: ratingIcon(_filters.rating!),
        selected: true,
        onRemove: () => _update(() => _filters =
            ContactFilters(role: _filters.role, tagId: _filters.tagId, inactiveDays: _filters.inactiveDays)),
      ));
    }
    if (_filters.role != null) {
      chips.add(PillChip(
        label: roleLabel(l, _filters.role!),
        selected: true,
        onRemove: () => _update(() => _filters =
            ContactFilters(rating: _filters.rating, tagId: _filters.tagId, inactiveDays: _filters.inactiveDays)),
      ));
    }
    if (_filters.tagId != null) {
      final name = _tags.where((t) => t.id == _filters.tagId).map((t) => t.name).firstOrNull ?? l.filterTag;
      chips.add(PillChip(
        label: name,
        selected: true,
        onRemove: () => _update(() => _filters =
            ContactFilters(rating: _filters.rating, role: _filters.role, inactiveDays: _filters.inactiveDays)),
      ));
    }
    if (_filters.inactiveDays != null) {
      chips.add(PillChip(
        label: l.filterDays(_filters.inactiveDays!),
        selected: true,
        onRemove: () =>
            _update(() => _filters = ContactFilters(rating: _filters.rating, role: _filters.role, tagId: _filters.tagId)),
      ));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 20, 12),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [for (final c in chips) Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: c)],
            ),
          ),
        ),
        TextButton(
          onPressed: () => _update(() => _filters = const ContactFilters()),
          child: Text(l.filterClearAll, style: TextStyle(color: p.primary, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

/// The glass card of rows, with letter headers and a side letter rail when [grouped].
class _ContactList extends StatefulWidget {
  const _ContactList({required this.items, required this.grouped, required this.onOpen});
  final List<ContactSummary> items;
  final bool grouped;
  final void Function(int id) onOpen;

  @override
  State<_ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<_ContactList> {
  final _keys = <String, GlobalKey>{};
  String? _selected;

  void _jump(String section) {
    final ctx = _keys[section]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: Duration.zero, alignment: 0);
    if (_selected != section) setState(() => _selected = section);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final children = <Widget>[];
    final sections = <String>[];
    String? last;
    var firstInGroup = true;
    for (final s in widget.items) {
      if (widget.grouped) {
        final sec = sectionOf(s.contact.sortKey);
        if (sec != last) {
          last = sec;
          sections.add(sec);
          firstInGroup = true;
          children.add(Padding(
            key: _keys.putIfAbsent(sec, GlobalKey.new),
            padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
            child: Text(sec, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.primary)),
          ));
        }
      }
      if (!firstInGroup) children.add(Divider(height: 1, thickness: 1, color: p.glassBorder));
      firstInGroup = false;
      children.add(ContactRow(summary: s, onTap: () => widget.onOpen(s.contact.id)));
    }
    final showRail = widget.grouped && sections.length > 1;
    final selected = _selected != null && sections.contains(_selected) ? _selected! : (sections.isEmpty ? '' : sections.first);
    return Stack(
      children: [
        ListView(
          padding: EdgeInsetsDirectional.fromSTEB(16, 0, showRail ? 36 : 16, 120),
          children: [
            GlassCard(padding: EdgeInsets.zero, child: Column(children: children)),
          ],
        ),
        if (showRail)
          PositionedDirectional(
            end: 6,
            top: 0,
            bottom: 120,
            child: Center(
              child: LayoutBuilder(
                builder: (context, box) {
                  const itemH = 18.0;
                  final h = sections.length * itemH;
                  void pick(double dy) {
                    final i = (dy / itemH).floor().clamp(0, sections.length - 1);
                    _jump(sections[i]);
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => pick(d.localPosition.dy),
                    onVerticalDragUpdate: (d) => pick(d.localPosition.dy),
                    child: SizedBox(
                      width: 24,
                      height: h > box.maxHeight ? box.maxHeight : h,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(children: [
                          for (final sec in sections)
                            Container(
                              width: 18,
                              height: itemH,
                              alignment: Alignment.center,
                              decoration: sec == selected
                                  ? BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(9))
                                  : null,
                              child: Text(
                                sec,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: sec == selected ? p.onPrimary : p.primary,
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
