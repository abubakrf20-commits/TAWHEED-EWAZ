import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards A-04: Firebase Auth keeps its session (FIREBASE_USER plus the
/// GET_TOKEN_RESPONSE entries — a refresh token) in the sharedpref file
/// `com.google.firebase.auth.api.Store.[DEFAULT].xml`.
///
/// Evidence: firebase-auth 24.2.0,
/// `com/google/firebase/auth/internal/zzce.class` builds the file name with
/// `String.format("com.google.firebase.auth.api.Store.%s", appName)`.
///
/// Both Android auto-backup mechanisms include the whole sharedpref domain,
/// so that file must be excluded explicitly in all three places; otherwise the
/// token travels to Google's cloud (or a new device) with the user's data.
///
/// The same file also guards the P3 backlog item from `SECURITY_PRIVACY.md`
/// §3: the on-device diagnostics log sits at the documents root (the `file`
/// domain) and must stay out of every backup surface too.
void main() {
  const authStore = 'com.google.firebase.auth.api.Store.[DEFAULT].xml';
  const excludeLine = '<exclude domain="sharedpref" path="$authStore"/>';
  const logExcludes = [
    '<exclude domain="file" path="tawheed_log.txt"/>',
    '<exclude domain="file" path="trayheed_log.txt"/>',
  ];

  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue,
        reason: 'run from the project root so $path resolves');
    return file.readAsStringSync();
  }

  /// The body of one <cloud-backup>/<device-transfer> section.
  String section(String src, String tag) {
    final start = src.indexOf('<$tag>');
    final end = src.indexOf('</$tag>');
    expect(start, isNonNegative, reason: 'missing <$tag> section');
    expect(end, greaterThan(start), reason: 'missing </$tag> section');
    return src.substring(start, end);
  }

  test('Android <= 11 backup excludes the Firebase Auth credential store', () {
    final src = read('android/app/src/main/res/xml/backup_rules.xml');
    expect(src, contains(excludeLine));
    // The vault key exclusion this file already carried must survive.
    expect(src, contains('<exclude domain="sharedpref" path="FlutterSecureStorage.xml"/>'));
  });

  test('Android 12+ cloud backup excludes the Firebase Auth credential store',
      () {
    final src = read('android/app/src/main/res/xml/data_extraction_rules.xml');
    expect(section(src, 'cloud-backup'), contains(excludeLine));
  });

  test('Android 12+ device transfer excludes the Firebase Auth credential store',
      () {
    final src = read('android/app/src/main/res/xml/data_extraction_rules.xml');
    expect(section(src, 'device-transfer'), contains(excludeLine));
  });

  test('the sharedpref domain is still included, so settings keep backing up',
      () {
    final backup = read('android/app/src/main/res/xml/backup_rules.xml');
    final extraction =
        read('android/app/src/main/res/xml/data_extraction_rules.xml');
    expect(backup, contains('<include domain="sharedpref" path="."/>'));
    expect(section(extraction, 'cloud-backup'),
        contains('<include domain="sharedpref" path="."/>'));
    expect(section(extraction, 'device-transfer'),
        contains('<include domain="sharedpref" path="."/>'));
  });

  group('the on-device diagnostics log stays out of every backup path', () {
    test('Android <= 11 backup', () {
      final src = read('android/app/src/main/res/xml/backup_rules.xml');
      for (final line in logExcludes) {
        expect(src, contains(line));
      }
    });

    test('Android 12+ cloud backup', () {
      final src =
          read('android/app/src/main/res/xml/data_extraction_rules.xml');
      final body = section(src, 'cloud-backup');
      for (final line in logExcludes) {
        expect(body, contains(line));
      }
    });

    test('Android 12+ device transfer', () {
      final src =
          read('android/app/src/main/res/xml/data_extraction_rules.xml');
      final body = section(src, 'device-transfer');
      for (final line in logExcludes) {
        expect(body, contains(line));
      }
    });

    test('the excluded paths still match the logger file names', () {
      final logger = File('lib/shared/utils/app_logger.dart').readAsStringSync();
      expect(logger, contains("_fileName = 'tawheed_log.txt'"));
      expect(logger, contains("_legacyFileName = 'trayheed_log.txt'"));
    });
  });
}
