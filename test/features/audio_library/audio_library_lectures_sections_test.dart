import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/audio_library/audio_library_manifest.dart';

/// The manifest shape after «متفرقه» moves under «سخنرانی» and the three new
/// lecture sections arrive: `lectures` carries five speaker sections and
/// there is no top-level `misc` category anymore.
///
/// The app needs no code change for this — sections are data-driven — so this
/// test pins the handling with a synthetic manifest, not the live bucket
/// snapshot (that one stays in audio_library_merged_manifest_test.dart until
/// the re-composed index.json is uploaded).
void main() {
  AudioTrack track(String id, String file) =>
      AudioTrack(id: id, title: 'درس $id', file: file, sizeBytes: 1000);

  AudioSpeaker speaker(String id, String title, List<AudioTrack> tracks) =>
      AudioSpeaker(id: id, title: title, tracks: tracks);

  AudioLibraryManifest build() {
    final ziaei = [track('lec-01', 'sokhanrani/ziaei/a.opus')];
    final goudarzi = [track('lec-gd-01', 'sokhanrani/goudarzi/1. a.opus')];
    final bazmandegan = [
      track('lec-bz-01', 'sokhanrani/bazmandegan/1. a.opus'),
    ];
    final tafsir = [
      track('lec-tb-01', 'sokhanrani/tafsir-badri/1. a.opus'),
    ];
    final misc = [track('misc-01', 'sokhanrani/درس تنها.opus')];
    final lectures = AudioCategory(
      id: 'lectures',
      tracks: [...ziaei, ...goudarzi, ...bazmandegan, ...tafsir, ...misc],
      speakers: [
        speaker('ziaei', 'شیخ ضیایی', ziaei),
        speaker('goudarzi', 'شیخ محمد رحیمی', goudarzi),
        speaker('bazmandegan', 'شیخ موسی بازماندگان', bazmandegan),
        speaker('tafsir-badri', 'تفسیر قرآن مولانا عبدالغنی بدری', tafsir),
        speaker('misc', 'متفرقه', misc),
      ],
    );
    return AudioLibraryManifest(version: 4, categories: [lectures]);
  }

  test('lectures carries the five sections, misc last', () {
    final lectures = build().categories.single;
    expect(lectures.id, 'lectures');
    expect(lectures.displayTitle, 'سخنرانی');
    expect(lectures.hasSpeakers, isTrue);
    expect(
      lectures.speakers.map((s) => s.id),
      ['ziaei', 'goudarzi', 'bazmandegan', 'tafsir-badri', 'misc'],
    );
    expect(
      lectures.speakers.map((s) => s.title),
      [
        'شیخ ضیایی',
        'شیخ محمد رحیمی',
        'شیخ موسی بازماندگان',
        'تفسیر قرآن مولانا عبدالغنی بدری',
        'متفرقه',
      ],
    );
  });

  test('sections tile the flat list exactly, in order', () {
    final lectures = build().categories.single;
    expect(
      lectures.speakers.expand((s) => s.tracks).map((t) => t.id),
      lectures.tracks.map((t) => t.id),
    );
  });

  test('every track resolves to its own section, misc included', () {
    final lectures = build().categories.single;
    for (final s in lectures.speakers) {
      for (final t in s.tracks) {
        expect(lectures.speakerOf(t)?.id, s.id, reason: t.id);
      }
    }
  });

  test('track titles carry the owning speaker, not the category byline', () {
    final lectures = build().categories.single;
    expect(
      lectures.trackDisplayTitle(lectures.tracks[1]),
      'درس lec-gd-01 (شیخ محمد رحیمی)',
    );
    expect(
      lectures.trackDisplayTitle(lectures.tracks.last),
      'درس misc-01 (متفرقه)',
    );
  });

  test('round-trip keeps the five sections', () {
    final restored = AudioLibraryManifest.fromJson(build().toJson());
    final lectures = restored.categories.single;
    expect(lectures.speakers.map((s) => s.id),
        ['ziaei', 'goudarzi', 'bazmandegan', 'tafsir-badri', 'misc']);
    expect(lectures.speakers.last.tracks.single.id, 'misc-01');
  });
}
