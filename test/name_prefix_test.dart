import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/domain/name_prefix.dart';

void main() {
  test('a title typed into the first name moves to the prefix', () {
    expect(splitNamePrefix('', 'Dr. Ahmad'), ('Dr.', 'Ahmad'));
    expect(splitNamePrefix('', 'Eng Sara'), ('Eng', 'Sara'));
    expect(splitNamePrefix('', 'د. أحمد'), ('د.', 'أحمد'));
    expect(splitNamePrefix('', 'المهندس خالد'), ('المهندس', 'خالد'));
  });
  test('real names and filled prefixes are left alone', () {
    expect(splitNamePrefix('', 'Ahmad'), ('', 'Ahmad'));
    expect(splitNamePrefix('', 'Mary Ann'), ('', 'Mary Ann'));
    expect(splitNamePrefix('Dr.', 'Ahmad'), ('Dr.', 'Ahmad'));
    expect(splitNamePrefix('Dr', 'Dr Ahmad'), ('Dr', 'Ahmad'));
    expect(splitNamePrefix('', 'Dr'), ('', 'Dr'));
  });
}
