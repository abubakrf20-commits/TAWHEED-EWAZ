import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/worship/domain/entities/worship_item.dart';

void main() {
  group('WorshipItem', () {
    test('constructor sets required fields', () {
      final item = WorshipItem(
        id: '1',
        label: 'قرائت قرآن',
        iconCodePoint: 0xe800,
        iconFontFamily: 'MaterialIcons',
      );
      expect(item.id, '1');
      expect(item.label, 'قرائت قرآن');
      expect(item.iconCodePoint, 0xe800);
      expect(item.iconFontFamily, 'MaterialIcons');
    });

    test('constructor sets default values', () {
      final item = WorshipItem(
        id: '1',
        label: 'نماز',
        iconCodePoint: 0xe801,
        iconFontFamily: 'MaterialIcons',
      );
      expect(item.done, false);
      expect(item.points, 10);
    });

    test('constructor sets custom values', () {
      final item = WorshipItem(
        id: '2',
        label: 'روزه',
        iconCodePoint: 0xe802,
        iconFontFamily: 'MaterialIcons',
        done: true,
        points: 20,
      );
      expect(item.done, true);
      expect(item.points, 20);
    });

    test('done is mutable', () {
      final item = WorshipItem(
        id: '1',
        label: 'صدقه',
        iconCodePoint: 0xe803,
        iconFontFamily: 'MaterialIcons',
      );
      item.done = true;
      expect(item.done, true);
    });

    group('copyWith', () {
      test('creates new object with same field values when no args', () {
        final item = WorshipItem(
          id: '1',
          label: 'ذکر',
          iconCodePoint: 0,
          iconFontFamily: 'MI',
        );
        final copy = item.copyWith();
        expect(copy.id, item.id);
        expect(copy.label, item.label);
      });

      test('replaces single field', () {
        final item = WorshipItem(
          id: '1',
          label: 'ذکر',
          iconCodePoint: 0,
          iconFontFamily: 'MI',
        );
        final copy = item.copyWith(points: 30);
        expect(copy.points, 30);
        expect(copy.label, 'ذکر');
      });
    });
  });
}
