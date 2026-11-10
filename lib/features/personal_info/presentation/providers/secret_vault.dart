import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/personal_info/services/pin_lock_service.dart';
import 'package:tawheeed/features/personal_info/services/secure_cipher.dart';

/// Loads the shared [SecureCipher] once. Resolved from flutter_secure_storage;
/// every screen that writes sensitive fields and every read that must decrypt
/// them watches this provider.
final secretVaultProvider = FutureProvider<SecureCipher>((ref) async {
  return PinLockService.cipher();
});

/// Decrypts [raw] with [cipher]. Empty values stay empty, and plain text passes
/// through untouched. Ciphertext that does not decrypt (wrong or rotated key)
/// resolves to '' — fail-closed: the caller never shows ciphertext to the user
/// and never crashes on it.
String decryptSafely(SecureCipher cipher, String raw) {
  if (raw.isEmpty) return '';
  if (!SecureCipher.isEncrypted(raw)) return raw;
  final decrypted = cipher.decrypt(raw);
  return SecureCipher.isEncrypted(decrypted) ? '' : decrypted;
}
