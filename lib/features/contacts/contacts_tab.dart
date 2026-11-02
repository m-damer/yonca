import '../../shared/ds.dart';
import 'bulk_actions.dart';
import 'phone_book_export.dart';
import 'bulk_more.dart';
import '../../domain/deal_models.dart';
import '../../domain/field_models.dart';
import 'contact_form_page.dart';
import '../../domain/activity_models.dart';
import '../../domain/schedule_models.dart';
import 'contact_quick_actions.dart';
import '../fields/field_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport, RenderBox;

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
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

/// Contacts tab (design S05): title and menu, search, count line with filter and sort buttons,
/// one glass card of rows, and a letter rail when sorted by name.
class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key, required this.repo, this.activities, this.schedule, this.deals, this.fields, this.navBar, this.onMenu});
  /// Opens the tools behind the header menu: 0 scan QR, 1 import, 2 update existing, 3 duplicates.
  final void Function(int action)? onMenu;
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
  bool _selecting = false;
  List<ContactSummary> _current = const [];

  Future<void> _rowMenu(ContactSummary s, Rect anchor) async {
    final repo = widget.repo;
    final k = await showContactRowMenu(context, anchor: anchor, hasPhone: s.phones.isNotEmpty, hasWhatsApp: s.whatsAppPhone != null);
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

  Future<void> _bulkActions() async {
    final repo = widget.repo;
    if (repo == null || _picked.isEmpty) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ids = _picked.toList();
    final selected = [for (final s in _current) if (_picked.contains(s.contact.id)) s];
    final action = await showBulkActionsSheet(context, count: ids.length);
    if (action == null || !mounted) return;
    void done(String text) {
      messenger.showSnackBar(SnackBar(content: Text(text)));
      if (mounted) {
        setState(() {
          _picked.clear();
          _selecting = false;
        });
      }
    }

    switch (action) {
      case BulkAction.share:
        await _bulkShare();
      case BulkAction.export:
        await shareCsv(selected);
      case BulkAction.edit:
        await _bulkEdit();
      case BulkAction.deal:
        final deals = widget.deals;
        if (deals == null) return;
        final stages = await deals.openStages();
        if (!mounted || stages.isEmpty) return;
        final c = await showBulkDealSheet(context, count: ids.length, stages: stages);
        if (c == null) return;
        for (final id in ids) {
          await deals.saveDeal(DealInput(title: c.title, contactId: id, amount: c.amount, stageId: c.stageId));
        }
        done(l.bulkCreatedDeals(ids.length));
      case BulkAction.field:
        final fields = widget.fields;
        if (fields == null) return;
        final list = await fields.fields(FieldScope.contact);
        if (!mounted) return;
        final c = await showBulkFieldSheet(context, count: ids.length, fields: list);
        if (c == null) return;
        for (final id in ids) {
          await fields.setValues(FieldScope.contact, id, {c.fieldId: c.value});
        }
        done(l.bulkDone(ids.length));
      case BulkAction.whatsapp:
        await showBulkWhatsAppSheet(context, selected);
      case BulkAction.email:
        if (!await emailAll(selected)) messenger.showSnackBar(SnackBar(content: Text(l.bulkEmailNone)));
      case BulkAction.phoneBook:
        await saveContactsToPhoneBook(context, selected);
      case BulkAction.merge:
        if (ids.length < 2) {
          messenger.showSnackBar(SnackBar(content: Text(l.bulkMergeNeed2)));
          return;
        }
        final keep = await showBulkPrimarySheet(context, selected);
        if (keep == null) return;
        final snap = await repo.merge(keep, [for (final id in ids) if (id != keep) id]);
        messenger.showSnackBar(SnackBar(
          content: Text(l.bulkDone(ids.length)),
          duration: const Duration(seconds: 8),
          action: snap == null ? null : SnackBarAction(label: l.undo, onPressed: () => repo.undoMerge(snap)),
        ));
        if (mounted) {
          setState(() {
            _picked.clear();
            _selecting = false;
          });
        }
      case BulkAction.remove:
        final allTags = await repo.allTags();
        if (!mounted) return;
        final c = await showBulkRemoveSheet(context, count: ids.length, tags: allTags);
        if (c == null) return;
        await repo.bulkEdit(ids, removeTag: c.tag, removeRole: c.role);
        done(l.bulkDone(ids.length));
      case BulkAction.task:
        final sched = widget.schedule;
        if (sched == null) return;
        final c = await showBulkTaskSheet(context, count: ids.length);
        if (c == null) return;
        for (final id in ids) {
          await sched.saveTask(TaskInput(title: c.title, contactId: id, dueAt: c.due, description: c.description));
        }
        done(l.bulkCreatedTasks(ids.length));
      case BulkAction.activity:
        final acts = widget.activities;
        if (acts == null) return;
        final c = await showBulkActivitySheet(context, count: ids.length);
        if (c == null) return;
        final now = DateTime.now();
        for (final id in ids) {
          await acts.save(ActivityInput(type: c.type, contactId: id, occurredAt: now, title: c.title, description: c.description));
        }
        done(l.bulkLogged(ids.length));
      case BulkAction.meeting:
        final sched = widget.schedule;
        if (sched == null) return;
        final c = await showBulkMeetingSheet(context, count: ids.length);
        if (c == null) return;
        await sched.saveMeeting(MeetingInput(title: c.title, contactIds: ids, startAt: c.start));
        done(l.bulkCreatedMeeting(ids.length));
      case BulkAction.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.bulkDeleteTitle(ids.length)),
            content: Text(l.bulkDeleteBody),
            actions: [
              DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
              DialogConfirm(l.delete, onPressed: () => Navigator.of(ctx).pop(true), danger: true),
            ],
          ),
        );
        if (ok != true) return;
        await repo.deleteMany(ids);
        done(l.bulkDeleted(ids.length));
    }
  }

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
    setState(() {
      _picked.clear();
      _selecting = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    if (widget.repo == null) {
      return EmptyState(icon: Lu.database, title: l.navContacts, body: l.noDatabase);
    }
    return Column(
      children: [
        HeaderBand(
          padding: EdgeInsets.zero,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, 0),
              child: Row(children: [
              Expanded(
                child: Text(l.navContacts,
                    style: TextStyle(
                        fontSize: AppFont.pageTitle, height: AppLine.snug, fontWeight: FontWeight.w600, color: p.onHeader)),
              ),
              HeaderMenu<int>(
                onSelected: (i) => i == 4 ? setState(() => _selecting = true) : widget.onMenu?.call(i),
                actions: [
                  MenuAction(0, Lu.scanLine, l.menuScanQr),
                  MenuAction(1, Lu.download, l.menuImport),
                  MenuAction(2, Lu.refreshCw, l.menuUpdateExisting),
                  MenuAction(3, Lu.merge, l.menuDuplicates),
                  MenuAction(4, Lu.check, l.menuSelect),
                ],
              ),
            ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 0),
              child: Container(
                height: AppControl.lg,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                decoration: BoxDecoration(color: p.glass, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Row(children: [
                  Icon(Lu.search, color: p.text2),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => _update(() => _query = v),
                      style: TextStyle(fontSize: AppFont.body, color: p.text),
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
          padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.md),
          child: Row(children: [
            Expanded(
              child: Text('${l.contactsCount(_lastCount)} · ${sortLabel(l, _sort)}',
                  style: TextStyle(fontSize: AppFont.meta, color: p.text2)),
            ),
            if (widget.fields != null) ...[
              GlassIconButton(
                icon: Lu.slidersHorizontal,
                tooltip: l.filterByField,
                filled: _fieldFilter != null,
                onTap: _openFieldFilter,
              ),
              const SizedBox(width: AppSpace.sm),
            ],
            GlassIconButton(
              icon: Lu.listFilter,
              tooltip: l.filterTitle,
              filled: _filters.isActive,
              onTap: _openFilter,
            ),
            const SizedBox(width: AppSpace.sm),
            GlassIconButton(
              icon: Lu.arrowUpDown,
              tooltip: l.sortTitle,
              onTap: _openSort,
            ),
          ]),
        ),
        if (_selecting || _picked.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
            child: Container(
              decoration: BoxDecoration(color: p.glass, borderRadius: BorderRadius.circular(AppRadius.md)),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
              child: Row(children: [
                IconButton(
                    tooltip: l.bulkClose,
                    icon: const Icon(Lu.x),
                    onPressed: () => setState(() {
                          _picked.clear();
                          _selecting = false;
                        })),
                Expanded(child: Text(l.selectedCount(_picked.length), style: const TextStyle(fontWeight: FontWeight.w600))),
                IconButton(
                    tooltip: l.bulkSelectAll,
                    onPressed: () => setState(() => _picked.addAll(_current.map((s) => s.contact.id))),
                    icon: const Icon(Lu.squareDashed)),
                TextButton(onPressed: _picked.isEmpty ? null : _bulkActions, child: Text(l.bulkActions)),
              ]),
            ),
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
                  icon: Lu.users,
                  title: none ? l.contactsEmptyTitle : l.contactsNoMatch,
                  body: none ? l.contactsEmptyBody : null,
                );
              }
              _current = items;
              return _ContactList(
                items: items,
                grouped: _sort == ContactSort.name,
                picked: _picked,
                onOpen: (id) => (_selecting || _picked.isNotEmpty) ? _toggle(id) : openContact(id),
                onLongPress: _toggle,
                onMenu: _rowMenu,
                onCall: (s) => quickCall(context, s),
                onWhatsApp: (s) => quickWhatsApp(context, s),
              );
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
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.xl, AppSpace.md),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: AppControl.md,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [for (final c in chips) Padding(padding: const EdgeInsetsDirectional.only(end: AppSpace.sm), child: c)],
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
        padding: EdgeInsets.only(top: children.isEmpty ? 0 : AppSpace.sm),
        child: GlassCard(padding: EdgeInsets.zero, child: Column(children: rows)),
      ));
      rows = <Widget>[];
    }

    final usedKeys = <String>{};
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
            // A section letter can come back when the list is not sorted by name; only its first header carries the key.
            key: usedKeys.add(sec) ? _keys.putIfAbsent(sec, GlobalKey.new) : null,
            padding: const EdgeInsetsDirectional.fromSTEB(AppSpace.sm, AppSpace.lg, AppSpace.xl, 0),
            child: Text(sec, style: TextStyle(fontSize: AppFont.meta, fontWeight: FontWeight.w600, color: p.primary)),
          ));
        }
      }
      y += _rowH;
      if (rows.isNotEmpty) rows.add(Divider(height: 1, thickness: 1, indent: AppSpace.lg, endIndent: AppSpace.lg, color: p.separator));
      rows.add(Builder(
        builder: (rowContext) => SwipeReveal(
          actions: widget.picked.isNotEmpty
              ? const []
              : [
                  if (s.whatsAppPhone != null) SwipeAction(icon: Lu.messageSquare, label: AppLocalizations.of(context).actionWhatsApp, color: context.palette.whatsapp, onTap: () => widget.onWhatsApp(s)),
                  if (s.phones.isNotEmpty) SwipeAction(icon: Lu.phone, label: AppLocalizations.of(context).actionCall, color: p.primary, onTap: () => widget.onCall(s)),
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
          padding: EdgeInsetsDirectional.fromSTEB(AppSpace.lg, 0, showRail ? AppSpace.x5 : AppSpace.lg, AppSpace.fabClear),
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
                                  ? BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(AppRadius.md))
                                  : null,
                              child: Text(
                                sec,
                                style: TextStyle(
                                  fontSize: AppFont.tiny,
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
