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
  const ScheduleRow({super.key, required this.item, required this.onTap, this.onToggle, this.showDate = false, this.flat = false, this.plain = false});
  final ScheduleItem item;
  final VoidCallback onTap;

  /// Check button tap for tasks.
  final VoidCallback? onToggle;
  final bool showDate;

  /// No card around the row, for use inside a grouped card.
  final bool flat;

  /// Calendar style: no trailing tag or check button, type icons and the longer sub line.
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final dayN = dayOnly(item.at).difference(dayOnly(DateTime.now())).inDays;
    final dayText = dayN == 0 ? l.relToday : (dayN == 1 ? l.relTomorrow : (dayN == -1 ? l.relYesterday : formatDayShort(context, item.at)));
    final timeText = item.kind == ScheduleKind.event ? l.allDay : (item.hasTime ? formatClock(context, item.at) : '');
    final when = showDate ? [dayText, if (timeText.isNotEmpty) timeText].join(', ') : timeText;
    final String sub;
    if (plain) {
      final end = item.kind == ScheduleKind.meeting && item.endAt != null ? l.timeRange(formatClock(context, item.at), formatClock(context, item.endAt!)) : null;
      sub = [
        if (item.overdue) l.sectionOverdue,
        if (end != null) end else if (when.isNotEmpty) when,
        if (item.kind == ScheduleKind.meeting && item.meetingType != null && item.meetingType != MeetingType.inPerson) meetingTypeLabel(l, item.meetingType!),
        if (item.kind == ScheduleKind.task && item.priority == Priority.high) priorityLabel(l, Priority.high),
        if (item.contactLabel != null) item.contactLabel!,
      ].join(' · ');
    } else {
      sub = [if (when.isNotEmpty) when, if (item.contactLabel != null) item.contactLabel!].join(' · ');
    }
    final struck = item.done || item.cancelled;
    final icon = switch (item.kind) {
      ScheduleKind.task => plain ? Icons.check_box_outlined : Icons.task_alt_outlined,
      ScheduleKind.meeting => meetingTypeIcon(item.meetingType ?? MeetingType.inPerson),
      ScheduleKind.event => plain ? Icons.card_giftcard_outlined : Icons.cake_outlined,
    };
    final row = InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 14, 11),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: item.kind == ScheduleKind.event && plain ? const Color(0xFF2E7D5B) : (item.overdue && !plain ? p.error : p.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 21 / 15,
                  fontWeight: FontWeight.w500,
                  decoration: struck ? TextDecoration.lineThrough : null,
                  color: struck ? p.text2 : p.text,
                ),
              ),
              if (sub.isNotEmpty || item.cancelled)
                Padding(
                  padding: EdgeInsets.zero,
                  child: Text(
                    item.cancelled ? '${l.meetingCancelled}${sub.isEmpty ? '' : ' · $sub'}' : sub,
                    style: TextStyle(fontSize: 13, height: 18 / 13, color: item.overdue && !plain ? p.error : p.text2),
                  ),
                ),
            ]),
          ),
          if (plain) const SizedBox.shrink() else if (item.kind == ScheduleKind.task)
            Tooltip(
              message: item.done ? l.reopenTask : l.markDone,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onToggle,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: item.done ? p.primary : p.surface2),
                  child: Icon(Icons.check, size: 20, color: item.done ? p.onPrimary : p.primary),
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
      child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
