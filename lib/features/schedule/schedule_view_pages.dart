import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_database.dart' show Task;
import '../../data/contacts_repository.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../settings/settings_widgets.dart';
import 'meeting_form_page.dart';
import 'schedule_labels.dart';
import 'task_form_page.dart';

String _relativeDay(BuildContext context, DateTime d) {
  final l = AppLocalizations.of(context);
  final today = dayOnly(DateTime.now());
  final diff = dayOnly(d).difference(today).inDays;
  if (diff == 0) return l.quickToday;
  if (diff == 1) return l.quickTomorrow;
  return formatDayShort(context, d);
}

/// Header band with back, title, edit pencil and a ⋮ menu (design Rec MView / TView).
class _ViewShell extends StatelessWidget {
  const _ViewShell({required this.title, required this.onEdit, required this.onMore, required this.children});
  final String title;
  final VoidCallback onEdit;
  final VoidCallback onMore;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(children: [
              GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: p.onHeader))),
              GlassIconButton(icon: Icons.edit_outlined, onHeader: true, onTap: onEdit),
              const SizedBox(width: 8),
              GlassIconButton(icon: Icons.more_vert, onHeader: true, onTap: onMore),
            ]),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 40), children: children)),
        ]),
      ),
    );
  }
}

Widget _heading(BuildContext context, List<Widget> chips, String title) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 6, children: chips),
      const SizedBox(height: 10),
      Text(title, style: TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600, color: context.palette.text)),
      const SizedBox(height: 14),
    ]);

Future<bool?> _confirmDelete(BuildContext context, String title, String body) {
  final l = AppLocalizations.of(context);
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete)),
      ],
    ),
  );
}

class MeetingViewPage extends StatefulWidget {
  const MeetingViewPage({super.key, required this.schedule, required this.contacts, required this.id});
  final ScheduleRepository schedule;
  final ContactsRepository contacts;
  final int id;

  @override
  State<MeetingViewPage> createState() => _MeetingViewPageState();
}

