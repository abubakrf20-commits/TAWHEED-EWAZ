import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/utils/geo_format.dart';

void main() {
  group('GeoFormat — the shared LTR-safe formatters (B2/B3)', () {
    test('degrees is LTR-isolated with the degree sign inside', () {
      final s = GeoFormat.degrees(246.9);
      expect(s.startsWith('\u2066'), isTrue);
      expect(s.endsWith('\u2069'), isTrue);
      expect(s, contains('246.9'));
      expect(s, contains('\u00b0'));
    });

    test('degrees decimals=0 rounds display only', () {
      expect(GeoFormat.degrees(113.49, decimals: 0), contains('113'));
    });

    test('signedDegrees uses a real minus and plus', () {
      expect(GeoFormat.signedDegrees(4.2), contains('+4.2'));
      final neg = GeoFormat.signedDegrees(-15.6);
      expect(neg.contains('\u2212'), isTrue);
      expect(neg.contains('-15.6'), isFalse);
    });

    test('percent rounds HALF UP to an integer (B2)', () {
      // 9.529707880484157% printed as «10%» — the old screen spray-printed
      // fifteen decimals.
      expect(GeoFormat.percent(9.529707880484157), contains('10'));
      expect(GeoFormat.percent(0.4), contains('0'));
      expect(GeoFormat.percent(99.5), contains('100'));
      expect(GeoFormat.percent(3.49), contains('3'));
      expect(GeoFormat.percent(3.5), contains('4'));
    });

    test('clock zero-pads and isolates', () {
      final s = GeoFormat.clock(2, 36);
      expect(s, contains('02:36'));
      expect(s.startsWith('\u2066'), isTrue);
    });

    test('durationWords spells durations in Persian words (B3)', () {
      final d = GeoFormat.durationWords(const Duration(hours: 15, minutes: 36));
      expect(d, contains('15'));
      expect(d, contains('ساعت'));
      expect(d, contains('36'));
      expect(d, contains('دقیقه'));
      // The banned shorthand shapes: digit followed by the bare letter.
      expect(RegExp(r'\dس').hasMatch(d), isFalse, reason: 'no «15س»');
      expect(RegExp(r'\dد').hasMatch(d), isFalse, reason: 'no «36د»');
      // 40 minutes: no hours segment at all.
      expect(GeoFormat.durationWords(const Duration(minutes: 40)),
          contains('40 دقیقه'));
    });
  });
}
