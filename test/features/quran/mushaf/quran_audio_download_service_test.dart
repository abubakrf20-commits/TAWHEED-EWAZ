import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/services/mp3quran_service.dart';
import 'package:tawheeed/features/quran/mushaf/quran_audio_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuranAudioDownloadState', () {
    test('copyWith preserves unspecified state and clears errors explicitly',
        () {
      const state = QuranAudioDownloadState(
        reciterId: 'r',
        surah: 3,
        done: 2,
        total: 10,
        running: true,
        error: 'old',
      );
      final updated = state.copyWith(done: 5, clearError: true);
      expect(updated.done, 5);
      expect(updated.total, 10);
      expect(updated.surah, 3);
      expect(updated.running, isTrue);
      expect(updated.error, isNull);
    });
  });

  group('QuranAudioDownloadService download runs', () {
    // In the test environment the underlying CDN call fails (no network),
    // so every run ends failed with a friendly error.
    test('startSurah exposes the range and always finishes', () async {
      final service = QuranAudioDownloadService.instance;
      await service.startSurah(
          Mp3QuranService.fallbackReciters.first.identifier, 3);
      final s = service.state.value;
      expect(s.running, isFalse);
      expect(s.reciterId, Mp3QuranService.fallbackReciters.first.identifier);
      expect(s.total, getVerseCount(3));
      expect(s.wholeQuran, isFalse);
    });

    test('startJuz counts exactly the requested inclusive ranges', () async {
      final service = QuranAudioDownloadService.instance;
      final ranges = juzVerseRanges(30);
      var expected = 0;
      for (final range in ranges.values) {
        expected += range.$2 - range.$1 + 1;
      }
      await service.startJuz('everyayah:Alafasy_128kbps', 30);
      expect(service.state.value.total, expected);
      expect(service.state.value.running, isFalse);
    });

    test('a run publishes running before it finishes', () async {
      final service = QuranAudioDownloadService.instance;
      final seenRunning = <bool>[];
      void listener() => seenRunning.add(service.state.value.running);
      service.state.addListener(listener);
      await service.startSurah('everyayah:Alafasy_128kbps', 114);
      service.state.removeListener(listener);
      expect(seenRunning, contains(true));
      expect(service.state.value.running, isFalse);
    });
  });
}
