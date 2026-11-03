import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../shared/pickers.dart';

import '../../shared/ds.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path/path.dart' as pth;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/format.dart';

import '../../data/activities_repository.dart';
import '../../data/app_database.dart' show Activity;
import '../../data/contacts_repository.dart';
import '../../domain/activity_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import '../deals/deal_widgets.dart' show stageLabel;
import '../schedule/schedule_labels.dart' show formatClock;
import '../schedule/schedule_widgets.dart';
import 'activity_card.dart';
import 'log_activity_page.dart';
import 'timeline_filter_sheet.dart';
import 'voice.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';
import '../../shared/scroll_fab.dart';

const _pageSize = 30;

/// Activities newest first under Today, Yesterday, This week and month names. Used by the contact's
/// Timeline tab and the global Timeline. Reloads when [reloadToken] changes.
class ActivityFeed extends StatefulWidget {
  const ActivityFeed({
    super.key,
    required this.activities,
    required this.contacts,
    this.contactId,
    this.types,
    this.noContactOnly = false,
    this.reloadToken = 0,
    this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.fabClear),
    this.header,
    this.filter,
    this.jumpTo,
    this.jumpToken = 0,
    this.onCount,
    this.onEmptyAction,
  });

  /// The Log activity button on the empty Timeline.
  final VoidCallback? onEmptyAction;

  /// The global Timeline's filter; when set it replaces [contactId], [types] and [noContactOnly].
  final TimelineFilter? filter;

  /// Scroll to the first entry on or before this day whenever [jumpToken] changes.
  final DateTime? jumpTo;
  final int jumpToken;

  /// Tells the parent how many entries match (for "8 results").
  final ValueChanged<int>? onCount;

  /// Shown above the first group (the Timeline's Upcoming card).
  final Widget? header;
  final ActivitiesRepository activities;
  final ContactsRepository contacts;
  final int? contactId;
  final Set<ActivityType>? types;
  final bool noContactOnly;
  final int reloadToken;

  /// Called after an activity was edited or deleted from its sheet.
  final VoidCallback? onChanged;
  final EdgeInsets padding;

  @override
  State<ActivityFeed> createState() => _ActivityFeedState();
}

class _ActivityFeedState extends State<ActivityFeed> {
  List<ActivityItem>? _items;
  List<SystemEvent> _events = const [];
  bool _more = false;
  bool _error = false;
  final _scroll = ScrollController();
  final Map<int, GlobalKey> _rowKeys = {};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  TimelineFilter? get _f => widget.filter;
  int? get _contactId => _f != null ? _f!.contactId : widget.contactId;
  bool get _noContact => _f != null ? _f!.noContactOnly : widget.noContactOnly;
  Set<ActivityType>? get _types => _f != null ? (_f!.types.isEmpty ? null : _f!.types) : widget.types;
  DateTime? get _until => _f?.to == null ? null : DateTime(_f!.to!.year, _f!.to!.month, _f!.to!.day + 1);

