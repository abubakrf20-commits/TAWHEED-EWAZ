import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/data/juzs.dart';
import 'package:tawheeed/features/quran/data/page_data.dart';
import 'package:tawheeed/features/quran/data/quran_data.dart';
import 'package:tawheeed/features/quran/data/suwar.dart';

/// Consolidated integrity guard for the shipped Qur'an text (audit I-1).
///
/// The mushaf bundle is read-only and must never be edited casually, so this
/// is a VERIFY-ONLY check: it pins the exact on-disk text asset by hash and
/// cross-checks the structural constants every screen relies on — 114 surahs,
/// 6236 ayahs, 604 pages, 30 juz — and that the per-surah ayah counts in the
/// metadata match the verses actually present in the loaded text. Any silent
/// corruption, an accidental edit to the protected asset, or drift between the
/// tables and the text fails here instead of mid-recitation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadQuranData);

  /// sha256 of assets/quran/quran_data.json as shipped. Changing the text asset
  /// is a deliberate, reviewed act — bump this only with that review.
  const shippedSha256 =
      '0f98be23465109f754aace185f85fb6e74df5bfd79ec4e3e851ee257a0f06f51';

  test('the shipped text asset is byte-for-byte unchanged', () {
    final bytes = File('assets/quran/quran_data.json').readAsBytesSync();
    expect(bytes, isNotEmpty);
    expect(sha256.convert(bytes).toString(), shippedSha256,
        reason: 'the protected Qur\'an text asset changed — '
            're-verify the source before accepting this hash');
  });

  test('surah metadata: 114 surahs, 6236 ayahs, ordered ids', () {
    expect(surah.length, 114);
    final totalAyat =
        surah.fold<int>(0, (sum, s) => sum + (s['aya'] as int));
    expect(totalAyat, 6236, reason: 'the standard Hafs ayah total');
    for (var i = 0; i < surah.length; i++) {
      expect(surah[i]['id'], i + 1, reason: 'surah ids must be 1..114');
      expect((surah[i]['aya'] as int) > 0, isTrue);
    }
  });

  test('page and juz tables cover the mushaf', () {
    expect(pageData.length, 604);
    expect(juz.length, 30);
  });

  test('loaded text carries every ayah the metadata promises', () {
    expect(quran.length, 6236);

    // Max aya_no present per surah must equal that surah's declared count, so
    // no verse is missing and none is duplicated beyond its real length.
    final maxAyahPerSurah = <int, int>{};
    for (final row in quran) {
      final sora = (row['sora'] as num).toInt();
      final ayaNo = (row['aya_no'] as num).toInt();
      final prev = maxAyahPerSurah[sora] ?? 0;
      if (ayaNo > prev) maxAyahPerSurah[sora] = ayaNo;
    }

    expect(maxAyahPerSurah.length, 114);
    for (final s in surah) {
      final id = s['id'] as int;
      expect(maxAyahPerSurah[id], s['aya'],
          reason: 'surah $id verse count disagrees with the text');
    }
  });

  test('every ayah text cell is non-empty', () {
    // A blank aya_text would render a hole in the mushaf; the hashed asset is
    // the same source, so this is a cheap belt-and-braces content check.
    final empty = quran
        .where((r) => (r['aya_text'] as String).trim().isEmpty)
        .length;
    expect(empty, 0, reason: 'decoded text uses the same asset bytes');
  });
}
