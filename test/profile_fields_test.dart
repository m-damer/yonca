import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/features/importing/profile_page.dart';

void main() {
  test('only ticked profile rows reach the QR code and the vCard, including website, address and social', () {
    final rows = [
      ProfileRow('phone', 'mobile', '+963 956666073', true),
      ProfileRow('website', 'work', 'https://ibc-power.com', true),
      ProfileRow('address', 'work', 'Damascus', false),
      ProfileRow('im', 'linkedin', 'linkedin.com/in/mdamer', true),
      ProfileRow('im', 'telegram', '@mdamer', false),
    ];
    final v = {'profile.name': 'Mahmoud Damer', 'profile.rows': encodeProfileRows(rows)};
    final card = profileVCard(v);
    expect(card, contains('URL:https://ibc-power.com'));
    expect(card, contains('X-SOCIALPROFILE;TYPE=linkedin:linkedin.com/in/mdamer'));
    expect(card, isNot(contains('Damascus')));
    expect(card, isNot(contains('@mdamer')));
    expect(profileQrFields(v).length, 4);
  });
}
