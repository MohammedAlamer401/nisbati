import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ناتج تجزئة سرّ (رمز أو رمز استرداد) مع الملح وعدد التكرارات.
class SecretHash {
  const SecretHash({required this.hash, required this.salt, required this.iterations});

  final String hash;
  final String salt;
  final int iterations;
}

/// تجزئة الأسرار بـ PBKDF2-HMAC-SHA256 — القسم 6.1.
///
/// السرّ لا يُخزَّن أبداً كنص. الحساب في Isolate منفصل حتى لا تتجمد الواجهة.
class PinHasher {
  const PinHasher({this.iterations = defaultIterations, this.useIsolate = true});

  static const defaultIterations = 210000;

  final int iterations;

  /// يُعطَّل في الاختبارات لأن الـ Isolate لا يعمل داخل الزمن الوهمي.
  final bool useIsolate;

  Future<SecretHash> hash(String secret) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final derived = await _run(secret, salt, iterations);
    return SecretHash(hash: base64Encode(derived), salt: base64Encode(salt), iterations: iterations);
  }

  Future<bool> verify(String secret, SecretHash stored) async {
    final derived = await _run(secret, base64Decode(stored.salt), stored.iterations);
    return _constantTimeEquals(derived, base64Decode(stored.hash));
  }

  Future<List<int>> _run(String secret, List<int> salt, int iterations) {
    if (!useIsolate) return _derive(secret, salt, iterations);
    return Isolate.run(() => _derive(secret, salt, iterations));
  }

  static Future<List<int>> _derive(String secret, List<int> salt, int iterations) async {
    final pbkdf2 = DartPbkdf2(
      macAlgorithm: DartHmac(const DartSha256()),
      iterations: iterations,
      bits: 256,
      // بلا توقف دوري: الحساب في Isolate لا يحجز الواجهة.
      pauseFrequency: 1 << 30,
    );
    final key = await pbkdf2.deriveKeyFromPassword(password: secret, nonce: salt);
    return key.extractBytes();
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

final pinHasherProvider = Provider<PinHasher>((ref) => const PinHasher());
