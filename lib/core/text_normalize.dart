/// Search and sort normalisation (docs/DESIGN.md, section E, Arabic rules).
/// Also used for filters and duplicate matching.
library;

const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
const _persianIndic = '۰۱۲۳۴۵۶۷۸۹';

bool _isDiacritic(int c) => (c >= 0x064B && c <= 0x065F) || c == 0x0670;

/// Lower-cases Latin text; treats أ إ آ ٱ ا as one letter, ى ي as one, ة ه as one;
/// removes diacritics and tatweel; turns Arabic-Indic digits into 0-9; trims and collapses spaces.
String normalizeText(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    if (_isDiacritic(rune) || rune == 0x0640) continue;
    var ch = String.fromCharCode(rune);
    switch (ch) {
      case 'أ':
      case 'إ':
      case 'آ':
      case 'ٱ':
        ch = 'ا';
      case 'ى':
        ch = 'ي';
      case 'ة':
        ch = 'ه';
      default:
        final a = _arabicIndic.indexOf(ch);
        final p = _persianIndic.indexOf(ch);
        if (a >= 0) {
          ch = '$a';
        } else if (p >= 0) {
          ch = '$p';
        }
    }
    out.write(ch);
  }
  return out.toString().toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Key used to order names: normalised, with a leading "ال" article ignored.
String sortKeyOf(String name) {
  final n = normalizeText(name);
  if (n.length > 2 && n.startsWith('ال')) return n.substring(2).trimLeft();
  return n;
}

bool isArabicLetter(int rune) => rune >= 0x0621 && rune <= 0x064A;

/// Group a sort key belongs to: 'arabic', 'latin' or 'other' (digits and symbols).
String scriptGroupOf(String sortKey) {
  if (sortKey.isEmpty) return 'other';
  final r = sortKey.runes.first;
  if (isArabicLetter(r)) return 'arabic';
  if (r >= 0x61 && r <= 0x7A) return 'latin';
  return 'other';
}

/// Alphabet-scroller section for a sort key: the letter itself, or '#'.
String sectionOf(String sortKey) {
  final g = scriptGroupOf(sortKey);
  if (g == 'other') return '#';
  final first = String.fromCharCode(sortKey.runes.first);
  return g == 'latin' ? first.toUpperCase() : first;
}

/// Compares two sort keys: Arabic names before English ones when [arabicFirst], and the
/// other way round otherwise; digits and symbols always last.
int compareSortKeys(String a, String b, {required bool arabicFirst}) {
  int rank(String k) {
    switch (scriptGroupOf(k)) {
      case 'arabic':
        return arabicFirst ? 0 : 1;
      case 'latin':
        return arabicFirst ? 1 : 0;
      default:
        return 2;
    }
  }

  final r = rank(a).compareTo(rank(b));
  return r != 0 ? r : a.compareTo(b);
}

/// Digits only, from a country code such as "+963" and a number typed by the user.
/// A number that starts with "+" or "00" is taken as already international.
/// Leading zeros of the national number are dropped, so "0944 123 456" and
/// "+963 944 123 456" match.
String normalizePhone(String countryCode, String number) {
  String digits(String s) {
    final b = StringBuffer();
    for (final r in normalizeText(s).runes) {
      if (r >= 0x30 && r <= 0x39) b.writeCharCode(r);
    }
    return b.toString();
  }

  final trimmed = number.trim();
  var cc = digits(countryCode);
  var n = digits(trimmed);
  if (trimmed.startsWith('+')) return n;
  if (n.startsWith('00')) return n.substring(2);
  n = n.replaceFirst(RegExp(r'^0+'), '');
  return '$cc$n';
}
