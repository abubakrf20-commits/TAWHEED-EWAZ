import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards Android package-visibility rules (Android 11+ / targetSdk 30+):
/// url_launcher's canLaunchUrl() returns false for a scheme unless the app
/// declares a matching `<queries>` intent, which had silently disabled the
/// emergency-contact dialer and the store rate button. A plain text check is
/// enough — the failure mode is a missing declaration, not a parsing bug.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');

  test('AndroidManifest declares <queries> for every launched scheme', () {
    expect(manifest.existsSync(), isTrue,
        reason: 'run from the project root so the manifest resolves');
    final xml = manifest.readAsStringSync();

    final queriesMatch = RegExp('<queries>([\\s\\S]*?)</queries>').firstMatch(xml);
    expect(queriesMatch, isNotNull,
        reason: 'no <queries> block — package visibility is broken');
    final queries = queriesMatch!.group(1)!;

    for (final scheme in ['tel', 'mailto', 'market', 'https']) {
      expect(queries, contains('android:scheme="$scheme"'),
          reason: '<queries> must cover the $scheme: intent');
    }
  });
}
