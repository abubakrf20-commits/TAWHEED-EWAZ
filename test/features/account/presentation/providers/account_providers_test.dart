import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/account/data/repositories/account_repository.dart';
import 'package:tawheeed/features/account/domain/entities/cloud_backup_item.dart';
import 'package:tawheeed/features/account/presentation/providers/account_providers.dart';

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository({this.email});

  final String? email;
  int signOutCalls = 0;

  @override
  Stream<String?> authStateChanges() => Stream<String?>.value(email);

  @override
  String? get currentAccountLabel => email;

  @override
  Future<String> signUpWithEmail(String email, String password) async => 'uid';

  @override
  Future<String> signInWithEmail(String email, String password) async => 'uid';

  @override
  Future<String?> signInWithGoogle({String? idToken}) async => 'uid';

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  Future<String> uploadBackup(File zip, {String? displayName}) async =>
      'name.zip';

  @override
  Future<List<CloudBackupItem>> listBackups(Directory tempDir) async =>
      const [];

  @override
  Future<String> downloadBackup(
          CloudBackupItem item, Directory tempDir) async =>
      '/tmp/x.zip';

  @override
  Future<void> deleteBackup(CloudBackupItem item) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> deleteAccount() async {}
}

/// Reads the first emitted value of [provider].
///
/// `container.read(streamProvider.future)` never resolves under riverpod 3 for
/// a `StreamProvider` — awaiting it hangs until the test times out — so the
/// value is taken from a listener instead.
Future<String?> firstEmail(ProviderContainer container) {
  final completer = Completer<String?>();
  container.listen(
    accountEmailProvider,
    (_, next) {
      // The first callback is the loading state, whose `value` is also null —
      // completing on it would pass the signed-out test by accident.
      if (next.isLoading || completer.isCompleted) return;
      completer.complete(next.value);
    },
    fireImmediately: true,
  );
  return completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('accountEmailProvider', () {
    test('emits the email from the overridden repository', () async {
      final container = ProviderContainer(overrides: [
        accountRepositoryProvider
            .overrideWithValue(_FakeAccountRepository(email: 'a@b.com')),
      ]);
      addTearDown(container.dispose);

      expect(await firstEmail(container), 'a@b.com');
    });

    test('emits null when nobody is signed in', () async {
      final container = ProviderContainer(overrides: [
        accountRepositoryProvider.overrideWithValue(_FakeAccountRepository()),
      ]);
      addTearDown(container.dispose);

      expect(await firstEmail(container), isNull);
    });

    test('follows the repository provider override (no Firebase needed)',
        () async {
      final repo = _FakeAccountRepository(email: 'signed@in.com');
      final container = ProviderContainer(overrides: [
        accountRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      expect(
          identical(container.read(accountRepositoryProvider), repo), isTrue);
      expect(await firstEmail(container), 'signed@in.com');
    });
  });
}
