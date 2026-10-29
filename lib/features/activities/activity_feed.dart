import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path/path.dart' as pth;
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
import 'activity_labels.dart';
import 'log_activity_page.dart';
import 'timeline_filter_sheet.dart';
import 'voice.dart';

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
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
        icon: Icons.history,
        title: filtered ? l.timelineFilteredEmpty : l.tlEmptyTitle,
        body: filtered ? null : l.tlEmptyBody,
        action: filtered ? null : PillButton(label: l.logActivity, onPressed: widget.onEmptyAction),
      );
    }
    if (items.isEmpty && widget.contactId != null) {
      final filtered = widget.types != null || widget.noContactOnly;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.contactId != null && !filtered
                ? l.noActivityYet
                : (filtered ? l.timelineFilteredEmpty : l.timelineEmpty),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.text2),
          ),
        ),
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
        children.add(SectionLabel(g.toUpperCase(), padding: const EdgeInsets.fromLTRB(4, 12, 4, 8)));
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
  const ContactFilesTab({super.key, required this.activities, required this.contactId, this.reloadToken = 0, this.onNote, this.onChanged});
  final ActivitiesRepository activities;
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
  _FileTile({required this.name, required this.sub, required this.kind, required this.open, this.path, this.at});
  final String name;
  final String sub;
  final String kind; // photos | docs | voice
  final VoidCallback open;
  final String? path;
  final DateTime? at;
}

class _ContactFilesTabState extends State<ContactFilesTab> {
  late Future<(List<ContactFileItem>, List<Activity>)> _future = _load();
  String _filter = 'all';

