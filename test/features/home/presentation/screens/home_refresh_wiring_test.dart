import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The reported failure included a pull-to-refresh that changed nothing: it
/// poked the repository directly, so the provider's state — and therefore the
/// hero and the card — never rebuilt. The refresh must go through the
/// notifier's reload, which forces a fresh fix and publishes the result.
///
/// Pumping the real HomeTab needs the database, settings and notification
/// graph; this guards the one wiring line that matters instead.
void main() {
  test('pull-to-refresh reloads prayer times through the provider', () {
    final source = File('lib/features/home/presentation/screens/home_tab.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), '');

    expect(
      source,
      contains(
          'onRefresh:()=>ref.read(prayerTimesProvider.notifier).reload(forceRefresh:true)'),
      reason: 'the RefreshIndicator must call PrayerTimes.reload, not the '
          'repository directly',
    );
  });
}
