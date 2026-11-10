import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/worship/presentation/utils/worship_colors.dart';

void main() {
  test('every default worship item has a distinct color', () {
    expect(WorshipColors.byId.length, greaterThanOrEqualTo(10));
    final colors = WorshipColors.byId.values.toSet();
    // No two default worships share an accent.
    expect(colors.length, WorshipColors.byId.length);
  });

  test('covers all ten default worship ids', () {
    const ids = [
      'quran',
      'sadaqa',
      'tahajjud',
      'fasting',
      'duha',
      'good_deeds',
      'wudu',
      'ghusl',
      'tayammum',
      'prayer',
    ];
    for (final id in ids) {
      expect(WorshipColors.byId[id], isNotNull,
          reason: 'missing color for $id');
    }
  });

  test('custom items fall back to their icon color', () {
    expect(WorshipColors.forItem('custom_1', Icons.spa),
        WorshipColors.byIcon[Icons.spa]);
    expect(WorshipColors.forItem('custom_1', Icons.clean_hands),
        WorshipColors.byIcon[Icons.clean_hands]);
  });

  test('unknown icons fall back to the neutral color', () {
    const unknown = IconData(0xE999);
    expect(WorshipColors.forItem('custom_1', unknown), WorshipColors.fallback);
  });

  group('blend', () {
    test('averages the channels of the given colors', () {
      final blend = WorshipColors.blend([
        const Color(0xFFFF0000),
        const Color(0xFF0000FF),
      ]);
      expect(blend.r, closeTo(0.5, 0.01)); // red channel averaged with blue
      expect(blend.g, closeTo(0, 0.01));
      expect(blend.b, closeTo(0.5, 0.01));
    });

    test('returns the fallback for an empty list', () {
      expect(WorshipColors.blend(const []), WorshipColors.fallback);
    });

    test('is idempotent for a single color', () {
      final c = WorshipColors.byId['quran']!;
      expect(WorshipColors.blend([c]), c);
    });
  });
}