  Future<(List<ContactFileItem>, List<Activity>)> _load() async => (await widget.activities.filesOfContact(widget.contactId), await widget.activities.voiceNotesOf(widget.contactId));

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

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final v = await showGlassSheet<String>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(l.addToFiles),
        SheetItem(first: true, icon: Icons.attach_file, iconSize: 40, title: l.attachFile, onTap: () => Navigator.of(ctx).pop('file')),
        SheetItem(icon: Icons.edit_note, iconSize: 40, title: l.writeNote, onTap: () => Navigator.of(ctx).pop('note')),
        SheetItem(icon: Icons.mic_none, iconSize: 40, title: l.recordVoice, onTap: () => Navigator.of(ctx).pop('note')),
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return FutureBuilder<(List<ContactFileItem>, List<Activity>)>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return ErrorView(onRetry: () => setState(() => _future = _load()));
        }
        if (!snap.hasData) return const LoadingView();
        final (files, voices) = snap.data!;
        final tiles = <_FileTile>[
          for (final f in files)
            _FileTile(
              name: f.file.name,
              sub: _size(f.file.path),
              kind: f.file.isImage ? 'photos' : 'docs',
              path: f.file.isImage ? f.file.path : null,
              at: f.activity.occurredAt,
              open: () => openActivityFile(context, f.file),
            ),
          for (final a in voices)
            _FileTile(
              name: a.title.isEmpty ? l.recordVoice : a.title,
              sub: '${a.voiceMs ~/ 60000}:${((a.voiceMs % 60000) ~/ 1000).toString().padLeft(2, '0')}',
              kind: 'voice',
              at: a.occurredAt,
              open: () => showGlassSheet<void>(
                context,
                builder: (_) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SheetTitle(a.title.isEmpty ? l.recordVoice : a.title),
                  VoicePlayer(path: a.voicePath!, durationMs: a.voiceMs),
                ]),
              ),
            ),
        ]..sort((x, y) => (y.at ?? DateTime(0)).compareTo(x.at ?? DateTime(0)));
        int n(String k) => tiles.where((t) => t.kind == k).length;
        final shown = _filter == 'all' ? tiles : [for (final t in tiles) if (t.kind == _filter) t];
        Widget chip(String k, String label) {
          final count = k == 'all' ? tiles.length : n(k);
          return PillChip(label: '$label $count', selected: _filter == k, onTap: () => setState(() => _filter = k));
        }

        return Stack(children: [
          if (tiles.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.filesEmpty, textAlign: TextAlign.center, style: TextStyle(color: p.text2))))
          else
            ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 100), children: [
              Wrap(spacing: 8, runSpacing: 8, children: [chip('all', l.filesAll), chip('photos', l.filesPhotos), chip('docs', l.filesDocs), chip('voice', l.filesVoice)]),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final t in shown)
                  LayoutBuilder(builder: (context, _) {
                    final w = (MediaQuery.sizeOf(context).width - 32 - 10) / 2;
                    return SizedBox(
                      width: w,
                      child: GlassCard(
                        padding: EdgeInsets.zero,
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: t.open,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    height: 84,
                                    width: double.infinity,
                                    child: t.path != null
                                        ? Image.file(File(t.path!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: p.surface2, child: Icon(Icons.image_outlined, size: 22, color: p.text2)))
                                        : ColoredBox(color: p.surface2, child: Icon(t.kind == 'voice' ? Icons.mic_none : Icons.insert_drive_file_outlined, size: 22, color: p.text2)),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w500)),
                                Text(t.sub, style: TextStyle(fontSize: 12.5, height: 1.4, color: p.text2)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ]),
            ]),
          PositionedDirectional(
            end: 16,
            bottom: 16,
            child: Material(
              color: p.primary,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _add,
                child: SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add, size: 22, color: p.onPrimary),
                      const SizedBox(width: 8),
                      Text(l.add, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.onPrimary)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
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
      if (f.deals) (l.tlDeals, () => setState(() => _filter = f.copyWith(deals: false))),
      if (f.contactName != null) (f.contactName!, () => setState(() => _filter = f.copyWith(contactId: null, contactName: null))),
      if (f.noContactOnly) (l.tlNoContactOnly, () => setState(() => _filter = f.copyWith(noContactOnly: false))),
    ];
    final range = f.from != null || f.to != null
        ? (f.from != null && f.to != null ? l.tlRange(day(f.from!), day(f.to!)) : (f.from != null ? '${l.tlFrom} ${day(f.from!)}' : '${l.tlTo} ${day(f.to!)}'))
        : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in chips)
          GestureDetector(
            onTap: c.$2,
            child: Container(
              height: 34,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 11, 0),
              decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(6), border: Border.all(color: p.primary)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(c.$1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.onPrimary)),
                Icon(Icons.close, size: 22, color: p.onPrimary),
              ]),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () => setState(() => _filter = const TimelineFilter()),
        child: Text(l.tlClearAll, style: TextStyle(fontSize: 13, height: 18.2 / 13, fontWeight: FontWeight.w600, color: p.primary)),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(range == null ? l.tlResults(_count) : l.tlResultsRange(l.tlResults(_count), range),
            style: TextStyle(fontSize: 13, height: 18.2 / 13, color: p.text2)),
      ),
      const SizedBox(height: 10),
    ]);
  }

  Widget _upcomingCard(AppLocalizations l, YoncaPalette p) {
    final s = widget.schedule;
    final c = widget.contacts;
    if (s == null || _upcoming.isEmpty) return const SizedBox.shrink();
    final shown = _expanded ? _upcoming : _upcoming.take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Expanded(child: Text(l.upcomingTitle, style: const TextStyle(fontSize: 16, height: 22.4 / 16, fontWeight: FontWeight.w600))),
              if (_upcoming.length > 3)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(children: [
                    Text(_expanded ? l.showLessLink : l.showAllLink, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: p.primary)),
                    const SizedBox(width: 14),
                    Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 22, color: p.text),
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
          const SizedBox(height: 6),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _log,
        icon: const Icon(Icons.add),
        label: Text(l.logActivity),
      ),
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(children: [
              GlassIconButton(
                icon: Icons.chevron_left,
                onHeader: true,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l.timelineTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: p.onHeader))),
              GlassIconButton(icon: Icons.calendar_today_outlined, tooltip: l.tlJumpTitle, onHeader: true, onTap: _jumpSheet),
              const SizedBox(width: 12),
              GlassIconButton(icon: Icons.filter_alt_outlined, tooltip: l.filterTitle, onHeader: true, filled: _filter.isActive, onTap: _filterSheet),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
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
      return GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.person_add_alt_outlined, size: 20, color: p.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.sysContactAdded(event.title), style: const TextStyle(fontSize: 15, height: 19 / 15, fontWeight: FontWeight.w600)),
              if (event.sub.trim().isNotEmpty) Text(event.sub, style: TextStyle(fontSize: 13.5, height: 18.9 / 13.5, color: p.text2)),
            ]),
          ),
          Text(time, style: TextStyle(fontSize: 12, height: 16.8 / 12, color: p.text2)),
        ]),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
      child: Row(children: [
        Icon(done ? Icons.check : (held ? Icons.event_available_outlined : Icons.swap_horiz), size: 18, color: p.primary),
        const SizedBox(width: 4),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, height: 18.9 / 13.5, color: p.text2))),
        const SizedBox(width: 10),
        Text(time, style: TextStyle(fontSize: 12, height: 16.8 / 12, color: p.text2)),
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
    final d = await showDatePicker(context: context, initialDate: _d, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d != null && mounted) setState(() => _d = d);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = dfmt(DateFormat('d MMM yyyy', Localizations.localeOf(context).toString()), _d);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.title, style: TextStyle(fontSize: 22, height: 32.8 / 22, fontWeight: FontWeight.w600, color: p.text)),
      const SizedBox(height: 27),
      GlassSelectField(label: l.fieldDate, value: text, onTap: _pick, trailing: const SizedBox.shrink()),
      const SizedBox(height: 26),
      Row(children: [
        Expanded(flex: 145, child: PillButton(label: l.cancel, outlined: true, height: 48, onPressed: () => Navigator.of(context).pop())),
        const SizedBox(width: 10),
        Expanded(flex: 203, child: PillButton(label: l.tlGo, height: 48, onPressed: () => Navigator.of(context).pop(_d))),
      ]),
    ]);
  }
}
