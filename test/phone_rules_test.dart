import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/core/phone_rules.dart';

void main() {
  test('numbers are checked against the country', () {
    expect(phoneInvalid('+963', '944 123 456'), isFalse);
    expect(phoneInvalid('+963', '0944123456'), isFalse);
    expect(phoneInvalid('+963', '123'), isTrue);
    expect(phoneInvalid('+963', ''), isFalse);
    expect(phoneInvalid('+971', '50 123 4567'), isFalse);
  });
  test('valid numbers are shown in the national format', () {
    expect(formatPhone('+963', '944123456').replaceAll(' ', ''), '944123456');
    expect(formatPhone('+963', '12'), '12');
  });
}