  @override
  void didUpdateWidget(covariant ActivityFeed old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken ||
        old.contactId != widget.contactId ||
        old.noContactOnly != widget.noContactOnly ||
        _typesKey(old.types) != _typesKey(widget.types) ||
        _filterKey(old.filter) != _filterKey(widget.filter)) {
      _load(reset: true);
    }
    if (old.jumpToken != widget.jumpToken && widget.jumpTo != null) _jump(widget.jumpTo!);
  }

  String _filterKey(TimelineFilter? f) => f == null
      ? ''
      : '${_typesKey(f.types)}|${f.tasks}|${f.meetings}|${f.deals}|${f.contactId}|${f.from}|${f.to}|${f.noContactOnly}';

  /// Brings the first entry on or before [day] into view, loading older pages when needed.
  Future<void> _jump(DateTime day) async {
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59);
    for (var guard = 0; guard < 40; guard++) {
      final entries = _entriesNow();
      final k = entries.indexWhere((e) => !e.$1.isAfter(end));
      if (k >= 0) {
        if (mounted) setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _rowKeys[k]?.currentContext;
          if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.02);
        });
        return;
      }
      if (!_more) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        return;
      }
      await _load(reset: false);
      if (!mounted) return;
    }
  }

  List<(DateTime, Object)> _entriesNow() {
    final f = _f;
    final events = f == null || f.wantsEvents ? _events.where((e) => f == null || f.wantsEvent(e.kind)) : const <SystemEvent>[];
    return <(DateTime, Object)>[
      for (final i in _items ?? const <ActivityItem>[]) (i.activity.occurredAt, i),
      for (final e in events) (e.at, e),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
  }

  String _typesKey(Set<ActivityType>? t) => t == null ? '' : (t.map((x) => x.name).toList()..sort()).join(',');

  Future<void> _load({required bool reset}) async {
    try {
      final have = reset ? 0 : (_items?.length ?? 0);
      final size = reset ? (_items == null ? _pageSize : _items!.length.clamp(_pageSize, 100000)) : _pageSize;
      final f = _f;
      final page = f != null && !f.wantsActivities
          ? <ActivityItem>[]
          : await widget.activities.list(
              contactId: _contactId,
              types: _types,
              noContactOnly: _noContact,
              from: f?.from,
              to: _until,
              limit: size + 1,
              offset: have,
            );
      if (!mounted) return;
      final fresh = page.length > size ? page.sublist(0, size) : page;
      final all = reset ? fresh : [...?_items, ...fresh];
      var events = const <SystemEvent>[];
      final wantEvents = f != null ? f.wantsEvents : (widget.contactId == null && widget.types == null && !widget.noContactOnly);
      if (wantEvents) {
        final more = page.length > size;
        var since = more && all.isNotEmpty ? all.last.activity.occurredAt : DateTime(2000);
        if (f?.from != null && f!.from!.isAfter(since)) since = f.from!;
        events = await widget.activities.systemEvents(since: since, until: _until);
      }
      if (!mounted) return;
      setState(() {
        _error = false;
        _more = page.length > size;
        _items = all;
        _events = events;
      });
      widget.onCount?.call(_entriesNow().length);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  String _group(BuildContext context, AppLocalizations l, DateTime d) {
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return l.groupToday;
    if (diff == 1) return l.groupYesterday;
    if (diff > 1 && diff < 7) return l.groupThisWeek;
    return dfmt(DateFormat.yMMMM(Localizations.localeOf(context).toString()), d);
  }

  Future<void> _open(ActivityItem item) async {
    final changed = await showActivitySheet(context, item: item, activities: widget.activities, contacts: widget.contacts);
    if (changed) {
      await _load(reset: true);
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = _items;
    if (_error) return ErrorView(onRetry: () => _load(reset: true));
    if (items == null) return widget.contactId == null ? const TimelineSkeleton() : const LoadingView();
    if (widget.contactId == null && _entriesNow().isEmpty) {
      final filtered = widget.filter?.isActive ?? false;
      return EmptyState(
        icon: Lu.history,
        title: filtered ? l.timelineFilteredEmpty : l.tlEmptyTitle,
        body: filtered ? null : l.tlEmptyBody,
        action: filtered ? null : PillButton(label: l.logActivity, onPressed: widget.onEmptyAction),
      );
    }
    if (items.isEmpty && widget.contactId != null) {
      final filtered = widget.types != null || widget.noContactOnly;
      return EmptyState(
        icon: Lu.history,
        title: filtered ? l.timelineFilteredEmpty : l.tlEmptyTitle,
        body: filtered ? null : l.tlEmptyBody,
      );
    }
    final children = <Widget>[if (widget.header != null) widget.header!];
    if (widget.contactId != null) {
      final p = context.palette;
      children.add(GlassCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var k = 0; k < items.length; k++) ...[
            if (k > 0) Divider(height: 1, thickness: 1, indent: 62, color: p.separator),
            ActivityCard(item: items[k], showContact: false, compact: true, onTap: () => _open(items[k])),
          ],
        ]),
      ));
      if (_more) {
        children.add(Center(child: TextButton(onPressed: () => _load(reset: false), child: Text(l.showMore))));
      }
      return ListView(padding: widget.padding, children: children);
    }
    String? last;
    final entries = _entriesNow();
    final flat = widget.filter?.isActive ?? false;
    _rowKeys.clear();
    for (var k = 0; k < entries.length; k++) {
      final entry = entries[k];
      final g = _group(context, l, entry.$1);
      if (!flat && g != last) {
        children.add(SectionLabel(g.toUpperCase(), padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.md, AppSpace.xs, AppSpace.sm)));
        last = g;
      }
      final o = entry.$2;
      final key = _rowKeys[k] = GlobalKey();
      if (o is ActivityItem) {
        children.add(KeyedSubtree(key: key, child: ActivityCard(item: o, showContact: widget.contactId == null, showDate: flat, onTap: () => _open(o))));
      } else if (o is SystemEvent) {
        children.add(KeyedSubtree(key: key, child: SystemEventRow(event: o, showDate: flat)));
      }
    }
    if (_more) {
      children.add(Center(
        child: TextButton(onPressed: () => _load(reset: false), child: Text(l.showMore)),
      ));
    }
    return ListView(controller: _scroll, padding: widget.padding, children: children);
  }
}

