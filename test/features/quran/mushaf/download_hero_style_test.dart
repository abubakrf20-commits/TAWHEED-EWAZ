import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// «فضای دانلود مصحف» is painted from the paper, not from gold.
///
/// The storage hero in the mushaf download sheet used to be filled with the
/// retired gold hero gradient. Beyond being off the reader's kit, that is a
/// fixed *light* field: on the night palette it put cream text on gold. The
/// hero is a private part of the reader, so there is no widget seam to pump it
/// through — this source guard stands in for one. If the copy of the reader's
/// duotone language below the card ever needs a second hue, change it there and
/// update this guard with the reason, do not quietly restore the gradient.
void main() {
  test('the download hero is filled from the palette, never from gold', () {
    final file = File(
        'lib/features/quran/mushaf/quran_download_storage_hero.dart');
    expect(file.existsSync(), isTrue,
        reason: 'the storage hero file moved — find it and re-point this guard');

    final source = file.readAsStringSync();

    expect(source.contains('heroGold'), isFalse,
        reason: 'the retired gold hero gradient must not come back');
    expect(source.contains('LinearGradient'), isFalse,
        reason: 'the card is a flat palette surface now, in both papers');
    expect(source.contains('palette.accent.withValues('), isTrue,
        reason: 'the fill and the border are derived from the reader\'s accent');
  });
}
