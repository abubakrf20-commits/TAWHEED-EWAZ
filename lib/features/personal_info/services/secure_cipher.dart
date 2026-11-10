import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Deterministic AES-GCM encryption of sensitive field values before they are
/// stored in the Drift database. The key is held by the caller (loaded from
/// flutter_secure_storage) — this class is a stateless pure helper so it can
/// be unit-tested without platform channels.
///
/// Encrypted payloads are Base64 with a fixed `enc:` prefix so the app can
/// (a) distinguish ciphertext from plaintext values and (b) skip encrypting
/// already-encrypted values on re-save.
const String kEncPrefix = 'enc:';

class SecureCipher {
  final Key _key;
  SecureCipher._(this._key);

  /// Builds a cipher from a raw 32-byte key material.
  factory SecureCipher.fromBytes(List<int> keyBytes) =>
      SecureCipher._(Key(Uint8List.fromList(keyBytes)));

  /// Whether [value] is already encrypted (has the `enc:` prefix).
  static bool isEncrypted(String value) => value.startsWith(kEncPrefix);

  String encrypt(String plain) {
    if (plain.isEmpty || isEncrypted(plain)) return plain;
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
    final box = encrypter.encrypt(plain, iv: iv);
    return '$kEncPrefix${iv.base64}.${box.base64}';
  }

  /// Decrypts a value created by [encrypt]. Pass-through for empty /
  /// un-encrypted legacy values so mixed data keeps working.
  String decrypt(String value) {
    if (value.isEmpty || !isEncrypted(value)) return value;
    final body = value.substring(kEncPrefix.length);
    final sep = body.indexOf('.');
    if (sep <= 0) return value;
    final iv = IV.fromBase64(body.substring(0, sep));
    final ct = body.substring(sep + 1);
    try {
      final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
      return encrypter.decrypt(Encrypted.fromBase64(ct), iv: iv);
    } catch (e) {
      AppLogger.warning('SecureCipher', 'decrypt failed, returning raw: $e');
      return value;
    }
  }
}
