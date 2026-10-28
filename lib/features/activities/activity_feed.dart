import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../core/format.dart';

import '../../data/activities_repository.dart';
import '../../data/contacts_repository.dart';
import '../../domain/activity_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import '../schedule/schedule_widgets.dart';
import 'activity_card.dart';
import 'activity_labels.dart';
import 'log_activity_page.dart';

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
  });

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
  bool _more = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void didUpdateWidget(covariant ActivityFeed old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken ||
        old.contactId != widget.contactId ||
        old.noContactOnly != widget.noContactOnly ||
        _typesKey(old.types) != _typesKey(widget.types)) {
      _load(reset: true);
    }
  }

  String _typesKey(Set<ActivityType>? t) => t == null ? '' : (t.map((x) => x.name).toList()..sort()).join(',');

  Future<void> _load({required bool reset}) async {
    try {
      final have = reset ? 0 : (_items?.length ?? 0);
      final size = reset ? (_items == null ? _pageSize : _items!.length.clamp(_pageSize, 100000)) : _pageSize;
      final page = await widget.activities.list(
        contactId: widget.contactId,
        types: widget.types,
        noContactOnly: widget.noContactOnly,
        limit: size + 1,
        offset: have,
      );
      if (!mounted) return;
      setState(() {
        _error = false;
        final fresh = page.length > size ? page.sublist(0, size) : page;
        _more = page.length > size;
        _items = reset ? fresh : [...?_items, ...fresh];
      });
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
    if (items == null) return const LoadingView();
    if (items.isEmpty) {
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
    for (final item in items) {
      final g = _group(context, l, item.activity.occurredAt);
      if (g != last) {
        children.add(SectionLabel(g.toUpperCase(), padding: const EdgeInsets.fromLTRB(4, 12, 4, 8)));
        last = g;
      }
      children.add(ActivityCard(item: item, showContact: widget.contactId == null, onTap: () => _open(item)));
    }
    if (_more) {
      children.add(Center(
        child: TextButton(onPressed: () => _load(reset: false), child: Text(l.showMore)),
      ));
    }
    return ListView(padding: widget.padding, children: children);
  }
}

/// The contact's Files tab: every file attached to the contact's activities, newest first.
class ContactFilesTab extends StatefulWidget {
  const ContactFilesTab({super.key, required this.activities, required this.contactId, this.reloadToken = 0});
  final ActivitiesRepository activities;
  final int contactId;
  final int reloadToken;

  @override
  State<ContactFilesTab> createState() => _ContactFilesTabState();
}

class _ContactFilesTabState extends State<ContactFilesTab> {
  late Future<List<ContactFileItem>> _future = widget.activities.filesOfContact(widget.contactId);

  @override
  void didUpdateWidget(covariant ContactFilesTab old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken) _future = widget.activities.filesOfContact(widget.contactId);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return FutureBuilder<List<ContactFileItem>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return ErrorView(onRetry: () {
            setState(() {
              _future = widget.activities.filesOfContact(widget.contactId);
            });
          });
        }
        if (!snap.hasData) return const LoadingView();
        final files = snap.data!;
        if (files.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.filesEmpty, textAlign: TextAlign.center, style: TextStyle(color: p.text2)),
            ),
          );
        }
        return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          for (final f in files)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: EdgeInsets.zero,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => openActivityFile(context, f.file),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: f.file.isImage
                              ? Image.file(File(f.file.path), fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: p.text2))
                              : ColoredBox(color: p.primaryContainer, child: Icon(Icons.insert_drive_file_outlined, color: p.onPrimaryContainer)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(f.file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(
                            '${l.fromActivity(activityTypeLabel(l, activityTypeFromName(f.activity.type)))} · ${formatWhen(context, f.activity.occurredAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.text2, fontSize: 13),
                          ),
                        ]),
                      ),
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
  const TimelinePage({super.key, required this.activities, required this.contacts, this.schedule});
  final ActivitiesRepository activities;
  final ContactsRepository contacts;
  final ScheduleRepository? schedule;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  ActivityType? _type;
  bool _general = false;
  int _token = 0;
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

  Future<void> _filter() async {
    final l = AppLocalizations.of(context);
    await showGlassSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          void pick(ActivityType? t, bool general) {
            setState(() {
              _type = t;
              _general = general;
            });
            setS(() {});
            Navigator.of(ctx).pop();
          }

          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.filterTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              PillChip(label: l.filterAllTypes, selected: _type == null && !_general, onTap: () => pick(null, false)),
              for (final t in ActivityType.values)
                PillChip(label: activityTypeLabel(l, t), icon: activityTypeIcon(t), selected: _type == t, onTap: () => pick(_type == t ? null : t, false)),
              PillChip(label: l.noContactLabel, selected: _general, onTap: () => pick(null, !_general)),
            ]),
          ]);
        },
      ),
    );
  }

  Widget _upcomingCard(AppLocalizations l, YoncaPalette p) {
    final s = widget.schedule;
    final c = widget.contacts;
    if (s == null || _upcoming.isEmpty) return const SizedBox.shrink();
    final shown = _expanded ? _upcoming : _upcoming.take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
            child: Row(children: [
              Expanded(child: Text(l.upcomingTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
              if (_upcoming.length > 3)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(children: [
                    Text(_expanded ? l.showLessLink : l.showAllLink, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.primary)),
                    Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: p.primary),
                  ]),
                ),
            ]),
          ),
          for (final i in shown) ...[
            Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: p.separator),
            ScheduleRow(
              item: i,
              showDate: true,
              flat: true,
              onTap: () async {
                await openScheduleItem(context, item: i, schedule: s, contacts: c);
                await _loadUpcoming();
              },
            ),
          ],
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(children: [
              GlassIconButton(
                icon: Icons.chevron_left,
                onHeader: true,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(l.timelineTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: p.onHeader))),
              GlassIconButton(icon: Icons.filter_alt_outlined, tooltip: l.filterTitle, onHeader: true, filled: _type != null || _general, onTap: _filter),
            ]),
          ),
          Expanded(
            child: ActivityFeed(
              activities: widget.activities,
              contacts: widget.contacts,
              types: _type == null ? null : {_type!},
              noContactOnly: _general,
              reloadToken: _token,
              header: _type == null && !_general ? _upcomingCard(l, p) : null,
            ),
          ),
        ]),
      ),
    );
  }
}
