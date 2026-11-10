import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/mushaf/quran_audio_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuranSurahTiming (approximate verse boundaries from text length)', () {
    test('maps boundaries and clamps the requested verse', () {
      final timing = QuranSurahTiming([0, 10, 20, 25]);
      final cases = <(int, int)>[
        (0, 1),
        (399, 1),
        (400, 2),
        (799, 2),
        (800, 3),
        (1000, 3),
      ];
      for (final (position, expected) in cases) {
        expect(timing.verseAtMs(position, 1000), expected);
      }
      expect(timing.offsetMsFor(1, 1000), 0);
      expect(timing.offsetMsFor(2, 1000), 400);
      expect(timing.offsetMsFor(99, 1000), 800);
    });

    test('forChapter builds a strictly increasing table for Al-Fatihah', () {
      final timing = QuranSurahTiming.forChapter(1);
      expect(timing.verseCount, getVerseCount(1));
      expect(timing.total, greaterThan(0));
      for (var i = 0; i < timing.cum.length; i++) {
        expect(timing.cum[i], greaterThanOrEqualTo(0));
        if (i > 0) {
          expect(timing.cum[i], greaterThan(timing.cum[i - 1]));
        }
      }
    });

    test('real chapter mapping is monotonic as position advances', () {
      const durMs = 120000;
      final timing = QuranSurahTiming.forChapter(36);
      var prevVerse = 0;
      for (var ms = 0; ms <= durMs; ms += 1000) {
        final v = timing.verseAtMs(ms, durMs);
        expect(v, greaterThanOrEqualTo(prevVerse),
            reason: 'mapping must be non-decreasing at $ms ms');
        prevVerse = v;
      }
    });

    test('handles degenerate inputs without crashing', () {
      final timing = QuranSurahTiming(const []);
      expect(timing.verseAtMs(0, 1000), 1);
      expect(timing.offsetMsFor(1, 1000), 0);
      final single = QuranSurahTiming(const [0, 1]);
      expect(single.verseAtMs(500, 1000), 1);
      expect(single.offsetMsFor(1, 1000), 0);
    });
  });

  group('QuranAudioController (no automatic downloads)', () {
    test('playVerse has no download call — talaawah is never auto-stored',
        () async {
      // Talaawah is sacred content: it must only be stored offline through
      // the explicit download sheet. Guard that the play path contains no
      // downloadSurah call (source-level guard; the plugin channels cannot
      // run in a plain Dart test).
      final source =
          await File('lib/features/quran/mushaf/quran_audio_controller.dart')
              .readAsString();
      expect(source.contains('downloadSurah'), isFalse,
          reason: 'playVerse must not download talaawah automatically');
    });
  });
}