class _MeetingViewPageState extends State<MeetingViewPage> {
  MeetingItem? _m;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await widget.schedule.getMeeting(widget.id);
    if (!mounted) return;
    if (m == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _m = m);
  }

  Future<void> _edit() async {
    await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => MeetingFormPage(schedule: widget.schedule, contacts: widget.contacts, id: widget.id)));
    if (!mounted) return;
    await _load();
  }

  Future<void> _cancel(bool cancelled) async {
    final l = AppLocalizations.of(context);
    if (!cancelled) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.cancelMeetingTitle),
          content: Text(l.cancelMeetingBody),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.backShort)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ctx.palette.error, foregroundColor: Theme.of(ctx).colorScheme.onError),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.cancelMeeting),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await widget.schedule.setMeetingStatus(widget.id, cancelled ? 'scheduled' : 'cancelled');
    await _load();
  }

  Future<void> _more() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final act = await showGlassSheet<String>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Icon(Icons.delete_outline, color: ctx.palette.error), title: Text(l.delete), onTap: () => Navigator.of(ctx).pop('delete')),
      ]),
    );
    if (act != 'delete' || !mounted) return;
    final ok = await _confirmDelete(context, l.deleteMeetingTitle, l.deleteMeetingBody);
    if (ok != true) return;
    await widget.schedule.deleteMeeting(widget.id);
    _gone = true;
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final m = _m;
    if (m == null || _gone) {
      return const Scaffold(backgroundColor: Colors.transparent, body: GlassBackdrop(child: SafeArea(child: LoadingView())));
    }
    final x = m.meeting;
    final cancelled = x.status == 'cancelled';
    final end = x.startAt.add(Duration(minutes: x.durationMinutes));
    final type = meetingTypeFromName(x.type);
    final alarmText = x.alarm ? l.reminderTypeAlarm : l.reminderTypeNotification;
    final dayWhen = '${formatDayShort(context, x.startAt)} · ${formatClock(context, x.startAt)}';
    Future<void> openLink(String url) async {
      final uri = Uri.tryParse(url.contains('://') ? url : 'https://$url');
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    return _ViewShell(
      title: l.kindMeeting,
      onEdit: _edit,
      onMore: _more,
      children: [
        _heading(
          context,
          [
            TagPill(meetingTypeLabel(l, type)),
            TagPill(_relativeDay(context, x.startAt)),
            if (cancelled) TagPill(l.meetingCancelled, bg: p.errorContainer, fg: p.onErrorContainer),
          ],
          x.title,
        ),
        SettingsGroup(children: [
          SettingsRow(
            icon: Icons.schedule,
            title: l.meetingTo(dayWhen, formatClock(context, end)),
            subtitle: x.reminderMinutes == null
                ? null
                : l.reminderSummary(reminderLabel(l, x.reminderMinutes, hasTime: true), alarmText),
          ),
          if (type == MeetingType.inPerson && x.place.isNotEmpty)
            SettingsRow(
              icon: Icons.location_on_outlined,
              title: x.place,
              subtitle: l.opensInMaps,
              onTap: () => launchUrl(Uri.parse('geo:0,0?q=${Uri.encodeComponent(x.place)}'), mode: LaunchMode.externalApplication),
            ),
          if (type == MeetingType.video && x.link.isNotEmpty)
            SettingsRow(icon: Icons.videocam_outlined, title: x.link, onTap: () => openLink(x.link)),
          if (x.description.isNotEmpty) SettingsRow(icon: Icons.notes, title: x.description),
        ]),
        if (m.contactIds.isNotEmpty) ...[
          SectionLabel(l.contactsHeader(m.contactIds.length)),
          SettingsGroup(children: [
            for (var i = 0; i < m.contactIds.length; i++)
              SettingsRow(
                leadingWidget: _Initials(name: m.contactNames[i], color: p.leaves[i % p.leaves.length]),
                title: m.contactNames[i],
                subtitle: i == 0 ? l.mainContact : null,
              ),
          ]),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: PillButton(label: cancelled ? l.restoreMeeting : l.cancelMeeting, outlined: true, danger: !cancelled, height: 48, onPressed: () => _cancel(cancelled))),
          const SizedBox(width: 12),
          Expanded(child: PillButton(label: l.edit, height: 48, onPressed: _edit)),
        ]),
      ],
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = name.trim().isEmpty ? '' : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.characters.first.toUpperCase()).join();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.onPrimary)),
    );
  }
}

class TaskViewPage extends StatefulWidget {
  const TaskViewPage({super.key, required this.schedule, required this.contacts, required this.id});
  final ScheduleRepository schedule;
  final ContactsRepository contacts;
  final int id;

  @override
  State<TaskViewPage> createState() => _TaskViewPageState();
}

