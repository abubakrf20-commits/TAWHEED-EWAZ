import 'dart:io';

import 'package:tawheeed/features/account/domain/entities/cloud_backup_item.dart';

/// The signed-in account and its cloud backups (Firebase).
///
/// Implementations should degrade gracefully (throw descriptive exceptions)
/// so the UI can surface errors in Persian without crashing. When Firebase is
/// unavailable the app simply doesn't expose this feature.
abstract class AccountRepository {
  /// Emits the current signed-in user's email (null when signed out).
  Stream<String?> authStateChanges();

  /// Display-safe identity of the current user, or null when signed out.
  String? get currentAccountLabel;

  /// Creates a new account with email/password. Returns the uid on success.
  Future<String> signUpWithEmail(String email, String password);

  /// Signs in with email/password. Returns the uid on success.
  Future<String> signInWithEmail(String email, String password);

  /// Signs in with Google. Returns the uid, or null when the user cancels.
  ///
  /// When [idToken] is supplied (the Drive sign-in that just happened), it is
  /// used directly so the user is not prompted twice; otherwise the Google
  /// account picker runs here.
  Future<String?> signInWithGoogle({String? idToken});

  Future<void> signOut();

  /// Stores [zip] under `users/{uid}/backups/…` and returns its upload name.
  Future<String> uploadBackup(File zip, {String? displayName});

  /// Lists the user's cloud backups, newest first.
  Future<List<CloudBackupItem>> listBackups(Directory tempDir);

  /// Downloads a backup to [tempDir] and returns the local zip path.
  Future<String> downloadBackup(CloudBackupItem item, Directory tempDir);

  Future<void> deleteBackup(CloudBackupItem item);

  /// Sends a password-reset email to [email]. Throws on failure so the UI can
  /// show a Persian message.
  Future<void> sendPasswordResetEmail(String email);

  /// Deletes the current user's account and, best-effort, its cloud backups.
  /// Throws a descriptive Persian message when Firebase demands a recent
  /// login first.
  Future<void> deleteAccount();
}
