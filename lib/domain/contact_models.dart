import '../data/app_database.dart';

enum Rating { none, hot, warm, cold }

enum Role { lead, client, supplier }

enum ContactSort { name, recentlyAdded, recentActivity, needsAttention, ratingHot, longestIdle }

/// Days without activity before a contact needs attention (docs/DESIGN.md defaults).
const inactivityDays = {
  Rating.hot: 7,
  Rating.warm: 14,
  Rating.cold: 30,
  Rating.none: 30,
};

Rating ratingFromName(String s) =>
    Rating.values.firstWhere((r) => r.name == s, orElse: () => Rating.none);

class PhoneInput {
  const PhoneInput({
    required this.number,
    this.countryCode = '+963',
    this.label = 'mobile',
    this.isWhatsApp = false,
  });
  final String number;
  final String countryCode;
  final String label;
  final bool isWhatsApp;
}

/// An email, website or address with its type (work, home or other).
/// [mapLink] is only used by addresses.
class EntryInput {
  const EntryInput({required this.value, this.label = 'work', this.mapLink = ''});
  final String value;
  final String label;
  final String mapLink;
}

/// A dated event of a contact (for example "Birthday"), optionally repeating every year.
class EventInput {
  const EventInput({required this.title, required this.date, this.yearly = true});
  final String title;
  final DateTime date;
  final bool yearly;
}

class ContactValidationException implements Exception {
  const ContactValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ContactInput {
  const ContactInput({
    this.firstName = '',
    this.lastName = '',
    this.company = '',
    this.prefix = '',
    this.nickname = '',
    this.jobTitle = '',
    this.department = '',
    this.emails = const [],
    this.websites = const [],
    this.addresses = const [],
    this.events = const [],
    this.requirements = '',
    this.temporaryNote = '',
    this.rating = Rating.none,
    this.photoPath,
    this.phones = const [],
    this.roles = const [],
    this.tags = const [],
  });

  final String firstName;
  final String lastName;
  final String company;
  final String prefix;
  final String nickname;
  final String jobTitle;
  final String department;
  final List<EntryInput> emails;
  final List<EntryInput> websites;
  final List<EntryInput> addresses;
  final List<EventInput> events;
  final String requirements;
  final String temporaryNote;
  final Rating rating;
  final String? photoPath;
  final List<PhoneInput> phones;
  final List<Role> roles;
  final List<String> tags;

  /// At least one of first name, last name, company or a phone number is required.
  void validate() {
    final hasPhone = phones.any((p) => p.number.trim().isNotEmpty);
    if (firstName.trim().isEmpty && lastName.trim().isEmpty && company.trim().isEmpty && !hasPhone) {
      throw const ContactValidationException('name_required');
    }
  }
}

/// What a list row or the details header shows.
class ContactSummary {
  const ContactSummary({
    required this.contact,
    required this.phones,
    required this.roles,
    required this.tags,
    this.entries = const [],
    this.events = const [],
  });

  final Contact contact;
  final List<ContactPhone> phones;
  final List<Role> roles;
  final List<Tag> tags;
  final List<ContactEntry> entries;
  final List<ContactEvent> events;

  List<ContactEntry> get emails => entries.where((e) => e.kind == 'email').toList();
  List<ContactEntry> get websites => entries.where((e) => e.kind == 'website').toList();
  List<ContactEntry> get addresses => entries.where((e) => e.kind == 'address').toList();

  /// Person name, else company, else the first phone number as typed.
  String get displayName {
    final n = contactDisplayName(contact);
    if (n.isNotEmpty) return n;
    return phones.isEmpty ? '' : phones.first.number;
  }

  /// True when the contact has neither a person name nor a company (only a number).
  bool get isIncomplete => contactDisplayName(contact).isEmpty;
}

/// "First Last", or the company when no person name is given.
String contactDisplayName(Contact c) {
  final person = '${c.firstName} ${c.lastName}'.trim();
  return person.isNotEmpty ? person : c.company;
}