/// The contact's Files tab (design CD3): filter chips, a two-column grid and an Add button.
class ContactFilesTab extends StatefulWidget {
  const ContactFilesTab({super.key, required this.activities, required this.contacts, required this.contactId, this.reloadToken = 0, this.onNote, this.onChanged});
  final ActivitiesRepository activities;
  final ContactsRepository contacts;
  final int contactId;
  final int reloadToken;

  /// Opens the note form for this contact ("Write a note", "Record a voice note").
  final VoidCallback? onNote;

  /// Called after a file was attached, so the tab count can refresh.
  final VoidCallback? onChanged;

  @override
  State<ContactFilesTab> createState() => _ContactFilesTabState();
}

class _FileTile {
  _FileTile({required this.id, required this.name, required this.sub, required this.kind, required this.open, required this.delete, this.path, this.sharePath, this.shareText, this.at});

  /// Unique in the list: kind and database id.
  final String id;
  final String name;
  final String sub;
  final String kind; // photos | docs | voice | notes
  final VoidCallback open;
  final Future<List<String>> Function() delete;

  /// Image shown as the thumbnail.
  final String? path;

  /// File to share, or text to share (notes).
  final String? sharePath;
  final String? shareText;
  final DateTime? at;
}

class _ContactFilesTabState extends State<ContactFilesTab> {
  late Future<(List<ContactFileItem>, List<Activity>, List<Activity>)> _future = _load();
  String _filter = 'all';
  final Set<String> _sel = {};
  bool _selecting = false;

  Future<(List<ContactFileItem>, List<Activity>, List<Activity>)> _load() async =>
      (await widget.activities.filesOfContact(widget.contactId), await widget.activities.voiceNotesOf(widget.contactId), await widget.activities.notesOf(widget.contactId));

