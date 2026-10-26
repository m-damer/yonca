import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/core/text_normalize.dart';

void main() {
  group('normalizeText', () {
    test('treats the alef forms as one letter', () {
      expect(normalizeText('أحمد'), normalizeText('احمد'));
      expect(normalizeText('إبراهيم'), normalizeText('ابراهيم'));
      expect(normalizeText('آمنة'), normalizeText('امنه'));
    });
    test('treats ى and ي, ة and ه as one letter', () {
      expect(normalizeText('مصطفى'), normalizeText('مصطفي'));
      expect(normalizeText('فاطمة'), normalizeText('فاطمه'));
    });
    test('removes diacritics and tatweel', () {
      expect(normalizeText('مُحَمَّد'), normalizeText('محمد'));
      expect(normalizeText('محـــمد'), normalizeText('محمد'));
    });
    test('compares Latin text without case and turns Arabic digits into 0-9', () {
      expect(normalizeText('  Ahmad   KHOURY '), 'ahmad khoury');
      expect(normalizeText('٠٩٤٤١٢٣'), '0944123');
      expect(normalizeText('۰۹۴۴'), '0944');
    });
  });

  group('sortKeyOf', () {
    test('ignores the leading article ال', () {
      expect(sortKeyOf('النور للتجارة'), sortKeyOf('نور للتجارة'));
    });
    test('keeps a name that is only the article letters', () {
      expect(sortKeyOf('ال'), 'ال');
    });
  });

  group('sections and ordering', () {
    test('sections: letter, Latin capital, or #', () {
      expect(sectionOf(sortKeyOf('أحمد')), 'ا');
      expect(sectionOf(sortKeyOf('ahmad')), 'A');
      expect(sectionOf(sortKeyOf('3M Syria')), '#');
      expect(sectionOf(''), '#');
    });
    test('Arabic first in the Arabic version, English first in English', () {
      final keys = [sortKeyOf('Omar'), sortKeyOf('أحمد'), sortKeyOf('42 Co'), sortKeyOf('Ali')];
      final ar = [...keys]..sort((a, b) => compareSortKeys(a, b, arabicFirst: true));
      expect(ar, [sortKeyOf('أحمد'), 'ali', 'omar', '42 co']);
      final en = [...keys]..sort((a, b) => compareSortKeys(a, b, arabicFirst: false));
      expect(en, ['ali', 'omar', sortKeyOf('أحمد'), '42 co']);
    });
  });

  group('normalizePhone', () {
    test('local and international forms match', () {
      final a = normalizePhone('+963', '0944 123 456');
      expect(a, '963944123456');
      expect(normalizePhone('+963', '+963 944 123 456'), a);
      expect(normalizePhone('+963', '00963944123456'), a);
      expect(normalizePhone('+963', '٠٩٤٤١٢٣٤٥٦'), a);
    });
    test('another country code gives another number', () {
      expect(normalizePhone('+90', '0532 111 22 33'), '905321112233');
    });
  });
}
