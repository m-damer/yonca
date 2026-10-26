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
