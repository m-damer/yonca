import 'package:flutter/material.dart';

import '../../core/format.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app_controller.dart';
import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../schedule/meeting_form_page.dart';
import '../schedule/schedule_widgets.dart';
import '../schedule/task_form_page.dart';
import '../settings/settings_page.dart';
import '../settings/updates_page.dart';

/// One line in the Bell list.
class BellEntry {
  const BellEntry({required this.id, required this.tab, required this.icon, required this.title, required this.subtitle, this.missed = false, this.read = false, this.reminder, this.item});
  final String id;

  /// `tasks`, `meetings`, `contacts` or `system`.
  final String tab;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool missed;
  final bool read;
  final ReminderSpec? reminder;
  final ScheduleItem? item;

  BellEntry asRead() => BellEntry(id: id, tab: tab, icon: icon, title: title, subtitle: subtitle, missed: missed, read: true, reminder: reminder, item: item);
}

/// What needs a look: missed alarms, overdue tasks, contacts to complete and system news.
class BellData {
  const BellData({required this.entries});
  final List<BellEntry> entries;

  int get badge => entries.where((e) => !e.read).length;
  bool get isEmpty => entries.isEmpty;
}

Set<String> _idSet(AppController c, String key) {
  final raw = c.pref(key) ?? '';
  return raw.isEmpty ? <String>{} : raw.split('|').toSet();
}

Future<BellData> loadBell(AppController c, {AppLocalizations? l10n}) async {
  final l = l10n ?? lookupAppLocalizations(c.locale);
  final read = _idSet(c, AppController.keyBellRead);
  final cleared = _idSet(c, AppController.keyBellCleared);
  final out = <BellEntry>[];
  void add(BellEntry e) {
    if (cleared.contains(e.id)) return;
    out.add(read.contains(e.id) ? e.asRead() : e);
  }

  final s = c.schedule;
  final now = DateTime.now();
  String when(DateTime d) => dfmt(DateFormat.jm(c.locale.toString()), d);
  if (s != null) {
    for (final r in await s.missedAlarms(now, c.ackedAlarms)) {
      add(BellEntry(
        id: 'missed:${r.kind}:${r.refId}:${r.at.millisecondsSinceEpoch}',
        tab: r.kind == 'task' ? 'tasks' : 'meetings',
        icon: r.kind == 'task' ? Icons.alarm_off_outlined : Icons.schedule,
        title: l.bellMissedItem(r.title),
        subtitle: when(r.at),
        missed: true,
        reminder: r,
      ));
    }
    for (final i in await s.overdueTasks()) {
      add(BellEntry(
        id: 'overdue:${i.id}',
        tab: 'tasks',
        icon: Icons.task_alt_outlined,
        title: l.bellOverdueItem(i.title),
        subtitle: [if (i.contactLabel != null) i.contactLabel!, when(i.at)].join(' · '),
        item: i,
      ));
    }
  }
  final contacts = c.contacts;
  if (contacts != null) {
    final n = (await contacts.list()).where((x) => x.isIncomplete).length;
    if (n > 0) {
      add(BellEntry(id: 'contacts:$n', tab: 'contacts', icon: Icons.group_outlined, title: l.bellContactsComplete(n), subtitle: l.bellTapToSee));
    }
  }
  final v = c.pref(AppController.keyUpdateAvailable);
  if (v != null && v.isNotEmpty) {
    add(BellEntry(id: 'update:$v', tab: 'system', icon: Icons.download_outlined, title: l.bellUpdate(v), subtitle: l.bellSystemLabel));
  }
  return BellData(entries: out);
}

/// Bell icon for the Home header, with a count of missed alarms and news.
class BellButton extends StatefulWidget {
  const BellButton({super.key, required this.controller, this.onGoTab});
  final AppController controller;
  final void Function(int index)? onGoTab;

  @override
  State<BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends State<BellButton> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.schedule?.revision.addListener(_load);
    widget.controller.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.controller.schedule?.revision.removeListener(_load);
    widget.controller.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final b = await loadBell(widget.controller);
    if (mounted && b.badge != _count) setState(() => _count = b.badge);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      GlassIconButton(
        icon: Icons.notifications_outlined,
        onHeader: true,
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BellPage(controller: widget.controller, onGoTab: widget.onGoTab)));
          _load();
        },
      ),
      if (_count > 0)
        PositionedDirectional(
          top: -4,
          end: -4,
          child: IgnorePointer(
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: context.palette.error, shape: BoxShape.circle),
              child: Text('$_count', style: TextStyle(fontSize: 11, height: 1, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onError)),
            ),
          ),
        ),
    ]);
  }
}

class BellPage extends StatefulWidget {
  const BellPage({super.key, required this.controller, this.onGoTab});
  final AppController controller;
  final void Function(int index)? onGoTab;

  @override
  State<BellPage> createState() => _BellPageState();
}

