import '../data/app_database.dart';

enum ActivityType { call, visit, message, note }

ActivityType activityTypeFromName(String s) =>
    ActivityType.values.firstWhere((t) => t.name == s, orElse: () => ActivityType.note);

/// Built-in outcome keys, in their default order.
const defaultOutcomeKeys = ['interested', 'needsTime', 'notInterested', 'noAnswer'];

/// At most this many outcomes can be active at once.
const maxActiveOutcomes = 8;

class ActivityFileInput {
  const ActivityFileInput({required this.path, required this.name, this.isImage = false});
  final String path;
  final String name;
  final bool isImage;
}

class ActivityInput {
  const ActivityInput({
    required this.type,
    this.contactId,
    required this.occurredAt,
    this.direction = '',
    this.durationMinutes,
    this.place = '',
    this.mapLink = '',
    this.channel = '',
    this.outcomeId,
    this.title = '',
    this.description = '',
    this.voicePath,
    this.voiceMs = 0,
    this.files = const [],
  });

  final ActivityType type;
  final int? contactId;
  final DateTime occurredAt;
  final String direction;
  final int? durationMinutes;
  final String place;
  final String mapLink;
  final String channel;
  final int? outcomeId;
  final String title;
  final String description;
  final String? voicePath;
  final int voiceMs;
  final List<ActivityFileInput> files;

  /// Why this activity cannot be saved yet, or null. Keys match the form's error texts.
  String? problem() {
    if (type != ActivityType.note && contactId == null) return 'contact';
    if (type == ActivityType.note && title.trim().isEmpty) return 'title';
    if ((type == ActivityType.call || type == ActivityType.visit) && outcomeId == null) return 'outcome';
    return null;
  }
}

class ActivityValidationException implements Exception {
  const ActivityValidationException(this.problem);
  final String problem;
  @override
  String toString() => problem;
}

/// An activity with what a card or the detail sheet needs.
class ActivityItem {
  const ActivityItem({
    required this.activity,
    this.outcome,
    this.contactName,
    this.files = const [],
  });
  final Activity activity;
  final Outcome? outcome;
  final String? contactName;
  final List<ActivityFile> files;

  ActivityType get type => activityTypeFromName(activity.type);
}

/// One file in a contact's Files tab, with the activity it came from.
class ContactFileItem {
  const ContactFileItem({required this.file, required this.activity});
  final ActivityFile file;
  final Activity activity;
}
