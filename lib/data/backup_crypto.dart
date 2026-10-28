import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Password protection for backup files.
///
/// Layout: magic(8) | salt(16) | nonce(16) | ciphertext | mac(32).
/// The key comes from the password by iterated HMAC-SHA256 (PBKDF2). The data is encrypted with
/// an HMAC-SHA256 counter keystream and authenticated with HMAC-SHA256 over everything before the
/// tag (encrypt-then-MAC), so a wrong password or a damaged file is detected before anything is used.
class BackupCrypto {
  static final magic = Uint8List.fromList(utf8.encode('YONCAB01'));
  static const iterations = 60000;

  static bool isEncrypted(List<int> data) {
    if (data.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (data[i] != magic[i]) return false;
    }
    return true;
  }

  static Uint8List _pbkdf2(String password, List<int> salt, int length) {
    final pw = utf8.encode(password);
    final out = BytesBuilder();
    var block = 1;
    while (out.length < length) {
      final h = Hmac(sha256, pw);
      var u = h.convert([...salt, (block >> 24) & 255, (block >> 16) & 255, (block >> 8) & 255, block & 255]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
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

  static Uint8List encrypt(List<int> plain, String password, {Random? random}) {
    final r = random ?? Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => r.nextInt(256)));
    final nonce = Uint8List.fromList(List.generate(16, (_) => r.nextInt(256)));
    final keys = _pbkdf2(password, salt, 64);
    final enc = _xor(Uint8List.fromList(plain), keys.sublist(0, 32), nonce);
    final body = BytesBuilder()
      ..add(magic)
      ..add(salt)
      ..add(nonce)
      ..add(enc);
    final mac = Hmac(sha256, keys.sublist(32)).convert(body.toBytes()).bytes;
    body.add(mac);
    return body.toBytes();
  }

  /// Returns the plain bytes, or null when the password is wrong or the file is damaged.
  static Uint8List? decrypt(List<int> data, String password) {
    if (!isEncrypted(data) || data.length < 8 + 16 + 16 + 32) return null;
    final salt = data.sublist(8, 24);
    final nonce = data.sublist(24, 40);
    final mac = data.sublist(data.length - 32);
    final body = data.sublist(0, data.length - 32);
    final keys = _pbkdf2(password, salt, 64);
    final expect = Hmac(sha256, keys.sublist(32)).convert(body).bytes;
    var diff = 0;
    for (var i = 0; i < 32; i++) {
      diff |= expect[i] ^ mac[i];
    }
    if (diff != 0) return null;
    return _xor(Uint8List.fromList(data.sublist(40, data.length - 32)), keys.sublist(0, 32), nonce);
  }
}
