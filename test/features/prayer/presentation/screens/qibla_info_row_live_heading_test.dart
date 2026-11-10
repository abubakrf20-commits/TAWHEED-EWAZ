import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The compass feed drives the dial through a `ValueListenableBuilder`. The
/// «جهت فعلی» card sits BELOW that hero card, and it used to be built from a
/// bare `_compass.value` read at page-build time — so it froze on the first
/// frame (device-proven: «—» under «جهت فعلی» for the whole session while the
/// diff line right above it read «اختلاف تا قبله: 21°»). It must take the
/// reading from its own listener instead.
String _withoutComments(String source) => source.split('\n').map((line) {
      final comment = line.indexOf('//');
      return comment < 0 ? line : line.substring(0, comment);
    }).join('\n');

void main() {
  final code = _withoutComments(File(
          'lib/features/prayer/presentation/screens/qibla_compass_card.dart')
      .readAsStringSync());

  test('the «جهت فعلی» row is built inside the compass listener', () {
    final call = code.indexOf('_buildInfoRow(reading)');
    expect(call, greaterThan(-1),
        reason: 'the info row must receive the live CompassReading');
    final builder = code
        .substring(0, call)
        .lastIndexOf('ValueListenableBuilder<CompassReading>');
    expect(builder, greaterThan(-1),
        reason: 'a bare call rebuilds only when the page does, so the heading '
            'card stays on its first-frame value');
    expect(call - builder, lessThan(400),
        reason: 'the call must sit inside that builder, not after it');
  });

  test('the info row never reads _compass.value directly', () {
    final start = code.indexOf('Widget _buildInfoRow(');
    expect(start, greaterThan(-1));
    final body = code.substring(start, start + 900);
    expect(body.contains('_compass.value'), isFalse,
        reason: 'reading the notifier inside a plain build freezes the card');
  });
}
