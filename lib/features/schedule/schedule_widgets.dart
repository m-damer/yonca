import 'event_form_page.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/contacts_repository.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../settings/settings_widgets.dart';
import 'meeting_form_page.dart';
import 'schedule_labels.dart';
import 'schedule_view_pages.dart';
import 'quick_task_sheet.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

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
    final dayText = dayN == 0 ? l.quickToday : (dayN == 1 ? l.quickTomorrow : (dayN == -1 ? '${l.relYesterday[0].toUpperCase()}${l.relYesterday.substring(1)}' : formatDayShort(context, item.at)));
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
      ScheduleKind.task => plain ? Lu.squareCheckBig : Lu.circleCheck,
      ScheduleKind.meeting => meetingTypeIcon(item.meetingType ?? MeetingType.inPerson),
      ScheduleKind.event => plain ? Lu.gift : Lu.cake,
    };
    final row = InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
        child: Row(children: [
          Container(
            width: AppSize.s36,
            height: AppControl.md,
            decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(icon, size: AppIcon.md, color: item.kind == ScheduleKind.event && plain ? p.calEvent : (item.overdue && !plain ? p.error : p.primary)),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFont.body,
                  height: AppLine.normal,
                  fontWeight: AppWeight.medium,
                  decoration: struck ? TextDecoration.lineThrough : null,
                  color: struck ? p.text2 : p.text,
                ),
              ),
              if (sub.isNotEmpty || item.cancelled)
                Padding(
                  padding: EdgeInsets.zero,
                  child: Text(
                    item.cancelled ? '${l.meetingCancelled}${sub.isEmpty ? '' : ' · $sub'}' : sub,
                    style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: item.overdue && !plain ? p.error : p.text2),
                  ),
                ),
            ]),
          ),
          if (plain) const SizedBox.shrink() else if (item.kind == ScheduleKind.task)
            Tooltip(
              message: item.done ? l.reopenTask : l.markDone,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: onToggle,
                child: Container(
                  width: AppSize.s36,
                  height: AppControl.md,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), color: item.done ? p.primary : p.surface2),
                  child: Icon(Lu.check, size: AppIcon.md, color: item.done ? p.onPrimary : p.primary),
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
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
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
      await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => EventFormPage(schedule: schedule, contacts: contacts, id: item.id)));
      return true;
  }
}

/// Summary of a calendar item with a button that opens the full page (design K2).
Future<bool> showItemSheet(
  BuildContext context, {
  required ScheduleItem item,
  required ScheduleRepository schedule,
  required ContactsRepository contacts,
}) async {
  final l = AppLocalizations.of(context);
  final isMeeting = item.kind == ScheduleKind.meeting;
  final isTask = item.kind == ScheduleKind.task;
  final meeting = isMeeting ? await schedule.getMeeting(item.id) : null;
  final task = isTask ? await schedule.getTask(item.id) : null;
  if (!context.mounted) return false;
  final m = meeting?.meeting;
  final kind = isMeeting ? l.kindMeeting : (isTask ? l.kindTask : l.kindEvent);
  final detail = isMeeting
      ? meetingTypeLabel(l, meetingTypeFromName(m!.type))
      : (isTask && task != null ? priorityLabel(l, priorityFromName(task.priority)) : null);
  final when = isMeeting
      ? l.meetingTo('${formatDay(context, item.at)} · ${formatClock(context, item.at)}', formatClock(context, item.at.add(Duration(minutes: m!.durationMinutes))))
      : '${formatDay(context, item.at)}${item.hasTime ? ' · ${formatClock(context, item.at)}' : ''}';
  final reminder = isMeeting
      ? (m!.reminderMinutes == null
          ? null
          : l.reminderSummary(reminderLabel(l, m.reminderMinutes, hasTime: true), m.alarm ? l.reminderTypeAlarm : l.reminderTypeNotification))
      : (task?.reminderMinutes == null
          ? null
          : l.reminderSummary(reminderLabel(l, task!.reminderMinutes, hasTime: item.hasTime), task.alarm ? l.reminderTypeAlarm : l.reminderTypeNotification));
  final contactsText = item.contactNames.isNotEmpty ? item.contactNames.join(', ') : (meeting?.contactNames.join(', ') ?? '');
  final place = (m != null && m.type == MeetingType.inPerson.name) ? m.place : '';
  final opened = await showGlassSheet<bool>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(item.title),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.sm),
        child: Text(detail == null ? kind : '$kind · $detail', style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, color: ctx.palette.text2)),
      ),
      SettingsGroup(children: [
        SettingsRow(icon: Lu.clock, title: when, subtitle: reminder),
        if (contactsText.isNotEmpty) SettingsRow(icon: Lu.user, title: contactsText),
        if (place.isNotEmpty)
          SettingsRow(
            icon: Lu.mapPin,
            title: place,
            subtitle: l.opensInMaps,
            onTap: () => launchUrl(Uri.parse('geo:0,0?q=${Uri.encodeComponent(place)}'), mode: LaunchMode.externalApplication),
          ),
      ]),
      const SizedBox(height: AppSpace.md),
      PillButton(
        label: isMeeting ? l.openMeeting : l.openTask,
        height: AppControl.lg,
        onPressed: () => Navigator.of(ctx).pop(true),
      ),
    ]),
  );
  if (opened != true || !context.mounted) return false;
  return openScheduleItem(context, item: item, schedule: schedule, contacts: contacts);
}

