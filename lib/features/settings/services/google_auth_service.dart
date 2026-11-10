import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/shared/utils/app_logger.dart';

/// Google sign-in for cloud backup (Drive `appDataFolder`).
///
/// Only the account identity is kept in memory + a lightweight signed-in flag
/// in prefs. No tokens are persisted by us (the plugin + `googleapis_auth`
/// client hold short-lived credentials in memory only).
class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  /// Minimal scope: the app's own hidden folder. The user's Drive files are
  /// never visible to us — and our backups never visible to the user.
  static String get driveScope => drive.DriveApi.driveAppdataScope;

  /// Web OAuth client ID of project `tawheed-1f347` — the `client_type: 3`
  /// entry of `android/app/google-services.json`, and the same value the
  /// google-services Gradle plugin publishes as `default_web_client_id`.
  ///
  /// google_sign_in 7.x still works with no `serverClientId` when that string
  /// resource exists, but this is passed EXPLICITLY so the picker can never
  /// die on a missing/stripped resource: without a serverClientId the
  /// Android plugin fails `getCredential` with MISSING_SERVER_CLIENT_ID
  /// before it shows any UI. It is also the client whose audience the
  /// Firebase `idToken` is minted for, so the Firebase link reuses the very
  /// same token the Drive session obtained.
  ///
  /// `test/android/google_sign_in_server_client_test.dart` fails if this ever
  /// drifts from the shipped google-services.json.
  static const String serverClientId =
      '583312950736-prh5p662m5dbh50ksomgpn2ve67reqqg.apps.googleusercontent.com';

  static const String _signedInKey = 'google_backup_signed_in';
  static const String _emailKey = 'google_backup_email';

  final ValueNotifier<GoogleSignInAccount?> account = ValueNotifier(null);
  bool _initialized = false;

  /// Must be called once at startup (before any silent restore attempt).
  Future<void> init() async {
    if (_initialized) return;
    try {
      await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
      // Only latch AFTER a successful initialize(): the flag used to be set
      // before the try, so one transient failure (a cold start with a briefly
      // dead network) disabled the picker for the rest of the process life —
      // the user's next tap would call authenticate() on an uninitialized
      // plugin and fail with no way out but a restart.
      _initialized = true;
      GoogleSignIn.instance.authenticationEvents.listen(
        (event) {
          final user = switch (event) {
            GoogleSignInAuthenticationEventSignIn(:final user) => user,
            _ => null,
          };
          account.value = user;
          unawaited(_persistAccount(user));
        },
        onError: (Object e) {
          AppLogger.warning('GoogleAuth', 'auth events error: $e');
        },
      );
    } catch (e) {
      AppLogger.warning('GoogleAuth', 'init failed: $e');
    }
  }

  /// Last known account (memory only). Null when signed out.
  GoogleSignInAccount? get currentUser => account.value;

  bool get isSignedIn => account.value != null;

  /// Email of the last signed-in account (for UI display after restarts).
  Future<String?> lastEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_emailKey);
    } catch (_) {
      AppLogger.warning('google_auth_service', 'operation failed');
      return null;
    }
  }

  /// Interactive sign-in (must be called from a button tap). Throws
  /// [GoogleSignInException] on user cancel — callers show nothing then.
  Future<GoogleSignInAccount> signIn() async {
    await init();
    final user = await GoogleSignIn.instance.authenticate();
    account.value = user;
    await _persistAccount(user);
    AppLogger.info('GoogleAuth', 'signed in: ${user.email}');
    return user;
  }

  /// Silent restore of a previous session (no UI). Returns the account or
  /// null when re-authentication is needed.
  ///
  /// Deliberately NOT wired at startup (audit U6-P2-5 is a false positive
  /// against a product decision): `attemptLightweightAuthentication` can
  /// fall back to the interactive account picker, which popped on every cold
  /// start (user report, 2026-10-19). The guard test
  /// `test/app/state/boot_no_google_prompt_test.dart` forbids any
  /// `GoogleAuthService` / `restoreSession` reference in
  /// `boot_coordinator.dart`. The session comes back only through the
  /// explicit account button in the account hub.
  Future<GoogleSignInAccount?> restoreSession() async {
    await init();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_signedInKey) != true) return null;
      final user =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (user != null) {
        account.value = user;
        await _persistAccount(user);
      }
      return user;
    } catch (e) {
      AppLogger.warning('GoogleAuth', 'silent restore failed: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      AppLogger.warning('GoogleAuth', 'signOut failed: $e');
    } finally {
      account.value = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_signedInKey, false);
      } catch (e) {
        AppLogger.warning('GoogleAuth', 'signOut persist failed: $e');
      }
    }
  }

  /// Full revoke (removes app access from the Google account server-side).
  Future<void> disconnect() async {
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      AppLogger.warning('GoogleAuth', 'disconnect failed: $e');
    } finally {
      account.value = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_signedInKey, false);
        await prefs.remove(_emailKey);
      } catch (e) {
        AppLogger.warning('GoogleAuth', 'disconnect persist failed: $e');
      }
    }
  }

  Future<void> _persistAccount(GoogleSignInAccount? user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_signedInKey, user != null);
      if (user != null) {
        await prefs.setString(_emailKey, user.email);
      }
    } catch (e) {
      AppLogger.warning('GoogleAuth', 'account persist failed: $e');
    }
  }
}
