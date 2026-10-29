import 'contact_form_page.dart';
import 'contact_quick_actions.dart';
import '../fields/field_filter.dart';
import 'package:flutter/material.dart';

import '../../core/text_normalize.dart';
import '../../data/app_database.dart';
import '../deals/deal_widgets.dart';
import '../../data/activities_repository.dart';
import '../../data/schedule_repository.dart';
import '../../data/deals_repository.dart';
import '../../data/fields_repository.dart';
import '../sharing/share_helpers.dart';
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
  const ContactsTab({super.key, required this.repo, this.activities, this.schedule, this.deals, this.fields, this.navBar});
  final Widget Function(BuildContext context)? navBar;
  final ContactsRepository? repo;
  final ActivitiesRepository? activities;
  final ScheduleRepository? schedule;
  final DealsRepository? deals;
  final FieldsRepository? fields;

  @override
  State<ContactsTab> createState() => ContactsTabState();
}

class ContactsTabState extends State<ContactsTab> {
  String _query = '';
  ContactSort _sort = ContactSort.recentActivity;
  ContactFilters _filters = const ContactFilters();
  Map<int, DealStage> _stagesById = const {};
  FieldFilter? _fieldFilter;
  Set<int>? _fieldOwners;
  Stream<List<ContactSummary>>? _stream;
  List<Tag> _tags = const [];
  bool _arabic = false;
  int _lastCount = 0;
  final _picked = <int>{};
  List<ContactSummary> _current = const [];