  @override
  void didUpdateWidget(covariant ContactFilesTab old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken) _future = _load();
  }

  String _size(String path) {
    try {
      final n = File(path).lengthSync();
      if (n >= 1024 * 1024) return '${(n / 1048576).toStringAsFixed(1)} MB';
      return '${(n / 1024).ceil()} KB';
    } catch (_) {
      return '';
    }
  }

  void _stopSelecting() => setState(() {
        _selecting = false;
        _sel.clear();
      });

  void _toggle(_FileTile t) => setState(() {
        _selecting = true;
        if (!_sel.remove(t.id)) _sel.add(t.id);
        if (_sel.isEmpty) _selecting = false;
      });

  /// Asks once, then deletes the items and their files from the phone.
  Future<void> _delete(List<_FileTile> items) async {
    final l = AppLocalizations.of(context);
    final sure = await showGlassSheet<bool>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(l.filesDeleteTitle),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          child: Text(l.filesDeleteBody, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, color: context.palette.text2)),
        ),
        SheetItem(first: true, icon: Lu.trash2, iconSize: 40, title: l.filesMenuDelete, danger: true, onTap: () => Navigator.of(ctx).pop(true)),
      ]),
    );
    if (sure != true || !mounted) return;
    for (final t in items) {
      final paths = await t.delete();
      for (final path in paths) {
        try {
          final file = File(path);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      _selecting = false;
      _sel.clear();
      _future = _load();
    });
    widget.onChanged?.call();
  }

  Future<void> _share(List<_FileTile> items) async {
    final files = [for (final t in items) if (t.sharePath != null && File(t.sharePath!).existsSync()) XFile(t.sharePath!)];
    final text = [for (final t in items) if (t.shareText != null && t.shareText!.isNotEmpty) t.shareText!].join('\n\n');
    if (files.isEmpty && text.isEmpty) return;
    if (files.isEmpty) {
      await Share.share(text);
    } else {
      await Share.shareXFiles(files, text: text.isEmpty ? null : text);
    }
  }

  Future<void> _openNote(Activity a) async {
    final item = await widget.activities.get(a.id);
    if (item == null || !mounted) return;
    final changed = await showActivitySheet(context, item: item, activities: widget.activities, contacts: widget.contacts);
    if (changed && mounted) {
      setState(() => _future = _load());
      widget.onChanged?.call();
    }
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final v = await showGlassSheet<String>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(l.addToFiles),
        SheetItem(first: true, icon: Lu.paperclip, iconSize: 40, title: l.attachFile, onTap: () => Navigator.of(ctx).pop('file')),
        SheetItem(icon: Lu.squarePen, iconSize: 40, title: l.addNoteTextVoice, onTap: () => Navigator.of(ctx).pop('note')),
      ]),
    );
    if (v == null || !mounted) return;
    if (v == 'note') {
      widget.onNote?.call();
      return;
    }
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null || !mounted) return;
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(pth.join(dir.path, 'activity_files'))..createSync(recursive: true);
    for (final f in res.files) {
      final src = f.path;
      if (src == null) continue;
      final dest = pth.join(folder.path, '${DateTime.now().microsecondsSinceEpoch}_${f.name}');
      await File(src).copy(dest);
      await widget.activities.save(ActivityInput(
        type: ActivityType.note,
        contactId: widget.contactId,
        occurredAt: DateTime.now(),
        title: f.name,
        files: [ActivityFileInput(path: dest, name: f.name, isImage: isImageName(f.name))],
      ));
    }
    if (!mounted) return;
    setState(() => _future = _load());
    widget.onChanged?.call();
  }

  /// One full-width row: the picture or icon at the start, the title and a small line, then the trash button
  /// (or a tick circle while selecting).
  Widget _row(_FileTile t, AppLocalizations l, YoncaPalette p) {
    final picked = _sel.contains(t.id);
    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: AppControl.xl,
        height: AppControl.xl,
        child: t.path != null
            ? Image.file(File(t.path!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: p.surface2, child: Icon(Lu.image, size: AppIcon.lg, color: p.text2)))
            : ColoredBox(color: p.surface2, child: Icon(t.kind == 'voice' ? Lu.mic : (t.kind == 'notes' ? Lu.fileText : Lu.file), size: AppIcon.lg, color: p.primary)),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: _selecting ? () => _toggle(t) : t.open,
            onLongPress: () => _toggle(t),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Row(children: [
                thumb,
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppFont.label, height: AppLine.normal, fontWeight: FontWeight.w500)),
                    if (t.sub.isNotEmpty) Text(t.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
                  ]),
                ),
                const SizedBox(width: AppSpace.sm),
                if (_selecting)
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.sm),
                    child: Icon(picked ? Lu.circleCheck : Lu.circle, color: picked ? p.primary : p.text2),
                  )
                else
                  GlassIconButton(icon: Lu.trash2, danger: true, size: AppControl.tile, tooltip: l.filesMenuDelete, onTap: () => _delete([t])),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return FutureBuilder<(List<ContactFileItem>, List<Activity>, List<Activity>)>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return ErrorView(onRetry: () => setState(() => _future = _load()));
        }
        if (!snap.hasData) return const LoadingView();
        final (files, voices, notes) = snap.data!;
        final tiles = <_FileTile>[
          for (final f in files)
            _FileTile(
              id: 'f${f.file.id}',
              name: f.file.name,
              sub: _size(f.file.path),
              kind: f.file.isImage ? 'photos' : 'docs',
              path: f.file.isImage ? f.file.path : null,
              sharePath: f.file.path,
              at: f.activity.occurredAt,
              open: () => openActivityFile(context, f.file),
              delete: () => widget.activities.deleteFile(f.file.id),
            ),
          for (final a in voices)
            _FileTile(
              id: 'v${a.id}',
              name: a.title.isEmpty ? l.recordVoice : a.title,
              sub: '${a.voiceMs ~/ 60000}:${((a.voiceMs % 60000) ~/ 1000).toString().padLeft(2, '0')}',
              kind: 'voice',
              sharePath: a.voicePath,
              at: a.occurredAt,
              open: () => showGlassSheet<void>(
                context,
                builder: (_) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SheetTitle(a.title.isEmpty ? l.recordVoice : a.title),
                  VoicePlayer(path: a.voicePath!, durationMs: a.voiceMs),
                ]),
              ),
              delete: () => widget.activities.removeVoice(a.id),
            ),
          for (final a in notes)
            _FileTile(
              id: 'n${a.id}',
              name: a.title.trim().isNotEmpty ? a.title.trim() : a.description.trim().split('\n').first,
              sub: a.title.trim().isNotEmpty ? a.description.trim().replaceAll('\n', ' ') : '',
              kind: 'notes',
              shareText: [a.title.trim(), a.description.trim()].where((x) => x.isNotEmpty).join('\n'),
              at: a.occurredAt,
              open: () => _openNote(a),
              delete: () async => widget.activities.delete(a.id),
            ),
        ]..sort((x, y) => (y.at ?? DateTime(0)).compareTo(x.at ?? DateTime(0)));
        int n(String k) => tiles.where((t) => t.kind == k).length;
        final shown = _filter == 'all' ? tiles : [for (final t in tiles) if (t.kind == _filter) t];
        final picked = [for (final t in tiles) if (_sel.contains(t.id)) t];
        Widget chip(String k, String label) {
          final count = k == 'all' ? tiles.length : n(k);
          return PillChip(label: '$label $count', selected: _filter == k, onTap: () => setState(() => _filter = k));
        }

        // At the top: Add, or the selection bar (count, select all, share, delete, cancel).
        final Widget top = _selecting
            ? Row(children: [
                GlassIconButton(icon: Lu.x, tooltip: l.cancel, onTap: _stopSelecting),
                const SizedBox(width: AppSpace.md),
                Expanded(child: Text(l.selectedCount(_sel.length), style: const TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w600))),
                TextButton(onPressed: () => setState(() => _sel..clear()..addAll([for (final t in shown) t.id])), child: Text(l.selectAll)),
                GlassIconButton(icon: Lu.share, tooltip: l.shareLabel, onTap: picked.isEmpty ? null : () => _share(picked)),
                const SizedBox(width: AppSpace.sm),
                GlassIconButton(icon: Lu.trash2, danger: true, tooltip: l.filesMenuDelete, onTap: picked.isEmpty ? null : () => _delete(picked)),
              ])
            : Row(children: [
                Expanded(child: PillButton(label: l.add, icon: Lu.plus, outlined: true, height: AppControl.lg, onPressed: _add)),
                if (tiles.isNotEmpty) ...[
                  const SizedBox(width: AppSpace.sm),
                  SizedBox(width: AppControl.btnS, child: PillButton(label: l.filesSelect, outlined: true, height: AppControl.lg, onPressed: () => setState(() => _selecting = true))),
                ],
              ]);

        return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.fabClear), children: [
          top,
          const SizedBox(height: AppSpace.md),
          if (tiles.isEmpty)
            Padding(padding: const EdgeInsets.only(top: AppSpace.xl), child: EmptyState(icon: Lu.paperclip, title: l.filesEmptyTitle, body: l.filesEmptyBody))
          else ...[
            Wrap(spacing: 8, runSpacing: 8, children: [chip('all', l.ratingAll), chip('photos', l.filesPhotos), chip('docs', l.filesDocs), chip('voice', l.filesVoice), chip('notes', l.filesNotes)]),
            const SizedBox(height: AppSpace.md),
            for (final t in shown) _row(t, l, p),
          ],
        ]);
      },
    );
  }
}

