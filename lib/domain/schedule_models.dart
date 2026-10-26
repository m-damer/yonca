import '../data/app_database.dart';

enum Priority { high, normal, low }

enum Repeat { none, daily, weekly, monthly }

enum MeetingType { inPerson, phone, video }

enum ScheduleKind { task, meeting, event }

Priority priorityFromName(String s) => Priority.values.firstWhere((p) => p.name == s, orElse: () => Priority.normal);
Repeat repeatFromName(String s) => Repeat.values.firstWhere((p) => p.name == s, orElse: () => Repeat.none);
MeetingType meetingTypeFromName(String s) =>
    MeetingType.values.firstWhere((p) => p.name == s, orElse: () => MeetingType.inPerson);

/// Date-only tasks remind at this hour on the due day.
const dateOnlyReminderHour = 9;

/// Moves [d] one repeat step forward (monthly keeps the day, or the last day of a shorter month).
DateTime nextOccurrence(DateTime d, Repeat r) {
  switch (r) {
    case Repeat.none:
      return d;
    case Repeat.daily:
      return DateTime(d.year, d.month, d.day + 1, d.hour, d.minute);
    case Repeat.weekly:
      return DateTime(d.year, d.month, d.day + 7, d.hour, d.minute);
    case Repeat.monthly:
      final lastDay = DateTime(d.year, d.month + 2, 0).day;
      final day = d.day > lastDay ? lastDay : d.day;
      return DateTime(d.year, d.month + 1, day, d.hour, d.minute);
  }
}

class TaskInput {
  const TaskInput({
    required this.title,
    this.contactId,
    required this.dueAt,
    this.hasTime = false,
    this.priority = Priority.normal,
    this.reminderMinutes = 60,
    this.alarm = true,
    this.repeat = Repeat.none,
    this.description = '',
  });
  final String title;
  final int? contactId;
  final DateTime dueAt;
  final bool hasTime;
  final Priority priority;
  final int? reminderMinutes;
  final bool alarm;
  final Repeat repeat;
  final String description;

  String? problem() => title.trim().isEmpty ? 'title' : null;
}

class MeetingInput {
  const MeetingInput({
    required this.title,
    this.contactIds = const [],
    required this.startAt,
    this.durationMinutes = 60,
    this.type = MeetingType.inPerson,
    this.place = '',
    this.link = '',
    this.description = '',
    this.reminderMinutes = 60,
    this.alarm = true,
    this.repeat = Repeat.none,
  });
  final String title;
  final List<int> contactIds;
  final DateTime startAt;
  final int durationMinutes;
  final MeetingType type;
  final String place;
  final String link;
  final String description;
  final int? reminderMinutes;
  final bool alarm;
  final Repeat repeat;

  String? problem() {
    if (title.trim().isEmpty) return 'title';
    if (contactIds.length > 10) return 'contacts';
    return null;
  }
}

class ScheduleValidationException implements Exception {
  const ScheduleValidationException(this.problem);
  final String problem;
  @override
  String toString() => problem;
}

/// One thing on the calendar, in a form every screen can show.
class ScheduleItem {
  const ScheduleItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.at,
    this.hasTime = true,
    this.contactIds = const [],
    this.contactNames = const [],
    this.done = false,
    this.overdue = false,
    this.priority,
    this.meetingType,
    this.cancelled = false,
    this.endAt,
  });
  final ScheduleKind kind;
  final int id;
  final String title;
  final DateTime at;
  final bool hasTime;
  final List<int> contactIds;
  final List<String> contactNames;
  final bool done;
  final bool overdue;
  final Priority? priority;
  final MeetingType? meetingType;
  final bool cancelled;
  final DateTime? endAt;

  /// Main contact name plus "+2" when there are more.
  String? get contactLabel {
    if (contactNames.isEmpty) return null;
    return contactNames.length == 1 ? contactNames.first : '${contactNames.first} +${contactNames.length - 1}';
  }
}

class MeetingItem {
  const MeetingItem({required this.meeting, required this.contactIds, required this.contactNames});
  final Meeting meeting;
  final List<int> contactIds;
  final List<String> contactNames;
}

/// A notification or alarm to show at [at].
class ReminderSpec {
  const ReminderSpec({required this.id, required this.kind, required this.refId, required this.at, required this.title, required this.body, required this.alarm});
  final int id;

  /// `task`, `meeting` or `event`, and the id of that row.
  final String kind;
  final int refId;
  final DateTime at;
  final String title;
  final String body;
  final bool alarm;
}