  Future<void> _rowMenu(ContactSummary s, Rect anchor) async {
    final repo = widget.repo;
    final k = await showContactRowMenu(context, anchor: anchor, hasPhone: s.phones.isNotEmpty, hasWhatsApp: s.phones.any((x) => x.isWhatsApp));
    if (k == null || !mounted || repo == null) return;
    switch (k) {
      case 'call':
        await quickCall(context, s);
      case 'whatsapp':
        await quickWhatsApp(context, s);
      case 'select':
        _toggle(s.contact.id);
      case 'edit':
        await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => ContactFormPage(repo: repo, id: s.contact.id)));
      case 'share':
        await showShareSheet(context, s);
      case 'delete':
        final l = AppLocalizations.of(context);
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.deleteTitle),
            content: Text(l.deleteBody),
            actions: [
              DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
              DialogConfirm(l.delete, danger: true, onPressed: () => Navigator.of(ctx).pop(true)),
            ],
          ),
        );
        if (ok == true) await repo.delete(s.contact.id);
    }
  }

  void _toggle(int id) => setState(() => _picked.contains(id) ? _picked.remove(id) : _picked.add(id));

  Future<void> _bulkShare() async {
    final list = [for (final s in _current) if (_picked.contains(s.contact.id)) s];
    await shareVCards(list);
  }

  Future<void> _bulkEdit() async {
    final repo = widget.repo;
    if (repo == null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ids = _picked.toList();
    final tags = await repo.allTags();
    if (!mounted) return;
    final c = await showBulkEditSheet(context, count: ids.length, tags: tags);
    if (c == null || c.isEmpty || !mounted) return;
    final lines = [
      if (c.tag != null) l.bulkLineTag(c.tag!),
      if (c.role != null) l.bulkLineRole(roleLabel(l, c.role!)),
      if (c.rating != null) l.bulkLineRating(ratingLabel(l, c.rating!)),
      l.bulkNothingElse,
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.bulkConfirmTitle(ids.length)),
        content: Text(lines.join(' ')),
        actions: [
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.applyBtn, onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (ok != true) return;
    await repo.bulkEdit(ids, rating: c.rating, addRole: c.role, addTag: c.tag);
    messenger.showSnackBar(SnackBar(content: Text(l.bulkDone(ids.length))));
    setState(_picked.clear);
  }

  void _rebuildStream() {
    final repo = widget.repo;
    if (repo == null) return;
    _stream = repo.watchList(
      query: _query,
      rating: _filters.rating,
      role: _filters.role,
      tagId: _filters.tagId,
      inactiveForDays: _filters.inactiveDays,
      stageId: _filters.stageId,
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

  Future<void> _openFieldFilter() async {
    final fields = widget.fields;
    if (fields == null) return;
    final picked = await pickFieldFilter(context, fields);
    if (picked == null) return;
    final owners = await fields.ownersWith(picked.fieldId, picked.value);
    if (!mounted) return;
    setState(() {
      _fieldFilter = picked;
      _fieldOwners = owners;
    });
  }

  void _clearFieldFilter() => setState(() {
        _fieldFilter = null;
        _fieldOwners = null;
      });

  Future<void> _openFilter() async {
    final repo = widget.repo;
    if (repo == null) return;
    final tags = await repo.allTags();
    final stages = await widget.deals?.openStages() ?? const <DealStage>[];
    if (!mounted) return;
    final result = await showFilterSheet(
      context,
      current: _filters,
      tags: tags,
      stages: stages,
      countFor: (f) async => (await repo.list(
        query: _query,
        rating: f.rating,
        role: f.role,
        tagId: f.tagId,
        inactiveForDays: f.inactiveDays,
        stageId: f.stageId,
      ))
          .length,
    );
    if (result != null) {
      _tags = tags;
      _stagesById = {for (final st in stages) st.id: st};
      _update(() => _filters = result);
    }
  }

  void openContact(int id) {
    final repo = widget.repo;
    if (repo == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ContactDetailsPage(repo: repo, activities: widget.activities, schedule: widget.schedule, deals: widget.deals, fields: widget.fields, id: id, navBar: widget.navBar)));
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
        HeaderBand(
          padding: EdgeInsets.zero,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(children: [
              Expanded(
                child: Text(l.navContacts,
                    style: TextStyle(
                        fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600, color: p.onHeader)),
              ),
              PopupMenuButton<int>(
                color: p.sheet,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                        Text(e.$2, style: const TextStyle(fontSize: 14)),
                      ]),
                    ),
                ],
                child: const IgnorePointer(child: GlassIconButton(icon: Icons.more_vert, onTap: null, onHeader: true)),
              ),
            ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: p.glass, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(Icons.search, color: p.text2),
                  const SizedBox(width: 8),
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
          ]),
        ),
        Container(
          height: 66,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(children: [
            Expanded(
              child: Text('${l.contactsCount(_lastCount)} · ${sortLabel(l, _sort)}',
                  style: TextStyle(fontSize: 13, color: p.text2)),
            ),
            if (widget.fields != null) ...[
              GlassIconButton(
                icon: Icons.tune,
                tooltip: l.filterByField,
                size: 40,
                radius: 8,
                filled: _fieldFilter != null,
                onTap: _openFieldFilter,
              ),
              const SizedBox(width: 8),
            ],
            GlassIconButton(
              icon: Icons.filter_alt_outlined,
              tooltip: l.filterTitle,
              size: 40,
              radius: 8,
              filled: _filters.isActive,
              onTap: _openFilter,
            ),
            const SizedBox(width: 8),
            GlassIconButton(
              icon: Icons.swap_vert,
              tooltip: l.sortTitle,
              size: 40,
              radius: 8,
              onTap: _openSort,
            ),
          ]),
        ),
        if (_filters.isActive || _fieldFilter != null) _activeFilters(l),
        Expanded(
          child: StreamBuilder<List<ContactSummary>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) return ErrorView(onRetry: () => _update(() {}));
              if (!snap.hasData) return const ListSkeleton();
              final owners = _fieldOwners;
              final items = owners == null ? snap.data! : snap.data!.where((s) => owners.contains(s.contact.id)).toList();
              if (items.length != _lastCount) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _lastCount != items.length) setState(() => _lastCount = items.length);
                });
              }
              if (items.isEmpty) {
                final none = _query.isEmpty && !_filters.isActive && _fieldFilter == null;
                return EmptyState(
                  icon: Icons.people_outline,
                  title: none ? l.contactsEmptyTitle : l.contactsNoMatch,
                  body: none ? l.contactsEmptyBody : null,
                );
              }
              _current = items;
              return _ContactList(
                items: items,
                grouped: _sort == ContactSort.name,
                picked: _picked,
                onOpen: (id) => _picked.isNotEmpty ? _toggle(id) : openContact(id),
                onLongPress: _toggle,
                onMenu: _rowMenu,
                onCall: (s) => quickCall(context, s),
                onWhatsApp: (s) => quickWhatsApp(context, s),
              );
            },
          ),
        ),
        if (_picked.isNotEmpty)
          Material(
            color: p.sheet,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Row(children: [
                  IconButton(tooltip: l.bulkClose, icon: const Icon(Icons.close), onPressed: () => setState(_picked.clear)),
                  Expanded(child: Text(l.selectedCount(_picked.length), style: const TextStyle(fontWeight: FontWeight.w600))),
                  TextButton.icon(onPressed: _bulkShare, icon: const Icon(Icons.share_outlined), label: Text(l.bulkShare)),
                  TextButton.icon(onPressed: _bulkEdit, icon: const Icon(Icons.edit_outlined), label: Text(l.bulkEdit)),
                ]),
              ),
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
            _filters.copy(noRating: true)),
      ));
    }
    if (_filters.role != null) {
      chips.add(PillChip(
        label: roleLabel(l, _filters.role!),
        selected: true,
        onRemove: () => _update(() => _filters =
            _filters.copy(noRole: true)),
      ));
    }
    if (_filters.tagId != null) {
      final name = _tags.where((t) => t.id == _filters.tagId).map((t) => t.name).firstOrNull ?? l.filterTag;
      chips.add(PillChip(
        label: name,
        selected: true,
        onRemove: () => _update(() => _filters =
            _filters.copy(noTag: true)),
      ));
    }
    if (_filters.stageId != null) {
      final st = _stagesById[_filters.stageId];
      chips.add(PillChip(
        label: st == null ? l.filterStage : stageLabel(l, st),
        selected: true,
        onRemove: () => _update(() => _filters = _filters.copy(noStage: true)),
      ));
    }
    if (_filters.inactiveDays != null) {
      chips.add(PillChip(
        label: l.filterDays(_filters.inactiveDays!),
        selected: true,
        onRemove: () =>
            _update(() => _filters = _filters.copy(noInactive: true)),
      ));
    }
    if (_fieldFilter != null) {
      chips.add(PillChip(label: '${_fieldFilter!.name}: ${_fieldFilter!.label}', selected: true, onRemove: _clearFieldFilter));
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
          onPressed: () {
            _clearFieldFilter();
            _update(() => _filters = const ContactFilters());
          },
          child: Text(l.filterClearAll, style: TextStyle(color: p.primary, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

/// The glass card of rows, with letter headers and a side letter rail when [grouped].
class _ContactList extends StatefulWidget {
  const _ContactList({required this.items, required this.grouped, required this.onOpen, required this.onLongPress, required this.picked, required this.onMenu, required this.onCall, required this.onWhatsApp});
  final Future<void> Function(ContactSummary s, Rect anchor) onMenu;
  final void Function(ContactSummary s) onCall;
  final void Function(ContactSummary s) onWhatsApp;
  final Set<int> picked;
  final void Function(int id) onLongPress;
  final List<ContactSummary> items;
  final bool grouped;
  final void Function(int id) onOpen;

  @override
  State<_ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<_ContactList> {
  final _keys = <String, GlobalKey>{};
  String? _selected;
  int? _menuId;

  final _scroll = ScrollController();

  /// Rough top of each letter section, so the list can jump to rows that are not built yet.
  final _estimate = <String, double>{};
  static const _rowH = 62.0;
  static const _headH = 32.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the side letter in step with the list while it scrolls.
  void _onScroll() {
    if (_estimate.isEmpty || !_scroll.hasClients) return;
    String? cur;
    for (final e in _estimate.entries) {
      final ctx = _keys[e.key]?.currentContext;
      double? top;
      if (ctx != null && ctx.mounted) {
        final box = ctx.findRenderObject();
        if (box is RenderBox && box.attached) {
          final vp = RenderAbstractViewport.maybeOf(box);
          if (vp != null) top = vp.getOffsetToReveal(box, 0).offset;
        }
      }
      top ??= e.value;
      if (top <= _scroll.offset + 8) cur = e.key;
    }
    if (cur != null && cur != _selected) setState(() => _selected = cur);
  }

  void _jump(String section) {
    if (_selected != section) setState(() => _selected = section);
    final ctx = _keys[section]?.currentContext;
    if (ctx != null && ctx.mounted) {
      Scrollable.ensureVisible(ctx, duration: Duration.zero, alignment: 0);
      return;
    }
    final est = _estimate[section];
    if (est == null || !_scroll.hasClients) return;
    _scroll.jumpTo(est.clamp(0.0, _scroll.position.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c2 = _keys[section]?.currentContext;
      if (c2 != null && c2.mounted) Scrollable.ensureVisible(c2, duration: Duration.zero, alignment: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final children = <Widget>[];
    final sections = <String>[];
    String? last;
    _estimate.clear();
    var y = 0.0;
    var rows = <Widget>[];
    void flush() {
      if (rows.isEmpty) return;
      children.add(Padding(
        padding: EdgeInsets.only(top: children.isEmpty ? 0 : 8),
        child: GlassCard(padding: EdgeInsets.zero, child: Column(children: rows)),
      ));
      rows = <Widget>[];
    }

    for (final s in widget.items) {
      if (widget.grouped) {
        final sec = sectionOf(s.contact.sortKey);
        if (sec != last) {
          flush();
          last = sec;
          sections.add(sec);
          _estimate[sec] = y;
          y += _headH + 8;
          children.add(Padding(
            key: _keys.putIfAbsent(sec, GlobalKey.new),
            padding: const EdgeInsetsDirectional.fromSTEB(6, 14, 20, 0),
            child: Text(sec, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.primary)),
          ));
        }
      }
      y += _rowH;
      if (rows.isNotEmpty) rows.add(Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: p.separator));
      rows.add(Builder(
        builder: (rowContext) => SwipeReveal(
          actions: widget.picked.isNotEmpty
              ? const []
              : [
                  if (s.phones.any((x) => x.isWhatsApp)) SwipeAction(icon: Icons.chat_outlined, label: AppLocalizations.of(context).actionWhatsApp, color: const Color(0xFF1E8E4E), onTap: () => widget.onWhatsApp(s)),
                  if (s.phones.isNotEmpty) SwipeAction(icon: Icons.call_outlined, label: AppLocalizations.of(context).actionCall, color: p.primary, onTap: () => widget.onCall(s)),
                ],
          child: ContactRow(
            summary: s,
            picked: widget.picked.contains(s.contact.id),
            outlined: _menuId == s.contact.id,
            onTap: () => widget.onOpen(s.contact.id),
            onLongPress: () async {
              if (widget.picked.isNotEmpty) return widget.onLongPress(s.contact.id);
              final box = rowContext.findRenderObject() as RenderBox;
              final rect = box.localToGlobal(Offset.zero) & box.size;
              setState(() => _menuId = s.contact.id);
              await widget.onMenu(s, rect);
              if (mounted) setState(() => _menuId = null);
            },
          ),
        ),
      ));
    }
    flush();
    final showRail = widget.grouped && sections.length > 1;
    final selected = _selected != null && sections.contains(_selected) ? _selected! : (sections.isEmpty ? '' : sections.first);
    return Stack(
      children: [
        ListView(
          controller: _scroll,
          padding: EdgeInsetsDirectional.fromSTEB(16, 0, showRail ? 36 : 16, 120),
          children: [
            ...children,
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
                                  fontWeight: FontWeight.w600,
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
