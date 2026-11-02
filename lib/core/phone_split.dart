import 'countries.dart';

/// Splits a phone number as found in a phone book or vCard into (country code, national number).
/// "+963 944 123 456" gives ("+963", "944 123 456"); "0944 123 456" gets [defaultCode];
/// an unknown international code keeps the whole number with an empty code.
(String, String) splitPhone(String raw, {String defaultCode = '+963'}) {
  var s = raw.trim();
  if (s.startsWith('00')) s = '+${s.substring(2)}';
  if (!s.startsWith('+')) return (defaultCode, s);
  final compact = s.replaceAll(RegExp(r'[\s\-().]'), '');
  for (final c in kDialCodes) {
    if (compact.startsWith(c)) {
      final rest = compact.substring(c.length);
      return (c, rest);
    }
  }
  return ('', compact);
}
