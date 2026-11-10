import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/services/app_secure_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

import 'secure_cipher.dart';

/// The «اطلاعات من» security layer:
///  • a random AES-256 key kept in flutter_secure_storage (Android Keystore)
///    — used by [cipher] to encrypt sensitive field values in the DB;
///  • a session PIN whose SHA-256(salt) hash is kept in the *same* Keystore
///    -backed secure storage, acting as the UI gate. The PIN does NOT derive
///    the cipher key, so changing the PIN never requires re-encrypting the
///    data, and forgetting the PIN still allows read access via secure storage
///    until the user explicitly resets the vault.
///
/// The verifier used to live in SharedPreferences, which meant the salt+hash
/// sat in plaintext inside `FlutterSharedPreferences.xml` (readable on a
/// rooted device, and eligible for Android auto-backup) *and* was carried by
/// portable backup archives. It now lives in secure storage, which
/// `backup_rules.xml` excludes and `BackupService` filters out.
///
/// Availability note: the Keystore is a shared dependency, not an extra one.
/// Every personal-info field is encrypted with the AES key that lives there,
/// so a Keystore that has become unreadable already costs the user their
/// data — the PIN gate was never the weaker link. Legacy verifiers are
/// therefore still *honoured* on read (a Keystore failure must not look like a
/// wrong PIN) but are migrated to secure storage and deleted on first
/// successful unlock.
class PinLockService {
  /// Legacy plaintext locations, kept only to migrate installs that predate
  /// the move to secure storage. Never written by [setPin] any more.
  static const _prefsPinHashKey = 'personal_info.pin_hash';
  static const _prefsPinSaltKey = 'personal_info.pin_salt';
  static const _prefsVaultKey = 'personal_info.vault_key_id';

  static const _secureKey = 'personal_info.aes_key';

  /// Authoritative PIN verifier, Keystore-encrypted at rest.
  static const _securePinVerifierKey = 'personal_info.pin_verifier';

  /// Shared instance — see [appSecureStorage] for why the plugin must never
  /// delete a key on a failed read (that would erase the vault AES key).
  static const storage = appSecureStorage;

  /// Whether a PIN has ever been set (i.e. the vault exists).
  static Future<bool> isPinSet() async {
    if (await _readSecureVerifier() != null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsPinHashKey)?.isNotEmpty ?? false;
  }

  /// Whether the vault (AES key) exists in secure storage without a PIN.
  static Future<bool> vaultExists() async {
    return await storage.read(key: _secureKey) != null;
  }

  /// Sets (or replaces) the session PIN. Returns true on success.
  ///
  /// Fails (rather than falling back to plaintext SharedPreferences) when
  /// secure storage is unavailable, so a Keystore problem can never silently
  /// downgrade the verifier to a readable one.
  static Future<bool> setPin(String pin) async {
    final salt = _randomSalt();
    final hash = _hashPin(pin, salt);
    final stored = await _writeSecureVerifier(_PinVerifier(salt, hash));
    if (!stored) return false;
    await _clearLegacyVerifier();
    return true;
  }

  /// Verifies the stored PIN hash against [pin].
  static Future<bool> verifyPin(String pin) async {
    final secure = await _readSecureVerifier();
    if (secure != null) {
      return _constantTimeEquals(secure.hash, _hashPin(pin, secure.salt));
    }

    // No usable secure verifier: fall back to a legacy plaintext one so a
    // Keystore read failure never presents itself as a wrong PIN. Migrate on
    // the first *successful* unlock only, so a wrong guess can never promote
    // an attacker-influenced value.
    final legacy = await _readLegacyVerifier();
    if (legacy == null) return false;
    if (!_constantTimeEquals(legacy.hash, _hashPin(pin, legacy.salt))) {
      return false;
    }
    if (await _writeSecureVerifier(legacy)) {
      await _clearLegacyVerifier();
    }
    return true;
  }

  /// Permanently wipes the PIN and the AES key (used by «پاک کردن صندوق»).
  /// The user data rows are NOT deleted here; the caller opts in.
  static Future<void> resetVault() async {
    await _clearLegacyVerifier();
    await storage.delete(key: _securePinVerifierKey);
    await storage.delete(key: _secureKey);
  }

  /// Loads the AES key from secure storage, creating + persisting it on first
  /// use. Every sensitive field value is encrypted with this before the DB.
  static Future<SecureCipher> cipher() async {
    final raw =
        await storage.read(key: _secureKey) ?? await _generateAndStoreKey();
    return SecureCipher.fromBytes(base64Decode(raw));
  }

  static Future<String> _generateAndStoreKey() async {
    final rng = Random.secure();
    final key = base64Encode(List<int>.generate(32, (_) => rng.nextInt(256)));
    await storage.write(key: _secureKey, value: key);
    return key;
  }

  static Future<_PinVerifier?> _readSecureVerifier() async {
    try {
      final raw = await storage.read(key: _securePinVerifierKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final salt = decoded['salt'];
      final hash = decoded['hash'];
      if (salt is! String || hash is! String) return null;
      if (salt.isEmpty || hash.isEmpty) return null;
      return _PinVerifier(salt, hash);
    } catch (_) {
      // Unreadable or corrupted entry: treat as "no secure verifier" so the
      // legacy fallback gets a chance instead of locking the user out.
      return null;
    }
  }

  static Future<bool> _writeSecureVerifier(_PinVerifier verifier) async {
    try {
      await storage.write(
        key: _securePinVerifierKey,
        value: jsonEncode(
          {'v': 1, 'salt': verifier.salt, 'hash': verifier.hash},
        ),
      );
      return true;
    } catch (e) {
      AppLogger.warning('PinLockService', 'verifier persist failed: $e');
      return false;
    }
  }

  static Future<_PinVerifier?> _readLegacyVerifier() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hash = prefs.getString(_prefsPinHashKey);
      final salt = prefs.getString(_prefsPinSaltKey);
      if (hash == null || salt == null) return null;
      if (hash.isEmpty || salt.isEmpty) return null;
      return _PinVerifier(salt, hash);
    } catch (e) {
      AppLogger.warning('PinLockService', 'legacy verifier read failed: $e');
      return null;
    }
  }

  /// Removes the legacy plaintext verifier. Best effort: if this fails the
  /// remaining copy is still only consulted when secure storage has no
  /// verifier, so it cannot shadow the authoritative one.
  static Future<void> _clearLegacyVerifier() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsPinHashKey);
      await prefs.remove(_prefsPinSaltKey);
      await prefs.remove(_prefsVaultKey);
    } catch (_) {
      // Nothing to do: a stale legacy copy is harmless once secure storage
      // holds the verifier.
    }
  }

  static String _randomSalt() {
    final rng = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => rng.nextInt(256)));
  }

  static String _hashPin(String pin, String salt) {
    final digest = sha256.convert(utf8.encode('$salt:$pin'));
    return base64Encode(digest.bytes);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

class _PinVerifier {
  const _PinVerifier(this.salt, this.hash);
  final String salt;
  final String hash;
}
