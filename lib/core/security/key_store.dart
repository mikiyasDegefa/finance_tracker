import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinResult {
  const PinResult(
      {required this.ok, this.lockedSeconds = 0, this.attemptsLeft = 0});
  final bool ok;
  final int lockedSeconds;
  final int attemptsLeft;
}

/// Keeps the PIN hash, lockout state and database key in the platform
/// secure store (Android Keystore / iOS Keychain).
class KeyStore {
  KeyStore() : _s = const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  static final _rng = Random.secure();

  static const _kDb = 'db_key';
  static const _kSalt = 'pin_salt';
  static const _kHash = 'pin_hash';
  static const _kFails = 'pin_fails';
  static const _kLock = 'pin_lock_until';
  static const _kBio = 'bio_enabled';

  List<int> _bytes(int n) => List<int>.generate(n, (_) => _rng.nextInt(256));

  Future<bool> hasPin() async => (await _s.read(key: _kHash)) != null;

  String _hash(String pin, String salt) {
    final saltBytes = utf8.encode(salt);
    List<int> d = utf8.encode('$salt:$pin');
    for (var i = 0; i < 20000; i++) {
      d = sha256.convert([...d, ...saltBytes]).bytes;
    }
    return base64.encode(d);
  }

  Future<void> setPin(String pin) async {
    final salt = base64.encode(_bytes(16));
    await _s.write(key: _kSalt, value: salt);
    await _s.write(key: _kHash, value: _hash(pin, salt));
    await _s.write(key: _kFails, value: '0');
    await _s.delete(key: _kLock);
  }

  Future<PinResult> verifyPin(String pin) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final until = int.tryParse(await _s.read(key: _kLock) ?? '0') ?? 0;
    if (until > now) {
      return PinResult(ok: false, lockedSeconds: ((until - now) / 1000).ceil());
    }
    final salt = await _s.read(key: _kSalt);
    final hash = await _s.read(key: _kHash);
    if (salt == null || hash == null) return const PinResult(ok: false);
    if (_hash(pin, salt) == hash) {
      await _s.write(key: _kFails, value: '0');
      await _s.delete(key: _kLock);
      return const PinResult(ok: true);
    }
    final fails = (int.tryParse(await _s.read(key: _kFails) ?? '0') ?? 0) + 1;
    await _s.write(key: _kFails, value: '$fails');
    if (fails >= 5) {
      final delay = min(900, 30 * pow(2, min(fails - 5, 5)).toInt());
      await _s.write(key: _kLock, value: '${now + delay * 1000}');
      return PinResult(ok: false, lockedSeconds: delay);
    }
    return PinResult(ok: false, attemptsLeft: 5 - fails);
  }

  Future<bool> biometricEnabled() async => (await _s.read(key: _kBio)) == '1';
  Future<void> setBiometric(bool on) =>
      _s.write(key: _kBio, value: on ? '1' : '0');

  /// 256-bit SQLCipher key (hex). Created once, never leaves secure storage.
  Future<String> dbKeyHex() async {
    var k = await _s.read(key: _kDb);
    if (k == null) {
      k = _bytes(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await _s.write(key: _kDb, value: k);
    }
    return k;
  }
}