class _BellPageState extends State<BellPage> {
  BellData? _data;
  String _tab = 'all';

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await loadBell(c);
    if (mounted) setState(() => _data = d);
  }

  Future<void> _markRead(String id) async {
    final read = _idSet(c, AppController.keyBellRead)..add(id);
    await c.setPref(AppController.keyBellRead, read.join('|'));
    await _load();
  }

  Future<void> _open(BellEntry e) async {
    await _markRead(e.id);
    if (!mounted) return;
    final s = c.schedule, contacts = c.contacts;
    final r = e.reminder;
    if (r != null && s != null && contacts != null) {
      await c.ackAlarm(r.kind, r.refId);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => r.kind == 'task'
            ? TaskFormPage(schedule: s, contacts: contacts, id: r.refId)
            : MeetingFormPage(schedule: s, contacts: contacts, id: r.refId),
      ));
    } else if (e.item != null && s != null && contacts != null) {
      await openScheduleItem(context, item: e.item!, schedule: s, contacts: contacts);
    } else if (e.tab == 'contacts') {
      widget.onGoTab?.call(1);
      Navigator.of(context).pop();
      return;
    } else if (e.tab == 'system') {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => UpdatesPage(controller: c)));
    }
    await _load();
  }

  void _undoToast(String text, String readBefore, String clearedBefore) {
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      action: SnackBarAction(
        label: l.undo,
        onPressed: () async {
          await c.setPref(AppController.keyBellRead, readBefore);
          await c.setPref(AppController.keyBellCleared, clearedBefore);
          await _load();
        },
      ),
    ));
  }

  Future<void> _markAll() async {
    final d = _data;
    if (d == null) return;
    final l = AppLocalizations.of(context);
    final before = c.pref(AppController.keyBellRead) ?? '';
    final clearedBefore = c.pref(AppController.keyBellCleared) ?? '';
    final read = _idSet(c, AppController.keyBellRead)..addAll(d.entries.map((e) => e.id));
    await c.setPref(AppController.keyBellRead, read.join('|'));
    for (final e in d.entries) {
      if (e.reminder != null) await c.ackAlarm(e.reminder!.kind, e.reminder!.refId);
    }
    await _load();
    if (mounted) _undoToast(l.bellMarkedRead, before, clearedBefore);
  }

  Future<void> _clearAll() async {
    final d = _data;
    if (d == null || d.isEmpty) return;
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.bellClearTitle),
        content: Text(l.bellClearBody(d.entries.length)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.bellClearAction)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final readBefore = c.pref(AppController.keyBellRead) ?? '';
    final before = c.pref(AppController.keyBellCleared) ?? '';
    final cleared = _idSet(c, AppController.keyBellCleared)..addAll(d.entries.map((e) => e.id));
    await c.setPref(AppController.keyBellCleared, cleared.join('|'));
    await _load();
    if (mounted) _undoToast(l.bellCleared, readBefore, before);
  }

  Widget _chip(String key, String label) {
    final p = context.palette;
    final on = _tab == key;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _tab = key),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? p.primary : null,
            borderRadius: BorderRadius.circular(8),
            border: on ? null : Border.all(color: p.glassBorder),
          ),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? p.onPrimary : p.text)),
        ),
      ),
    );
  }

  Widget _row(BellEntry e, AppLocalizations l) {
    final p = context.palette;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => _open(e),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(8)),
              child: Icon(e.icon, size: 22, color: p.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, style: TextStyle(fontSize: 15, fontWeight: e.read ? FontWeight.w400 : FontWeight.w600, color: p.text)),
                const SizedBox(height: 2),
                Text(e.subtitle, style: TextStyle(fontSize: 13, color: p.text2)),
              ]),
            ),
            if (e.missed) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: p.errorContainer, borderRadius: BorderRadius.circular(8)),
                child: Text(l.bellMissedPill, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.onErrorContainer)),
              ),
              const SizedBox(width: 10),
            ],
            if (!e.read) Container(width: 8, height: 8, decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final d = _data;
    final shown = d == null ? const <BellEntry>[] : [for (final e in d.entries) if (_tab == 'all' || e.tab == _tab) e];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: SafeArea(
              bottom: false,
              child: Row(children: [
                GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 12),
                Expanded(child: Text(l.bellTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: p.onHeader))),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: p.onHeader),
                  onSelected: (v) {
                    if (v == 'read') _markAll();
                    if (v == 'clear') _clearAll();
                    if (v == 'settings') {
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(controller: c)));
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'read', child: Text(l.bellMenuMarkAll)),
                    PopupMenuItem(value: 'clear', child: Text(l.bellMenuClear)),
                    PopupMenuItem(value: 'settings', child: Text(l.bellMenuSettings)),
                  ],
                ),
              ]),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              children: [
                _chip('all', l.bellTabAll),
                _chip('tasks', l.bellTabTasks),
                _chip('meetings', l.bellTabMeetings),
                _chip('contacts', l.bellTabContacts),
              ],
            ),
          ),
          Expanded(
            child: d == null
                ? const SizedBox.shrink()
                : shown.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.notifications_none, size: 28, color: p.onPrimaryContainer),
                            ),
                            const SizedBox(height: 16),
                            Text(l.bellCaughtTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(l.bellCaughtBody, textAlign: TextAlign.center, style: TextStyle(color: p.text2)),
                          ]),
                        ),
                      )
                    : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
                        GlassCard(
                          padding: EdgeInsets.zero,
                          child: Column(children: [
                            for (var i = 0; i < shown.length; i++) ...[
                              if (i > 0) Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: p.separator),
                              _row(shown[i], l),
                            ],
                          ]),
                        ),
                      ]),
          ),
        ]),
      ),
    );
  }
}