/// Global Timeline (design Tl): an Upcoming card, then every activity newest first, with a type filter.
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key, required this.activities, required this.contacts, this.schedule, this.initialFilter = const TimelineFilter()});

  /// Start with this filter applied (used by the screenshot harness).
  final TimelineFilter initialFilter;
  final ActivitiesRepository activities;
  final ContactsRepository contacts;
  final ScheduleRepository? schedule;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  late TimelineFilter _filter = widget.initialFilter;
  int _token = 0;
  DateTime? _jumpTo;
  int _jumpToken = 0;
  int _count = 0;
  List<ScheduleItem> _upcoming = const [];
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadUpcoming();
  }

  Future<void> _loadUpcoming() async {
    final s = widget.schedule;
    if (s == null) return;
    final now = DateTime.now();
    final items = await s.itemsBetween(now, DateTime(now.year, now.month, now.day + 30), includeDone: false);
    if (mounted) setState(() => _upcoming = items.where((i) => !i.done).toList());
  }

  Future<void> _log() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = await Navigator.of(context).push<int>(MaterialPageRoute(
      builder: (_) => LogActivityPage(activities: widget.activities, contacts: widget.contacts, schedule: widget.schedule),
    ));
    if (id != null && id > 0 && mounted) {
      setState(() => _token++);
      messenger.showSnackBar(SnackBar(content: Text(l.activitySaved)));
    }
  }

  /// How many entries the filter would show (for "Show 8 results").
  Future<int> _countFor(TimelineFilter f) async {
    final until = f.to == null ? null : DateTime(f.to!.year, f.to!.month, f.to!.day + 1);
    var n = 0;
    if (f.wantsActivities) {
      n += (await widget.activities.list(
        contactId: f.contactId,
        types: f.types.isEmpty ? null : f.types,
        noContactOnly: f.noContactOnly,
        from: f.from,
        to: until,
      ))
          .length;
    }
    if (f.wantsEvents) {
      n += (await widget.activities.systemEvents(since: f.from ?? DateTime(2000), until: until)).where((e) => f.wantsEvent(e.kind)).length;
    }
    return n;
  }

  Future<void> _filterSheet() async {
    final res = await showTimelineFilter(context, contacts: widget.contacts, current: _filter, count: _countFor);
    if (res != null && mounted) setState(() => _filter = res);
  }

  Future<void> _jumpSheet() async {
    final l = AppLocalizations.of(context);
    final d = await showGlassSheet<DateTime>(
      context,
      builder: (ctx) => _JumpBody(title: l.tlJumpTitle),
    );
    if (d != null && mounted) {
      setState(() {
        _jumpTo = d;
        _jumpToken++;
      });
    }
  }

  Widget _activeFilters(AppLocalizations l, YoncaPalette p) {
    final f = _filter;
    final locale = Localizations.localeOf(context).toString();
    String day(DateTime d) => dfmt(DateFormat('d MMM', locale), d);
    final chips = <(String, VoidCallback)>[
      for (final t in ActivityType.values)
        if (f.types.contains(t)) (timelineKindLabel(l, t), () => setState(() => _filter = f.copyWith(types: {...f.types}..remove(t)))),
      if (f.tasks) (l.tlTasks, () => setState(() => _filter = f.copyWith(tasks: false))),
      if (f.meetings) (l.tlMeetings, () => setState(() => _filter = f.copyWith(meetings: false))),
      if (f.deals) (l.navDeals, () => setState(() => _filter = f.copyWith(deals: false))),
      if (f.contactName != null) (f.contactName!, () => setState(() => _filter = f.copyWith(contactId: null, contactName: null))),
      if (f.noContactOnly) (l.tlNoContactOnly, () => setState(() => _filter = f.copyWith(noContactOnly: false))),
    ];
    final range = f.from != null || f.to != null
        ? (f.from != null && f.to != null ? l.tlRange(day(f.from!), day(f.to!)) : (f.from != null ? '${l.tlFrom} ${day(f.from!)}' : '${l.tlTo} ${day(f.to!)}'))
        : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: AppSpace.sm),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in chips)
          GestureDetector(
            onTap: c.$2,
            child: Container(
              height: AppControl.sm,
              padding: const EdgeInsetsDirectional.fromSTEB(AppSpace.lg, 0, AppSpace.md, 0),
              decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: p.primary)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(c.$1, style: TextStyle(fontSize: AppFont.meta, fontWeight: FontWeight.w600, color: p.onPrimary)),
                Icon(Lu.x, size: AppIcon.lg, color: p.onPrimary),
              ]),
            ),
          ),
      ]),
      const SizedBox(height: AppSpace.sm),
      GestureDetector(
        onTap: () => setState(() => _filter = const TimelineFilter()),
        child: Text(l.tlClearAll, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, fontWeight: FontWeight.w600, color: p.primary)),
      ),
      const SizedBox(height: AppSpace.md),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
        child: Text(range == null ? l.tlResults(_count) : l.tlResultsRange(l.tlResults(_count), range),
            style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
      ),
      const SizedBox(height: AppSpace.md),
    ]);
  }

  Widget _upcomingCard(AppLocalizations l, YoncaPalette p) {
    final s = widget.schedule;
    final c = widget.contacts;
    if (s == null || _upcoming.isEmpty) return const SizedBox.shrink();
    final shown = _expanded ? _upcoming : _upcoming.take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm, bottom: AppSpace.xs),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 0),
            child: Row(children: [
              Expanded(child: Text(l.upcomingTitle, style: const TextStyle(fontSize: AppFont.bodyL, height: AppLine.normal, fontWeight: FontWeight.w600))),
              if (_upcoming.length > 3)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(children: [
                    Text(_expanded ? l.showLessLink : l.showAllLink, style: TextStyle(fontSize: AppFont.meta, fontWeight: FontWeight.w500, color: p.primary)),
                    const SizedBox(width: AppSpace.lg),
                    Icon(_expanded ? Lu.chevronUp : Lu.chevronDown, size: AppIcon.lg, color: p.text),
                  ]),
                ),
            ]),
          ),
          for (var k = 0; k < shown.length; k++) ...[
            ScheduleRow(
              item: shown[k],
              showDate: true,
              plain: true,
              flat: true,
              onTap: () async {
                await openScheduleItem(context, item: shown[k], schedule: s, contacts: c);
                await _loadUpcoming();
              },
            ),
          ],
          const SizedBox(height: AppSpace.sm),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FabScope(child: Builder(builder: _buildScreen));

  Widget _buildScreen(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: ExpandingFab(onPressed: _log, label: l.logActivity),
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, 0),
            child: Row(children: [
              GlassIconButton(
                icon: Lu.chevronLeft,
                onHeader: true,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(child: PageTitle(l.timelineTitle)),
              GlassIconButton(icon: Lu.calendar, tooltip: l.tlJumpTitle, onHeader: true, onTap: _jumpSheet),
              const SizedBox(width: AppSpace.md),
              GlassIconButton(icon: Lu.listFilter, tooltip: l.filterTitle, onHeader: true, filled: _filter.isActive, onTap: _filterSheet),
            ]),
          ),
          Expanded(
            child: ActivityFeed(
              activities: widget.activities,
              contacts: widget.contacts,
              filter: _filter,
              reloadToken: _token,
              jumpTo: _jumpTo,
              jumpToken: _jumpToken,
              onCount: (n) {
                if (n != _count) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() => _count = n) : null);
              },
              onEmptyAction: _log,
              padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.fabClear),
              header: _filter.isActive ? _activeFilters(l, p) : _upcomingCard(l, p),
            ),
          ),
        ]),
      ),
    );
  }
}