/// "Add" sheet (design H5, K3): the rows depend on where it is opened.
Future<void> showAddSheet(
  BuildContext context, {
  required ScheduleRepository schedule,
  required ContactsRepository contacts,
  int? contactId,
  DateTime? day,
  VoidCallback? onNewContact,
  VoidCallback? onLogActivity,
  VoidCallback? onNewDeal,
  VoidCallback? onScanQr,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  Widget row(BuildContext ctx, IconData icon, String title, String key, bool first) => SheetItem(
        first: first,
        icon: icon,
        iconSize: 44,
        title: title,
        vpad: AppSpace.rowS,
        onTap: () => Navigator.of(ctx).pop(key),
      );
  final choice = await showGlassSheet<String>(
    context,
    builder: (ctx) {
      final rows = <(IconData, String, String)>[
        if (onNewContact != null) (Lu.users, l.newContact, 'contact'),
        if (onLogActivity != null) (Lu.pencil, l.logActivity, 'log'),
        if (onNewDeal != null) (Lu.banknote, l.addDeal, 'deal'),
        if (day == null) (Lu.calendar, l.addMeeting, 'meeting'),
        (Lu.squareCheckBig, l.addTask, 'task'),
        if (day != null) (Lu.calendar, l.addMeeting, 'meeting'),
        if (day != null) (Lu.gift, l.addEventRow, 'event'),
        if (onScanQr != null) (Lu.qrCode, l.scanQr, 'scan'),
      ];
      if (day != null) {
        const order = {'task': 0, 'meeting': 1, 'event': 2};
        rows.sort((a, b) => (order[a.$3] ?? 3).compareTo(order[b.$3] ?? 3));
      }
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetOverline(day == null ? l.add : l.addOnDay(formatDayShort(ctx, day))),
        for (var i = 0; i < rows.length; i++) row(ctx, rows[i].$1, rows[i].$2, rows[i].$3, i == 0),
      ]);
    },
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'contact') {
    onNewContact?.call();
  } else if (choice == 'log') {
    onLogActivity?.call();
  } else if (choice == 'deal') {
    onNewDeal?.call();
  } else if (choice == 'scan') {
    onScanQr?.call();
  } else if (choice == 'task') {
    final id = await showQuickTask(context, schedule: schedule, contacts: contacts, contactId: contactId, day: day);
    if (id != null && id > 0) messenger.showSnackBar(SnackBar(content: Text(l.taskSaved)));
  } else if (choice == 'event') {
    await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => EventFormPage(schedule: schedule, contacts: contacts, contactId: contactId, day: day)));
  } else {
    final id = await Navigator.of(context)
        .push<int>(MaterialPageRoute(builder: (_) => MeetingFormPage(schedule: schedule, contacts: contacts, contactId: contactId, day: day)));
    if (id != null && id > 0) messenger.showSnackBar(SnackBar(content: Text(l.meetingSaved)));
  }
}
