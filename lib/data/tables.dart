import 'package:drift/drift.dart';

class Contacts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get firstName => text().withDefault(const Constant(''))();
  TextColumn get lastName => text().withDefault(const Constant(''))();
  TextColumn get company => text().withDefault(const Constant(''))();
  TextColumn get prefix => text().withDefault(const Constant(''))();
  TextColumn get department => text().withDefault(const Constant(''))();
  TextColumn get nickname => text().withDefault(const Constant(''))();
  TextColumn get jobTitle => text().withDefault(const Constant(''))();
  // email, website, address and their labels below are the pre-v4 single values; since v4 they live in ContactEntries.
  TextColumn get email => text().withDefault(const Constant(''))();
  TextColumn get website => text().withDefault(const Constant(''))();
  TextColumn get address => text().withDefault(const Constant(''))();

  /// work, home or other: the type shown next to the email, website and address.
  TextColumn get emailLabel => text().withDefault(const Constant('work'))();
  TextColumn get websiteLabel => text().withDefault(const Constant('work'))();
  TextColumn get addressLabel => text().withDefault(const Constant('work'))();
  TextColumn get requirements => text().withDefault(const Constant(''))();
  TextColumn get temporaryNote => text().withDefault(const Constant(''))();

  /// none, hot, warm or cold.
  TextColumn get rating => text().withDefault(const Constant('none'))();
  TextColumn get photoPath => text().nullable()();

  /// Set when the user edits the automatic status line by hand.
  TextColumn get statusOverride => text().nullable()();

  /// Normalised name used to order the list.
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// Normalised text of everything searchable on the contact.
  TextColumn get searchText => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastActivityAt => dateTime().nullable()();
}

class ContactPhones extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contactId =>
      integer().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get countryCode => text().withDefault(const Constant('+963'))();
  TextColumn get number => text()();
  TextColumn get label => text().withDefault(const Constant('mobile'))();

  /// Digits only, country code included. Used for duplicate checks and search.
  TextColumn get normalized => text()();
  BoolColumn get isWhatsApp => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();
}

/// Extra emails, websites and addresses of a contact (a contact can have several of each).
class ContactEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contactId =>
      integer().references(Contacts, #id, onDelete: KeyAction.cascade)();

  /// email, website or address.
  TextColumn get kind => text()();
  TextColumn get value => text()();

  /// work, home or other.
  TextColumn get label => text().withDefault(const Constant('work'))();

  /// Addresses only: a link (for example a Google Maps share link) the map action opens.
  TextColumn get mapLink => text().withDefault(const Constant(''))();
  IntColumn get position => integer().withDefault(const Constant(0))();
}

/// A dated event of a contact, for example a birthday. Alerts arrive with the Calendar (M3).
class ContactEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contactId =>
      integer().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  DateTimeColumn get date => dateTime()();

  /// Repeats every year on the same day.
  BoolColumn get yearly => boolean().withDefault(const Constant(true))();
  IntColumn get position => integer().withDefault(const Constant(0))();
}

/// The shared list of call, visit and message outcomes (chips in the Log activity form).
class Outcomes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Shown as is for custom outcomes; empty for built-in ones (their name comes from [key]).
  TextColumn get name => text().withDefault(const Constant(''))();

  /// interested, needsTime, notInterested or noAnswer for built-in outcomes; null for custom ones.
  TextColumn get key => text().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// A call, visit, message or note. [contactId] is null only for a general note.
class Activities extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// call, visit, message or note.
  TextColumn get type => text()();
  IntColumn get contactId =>
      integer().nullable().references(Contacts, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get occurredAt => dateTime()();

  /// Call: in or out. Message: sent or received. Empty otherwise.
  TextColumn get direction => text().withDefault(const Constant(''))();
  IntColumn get durationMinutes => integer().nullable()();
  TextColumn get place => text().withDefault(const Constant(''))();
  TextColumn get mapLink => text().withDefault(const Constant(''))();

  /// Message only: whatsapp or email.
  TextColumn get channel => text().withDefault(const Constant(''))();
  IntColumn get outcomeId => integer().nullable().references(Outcomes, #id)();

  /// Notes only.
  TextColumn get title => text().withDefault(const Constant(''))();

  /// The description (for a note: its text).
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get voicePath => text().nullable()();
  IntColumn get voiceMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

/// A file or photo attached to an activity.
class ActivityFiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get activityId =>
      integer().references(Activities, #id, onDelete: KeyAction.cascade)();
  TextColumn get path => text()();
  TextColumn get name => text()();
  BoolColumn get isImage => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();
}

/// A to-do. [dueAt] is midnight of the due day when [hasTime] is false.
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  IntColumn get contactId =>
      integer().nullable().references(Contacts, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get dueAt => dateTime()();
  BoolColumn get hasTime => boolean().withDefault(const Constant(false))();

  /// high, normal or low.
  TextColumn get priority => text().withDefault(const Constant('normal'))();

  /// Minutes before the due time; null = no reminder. Date-only tasks remind at 9:00 on the day.
  IntColumn get reminderMinutes => integer().nullable()();

  /// Alarm (strong alert) instead of a plain notification.
  BoolColumn get alarm => boolean().withDefault(const Constant(true))();

  /// none, daily, weekly or monthly.
  TextColumn get repeat => text().withDefault(const Constant('none'))();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get doneAt => dateTime().nullable()();

  /// The reminder moved here by Snooze.
  DateTimeColumn get snoozedUntil => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class Meetings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get startAt => dateTime()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(60))();

  /// inPerson, phone or video.
  TextColumn get type => text().withDefault(const Constant('inPerson'))();
  TextColumn get place => text().withDefault(const Constant(''))();

  /// A map link (in person) or a video link.
  TextColumn get link => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get reminderMinutes => integer().nullable()();
  BoolColumn get alarm => boolean().withDefault(const Constant(true))();
  TextColumn get repeat => text().withDefault(const Constant('none'))();

  /// scheduled, cancelled or held.
  TextColumn get status => text().withDefault(const Constant('scheduled'))();
  DateTimeColumn get createdAt => dateTime()();
}

class MeetingContacts extends Table {
  IntColumn get meetingId =>
      integer().references(Meetings, #id, onDelete: KeyAction.cascade)();
  IntColumn get contactId =>
      integer().references(Contacts, #id, onDelete: KeyAction.cascade)();

  /// 0 is the main contact.
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {meetingId, contactId};
}

class ContactRoles extends Table {
  IntColumn get contactId =>
      integer().references(Contacts, #id, onDelete: KeyAction.cascade)();

  /// lead, client or supplier.
  TextColumn get role => text()();

  @override
  Set<Column> get primaryKey => {contactId, role};
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Normalised name; unique so "Solar" and "solar" are one tag.
  TextColumn get nameKey => text().unique()();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
}

class ContactTags extends Table {
  IntColumn get contactId =>
      integer().references(Contacts, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {contactId, tagId};
}
