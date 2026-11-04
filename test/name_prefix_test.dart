import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/domain/name_prefix.dart';

void main() {
  test('a title typed into the first name moves to the prefix', () {
    expect(splitNamePrefix('', 'Dr. Ahmad'), ('Dr.', 'Ahmad'));
    expect(splitNamePrefix('', 'Eng Sara'), ('Eng.', 'Sara'));
    expect(splitNamePrefix('', 'د. أحمد'), ('د.', 'أحمد'));
    expect(splitNamePrefix('', 'المهندس خالد'), ('المهندس', 'خالد'));
  });
  test('real names and filled prefixes are left alone', () {
    expect(splitNamePrefix('', 'Ahmad'), ('', 'Ahmad'));
    expect(splitNamePrefix('', 'Mary Ann'), ('', 'Mary Ann'));
    expect(splitNamePrefix('Dr.', 'Ahmad'), ('Dr.', 'Ahmad'));
    expect(splitNamePrefix('Dr', 'Dr Ahmad'), ('Dr.', 'Ahmad'));
    expect(splitNamePrefix('د', 'أحمد'), ('د.', 'أحمد'));
    expect(splitNamePrefix('المهندس', 'خالد'), ('المهندس', 'خالد'));
    expect(splitNamePrefix('', 'Dr'), ('', 'Dr'));
    expect(splitNamePrefix('م', 'م. أحمد'), ('م.', 'أحمد'));
    expect(splitNamePrefix('م.', 'م. أحمد'), ('م.', 'أحمد'));
    expect(splitNamePrefix('', 'د.أحمد'), ('د.', 'أحمد'));
  });
  test('a title in the given-name field with the real first name in the middle name', () {
    final r = fixPhoneName('', 'Eng.', 'Mahmoud');
    expect((r.prefix, r.first, r.middle), ('Eng.', 'Mahmoud', ''));
    final a = fixPhoneName('', 'م', 'محمود');
    expect((a.prefix, a.first, a.middle), ('م.', 'محمود', ''));
    final k = fixPhoneName('Dr.', 'Ahmad', 'Ali');
    expect((k.prefix, k.first, k.middle), ('Dr.', 'Ahmad', 'Ali'));
    final real = fixPhoneName('', 'Mary', 'Ann');
    expect((real.prefix, real.first, real.middle), ('', 'Mary', 'Ann'));
  });
}
