import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/data/backup_crypto.dart';

void main() {
  final plain = Uint8List.fromList(List.generate(5000, (i) => (i * 7) % 256));

  test('new backups use the new format and the full number of rounds', () {
    final enc = BackupCrypto.encrypt(plain, 'secret', random: Random(1), rounds: 1000);
    expect(utf8.decode(enc.sublist(0, 8)), 'YONCAB02');
    expect(BackupCrypto.iterations, greaterThanOrEqualTo(600000));
    expect(BackupCrypto.isEncrypted(enc), isTrue);
    expect(BackupCrypto.decrypt(enc, 'secret'), orderedEquals(plain));
  });

  test('a wrong password, a changed byte or a cut file is refused', () {
    final enc = BackupCrypto.encrypt(plain, 'secret', rounds: 1000);
    expect(BackupCrypto.decrypt(enc, 'nope'), isNull);
    for (final at in [3, 9, 15, 30, 45, enc.length - 1]) {
      final bad = Uint8List.fromList(enc)..[at] ^= 1;
      expect(BackupCrypto.decrypt(bad, 'secret'), isNull, reason: 'byte $at');
    }
    expect(BackupCrypto.decrypt(enc.sublist(0, 30), 'secret'), isNull);
  });

  test('the same data encrypts differently each time', () {
    final a = BackupCrypto.encrypt(plain, 'secret', rounds: 1000);
    final b = BackupCrypto.encrypt(plain, 'secret', rounds: 1000);
    expect(a, isNot(orderedEquals(b)));
  });

  test('a backup made with the old format still restores', () {
    final old = BackupCrypto.encryptV1(plain, 'secret');
    expect(utf8.decode(old.sublist(0, 8)), 'YONCAB01');
    expect(BackupCrypto.isEncrypted(old), isTrue);
    expect(BackupCrypto.decrypt(old, 'secret'), orderedEquals(plain));
    expect(BackupCrypto.decrypt(old, 'nope'), isNull);
  });

  test('an absurd round count in a file is refused instead of hanging', () {
    final enc = Uint8List.fromList(BackupCrypto.encrypt(plain, 'secret', rounds: 1000));
    enc.setRange(8, 12, [0x7f, 0xff, 0xff, 0xff]);
    expect(BackupCrypto.decrypt(enc, 'secret'), isNull);
  });
}
