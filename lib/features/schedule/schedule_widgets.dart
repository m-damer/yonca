import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/contacts_repository.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'meeting_form_page.dart';
import 'schedule_labels.dart';
import 'schedule_view_pages.dart';
import 'quick_task_sheet.dart';
import 'task_form_page.dart';

/// One row of the agenda, the task list or a day: icon or checkbox, title, time and contact.
class ScheduleRow extends StatelessWidget {
  const ScheduleRow({super.key, required this.item, required this.onTap, this.onToggle, this.showDate = false, this.flat = false});
  final ScheduleItem item;
  final VoidCallback onTap;

  /// Check button tap for tasks.
  final VoidCallback? onToggle;
  final bool showDate;

  /// No card around the row, for use inside a grouped card.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final when = [
      if (showDate) formatDay(context, item.at),
      if (item.kind == ScheduleKind.event) l.allDay else if (item.hasTime) formatClock(context, item.at),
    ].join(' · ');
    final sub = [if (when.isNotEmpty) when, if (item.contactLabel != null) item.contactLabel!].join(' · ');
    final struck = item.done || item.cancelled;
    final icon = switch (item.kind) {
      ScheduleKind.task => Icons.task_alt_outlined,
      ScheduleKind.meeting => meetingTypeIcon(item.meetingType ?? MeetingType.inPerson),
      ScheduleKind.event => Icons.cake_outlined,
    };
    final row = InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 22, color: item.overdue ? p.error : p.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: struck ? TextDecoration.lineThrough : null,
                  color: struck ? p.text2 : p.text,
                ),
              ),
              if (sub.isNotEmpty || item.cancelled)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.cancelled ? '${l.meetingCancelled}${sub.isEmpty ? '' : ' · $sub'}' : sub,
                    style: TextStyle(fontSize: 12, color: item.overdue ? p.error : p.text2),
                  ),
                ),
            ]),
          ),
          if (item.kind == ScheduleKind.task)
            Tooltip(
              message: item.done ? l.reopenTask : l.markDone,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onToggle,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: item.done ? p.primary : p.primaryContainer),
                  child: Icon(Icons.check, size: 20, color: item.done ? p.onPrimary : p.onPrimaryContainer),
                ),
              ),
            )
          else if (item.kind == ScheduleKind.meeting)
            TagPill(l.kindMeeting),
        ]),
      ),
    );
    if (flat) return Material(type: MaterialType.transparency, child: row);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(padding: EdgeInsets.zero, child: Material(type: MaterialType.transparency, child: row)),
    );
  }
}

/// Opens the right editor for a calendar item. Returns true when something changed.
Future<bool> openScheduleItem(
  BuildContext context, {
  required ScheduleItem item,
  required ScheduleRepository schedule,
  required ContactsRepository contacts,
  void Function(int contactId)? onOpenContact,
}) async {
  switch (item.kind) {
    case ScheduleKind.task:
      await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => TaskViewPage(schedule: schedule, contacts: contacts, id: item.id)));
      return true;
    case ScheduleKind.meeting:
      await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => MeetingViewPage(schedule: schedule, contacts: contacts, id: item.id)));
      return true;
    case ScheduleKind.event:
      if (item.contactIds.isNotEmpty) onOpenContact?.call(item.contactIds.first);
      return false;
  }
}

Widget _sheetTitle(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    );

Future<bool?> showTaskActions(
  BuildContext context, {
  required ScheduleItem item,
  required ScheduleRepository schedule,
  required ContactsRepository contacts,
}) {
  final l = AppLocalizations.of(context);
  return showGlassSheet<bool>(
    context,
    builder: (ctx) {
      Future<void> edit() async {
        final nav = Navigator.of(ctx);
        await nav.push<int>(MaterialPageRoute(builder: (_) => TaskFormPage(schedule: schedule, contacts: contacts, id: item.id)));
        nav.pop(true);
      }

      Future<void> run(Future<void> Function() f) async {
        final nav = Navigator.of(ctx);
        await f();
        nav.pop(true);
      }

      DateTime tomorrow9() {
        final n = DateTime.now().add(const Duration(days: 1));
        return DateTime(n.year, n.month, n.day, 9);
      }

      return Column(mainAxisSize: MainAxisSize.min, children: [
        _sheetTitle(item.title),
        ListTile(
          leading: Icon(item.done ? Icons.undo : Icons.check_circle_outline),
          title: Text(item.done ? l.reopenTask : l.markDone),
          onTap: () => run(() => item.done ? schedule.reopenTask(item.id) : schedule.completeTask(item.id)),
        ),
        if (!item.done) ...[
          ListTile(
            leading: const Icon(Icons.snooze),
            title: Text('${l.snooze} · ${l.snooze1h}'),
            onTap: () => run(() => schedule.snoozeTask(item.id, DateTime.now().add(const Duration(hours: 1)))),
          ),
          ListTile(
            leading: const Icon(Icons.snooze),
            title: Text('${l.snooze} · ${l.snoozeTomorrow}'),
            onTap: () => run(() => schedule.snoozeTask(item.id, tomorrow9())),
          ),
        ],
        ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l.edit), onTap: edit),
      ]);
    },
  );
}

