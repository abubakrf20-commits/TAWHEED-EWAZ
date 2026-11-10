import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/personal_info/services/pin_lock_service.dart';

const _hashKey = 'personal_info.pin_hash';
const _saltKey = 'personal_info.pin_salt';
const _vaultKey = 'personal_info.vault_key_id';
const _secureVerifierKey = 'personal_info.pin_verifier';

String _legacyHash(String pin, String salt) =>
    base64Encode(sha256.convert(utf8.encode('$salt:$pin')).bytes);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  Future<Map<String, dynamic>> secureVerifier() async {
    final raw = await PinLockService.storage.read(key: _secureVerifierKey);
    return jsonDecode(raw!) as Map<String, dynamic>;
  }

  group('setPin', () {
    test('keeps the verifier in secure storage, never in SharedPreferences',
        () async {
      expect(await PinLockService.setPin('1379'), isTrue);

      final stored = await secureVerifier();
      expect(stored['salt'], isA<String>());
      expect(stored['hash'], isA<String>());

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_hashKey), isNull);
      expect(prefs.getString(_saltKey), isNull);
      expect(prefs.getString(_vaultKey), isNull);
    });

    test('salts each pin so two installs never share a verifier', () async {
      await PinLockService.setPin('1379');
      final first = await secureVerifier();
      await PinLockService.setPin('1379');
      final second = await secureVerifier();
      expect(second['salt'], isNot(first['salt']));
      expect(second['hash'], isNot(first['hash']));
    });

    test('reports the vault as existing', () async {
      expect(await PinLockService.isPinSet(), isFalse);
      await PinLockService.setPin('1379');
      expect(await PinLockService.isPinSet(), isTrue);
    });
  });

  group('verifyPin', () {
    test('accepts the right pin and rejects the wrong one', () async {
      await PinLockService.setPin('1379');
      expect(await PinLockService.verifyPin('1379'), isTrue);
      expect(await PinLockService.verifyPin('1380'), isFalse);
      expect(await PinLockService.verifyPin(''), isFalse);
    });

    test('keeps working after the pin is changed', () async {
      await PinLockService.setPin('1379');
      await PinLockService.setPin('2024');
      expect(await PinLockService.verifyPin('1379'), isFalse);
      expect(await PinLockService.verifyPin('2024'), isTrue);
    });

    test('fails when no pin was ever set', () async {
      expect(await PinLockService.verifyPin('1379'), isFalse);
    });
  });

  group('legacy plaintext verifier migration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        _hashKey: _legacyHash('1379', 'legacy-salt'),
        _saltKey: 'legacy-salt',
        _vaultKey: 'v1',
      });
    });

    test('is reported as set before any migration happens', () async {
      expect(await PinLockService.isPinSet(), isTrue);
    });

    test('unlocks, then moves the verifier into secure storage', () async {
      expect(await PinLockService.verifyPin('1379'), isTrue);

      final stored = await secureVerifier();
      expect(stored['salt'], 'legacy-salt');
      expect(stored['hash'], _legacyHash('1379', 'legacy-salt'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_hashKey), isNull);
      expect(prefs.getString(_saltKey), isNull);
      expect(prefs.getString(_vaultKey), isNull);
    });

    test('still verifies after migration, from secure storage', () async {
      await PinLockService.verifyPin('1379');
      expect(await PinLockService.verifyPin('1379'), isTrue);
      expect(await PinLockService.verifyPin('9999'), isFalse);
    });

    test('a wrong pin neither unlocks nor migrates', () async {
      expect(await PinLockService.verifyPin('0000'), isFalse);

      final raw = await PinLockService.storage.read(key: _secureVerifierKey);
      expect(raw, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_hashKey), _legacyHash('1379', 'legacy-salt'));
      expect(prefs.getString(_saltKey), 'legacy-salt');
    });

    test('setPin replaces the legacy copy and clears it', () async {
      await PinLockService.setPin('5555');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_hashKey), isNull);
      expect(prefs.getString(_saltKey), isNull);
      expect(prefs.getString(_vaultKey), isNull);
      expect(await PinLockService.verifyPin('5555'), isTrue);
      expect(await PinLockService.verifyPin('1379'), isFalse);
    });
  });

  group('precedence', () {
    test('the secure verifier wins over a stale legacy copy', () async {
      await PinLockService.setPin('2024');
      final secure = await secureVerifier();

      SharedPreferences.setMockInitialValues(<String, Object>{
        _hashKey: _legacyHash('1379', 'legacy-salt'),
        _saltKey: 'legacy-salt',
      });

      expect(await PinLockService.verifyPin('2024'), isTrue);
      expect(await PinLockService.verifyPin('1379'), isFalse);

      // Still the same record: the stale copy was never consulted or adopted.
      expect(await secureVerifier(), secure);
    });
  });

  group('resetVault', () {
    test('clears the secure verifier and the vault key', () async {
      await PinLockService.setPin('1379');
      await PinLockService.cipher();
      expect(await PinLockService.vaultExists(), isTrue);

      await PinLockService.resetVault();

      expect(await PinLockService.isPinSet(), isFalse);
      expect(await PinLockService.vaultExists(), isFalse);
      expect(await PinLockService.verifyPin('1379'), isFalse);
      expect(
        await PinLockService.storage.read(key: _secureVerifierKey),
        isNull,
      );
    });

    test('clears a legacy verifier too', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        _hashKey: _legacyHash('1379', 'legacy-salt'),
        _saltKey: 'legacy-salt',
        _vaultKey: 'v1',
      });

      await PinLockService.resetVault();

      expect(await PinLockService.isPinSet(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_hashKey), isNull);
      expect(prefs.getString(_saltKey), isNull);
      expect(prefs.getString(_vaultKey), isNull);
    });
  });
}
