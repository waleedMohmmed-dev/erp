import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

abstract final class PasswordHasher {
  static String randomSalt([int bytes = 16]) {
    final Random random = Random.secure();
    final List<int> values = List<int>.generate(
      bytes,
      (_) => random.nextInt(256),
    );
    return base64Url.encode(values);
  }

  static String hash(String password, String salt) {
    final Digest digest = sha256.convert(utf8.encode('$salt$password'));
    return digest.toString();
  }

  static bool verify({
    required String password,
    required String salt,
    required String expectedHash,
  }) {
    final String actual = hash(password, salt);
    if (actual.length != expectedHash.length) {
      return false;
    }
    int mismatch = 0;
    for (int i = 0; i < actual.length; i++) {
      mismatch |= actual.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return mismatch == 0;
  }
}
