/// Titles that phones often store inside the given-name field ("Dr. Ahmad").
const _titles = <String>[
  'dr', 'prof', 'professor', 'eng', 'engr', 'mr', 'mrs', 'ms', 'miss', 'sir', 'madam', 'sheikh', 'sheikha', 'shaikh', 'hajj', 'haj', 'hajji', 'capt', 'col', 'gen', 'maj', 'lt', 'sgt', 'rev', 'fr', 'judge', 'arch', 'ing',
  'د', 'دكتور', 'الدكتور', 'دكتورة', 'الدكتورة', 'م', 'مهندس', 'المهندس', 'مهندسة', 'المهندسة', 'أ', 'ا', 'أستاذ', 'الأستاذ', 'استاذ', 'الاستاذ', 'أستاذة', 'الأستاذة', 'بروفيسور', 'البروفيسور', 'شيخ', 'الشيخ', 'حاج', 'الحاج', 'حاجة', 'الحاجة', 'سيد', 'السيد', 'سيدة', 'السيدة', 'عقيد', 'العقيد', 'لواء', 'اللواء', 'عميد', 'العميد', 'نقيب', 'النقيب', 'ملازم', 'الملازم', 'رائد', 'الرائد', 'مقدم', 'المقدم', 'القاضي', 'قاضي', 'الأخ', 'أخ',
];

/// Splits a leading title off [first] when the phone left the prefix field empty.
/// Returns (prefix, first). A name that is only a title is left alone.
(String, String) splitNamePrefix(String prefix, String first) {
  final f = first.trim();
  final p = prefix.trim();
  if (f.isEmpty) return (p, f);
  if (p.isNotEmpty) {
    // The phone filled both: drop the title from the first name if it repeats there.
    if (f.toLowerCase().startsWith('${p.toLowerCase()} ') ) return (p, f.substring(p.length).trim());
    return (p, f);
  }
  final m = RegExp(r'^(\S+?)[.،,]?\s+(.+)$', dotAll: true).firstMatch(f);
  if (m == null) return ('', f);
  final head = m.group(1)!;
  final key = head.replaceAll('.', '').toLowerCase();
  if (_titles.contains(key)) {
    // Keep the title as typed, with its dot.
    final raw = f.substring(0, f.indexOf(head) + head.length);
    final dot = f.length > raw.length && (f[raw.length] == '.') ? '.' : '';
    return ('$raw$dot'.trim(), m.group(2)!.trim());
  }
  return ('', f);
}
