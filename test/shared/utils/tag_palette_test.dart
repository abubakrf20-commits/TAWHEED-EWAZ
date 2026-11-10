import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/utils/tag_palette.dart';

/// Independent FNV-1a 32-bit reference implementation: the expected values
/// below must keep matching [stableHash] — if the helper is ever swapped
/// for `String.hashCode` (randomized per isolate) these fail.
int _fnv1a(String value) {
  var hash = 0x811C9DC5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

void main() {
  group('stableHash', () {
    test('matches the standard FNV-1a 32-bit test vectors', () {
      expect(stableHash(''), 0x811C9DC5);
      expect(stableHash('a'), 0xE40C292C);
      expect(stableHash('foobar'), 0xBF9CF968);
    });

    test('agrees with the reference implementation for Persian labels', () {
      for (final s in ['قرآن', 'خانه', 'مطالعه', 'کار روزانه', 'حفظ']) {
        expect(stableHash(s), _fnv1a(s));
      }
    });

    test('stays inside the unsigned 32-bit range', () {
      for (final s in ['', 'a', 'قرآن', 'یک برچسب نسبتاً بلند برای آزمون']) {
        expect(stableHash(s), inInclusiveRange(0, 0xFFFFFFFF));
      }
    });
  });

  group('stablePaletteColor', () {
    const palette = <Color>[Colors.red, Colors.green, Colors.blue];

    test('always returns one of the palette colors', () {
      for (final tag in ['قرآن', 'خانه', 'کار', 'x', '']) {
        expect(stablePaletteColor(tag, palette), isIn(palette));
      }
    });

    test('same label maps to the same color (launch-stable)', () {
      expect(stablePaletteColor('قرآن', palette),
          stablePaletteColor('قرآن', palette));
      expect(stablePaletteColor('قرآن', palette),
          isNot(stablePaletteColor('خانه', palette)));
    });

    test('empty palette falls back to grey instead of throwing', () {
      expect(stablePaletteColor('قرآن', const []), Colors.grey);
    });
  });
}
