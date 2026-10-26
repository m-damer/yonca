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
    this.emailLabel = 'work',
    this.websiteLabel = 'work',
    this.addressLabel = 'work',
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
  final String emailLabel;
  final String websiteLabel;
  final String addressLabel;
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
  });

  final Contact contact;
  final List<ContactPhone> phones;
  final List<Role> roles;
  final List<Tag> tags;

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
