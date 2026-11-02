import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import 'countries.dart';

IsoCode? _iso(String code) {
  final c = countryForCode(code);
  if (c == null) return null;
  for (final i in IsoCode.values) {
    if (i.name == c.iso) return i;
  }
  return null;
}

/// Reads a typed number for the chosen dial code (national form such as "0944 123 456" is fine).
/// Null when it cannot be read.
PhoneNumber? parsePhone(String code, String number) {
  final raw = number.trim();
  if (raw.isEmpty) return null;
  try {
    if (raw.startsWith('+')) return PhoneNumber.parse(raw);
    final iso = _iso(code);
    if (iso != null) return PhoneNumber.parse(raw, destinationCountry: iso);
    return PhoneNumber.parse('$code$raw');
  } catch (_) {
    return null;
  }
}

/// True when a typed number is not a valid number for the country: wrong length or a start that
/// country does not use. An empty field is never invalid (a contact may have no phone).
bool phoneInvalid(String code, String number) {
  if (number.trim().isEmpty) return false;
  final p = parsePhone(code, number);
  if (p == null) return number.replaceAll(RegExp(r'\D'), '').length < 7;
  return !p.isValid();
}

/// The national number the way people write it in that country, or the text as typed.
String formatPhone(String code, String number) {
  final p = parsePhone(code, number);
  if (p == null || !p.isValid()) return number;
  try {
    return p.formatNsn();
  } catch (_) {
    return number;
  }
}
