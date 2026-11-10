import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/prayer/presentation/screens/prayer_times_share_screen.dart';

/// The longest value the strip ever prints: a Hijri date with a long month
/// name. Its text is wider than its cell, so it is scaled down by the cell's
/// `FittedBox` — the exact case that used to shorten the Hijri box.
const _hijri = '۱۴ جمادی‌الاول ۱۴۴۷';

Future<void> _pumpStrip(WidgetTester tester, {double width = 300}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: width,
            child: const PrayerShareDateStrip(
              weekday: 'پنجشنبه',
              shamsi: '۲۵ مهر ۱۴۰۵',
              hijri: _hijri,
              gregorian: '16 اکتبر 2026',
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

Rect _cellRect(WidgetTester tester, String value) {
  final container = find
      .ancestor(of: find.text(value), matching: find.byType(Container))
      .first;
  return tester.getRect(container);
}

void main() {
  testWidgets('the four date boxes share one size (the Hijri box included)',
      (tester) async {
    await _pumpStrip(tester);

    final cells = <String, Rect>{
      'weekday': _cellRect(tester, 'پنجشنبه'),
      'shamsi': _cellRect(tester, '۲۵ مهر ۱۴۰۵'),
      'hijri': _cellRect(tester, _hijri),
      'gregorian': _cellRect(tester, '16 اکتبر 2026'),
    };

    final first = cells['weekday']!;
    for (final entry in cells.entries) {
      expect(entry.value.width, moreOrLessEquals(first.width, epsilon: 0.01),
          reason: '${entry.key} must share the row width');
      expect(
        entry.value.height,
        moreOrLessEquals(first.height, epsilon: 0.01),
        reason: '${entry.key} must share the row height — a scaled-down value '
            'used to shrink its own box (the reported «هجری کوتاه‌تر است»)',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the strip fits a narrow card without overflowing',
      (tester) async {
    await _pumpStrip(tester, width: 260);
    expect(tester.takeException(), isNull);
    final hijri = _cellRect(tester, _hijri);
    expect(hijri.width, greaterThan(0));
    expect(hijri.height, greaterThan(0));
  });
}