/// A line the app wrote on its own: task completed, deal moved or contact added.
class SystemEventRow extends StatelessWidget {
  const SystemEventRow({super.key, required this.event, this.showDate = false});
  final SystemEvent event;

  /// Show the day ("26 Oct") instead of the time, as in a filtered list.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final time = showDate ? dfmt(DateFormat('d MMM', Localizations.localeOf(context).toString()), event.at) : formatClock(context, event.at);
    if (event.kind == SystemEventKind.contactAdded) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: GlassCard(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const IconTile(icon: Lu.userPlus),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Row 1: what happened, one step smaller and muted, always a single line.
                Text(l.sysContactAddedLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
                Text(event.title, style: const TextStyle(fontSize: AppFont.body, height: AppLine.snug, fontWeight: FontWeight.w600)),
                if (event.sub.trim().isNotEmpty) Text(event.sub, style: TextStyle(fontSize: AppFont.label, height: AppLine.normal, color: p.text2)),
              ]),
            ),
            Text(time, style: TextStyle(fontSize: AppFont.badge, height: AppLine.normal, color: p.text2)),
          ]),
        ),
      );
    }
    final done = event.kind == SystemEventKind.taskDone;
    final held = event.kind == SystemEventKind.meetingHeld;
    final text = done
        ? l.sysTaskDone(event.title)
        : held
            ? l.sysMeetingHeld(event.title)
            : l.sysDealMoved(event.title, event.stage == null ? '' : stageLabel(l, event.stage!));
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.sm, AppSpace.sm),
      child: Row(children: [
        Icon(done ? Lu.check : (held ? Lu.calendarCheck : Lu.arrowLeftRight), size: AppIcon.md, color: p.primary),
        const SizedBox(width: AppSpace.xs),
        Expanded(child: Text(text, style: TextStyle(fontSize: AppFont.label, height: AppLine.normal, color: p.text2))),
        const SizedBox(width: AppSpace.md),
        Text(time, style: TextStyle(fontSize: AppFont.badge, height: AppLine.normal, color: p.text2)),
      ]),
    );
  }
}


