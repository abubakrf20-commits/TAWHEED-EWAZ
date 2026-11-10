import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one-tap Google linking: the phone's Google account must open
/// BOTH clouds — the Drive session and the Firebase identity — so every
/// device with the same Google account sees the same backups.
///
/// The Google picker UI cannot run in a plain Dart test (platform plugin), so
/// these are source guards in the repo's established style: they pin the
/// wiring (Drive sign-in, then Firebase credential with the SAME idToken so
/// the picker never appears twice), not the pixels.
Future<String> readSource(String path) async =>
    (await File(path).readAsString()).replaceAll('\r\n', '\n');

void main() {
  group('Google one-tap links Drive + Firebase', () {
    test('the account screen signs into Firebase after the Drive tap',
        () async {
      final screen = await readSource(
          'lib/features/account/presentation/screens/account_screen.dart');
      final fn = screen.substring(screen.indexOf('Future<void> _signInGoogle'));
      final body = fn.substring(0, fn.indexOf('Future<void> _signOut'));
      expect(body.contains('GoogleAuthService.instance.signIn()'), isTrue,
          reason: 'the Drive session must come first (primary cloud)');
      expect(body.contains('signInWithGoogle('), isTrue,
          reason: 'the Firebase identity must be linked on the same tap');
      expect(body.contains('idToken:'), isTrue,
          reason: 'the Drive idToken must be reused — no second picker');
    });

    test('the repository honours a supplied idToken without re-prompting',
        () async {
      final repo = await readSource(
          'lib/features/account/data/repositories/firebase_account_repository.dart');
      expect(repo.contains('signInWithGoogle({String? idToken})'), isTrue,
          reason: 'the token must be an explicit input of the link step');
      expect(repo.contains('GoogleAuthProvider.credential(idToken: token)'),
          isTrue,
          reason: 'the Firebase credential comes from that token');
    });

    test('a stale-password collision explains itself instead of dying',
        () async {
      final repo = await readSource(
          'lib/features/account/data/repositories/firebase_account_repository.dart');
      expect(
          repo.contains('account-exists-with-different-credential'), isTrue,
          reason: 'the merge collision must be caught, not generic-failed');
    });

    test('a Firebase-link failure is surfaced after the Drive tap', () async {
      final screen = await readSource(
          'lib/features/account/presentation/screens/account_screen.dart');
      final fn = screen.substring(screen.indexOf('Future<void> _signInGoogle'));
      final body = fn.substring(0, fn.indexOf('Future<void> _signOut'));
      expect(body.contains('AppSnackBar.error'), isTrue,
          reason: 'the inline error only renders in the signed-out auth forms, '
              'so a link failure after Drive success needs its own notice');
    });

    test('sign-out clears both sessions without a stale-stream gate', () async {
      final screen = await readSource(
          'lib/features/account/presentation/screens/account_screen.dart');
      final fn = screen.substring(screen.indexOf('Future<void> _signOut'));
      final body = fn.substring(0, fn.indexOf('Future<void> _deleteAccount'));
      expect(body.contains('accountEmailProvider).value != null'), isFalse,
          reason: 'a stale stream value skipped the Firebase sign-out');
      expect(body.contains('GoogleAuthService.instance.signOut()'), isTrue,
          reason: 'the Drive session still needs clearing');
      expect(body.contains('accountRepositoryProvider).signOut()'), isTrue,
          reason: 'the Firebase session is cleared unconditionally');
    });

    test('delete wipes the Drive folder and revokes access', () async {
      final screen = await readSource(
          'lib/features/account/presentation/screens/account_screen.dart');
      final fn = screen.substring(screen.indexOf('Future<void> _deleteAccount'));
      expect(fn.contains('_purgeDriveBackups()'), isTrue,
          reason: 'the hidden Drive folder must not survive deletion');
      expect(fn.contains('.disconnect()'), isTrue,
          reason: 'Drive access must be revoked server-side, not just signed out');
    });
  });
}