class _TaskViewPageState extends State<TaskViewPage> {
  Task? _t;
  String _contact = '';
  String _company = '';
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await widget.schedule.getTask(widget.id);
    if (!mounted) return;
    if (t == null) {
      Navigator.of(context).pop();
      return;
    }
    var name = '';
    var company = '';
    if (t.contactId != null) {
      final s = await widget.contacts.get(t.contactId!);
      name = s?.displayName ?? '';
      company = s?.contact.company ?? '';
    }
    if (!mounted) return;
    setState(() {
      _t = t;
      _contact = name;
      _company = company;
    });
  }

  Future<void> _edit() async {
    await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => TaskFormPage(schedule: widget.schedule, contacts: widget.contacts, id: widget.id)));
    if (!mounted) return;
    await _load();
  }

  Future<void> _toggleDone(bool done) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (done) {
      await widget.schedule.reopenTask(widget.id);
    } else {
      final next = await widget.schedule.completeTask(widget.id);
      if (next != null) {
        final n = await widget.schedule.getTask(next);
        if (n != null && mounted) {
          messenger.showSnackBar(SnackBar(content: Text(l.taskDoneNext(formatDay(context, n.dueAt)))));
        }
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l.taskDone)));
      }
    }
    await _load();
  }

  Future<void> _snooze() async {
    final l = AppLocalizations.of(context);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final until = await showGlassSheet<DateTime>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.snooze), title: Text(l.snooze1h), onTap: () => Navigator.of(ctx).pop(DateTime.now().add(const Duration(hours: 1)))),
        ListTile(
          leading: const Icon(Icons.snooze),
          title: Text(l.snoozeTomorrow),
          onTap: () => Navigator.of(ctx).pop(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9)),
        ),
      ]),
    );
    if (until == null) return;
    await widget.schedule.snoozeTask(widget.id, until);
    await _load();
  }

  Future<void> _more() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final act = await showGlassSheet<String>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Icon(Icons.delete_outline, color: ctx.palette.error), title: Text(l.delete), onTap: () => Navigator.of(ctx).pop('delete')),
      ]),
    );
    if (act != 'delete' || !mounted) return;
    final ok = await _confirmDelete(context, l.deleteTaskTitle, l.deleteTaskBody);
    if (ok != true) return;
    await widget.schedule.deleteTask(widget.id);
    _gone = true;
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final t = _t;
    if (t == null || _gone) {
      return const Scaffold(backgroundColor: Colors.transparent, body: GlassBackdrop(child: SafeArea(child: LoadingView())));
    }
    final done = t.doneAt != null;
    final overdue = !done && t.dueAt.isBefore(t.hasTime ? DateTime.now() : dayOnly(DateTime.now()));
    final pr = priorityFromName(t.priority);
    final repeat = repeatFromName(t.repeat);
    final when = _relativeDay(context, t.dueAt);
    final dueText = l.dueWhen(t.hasTime ? '$when, ${formatClock(context, t.dueAt)}' : when);
    return _ViewShell(
      title: l.kindTask,
      onEdit: _edit,
      onMore: _more,
      children: [
        _heading(
          context,
          [
            if (done) TagPill(l.chipDone, bg: p.primaryContainer, fg: p.onPrimaryContainer) else if (overdue) TagPill(l.chipOverdue, bg: p.errorContainer, fg: p.onErrorContainer),
            TagPill(priorityLabel(l, pr), bg: pr == Priority.high ? p.primaryContainer : null),
          ],
          t.title,
        ),
        SettingsGroup(children: [
          SettingsRow(
            icon: Icons.schedule,
            title: dueText,
            subtitle: t.reminderMinutes == null
                ? null
                : l.reminderSummary(reminderLabel(l, t.reminderMinutes, hasTime: t.hasTime), t.alarm ? l.reminderTypeAlarm : l.reminderTypeNotification),
          ),
          if (_contact.isNotEmpty) SettingsRow(icon: Icons.person_outline, title: _contact, subtitle: _company.isEmpty ? null : _company),
          if (repeat != Repeat.none)
            SettingsRow(icon: Icons.sync, title: l.repeatsEvery(repeatLabel(l, repeat).toLowerCase()), subtitle: l.repeatNote),
        ]),
        if (t.description.isNotEmpty) ...[
          SectionLabel(l.fieldDescriptionHead),
          GlassCard(padding: const EdgeInsets.all(16), child: Text(t.description, style: const TextStyle(fontSize: 15, height: 1.4))),
        ],
        const SizedBox(height: 20),
        if (done)
          PillButton(label: l.markNotDone, icon: Icons.sync, outlined: true, height: 48, onPressed: () => _toggleDone(true))
        else
          Row(children: [
            Expanded(child: PillButton(label: l.snooze, icon: Icons.schedule, outlined: true, height: 48, onPressed: _snooze)),
            const SizedBox(width: 12),
            Expanded(child: PillButton(label: l.chipDone, icon: Icons.check, height: 48, onPressed: () => _toggleDone(false))),
          ]),
      ],
    );
  }
}
