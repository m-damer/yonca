import 'package:intl/intl.dart' show DateFormat;

/// Look choices that formatting code reads (set by the app controller).
class Look {
  static bool levantMonths = false;
}

const _standard = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const _levant = ['كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران', 'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول'];

/// Replaces standard Arabic month names with the Levant names (كانون الثاني, شباط, …).
String levantMonthNames(String s) {
  var out = s;
  for (var i = 0; i < 12; i++) {
    out = out.replaceAll(_standard[i], _levant[i]);
  }
  return out;
}

/// Formats a date; uses the Levant month names when that choice is on and the text is Arabic.
String dfmt(DateFormat f, DateTime d) {
  final s = westernDigits(f.format(d));
  return Look.levantMonths && f.locale.startsWith('ar') ? levantMonthNames(s) : s;
}

/// Arabic-Indic digits (٠-٩, ۰-۹) as Western digits; the Indic-digits choice is drawn by the font instead.
String westernDigits(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x0660 && r <= 0x0669) {
      b.writeCharCode(r - 0x0660 + 0x30);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      b.writeCharCode(r - 0x06F0 + 0x30);
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}
