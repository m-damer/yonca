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
  final s = f.format(d);
  return Look.levantMonths && f.locale.startsWith('ar') ? levantMonthNames(s) : s;
}
