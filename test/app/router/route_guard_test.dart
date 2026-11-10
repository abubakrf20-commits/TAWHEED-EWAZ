import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/app/router/route_guard.dart';

/// Android can hand Flutter an initial route the app never asked for. The
/// guard is what keeps that from rendering the 404 page before the splash.
void main() {
  test('widget trampoline locations are foreign', () {
    expect(
      isForeignLocation(Uri.parse('glance-action:/CALLBACK?appWidgetId=224')),
      isTrue,
    );
    expect(
      isForeignLocation(Uri.parse('/CALLBACK?appWidgetId=224&viewId=7')),
      isTrue,
    );
    expect(isForeignLocation(Uri.parse('CALLBACK?appWidgetId=224')), isTrue);
  });

  test('other apps\' schemes are foreign', () {
    expect(isForeignLocation(Uri.parse('https://example.com/x')), isTrue);
    expect(isForeignLocation(Uri.parse('intent://scan/#Intent;end')), isTrue);
  });

  test('every real app route is not foreign', () {
    for (final path in <String>[
      '/',
      '/splash',
      '/onboarding',
      '/zakat',
      '/prayer/settings',
      '/quran/123',
      '/settings/notifications',
    ]) {
      expect(isForeignLocation(Uri.parse(path)), isFalse, reason: path);
    }
  });

  test('the app\'s own scheme is allowed', () {
    expect(isForeignLocation(Uri.parse('tawheed://prayer')), isFalse);
  });

  test('an empty location falls through to the router', () {
    expect(isForeignLocation(Uri.parse('')), isFalse);
  });
}
