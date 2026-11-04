import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:pointycastle/export.dart' as pc;

/// Password protection for backup files.
///
/// Current format (`YONCAB02`): magic(8) | iterations(4, big endian) | salt(16) | nonce(12) |
/// AES-256-GCM ciphertext with its 16 byte tag. The key comes from the password by PBKDF2-HMAC-SHA256
/// ([iterations] rounds, stored in the file so it can be raised later). The header is authenticated
/// as additional data, so a wrong password or any change to the file is detected before anything is used.
///
/// The first format (`YONCAB01`: 60,000 rounds, HMAC-SHA256 counter keystream + HMAC tag) is still
/// read so older backups restore, but it is never written any more.
class BackupCrypto {
  static final magic = Uint8List.fromList(utf8.encode('YONCAB02'));
  static final _magicV1 = Uint8List.fromList(utf8.encode('YONCAB01'));
  static const iterations = 600000;
  static const _iterationsV1 = 60000;
  static const _maxIterations = 20000000;
  static const _headerV2 = 8 + 4 + 16 + 12;

  static bool _starts(List<int> data, List<int> m) {
    if (data.length < m.length) return false;
    for (var i = 0; i < m.length; i++) {
      if (data[i] != m[i]) return false;
    }
    return true;
  }

  static bool isEncrypted(List<int> data) => _starts(data, magic) || _starts(data, _magicV1);

  static Uint8List _pbkdf2V1(String password, List<int> salt, int length) {
    final pw = utf8.encode(password);
    final out = BytesBuilder();
    var block = 1;
    while (out.length < length) {
      final h = Hmac(sha256, pw);
      var u = h.convert([...salt, (block >> 24) & 255, (block >> 16) & 255, (block >> 8) & 255, block & 255]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < _iterationsV1; i++) {
        u = h.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
      block++;
    }
    return Uint8List.fromList(out.toBytes().sublist(0, length));
  }

  static Uint8List _xor(Uint8List data, List<int> key, List<int> nonce) {
    final h = Hmac(sha256, key);
    final out = Uint8List(data.length);
    var counter = 0;
    for (var pos = 0; pos < data.length; pos += 32) {
      final ks = h.convert([...nonce, (counter >> 24) & 255, (counter >> 16) & 255, (counter >> 8) & 255, counter & 255]).bytes;
      counter++;
      final end = min(pos + 32, data.length);
      for (var i = pos; i < end; i++) {
        out[i] = data[i] ^ ks[i - pos];
      }
    }
    return out;
  }

  static Uint8List _key(String password, List<int> salt, int rounds) {
    final kdf = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(Uint8List.fromList(salt), rounds, 32));
    return kdf.process(Uint8List.fromList(utf8.encode(password)));
  }

  static Uint8List _random(Random r, int n) => Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));

  /// Encrypts with the current format. [rounds] is only lowered by tests.
  static Uint8List encrypt(List<int> plain, String password, {Random? random, int rounds = iterations}) {
    final r = random ?? Random.secure();
    final salt = _random(r, 16);
    final nonce = _random(r, 12);
    final header = BytesBuilder()
      ..add(magic)
      ..add([(rounds >> 24) & 255, (rounds >> 16) & 255, (rounds >> 8) & 255, rounds & 255])
      ..add(salt)
      ..add(nonce);
    final head = header.toBytes();
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(true, pc.AEADParameters(pc.KeyParameter(_key(password, salt, rounds)), 128, nonce, head));
    final body = cipher.process(Uint8List.fromList(plain));
    return (BytesBuilder()
          ..add(head)
          ..add(body))
        .toBytes();
  }

  /// Returns the plain bytes, or null when the password is wrong or the file is damaged.
  static Uint8List? decrypt(List<int> data, String password) {
    if (_starts(data, magic)) return _decryptV2(data, password);
    if (_starts(data, _magicV1)) return _decryptV1(data, password);
    return null;
  }

  static Uint8List? _decryptV2(List<int> data, String password) {
    if (data.length < _headerV2 + 16) return null;
    final rounds = (data[8] << 24) | (data[9] << 16) | (data[10] << 8) | data[11];
    if (rounds < 1 || rounds > _maxIterations) return null;
    final salt = data.sublist(12, 28);
    final nonce = Uint8List.fromList(data.sublist(28, 40));
    final head = Uint8List.fromList(data.sublist(0, _headerV2));
    try {
      final cipher = pc.GCMBlockCipher(pc.AESEngine())
        ..init(false, pc.AEADParameters(pc.KeyParameter(_key(password, salt, rounds)), 128, nonce, head));
      return cipher.process(Uint8List.fromList(data.sublist(_headerV2)));
    } on pc.InvalidCipherTextException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// Writes the old format. Only for the test that proves old backups still restore.
  @visibleForTesting
  static Uint8List encryptV1(List<int> plain, String password, {Random? random}) {
    final r = random ?? Random.secure();
    final salt = _random(r, 16);
    final nonce = _random(r, 16);
    final keys = _pbkdf2V1(password, salt, 64);
    final enc = _xor(Uint8List.fromList(plain), keys.sublist(0, 32), nonce);
    final body = BytesBuilder()
      ..add(_magicV1)
      ..add(salt)
      ..add(nonce)
      ..add(enc);
    final mac = Hmac(sha256, keys.sublist(32)).convert(body.toBytes()).bytes;
    body.add(mac);
    return body.toBytes();
  }

  static Uint8List? _decryptV1(List<int> data, String password) {
    if (data.length < 8 + 16 + 16 + 32) return null;
    final salt = data.sublist(8, 24);
    final nonce = data.sublist(24, 40);
    final mac = data.sublist(data.length - 32);
    final body = data.sublist(0, data.length - 32);
    final keys = _pbkdf2V1(password, salt, 64);
    final expect = Hmac(sha256, keys.sublist(32)).convert(body).bytes;
    var diff = 0;
    for (var i = 0; i < 32; i++) {
      diff |= expect[i] ^ mac[i];
    }
    if (diff != 0) return null;
    return _xor(Uint8List.fromList(data.sublist(40, data.length - 32)), keys.sublist(0, 32), nonce);
  }
}