Future<bool?> showMeetingActions(
  BuildContext context, {
  required ScheduleItem item,
  required ScheduleRepository schedule,
  required ContactsRepository contacts,
}) async {
  final l = AppLocalizations.of(context);
  final m = await schedule.getMeeting(item.id);
  if (m == null || !context.mounted) return null;
  final x = m.meeting;
  final cancelled = x.status == 'cancelled';
  return showGlassSheet<bool>(
    context,
    builder: (ctx) {
      final p = ctx.palette;
      Future<void> run(Future<void> Function() f) async {
        final nav = Navigator.of(ctx);
        await f();
        nav.pop(true);
      }

      return Column(mainAxisSize: MainAxisSize.min, children: [
        _sheetTitle(x.title),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              [
                '${formatDay(ctx, item.at)} · ${formatClock(ctx, item.at)}',
                meetingTypeLabel(l, meetingTypeFromName(x.type)),
                if (x.place.isNotEmpty) x.place,
                if (m.contactNames.isNotEmpty) m.contactNames.join(', '),
                if (cancelled) l.meetingCancelled,
              ].join('\n'),
              style: TextStyle(color: p.text2, height: 1.4),
            ),
          ),
        ),
        if (x.link.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: Text(x.link, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () async {
              final uri = Uri.tryParse(x.link.contains('://') ? x.link : 'https://${x.link}');
              if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: Text(l.edit),
          onTap: () async {
            final nav = Navigator.of(ctx);
            await nav.push<int>(MaterialPageRoute(builder: (_) => MeetingFormPage(schedule: schedule, contacts: contacts, id: x.id)));
            nav.pop(true);
          },
        ),
        ListTile(
          leading: Icon(cancelled ? Icons.restore : Icons.event_busy_outlined),
          title: Text(cancelled ? l.restoreMeeting : l.cancelMeeting),
          onTap: () => run(() => schedule.setMeetingStatus(x.id, cancelled ? 'scheduled' : 'cancelled')),
        ),
      ]);
    },
  );
}

/// "Add" sheet: task or meeting (and log activity when [onLogActivity] is given).
Future<void> showAddSheet(
  BuildContext context, {
  required ScheduleRepository schedule,
  required ContactsRepository contacts,
  int? contactId,
  VoidCallback? onLogActivity,
  VoidCallback? onNewDeal,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showGlassSheet<String>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      _sheetTitle(l.addSheetTitle),
      if (onLogActivity != null)
        ListTile(
          leading: const Icon(Icons.history_edu_outlined),
          title: Text(l.logActivity),
          onTap: () => Navigator.of(ctx).pop('log'),
        ),
      if (onNewDeal != null)
        ListTile(
          leading: const Icon(Icons.paid_outlined),
          title: Text(l.addDeal),
          onTap: () => Navigator.of(ctx).pop('deal'),
        ),
      ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(l.addTask),
        onTap: () => Navigator.of(ctx).pop('task'),
      ),
      ListTile(
        leading: const Icon(Icons.groups_outlined),
        title: Text(l.addMeeting),
        onTap: () => Navigator.of(ctx).pop('meeting'),
      ),
    ]),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'log') {
    onLogActivity?.call();
  } else if (choice == 'deal') {
    onNewDeal?.call();
  } else if (choice == 'task') {
    final id = await showQuickTask(context, schedule: schedule, contacts: contacts, contactId: contactId);
    if (id != null && id > 0) messenger.showSnackBar(SnackBar(content: Text(l.taskSaved)));
  } else {
    final id = await Navigator.of(context)
        .push<int>(MaterialPageRoute(builder: (_) => MeetingFormPage(schedule: schedule, contacts: contacts, contactId: contactId)));
    if (id != null && id > 0) messenger.showSnackBar(SnackBar(content: Text(l.meetingSaved)));
  }
}
