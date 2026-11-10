import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the native side of `com.tawheeed/magnetic_declination`.
///
/// StandardMessageCodec encodes a Dart `int` that fits signed 32 bits as
/// `java.lang.Integer`, so `call.argument<Long>("timestamp")` throws at the
/// cast for epoch SECONDS (~1.7e9) and every lookup failed with
/// `MAGNETIC_ERROR`. The Dart channel tests mock the platform and the JVM test
/// set has no Robolectric, so the native handler is pinned by source scan (the
/// repo's style for native invariants — see android_manifest_queries_test.dart).
Future<String> readSource(String path) async =>
    (await File(path).readAsString()).replaceAll('\r\n', '\n');

String stripLineComments(String source) => source
    .split('\n')
    .map((line) {
      final at = line.indexOf('//');
      return at == -1 ? line : line.substring(0, at);
    })
    .join('\n');

void main() {
  late String activity;
  late String service;

  setUpAll(() async {
    activity = await readSource(
        'android/app/src/main/kotlin/com/islamic/tawheeed/MainActivity.kt');
    service =
        await readSource('lib/features/prayer/services/magnetic_declination_service.dart');
  });

  group('magnetic declination channel', () {
    test('the handler reads the timestamp as a Number and widens it', () {
      final start = activity.indexOf('"calculateDeclination" ->');
      expect(start, greaterThan(0), reason: 'the handler must exist');
      final block = activity.substring(start, start + 900);

      expect(block.contains('argument<Number>("timestamp")?.toLong()'), isTrue,
          reason: 'epoch seconds arrive as java.lang.Integer; a typed Long '
              'read throws and the qibla loses its true-north correction');
      expect(block.contains('argument<Long>("timestamp")'), isFalse,
          reason: 'the exact cast that broke every lookup');
      expect(block.contains('argument<Int>("timestamp")'), isFalse,
          reason: 'an Int read breaks once the value outgrows 32 bits');
    });

    test('Dart sends seconds; the native side converts to milliseconds', () {
      expect(service.contains('date.millisecondsSinceEpoch ~/ 1000'), isTrue,
          reason: 'the wire unit is seconds (GeomagneticField wants millis)');
      expect(activity.contains('timestamp * 1000'), isTrue,
          reason: 'the native side must widen seconds to milliseconds');
    });

    test('no other small numeric argument is read as a typed Long/Int', () {
      // Epoch MILLISECONDS (~1.7e12) do not fit Int32, so they arrive as
      // java.lang.Long and the typed read is safe. The alarm keys are the only
      // ones allowed to rely on that — a new small integer read this way would
      // fail the same way the declination timestamp did.
      const epochMillisKeys = {'trigger_time', 'mute_time', 'iqamah_time'};
      final typedReads = RegExp(r'call\.argument<(Long|Int)>\("([a-z_]+)"\)')
          .allMatches(stripLineComments(activity));

      for (final match in typedReads) {
        expect(epochMillisKeys.contains(match.group(2)), isTrue,
            reason: '${match.group(2)} is read as a typed ${match.group(1)}; '
                'only epoch-millisecond keys survive that cast. Use '
                'argument<Number>(...).toLong() for anything smaller.');
      }
      expect(typedReads.length, epochMillisKeys.length,
          reason: 'the allowlist above must match the real read sites');
    });
  });
}
