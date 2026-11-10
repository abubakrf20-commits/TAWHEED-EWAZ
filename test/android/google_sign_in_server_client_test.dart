import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Google/Firebase auth wiring — the class of defect that makes
/// sign-in silently impossible and has no Dart-level symptom.
///
/// Two incidents, both proven against the built APK:
///
/// 1. `com.google.gms.google-services` was declared `apply false` in
///    settings.gradle.kts but NEVER APPLIED in `android/app/build.gradle.kts`.
///    `android/app/google-services.json` was therefore inert: aapt2 on the
///    release APK found no `default_web_client_id` string at all, so
///    google_sign_in 7.x could not resolve a serverClientId and failed
///    `getCredential` with MISSING_SERVER_CLIENT_ID *before showing the
///    account picker* — the tap did nothing at all.
/// 2. `GoogleSignIn.instance.initialize()` was called with no
///    `serverClientId`, relying entirely on that generated resource.
///
/// The third guard covers the cold-start race: `Firebase.apps` is empty for
/// the first seconds of a launch (init is deliberately unawaited), so any
/// `apps.isEmpty` check that does not await `ensureFirebaseInitialized()`
/// turns a legitimate sign-in tap into «سرویس ابری در دسترس نیست.»

String read(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');

Map<String, dynamic> googleServicesJson() {
  final raw = File('android/app/google-services.json').readAsStringSync();
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  group('google-services Gradle plugin', () {
    test('android/app/build.gradle.kts APPLIES the plugin', () {
      final gradle = read('android/app/build.gradle.kts');
      final pluginsBlock = gradle.substring(
          gradle.indexOf('plugins {'), gradle.indexOf('}', gradle.indexOf('plugins {')));
      expect(pluginsBlock, contains('id("com.google.gms.google-services")'),
          reason: 'declared-only-with-apply-false in settings.gradle.kts means '
              'google-services.json is never processed: no default_web_client_id '
              'resource → the Google picker never opens');
    });

    test('the app module keeps its google-services.json in place', () {
      expect(File('android/app/google-services.json').existsSync(), isTrue,
          reason: 'the plugin reads exactly this path');
      final json = googleServicesJson();
      final clients = json['client'] as List<dynamic>;
      final packages = clients
          .map((c) => (c as Map<String, dynamic>)['client_info']
              ['android_client_info']['package_name'])
          .toSet();
      expect(packages, contains('com.islamic.tawheeed'),
          reason: 'the JSON must cover the applicationId');
    });
  });

  group('serverClientId', () {
    test('matches the WEB oauth client of the shipped google-services.json',
        () {
      final json = googleServicesJson();
      final webIds = <String>[];
      final androidPackages = <String>{};
      for (final c in json['client'] as List<dynamic>) {
        final cm = c as Map<String, dynamic>;
        for (final o in cm['oauth_client'] as List<dynamic>) {
          final om = o as Map<String, dynamic>;
          if (om['client_type'] == 3) webIds.add(om['client_id'] as String);
          if (om['client_type'] == 1) {
            androidPackages.add((cm['client_info'] as Map<String, dynamic>)['android_client_info']['package_name'] as String);
          }
        }
      }
      expect(webIds, isNotEmpty,
          reason: 'no type-3 (web) oauth client → no serverClientId exists');

      final auth = read('lib/features/settings/services/google_auth_service.dart');
      for (final id in webIds) {
        expect(auth, contains(id),
            reason: 'GoogleAuthService.serverClientId drifted from the shipped '
                'web client; idToken would be minted for the wrong audience');
      }
    });

    test('both initialize() call sites pass it explicitly', () {
      final service = read('lib/features/settings/services/google_auth_service.dart');
      expect(service, contains('initialize(serverClientId: serverClientId)'),
          reason: 'the Drive session must not depend on a generated resource');

      final repo = read(
          'lib/features/account/data/repositories/firebase_account_repository.dart');
      expect(repo, contains('initialize(serverClientId: GoogleAuthService.serverClientId)'),
          reason: 'the Firebase fallback path must carry the same client');
    });

    test('the release signing key is registered in the JSON', () {
      final json = googleServicesJson();
      final hashes = <String>{};
      for (final c in json['client'] as List<dynamic>) {
        final cm = c as Map<String, dynamic>;
        for (final o in cm['oauth_client'] as List<dynamic>) {
          final om = o as Map<String, dynamic>;
          final androidInfo = om['android_info'] as Map<String, dynamic>?;
          if (androidInfo != null && androidInfo['certificate_hash'] != null) {
            hashes.add(androidInfo['certificate_hash'] as String);
          }
        }
      }
      expect(hashes, isNotEmpty,
          reason: 'a release build without a registered SHA-1 always fails with '
              'DEVELOPER_ERROR');
      expect(hashes, contains('7b8572bd78ee098f543b3018059050f588476f46'),
          reason: 'SHA-1 of android/app/release-key.jks (alias upload) must '
              'stay registered, or release sign-in breaks');
    });
  });

  group('cold-start init race', () {
    test('the account repository awaits ensureFirebaseInitialized', () {
      final repo = read(
          'lib/features/account/data/repositories/firebase_account_repository.dart');
      expect(repo, contains('ensureFirebaseInitialized()'),
          reason: 'the lazy init is unawaited in main(); a bare apps.isEmpty '
              'check is a race, not a state');
      expect(repo, contains('Future<bool> get _available async'),
          reason: '_available must await init, not read apps in place');
      // Every guard must await: a single missed one re-opens the bug.
      expect(RegExp(r'if \(!_available\)').hasMatch(repo), isFalse,
          reason: 'a synchronous _available check is the cold-start failure');
      expect(repo, contains('authStateChanges() async*'),
          reason: 'the hub watches this stream at build time — it must never '
              'throw before Firebase is up');
    });

    test('the repository no longer touches FirebaseAuth.instance eagerly', () {
      final repo = read(
          'lib/features/account/data/repositories/firebase_account_repository.dart');
      expect(repo, contains('auth.FirebaseAuth? _authInstance'),
          reason: 'FirebaseAuth.instance throws with no app; keep the field '
              'nullable and resolve it on first use');
      expect(RegExp(r': _auth = authInstance \?\?').hasMatch(repo), isFalse,
          reason: 'an eager initializer runs at provider-read time, before init');
    });
  });
}