/// "Jump to date": one date field, Cancel and Go.
class _JumpBody extends StatefulWidget {
  const _JumpBody({required this.title});
  final String title;

  @override
  State<_JumpBody> createState() => _JumpBodyState();
}

class _JumpBodyState extends State<_JumpBody> {
  DateTime _d = DateTime.now();

  Future<void> _pick() async {
    final d = await pickDate(context, initialDate: _d, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d != null && mounted) setState(() => _d = d);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = dfmt(DateFormat('d MMM yyyy', Localizations.localeOf(context).toString()), _d);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.title, style: TextStyle(fontSize: AppFont.pageTitle, height: AppLine.relaxed, fontWeight: FontWeight.w600, color: p.text)),
      const SizedBox(height: AppSpace.x3),
      GlassSelectField(label: l.fieldDate, value: text, onTap: _pick, trailing: const SizedBox.shrink()),
      const SizedBox(height: AppSpace.x3),
      Row(children: [
        Expanded(flex: 145, child: PillButton(label: l.cancel, outlined: true, height: AppControl.lg, onPressed: () => Navigator.of(context).pop())),
        const SizedBox(width: AppSpace.md),
        Expanded(flex: 203, child: PillButton(label: l.tlGo, height: AppControl.lg, onPressed: () => Navigator.of(context).pop(_d))),
      ]),
    ]);
  }
}
