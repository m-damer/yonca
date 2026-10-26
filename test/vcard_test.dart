import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/core/phone_split.dart';
import 'package:yonca/domain/vcard.dart';

void main() {
  test('splitPhone separates known country codes and keeps unknown ones whole', () {
    expect(splitPhone('+963 944 123 456'), ('+963', '944123456'));
    expect(splitPhone('00971501234567'), ('+971', '501234567'));
    expect(splitPhone('0944 123 456'), ('+963', '0944 123 456'));
    expect(splitPhone('+33 1 23 45 67 89'), ('', '+33123456789'));
    expect(splitPhone('0944123456', defaultCode: '+90'), ('+90', '0944123456'));
  });

  test('parses names, company, phones, emails, escapes and folded lines', () {
    const text = 'BEGIN:VCARD\r\nVERSION:3.0\r\nN:Ali;Sara;;Dr.;\r\nFN:Dr. Sara Ali\r\nORG:Sun\\, Co;Sales\r\nTITLE:Manager\r\n'
        'TEL;TYPE=CELL:+963 944 123 456\r\nTEL;TYPE=WORK:0112223344\r\nEMAIL;TYPE=INTERNET:sara@example.com\r\n'
        'NOTE:Line one\\nLine two and a very long\r\n  folded part\r\nEND:VCARD\r\n'
        'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Only Name\r\nEND:VCARD\r\nBEGIN:VCARD\r\nVERSION:3.0\r\nEND:VCARD\r\n';
    final list = parseVCards(text);
    expect(list.length, 2);
    final a = list.first;
    expect(a.firstName, 'Sara');
    expect(a.lastName, 'Ali');
    expect(a.prefix, 'Dr.');
    expect(a.company, 'Sun, Co');
    expect(a.department, 'Sales');
    expect(a.jobTitle, 'Manager');
    expect(a.phones.map((p) => (p.countryCode, p.number, p.label)), [('+963', '944123456', 'mobile'), ('+963', '0112223344', 'work')]);
    expect(a.emails.single.value, 'sara@example.com');
    expect(a.requirements, 'Line one\nLine two and a very long folded part');
    expect(list.last.firstName, 'Only');
    expect(list.last.lastName, 'Name');
  });
}
