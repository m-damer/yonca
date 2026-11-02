import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import '../../core/phone_split.dart';
import '../../core/text_normalize.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';

enum PhoneBookResult { saved, exists, denied, failed }

fc.PhoneLabel _phoneLabel(String v) => switch (v) {
      'work' => fc.PhoneLabel.work,
      'home' => fc.PhoneLabel.home,
      'mobile' => fc.PhoneLabel.mobile,
      _ => fc.PhoneLabel.other,
    };

fc.EmailLabel _emailLabel(String v) => switch (v) {
      'work' => fc.EmailLabel.work,
      'home' => fc.EmailLabel.home,
      _ => fc.EmailLabel.other,
    };

/// Writes the contact to the phone's address book. Does nothing when a phone contact already
/// has one of the same numbers, so pressing it twice never makes a duplicate.
Future<PhoneBookResult> saveToPhoneBook(ContactSummary s, {List<fc.Contact>? existing}) async {
  try {
    if (!await fc.FlutterContacts.requestPermission(readonly: false)) return PhoneBookResult.denied;
    final onPhone = existing ?? await fc.FlutterContacts.getContacts(withProperties: true, withPhoto: false);
    final mine = {for (final p in s.phones) p.normalized};
    for (final c in onPhone) {
      for (final p in c.phones) {
        if (p.number.trim().isEmpty) continue;
        final (code, number) = splitPhone(p.number);
        if (mine.contains(normalizePhone(code, number))) return PhoneBookResult.exists;
      }
    }
    final c = s.contact;
    final photo = c.photoPath;
    final contact = fc.Contact(
      name: fc.Name(first: c.firstName, middle: c.middleName, last: c.lastName, prefix: c.prefix, suffix: c.suffix, nickname: c.nickname),
      phones: [for (final p in s.phones) fc.Phone('${p.countryCode}${p.number}', label: _phoneLabel(p.label))],
      emails: [for (final e in s.emails) fc.Email(e.value, label: _emailLabel(e.label))],
      websites: [for (final w in s.websites) fc.Website(w.value)],
      addresses: [for (final a in s.addresses) fc.Address(a.value)],
      organizations: [
        if (c.company.trim().isNotEmpty || c.jobTitle.trim().isNotEmpty || c.department.trim().isNotEmpty)
          fc.Organization(company: c.company, title: c.jobTitle, department: c.department),
      ],
      notes: [if (c.requirements.trim().isNotEmpty) fc.Note(c.requirements.trim())],
      photo: photo != null && File(photo).existsSync() ? await File(photo).readAsBytes() : null,
    );
    await fc.FlutterContacts.insertContact(contact);
    return PhoneBookResult.saved;
  } catch (_) {
    return PhoneBookResult.failed;
  }
}

/// Saves one or more contacts and shows a single message with the outcome.
Future<void> saveContactsToPhoneBook(BuildContext context, List<ContactSummary> list) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  var saved = 0, exists = 0, failed = 0;
  var denied = false;
  List<fc.Contact>? onPhone;
  if (list.length > 1) {
    try {
      if (await fc.FlutterContacts.requestPermission(readonly: false)) {
        onPhone = await fc.FlutterContacts.getContacts(withProperties: true, withPhoto: false);
      }
    } catch (_) {}
  }
  for (final s in list) {
    final r = await saveToPhoneBook(s, existing: onPhone);
    switch (r) {
      case PhoneBookResult.saved:
        saved++;
        if (onPhone != null) onPhone = [...onPhone, fc.Contact(phones: [for (final p in s.phones) fc.Phone('${p.countryCode}${p.number}')])];
      case PhoneBookResult.exists:
        exists++;
      case PhoneBookResult.denied:
        denied = true;
      case PhoneBookResult.failed:
        failed++;
    }
    if (denied) break;
  }
  final text = denied
      ? l.phoneBookDenied
      : saved > 0
          ? l.phoneBookSaved(saved, exists + failed)
          : exists > 0
              ? l.phoneBookExists
              : l.phoneBookFailed;
  messenger.showSnackBar(SnackBar(content: Text(text)));
}
