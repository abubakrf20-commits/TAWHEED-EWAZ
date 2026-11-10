import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against the double-encoding class that shipped garbled notifications
/// in 1.8.0: Persian/Arabic text was read as CP1256 and re-saved as UTF-8, so
/// «یادآورها» became «غŒط§ط¯ط¢ظˆط±ظ‡ط§». Such a line always ends up with an
/// Arabic letter sitting directly against a CP1256 residue character.
///
/// The scan is adjacency-based on purpose. The residue characters do appear in
/// this repository legitimately — «Münchhausen» in the yaqeen content, the unit
/// vector «û» in the eclipse math, «‰» in the zakat screen — but never glued to
/// an Arabic letter, which is what makes the rule both cheap and precise.
void main() {
  // This file's own doc comment quotes the garbled text, so it is exempt.
  const guardFile = 'test/core/utils/text_encoding_guard_test.dart';
  const arabicRanges = [
    (0x0600, 0x08FF), // Arabic block (includes Persian ژ چ پ گ)
    (0xFB90, 0xFDFF), // Arabic presentation forms A
    (0xFE70, 0xFEFF), // Arabic presentation forms B
  ];
  // CP1256 images of the bytes a UTF-8 Arabic sequence cannot produce on its own.
  const residue = <int>{
    0x0152, 0x0153, // Œ œ
    0x20AC, // €
    0x201A, // ‚
    0x0192, // ƒ
    0x201E, // „
    0x2020, // †
    0x2021, // ‡
    0x02C6, // ˆ
    0x2030, // ‰
    0x0160, 0x0161, // Š š
    0x2039, 0x203A, // ‹ ›
    0x017D, 0x017E, // Ž ž
  };
  bool isArabic(int c) =>
      arabicRanges.any((r) => c >= r.$1 && c <= r.$2);
  bool isResidue(int c) =>
      residue.contains(c) ||
      (c >= 0xC0 && c <= 0xFF && c != 0xD7 && c != 0xF7); // × ÷ are used for real

  test('no source or content file carries CP1256 double-encoded text', () {
    final offenders = <String>[];
    final fffd = <String>[];
    final boms = <String>[];
    for (final dir in ['lib', 'test', 'assets', 'android'].map(Directory.new)) {
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (!path.endsWith('.dart') &&
            !path.endsWith('.json') &&
            !path.endsWith('.arb') &&
            !path.endsWith('.xml') &&
            !path.endsWith('.kt')) {
          continue;
        }
        if (path.endsWith('.g.dart')) continue;
        if (path.endsWith(guardFile)) continue;
        if (entity.lengthSync() > 8 * 1024 * 1024) continue;
        // Invalid UTF-8 throws here (malformed input) — a trans-coded file
        // can never slip through silently.
        final text = entity.readAsStringSync();
        if (path.endsWith('.dart') &&
            text.isNotEmpty &&
            text.codeUnitAt(0) == 0xFEFF) {
          // A BOM on a Dart file is the fingerprint of a byte-level rewrite
          // through a mismatched console encoding (the 1f3fa80 incident wrote
          // one alongside 59 mojibake lines). Dart tolerates it, but its
          // presence means the file was re-encoded by hand — reject it.
          boms.add(path);
        }
        for (var i = 0; i < text.length; i++) {
          final c = text.codeUnitAt(i);
          if (c == 0xFFFD) {
            // U+FFFD means some decoder already replaced undecodable bytes:
            // the damage is baked in, not just mis-displayed.
            final line = text.substring(0, i).split('\n').length;
            fffd.add('$path:$line');
            break;
          }
          if (i == text.length - 1) break;
          final a = c, b = text.codeUnitAt(i + 1);
          if ((isArabic(a) && isResidue(b)) || (isResidue(a) && isArabic(b))) {
            final line = text.substring(0, i).split('\n').length;
            offenders.add('$path:$line');
            i++; // report each adjacency run once, not per character pair
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'double-encoded (mojibake) text — see this test\'s doc comment');
    expect(fffd, isEmpty,
        reason: 'U+FFFD replacement characters — bytes were lost in transit');
    expect(boms, isEmpty,
        reason: 'BOM on Dart files — fingerprint of a console re-encoding');
  });

  test('the notification strings the 1.8.0 build shipped garbled are Persian',
      () {
    const file = 'lib/shared/services/notification_service.dart';
    final text = File(file).readAsStringSync();
    for (final expected in [
      "'یادآورها'",
      "'اوقات نماز'",
      "'مناسبت‌های اسلامی'",
      "'اذان فجر'",
      "'الصَّلَاةُ خَيْرٌ مِّنَ النَّوْمِ'",
      "'أَقِيمُوا الصَّلَاةَ'",
    ]) {
      expect(text, contains(expected), reason: '$expected must appear verbatim');
    }
  });
}
