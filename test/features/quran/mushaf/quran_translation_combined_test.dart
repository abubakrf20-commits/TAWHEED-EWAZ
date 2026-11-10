// Source-level guards for the «تلاوت سپس ترجمه» (recitation-then-translation)
// combined mode of the ayah audio translation.
//
// The QuranEnc site's player offers the exact mode the reader now mirrors:
// «التلاوة ثم الترجمة» — the ayah's recitation plays first, then its
// translation. The toggle lives in the translation mini player's settings
// menu; the controller flag is the single source of truth.
//
// Like quran_audio_controller_test.dart, these are source guards: the
// audioplayers platform channels cannot run in a plain Dart test, so the
// invariants that matter (the phase switch, the pref round-trip and the
// pane wiring) are pinned against the source files instead.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a repo file with line endings normalised (Windows checkouts carry
/// CRLF; `contains` with `\n` must not depend on the checkout's eol style).
Future<String> readSource(String path) async =>
    (await File(path).readAsString()).replaceAll('\r\n', '\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuranTranslationAudioController — combined mode wiring', () {
    test('playVerse takes the skipRecitation flag and phases the session',
        () async {
      final source = await readSource('lib/features/quran/mushaf/'
          'quran_translation_audio_controller.dart');
      expect(source.contains('skipRecitation'), isTrue,
          reason: 'playVerse must offer the translation-half re-entry flag');
      expect(source.contains("'recitation'"), isTrue,
          reason: 'a combined session must run a recitation phase');
      expect(source.contains("'translation'"), isTrue,
          reason: 'the phase must resolve to translation for plain sessions');
    });

    test(
        'the completion handler switches recitation→translation, never '
        're-plays the recitation', () async {
      final source = await readSource('lib/features/quran/mushaf/'
          'quran_translation_audio_controller.dart');
      final onComplete = source.substring(source.indexOf('void _onComplete'));
      expect(onComplete.contains("_phase == 'recitation'"), isTrue,
          reason: 'the recitation half must be detected on completion');
      expect(onComplete.contains('skipRecitation: true'), isTrue,
          reason: 'the translation half must not re-enter the recitation');
      expect(onComplete.contains('playVerse(c, v)'), isTrue,
          reason: 'continuous mode must keep advancing verse by verse');
    });

    test('the toggle API and the phase getter exist', () async {
      final source = await readSource('lib/features/quran/mushaf/'
          'quran_translation_audio_controller.dart');
      expect(source.contains('void setCombinedWithRecitation'), isTrue,
          reason: 'the reader must be able to switch the mode at runtime');
      expect(source.contains('bool get isPlayingRecitation'), isTrue,
          reason: 'the mini player labels the running half via this getter');
      expect(source.contains('bool get combinedWithRecitation'), isTrue,
          reason: 'the pane toggle reads this for its check');
    });
  });

  group('QuranMushafView — pref + pane wiring', () {
    test('the combined choice is persisted (default ON) and restored at init',
        () async {
      final source =
          await readSource('lib/features/quran/mushaf/quran_mushaf_view.dart');
      expect(source.contains("'quran_translation_combined'"), isTrue,
          reason: 'the pref key must be the single round-trip key');
      expect(source.contains("p.getBool('quran_translation_combined') ?? true"),
          isTrue,
          reason: 'the default is ON — the mode the user asked for');
      expect(
          source.contains("prefs.setBool('quran_translation_combined', value)"),
          isTrue,
          reason: 'toggling must persist for the next launch');
    });

    test('the translation pane hooks onCombined into the controller', () async {
      final source =
          await readSource('lib/features/quran/mushaf/quran_mushaf_view.dart');
      expect(source.contains('onCombined: _setTranslationCombined'), isTrue,
          reason: 'the pane toggle must reach the view handler');
      expect(
          source.contains('void _setTranslationCombined(bool value)'), isTrue,
          reason: 'the handler must exist');
      expect(
          source.contains('setCombinedWithRecitation(\n'
              '        _translationAudio.combinedWithRecitation,\n'
              '        reciterId: _reciterId)'),
          isTrue,
          reason: 'every translation tap must re-sync the reader reciter');
    });
  });

  group('QuranTranslationAudioController — background prefetch', () {
    test('playVerse kicks off prefetching the next verses', () async {
      // Without prefetch every verse blocks on a fresh ~30s CDN download
      // at play time; the next verses must download while one plays.
      final source = await readSource('lib/features/quran/mushaf/'
          'quran_translation_audio_controller.dart');
      expect(source.contains('unawaited(_prefetchAhead(surah, verse))'), isTrue,
          reason: 'a started verse must schedule the background prefetch');
      expect(source.contains('Future<void> _prefetchAhead('), isTrue,
          reason: 'the prefetch routine must exist');
      expect(source.contains('ensureVerseDownloaded('), isTrue,
          reason: 'prefetch must warm the translation cache');
      expect(source.contains('Mp3QuranService.prefetchVerse('), isTrue,
          reason: 'combined mode must also warm the recitation half');
    });

    test('concurrent verse downloads share one in-flight future', () async {
      // A tap on "next" while its prefetch is still downloading must not
      // start a second download (nor two writers on one file).
      final source = await readSource('lib/features/quran/mushaf/'
          'quran_translation_download_service.dart');
      expect(source.contains('_inflight'), isTrue,
          reason: 'the service must track in-flight verse downloads');
      expect(
          source.contains(
              'return fut.whenComplete(() => _inflight.remove(key))'),
          isTrue,
          reason: 'the in-flight entry must be released when done');
    });
  });

  group('QuranReaderPlayer — the settings menu item', () {
    test('the translation pane menu offers «تلاوت سپس ترجمه» / «فقط ترجمه»',
        () async {
      final source =
          await readSource('lib/features/quran/mushaf/quran_reader_player.dart');
      expect(source.contains("value == 'combined'"), isTrue,
          reason: 'the menu must toggle the combined mode');
      expect(
          source.contains('onCombined(!audio.combinedWithRecitation)'), isTrue,
          reason: 'the menu must flip the controller flag');
      expect(source.contains('تلاوت سپس ترجمه'), isTrue,
          reason: 'the ON label names the combined mode');
      expect(source.contains('فقط ترجمه'), isTrue,
          reason: 'the OFF label keeps translation-only discoverable');
    });
  });
}
