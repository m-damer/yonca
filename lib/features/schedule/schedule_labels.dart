import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';

String priorityLabel(AppLocalizations l, Priority p) => switch (p) {
      Priority.high => l.priorityHigh,
      Priority.normal => l.priorityNormal,
      Priority.low => l.priorityLow,
    };

String repeatLabel(AppLocalizations l, Repeat r) => switch (r) {
      Repeat.none => l.repeatNone,
      Repeat.daily => l.repeatDaily,
      Repeat.weekly => l.repeatWeekly,
      Repeat.monthly => l.repeatMonthly,
    };

String meetingTypeLabel(AppLocalizations l, MeetingType t) => switch (t) {
      MeetingType.inPerson => l.typeInPerson,
      MeetingType.phone => l.typePhone,
      MeetingType.video => l.typeVideo,
    };

IconData meetingTypeIcon(MeetingType t) => switch (t) {
      MeetingType.inPerson => Icons.groups_outlined,
      MeetingType.phone => Icons.phone_in_talk_outlined,
      MeetingType.video => Icons.videocam_outlined,
    };

IconData scheduleKindIcon(ScheduleItem i) => switch (i.kind) {
      ScheduleKind.task => i.done ? Icons.check_circle : Icons.radio_button_unchecked,
      ScheduleKind.meeting => meetingTypeIcon(i.meetingType ?? MeetingType.inPerson),
      ScheduleKind.event => Icons.cake_outlined,
    };

String scheduleKindLabel(AppLocalizations l, ScheduleKind k) => switch (k) {
      ScheduleKind.task => l.kindTask,
      ScheduleKind.meeting => l.kindMeeting,
      ScheduleKind.event => l.kindEvent,
    };

/// Reminder choices in minutes before the time; null means none.
List<int?> reminderChoices({required bool hasTime}) => hasTime ? const [null, 0, 5, 15, 30, 60, 1440] : const [null, 60];

String reminderLabel(AppLocalizations l, int? minutes, {required bool hasTime}) {
  if (minutes == null) return l.reminderNone;
  if (!hasTime) return l.reminderOnDay;
  if (minutes == 0) return l.reminderAtTime;
  if (minutes == 60) return l.reminderHourBefore;
  if (minutes == 1440) return l.reminderDayBefore;
  return l.reminderMinBefore(minutes);
}

String formatDay(BuildContext context, DateTime d) =>
    DateFormat.yMMMEd(Localizations.localeOf(context).toString()).format(d);

String formatClock(BuildContext context, DateTime d) =>
    DateFormat.jm(Localizations.localeOf(context).toString()).format(d);

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

Color priorityColor(YoncaPalette p, Priority? pr) => switch (pr) {
      Priority.high => p.error,
      Priority.low => p.text2,
      _ => p.primary,
    };

/// Sheet to pick one of the reminder choices.
Future<({int? value})?> pickReminder(BuildContext context, {required bool hasTime, required int? current}) {
  final l = AppLocalizations.of(context);
  return showGlassSheet<({int? value})>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(l.fieldReminder, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
      ),
      for (final c in reminderChoices(hasTime: hasTime))
        ListTile(
          title: Text(reminderLabel(l, c, hasTime: hasTime)),
          trailing: c == current ? const Icon(Icons.check) : null,
          onTap: () => Navigator.of(ctx).pop((value: c)),
        ),
    ]),
  );
}
