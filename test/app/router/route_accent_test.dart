import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/app/router/route_accent.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Every pushed page carries the identity colour of its own section, so a
/// route opened from «بیشتر» does not stay orange when it is about زکات or
/// رقیه. The table is data — this test is what keeps it honest.
void main() {
  test('known routes map to their identity hue', () {
    expect(routeAccentFor('/zakat'), TopicHues.zakat);
    expect(routeAccentFor('/ruqyah'), TopicHues.ruqyah);
    expect(routeAccentFor('/books'), TopicHues.ketabkhaneh);
    expect(routeAccentFor('/tools/moon'), TopicHues.moon);
    expect(routeAccentFor('/hadeeth-enc/123'), TopicHues.hadeethEnc);
  });

  test('the longest prefix wins', () {
    expect(routeAccentFor('/prayer/period'), TopicHues.period);
    expect(routeAccentFor('/prayer/settings'), TopicHues.prayer);
    expect(routeAccentFor('/prayer'), TopicHues.prayer);
    expect(routeAccentFor('/settings/notifications'), TopicHues.app);
  });

  test('unknown routes fall back to the phase palette', () {
    expect(routeAccentFor('/'), isNull);
    expect(routeAccentFor('/not-a-route'), isNull);
  });

  test('a prefix never matches a sibling with the same stem', () {
    // `/dua` must not swallow `/duas` (and vice versa: longest wins).
    expect(routeAccentFor('/dua'), TopicHues.dua);
    expect(routeAccentFor('/duas'), TopicHues.duas);
  });
}
