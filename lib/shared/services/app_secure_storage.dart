import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The one secure-storage instance every secret in the app is read through.
///
/// `resetOnError: false` is load-bearing. The plugin's default (`true`) reacts
/// to a failed read by **deleting that key** and retrying — flutter_secure_storage
/// 10.3.4 `FlutterSecureStorage.handleStorageError` — so a transient Keystore
/// error would silently erase the vault AES key (`personal_info.aes_key`) or the
/// auto-backup key (`backup.auto_key`), and the next write would mint a fresh
/// key over data sealed with the lost one. With this flag a failure surfaces
/// instead, and the stored key survives for a retry.
///
/// `migrateOnAlgorithmChange` stays at its default so an upgrade that changes
/// the plugin's cipher still migrates existing values.
const appSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: false),
);
