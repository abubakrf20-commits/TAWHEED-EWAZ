import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart' as gs;
import 'package:path/path.dart' as p;
import 'package:tawheeed/features/account/data/repositories/account_repository.dart';
import 'package:tawheeed/features/account/domain/entities/cloud_backup_item.dart';
import 'package:tawheeed/features/settings/services/google_auth_service.dart';
import 'package:tawheeed/shared/services/firebase_core_init.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Firebase-backed [AccountRepository]: Firebase Auth (email/password) for the
/// identity, Firebase Storage for backup ZIPs under `users/{uid}/backups`.
class FirebaseAccountRepository implements AccountRepository {
  final auth.FirebaseAuth? _authInstance;
  final FirebaseStorage? _storageInstance;

  /// Resolved lazily on first use: `FirebaseAuth.instance` THROWS when no
  /// Firebase app exists yet, and this repository is constructed the moment
  /// the hub page opens — long before the background `ensureFirebaseInitialized`
  /// (`main.dart` starts it unawaited) has necessarily finished. A eager field
  /// initializer made the very first provider read throw on a cold start.
  auth.FirebaseAuth get _auth => _authInstance ?? auth.FirebaseAuth.instance;

  FirebaseStorage get _storage => _storageInstance ?? FirebaseStorage.instance;

  FirebaseAccountRepository({
    auth.FirebaseAuth? authInstance,
    FirebaseStorage? storage,
  })  : _authInstance = authInstance,
        _storageInstance = storage;

  /// True when the identity cloud is usable.
  ///
  /// It AWAITS the lazy init first: `Firebase.apps.isEmpty` during the first
  /// seconds of a cold start is a race, not a state — the old check turned
  /// every sign-in tap inside that window into «سرویس ابری در دسترس نیست.»
  /// (`ensureFirebaseInitialized` is memoized and bounded at 8s, so this adds
  /// nothing once init has finished).
  Future<bool> get _available async {
    await ensureFirebaseInitialized();
    return Firebase.apps.isNotEmpty;
  }

  Reference _backupsRef(String uid) => _storage.ref('users/$uid/backups');

  @override
  Stream<String?> authStateChanges() async* {
    await ensureFirebaseInitialized();
    if (Firebase.apps.isEmpty) {
      // Never throw from a stream the hub watches at build time — a signed-out
      // page must render, not error.
      yield null;
      return;
    }
    yield* _auth.authStateChanges().map((u) => u?.email);
  }

  @override
  String? get currentAccountLabel =>
      Firebase.apps.isEmpty ? null : _auth.currentUser?.email;

  @override
  Future<String> signUpWithEmail(String email, String password) async {
    if (!await _available) {
      throw Exception('سرویس ابری در دسترس نیست.');
    }
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user!.uid;
  }

  @override
  Future<String> signInWithEmail(String email, String password) async {
    if (!await _available) {
      throw Exception('سرویس ابری در دسترس نیست.');
    }
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user!.uid;
  }

