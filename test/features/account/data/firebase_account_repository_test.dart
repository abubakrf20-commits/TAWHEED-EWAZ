import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/account/data/repositories/firebase_account_repository.dart';

/// A Storage `listAll()` on a prefix that has never held an object answers
/// with a 404. For a fresh account that is «هنوز نسخه‌ای آپلود نشده», so the
/// hub must render its empty state — not «دریافت فهرست ناموفق بود».
void main() {
  group('FirebaseAccountRepository.isMissingBackupsPrefix', () {
    test('object-not-found is an empty prefix', () {
      expect(
        FirebaseAccountRepository.isMissingBackupsPrefix(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'object-not-found',
            message: 'Object does not exist at location.',
          ),
        ),
        isTrue,
      );
    });

    test('the «does not exist» wording is accepted without the code', () {
      expect(
        FirebaseAccountRepository.isMissingBackupsPrefix(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'unknown',
            message: 'Object does not exist at location.',
          ),
        ),
        isTrue,
      );
    });

    test('the «no object exists» wording is accepted too', () {
      expect(
        FirebaseAccountRepository.isMissingBackupsPrefix(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'unknown',
            message: 'No object exists at the desired reference.',
          ),
        ),
        isTrue,
      );
    });

    test('permission-denied stays a real failure', () {
      expect(
        FirebaseAccountRepository.isMissingBackupsPrefix(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'unauthorized',
            message: 'User does not have permission.',
          ),
        ),
        isFalse,
      );
    });

    test('a non-Firebase error is never swallowed', () {
      expect(
        FirebaseAccountRepository.isMissingBackupsPrefix(
          Exception('network down'),
        ),
        isFalse,
      );
    });
  });

  test('listBackups maps a missing prefix to an empty list', () async {
    final source = (await File(
            'lib/features/account/data/repositories/firebase_account_repository.dart')
        .readAsString());
    final fn = source
        .substring(source.indexOf('Future<List<CloudBackupItem>> listBackups'));
    final body = fn.substring(0, fn.indexOf('Future<String> downloadBackup'));
    expect(body.contains('on FirebaseException catch (e)'), isTrue,
        reason: 'the Storage 404 must be caught at the list call');
    expect(body.contains('isMissingBackupsPrefix(e)'), isTrue,
        reason: 'only a missing prefix is an empty list');
    expect(body.contains('return <CloudBackupItem>[];'), isTrue,
        reason: 'the hub then shows its empty state, not an error');
  });
}
