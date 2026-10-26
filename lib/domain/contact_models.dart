import '../data/app_database.dart';

enum Rating { none, hot, warm, cold }

enum Role { lead, client, supplier }

enum ContactSort { name, recentlyAdded, recentActivity, needsAttention }

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
    this.nickname = '',
    this.jobTitle = '',
    this.email = '',
    this.website = '',
    this.address = '',
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
  final String nickname;
  final String jobTitle;
  final String email;
  final String website;
  final String address;
  final String requirements;
  final String temporaryNote;
  final Rating rating;
  final String? photoPath;
  final List<PhoneInput> phones;
  final List<Role> roles;
  final List<String> tags;

  /// At least one of first name, last name or company is required.
  void validate() {
    if (firstName.trim().isEmpty && lastName.trim().isEmpty && company.trim().isEmpty) {
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
  });

  final Contact contact;
  final List<ContactPhone> phones;
  final List<Role> roles;
  final List<Tag> tags;

  String get displayName => contactDisplayName(contact);
}

/// "First Last", or the company when no person name is given.
String contactDisplayName(Contact c) {
  final person = '${c.firstName} ${c.lastName}'.trim();
  return person.isNotEmpty ? person : c.company;
}