  @override
  Future<String?> signInWithGoogle({String? idToken}) async {
    if (!await _available) {
      throw Exception('سرویس ابری در دسترس نیست.');
    }
    try {
      var token = idToken;
      if (token == null || token.isEmpty) {
        await gs.GoogleSignIn.instance
            .initialize(serverClientId: GoogleAuthService.serverClientId);
        final user = await gs.GoogleSignIn.instance.authenticate();
        token = user.authentication.idToken;
      }
      if (token == null || token.isEmpty) {
        throw StateError('دریافت توکن هویت از گوگل ناموفق بود.');
      }
      final credential = auth.GoogleAuthProvider.credential(idToken: token);
      final result = await _auth.signInWithCredential(credential);
      return result.user?.uid;
    } on gs.GoogleSignInException catch (e) {
      AppLogger.warning('firebase_account_repository', 'error: $e');
      if (e.code == gs.GoogleSignInExceptionCode.canceled) return null;
      throw Exception(
          'ورود با گوگل ناموفق بود: ${e.description ?? e.code.name}');
    } on auth.FirebaseAuthException catch (e) {
      // The Google address already exists as an email/password account (and
      // the project keeps one account per email): Firebase cannot silently
      // merge them. The Drive session still stands — only the Firebase link
      // needs the user to sign in with email/password first.
      AppLogger.warning('firebase_account_repository', 'link failed: $e');
      if (e.code == 'account-exists-with-different-credential') {
        // StateError (not Exception): the screen's friendly-error mapper
        // passes StateError messages through verbatim.
        throw StateError('این ایمیل قبلاً با رمز عبور ثبت شده است؛ '
            'برای اتصال ابری، اول با ایمیل و رمز وارد شوید.');
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e, st) {
      AppLogger.error('AccountRepository', 'signOut failed: $e', st);
    }
  }

  @override
  Future<String> uploadBackup(File zip, {String? displayName}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('ابتدا وارد حساب شوید.');
    final ts = DateTime.now().millisecondsSinceEpoch;
    final name = displayName ?? 'tawheeed_backup_$ts.zip';
    final ref = _backupsRef(uid).child(name);
    await ref.putFile(zip);
    return name;
  }

  /// Storage answers a `listAll()` on a prefix that has never held a single
  /// object with a 404 (`object-not-found`). For a fresh account that means
  /// «هنوز نسخه‌ای آپلود نشده», not a failed list — so it must read as empty,
  /// not as the hub's «دریافت فهرست ناموفق بود».
  @visibleForTesting
  static bool isMissingBackupsPrefix(Object error) {
    if (error is! FirebaseException) return false;
    if (error.code == 'object-not-found') return true;
    final message = error.message?.toLowerCase() ?? '';
    return message.contains('does not exist') ||
        message.contains('no object exists');
  }

  @override
  Future<List<CloudBackupItem>> listBackups(Directory tempDir) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('ابتدا وارد حساب شوید.');
    final ListResult result;
    try {
      result = await _backupsRef(uid).listAll();
    } on FirebaseException catch (e) {
      if (!isMissingBackupsPrefix(e)) rethrow;
      return <CloudBackupItem>[];
    }
    final items = <CloudBackupItem>[];
    for (final item in result.items) {
      try {
        final meta = await item.getMetadata();
        items.add(CloudBackupItem(
          name: item.name,
          sizeBytes: meta.size ?? 0,
          updated: meta.updated ?? meta.timeCreated ?? DateTime.now(),
        ));
      } catch (e) {
        AppLogger.warning('AccountRepository', 'metadata failed $e');
      }
    }
    items.sort((a, b) => b.updated.compareTo(a.updated));
    return items;
  }

  @override
  Future<String> downloadBackup(CloudBackupItem item, Directory tempDir) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('ابتدا وارد حساب شوید.');
    final ref = _backupsRef(uid).child(item.name);
    final bytes = await ref.getData();
    if (bytes == null) throw Exception('دانلود نسخه ابری ناموفق بود.');
    final file = File(p.join(tempDir.path, item.name));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<void> deleteBackup(CloudBackupItem item) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('ابتدا وارد حساب شوید.');
    await _backupsRef(uid).child(item.name).delete();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (!await _available) {
      throw Exception('سرویس ابری در دسترس نیست.');
    }
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('ابتدا وارد حساب شوید.');
    // Best-effort: remove the user's cloud backups so nothing is left behind.
    // A failure here must still let the account itself be deleted.
    try {
      final result = await _backupsRef(user.uid).listAll();
      for (final item in result.items) {
        await item.delete();
      }
    } catch (e) {
      AppLogger.warning('AccountRepository', 'backup cleanup failed: $e');
    }
    try {
      await user.delete();
    } on auth.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception(
            'برای حذف حساب، لطفاً ابتدا دوباره وارد شوید و باز تلاش کنید.');
      }
      rethrow;
    }
  }
}
