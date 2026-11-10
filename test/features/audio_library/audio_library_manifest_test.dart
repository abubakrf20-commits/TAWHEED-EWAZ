import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/audio_library/audio_library_manifest.dart';

Map<String, dynamic> _sampleJson() => {
      'version': 1,
      'categories': [
        {
          'id': 'yaqeen',
          'tracks': [
            {
              'id': 'yaqeen-01',
              'title': 'معرفت شناسی',
              'file': 'yaqeen/01-marefat-shenasi.opus',
              'sizeBytes': 6712688,
            },
            {
              'id': 'yaqeen-02',
              'title': 'اثبات وجود خدا (امکان و وجوب)',
              'file': 'yaqeen/02-esbat-vojude-khoda-emkan-vojub.opus',
              'sizeBytes': 8514799,
            },
          ],
        },
        {
          'id': 'anasheed',
          'tracks': [
            {
              'id': 'anasheed-01',
              'title': 'نشید',
              'file': 'anasheed/01-nasheed.opus',
              'sizeBytes': 1000,
            },
          ],
        },
      ],
    };

void main() {
  group('AudioLibraryManifest.fromJson', () {
    test('parses categories and tracks', () {
      final m = AudioLibraryManifest.fromJson(_sampleJson());
      expect(m.version, 1);
      expect(m.categories.length, 2);
      expect(m.allTracks.length, 3);

      final yaqeen = m.categories.first;
      expect(yaqeen.id, 'yaqeen');
      expect(yaqeen.tracks.length, 2);
      expect(yaqeen.tracks.first.title, 'معرفت شناسی');
      expect(yaqeen.tracks.first.file, 'yaqeen/01-marefat-shenasi.opus');
      expect(yaqeen.tracks.first.sizeBytes, 6712688);
      expect(yaqeen.totalSizeBytes, 6712688 + 8514799);
    });

    test('tolerates missing fields with safe defaults', () {
      final m = AudioLibraryManifest.fromJson({
        'categories': [
          {
            'id': 'x',
            'tracks': [
              {'id': 't1', 'title': 'نشست', 'file': 'x/t1.opus'}
            ],
          },
        ],
      });
      expect(m.categories.single.tracks.single.sizeBytes, 0);
      expect(m.version, 1);
    });

    test('flattens tracks from speakers and sets hasSpeakers', () {
      final m = AudioLibraryManifest.fromJson({
        'categories': [
          {
            'id': 'lectures',
            'speakers': [
              {
                'id': 'ziaei',
                'title': 'شیخ ضیایی',
                'tracks': [
                  {
                    'id': 'l01',
                    'title': 'درس ۱',
                    'file': 'lectures/ziaei/l01.opus',
                    'sizeBytes': 500
                  },
                  {
                    'id': 'l02',
                    'title': 'درس ۲',
                    'file': 'lectures/ziaei/l02.opus',
                    'sizeBytes': 600
                  },
                ],
              },
            ],
            'tracks': [],
          },
        ],
      });
      final cat = m.categories.single;
      expect(cat.hasSpeakers, isTrue);
      expect(cat.speakers.length, 1);
      expect(cat.speakers.first.id, 'ziaei');
      expect(cat.tracks.length, 2);
      expect(cat.tracks[0].id, 'l01');
      expect(cat.tracks[1].id, 'l02');
      expect(cat.totalSizeBytes, 500 + 600);
      expect(cat.speakerOf(cat.tracks.first)?.id, 'ziaei');
    });
  });

  group('AudioCategory display metadata', () {
    test('resolves Persian display titles by category id', () {
      expect(const AudioCategory(id: 'yaqeen', tracks: []).displayTitle,
          'رد شبهات');
      expect(const AudioCategory(id: 'anasheed', tracks: []).displayTitle,
          'اناشید اسلامی');
      expect(const AudioCategory(id: 'lectures', tracks: []).displayTitle,
          'سخنرانی');
      expect(const AudioCategory(id: 'unknown', tracks: []).displayTitle,
          'unknown');
    });

    test('provides an icon per known category', () {
      expect(const AudioCategory(id: 'yaqeen', tracks: []).icon,
          Icons.verified_user_outlined);
      expect(const AudioCategory(id: 'anasheed', tracks: []).icon,
          Icons.music_note_outlined);
      expect(const AudioCategory(id: 'lectures', tracks: []).icon,
          Icons.graphic_eq);
      expect(const AudioCategory(id: 'unknown', tracks: []).icon,
          Icons.headphones_outlined);
    });

    test('appends the teacher byline per category and keeps others clean', () {
      const yaqeen = AudioCategory(id: 'yaqeen', tracks: []);
      const lectures = AudioCategory(id: 'lectures', tracks: []);
      const anasheed = AudioCategory(id: 'anasheed', tracks: []);
      const track = AudioTrack(
          id: 't1', title: 'درس پنجم', file: 'c/t1.opus', sizeBytes: 1);

      expect(yaqeen.trackDisplayTitle(track), 'درس پنجم (استاد مراد یوسفی)');
      expect(lectures.trackDisplayTitle(track), 'درس پنجم (شیخ ضیایی)');
      expect(anasheed.trackDisplayTitle(track), 'درس پنجم');
      expect(AudioCategory.bylineForCategory('unknown'), isNull);
    });

    test('uses speaker title as byline when category has speakers', () {
      const speaker = AudioSpeaker(
        id: 'ziaei',
        title: 'شیخ ضیایی',
        tracks: [
          AudioTrack(
              id: 't1', title: 'درس اول', file: 'x/t1.opus', sizeBytes: 100),
        ],
      );
      const cat = AudioCategory(
        id: 'lectures',
        tracks: [
          AudioTrack(
              id: 't1', title: 'درس اول', file: 'x/t1.opus', sizeBytes: 100),
        ],
        speakers: [speaker],
      );
      const track = AudioTrack(
          id: 't1', title: 'درس اول', file: 'x/t1.opus', sizeBytes: 100);
      expect(cat.trackDisplayTitle(track), 'درس اول (شیخ ضیایی)');
    });

    test('does not append group title when category has no canonical byline',
        () {
      const arabicSpeaker = AudioSpeaker(
        id: 'arabi',
        title: 'عربی',
        tracks: [
          AudioTrack(
              id: 't1', title: 'نیّه', file: 'a/t1.opus', sizeBytes: 100),
        ],
      );
      const farsiSpeaker = AudioSpeaker(
        id: 'farsi',
        title: 'فارسی',
        tracks: [
          AudioTrack(
              id: 't2', title: 'دل غافل', file: 'a/t2.opus', sizeBytes: 200),
        ],
      );
      const cat = AudioCategory(
        id: 'anasheed',
        tracks: [
          AudioTrack(
              id: 't1', title: 'نیّه', file: 'a/t1.opus', sizeBytes: 100),
          AudioTrack(
              id: 't2', title: 'دل غافل', file: 'a/t2.opus', sizeBytes: 200),
        ],
        speakers: [arabicSpeaker, farsiSpeaker],
      );
      const t1 = AudioTrack(
          id: 't1', title: 'نیّه', file: 'a/t1.opus', sizeBytes: 100);
      const t2 = AudioTrack(
          id: 't2', title: 'دل غافل', file: 'a/t2.opus', sizeBytes: 200);
      expect(cat.trackDisplayTitle(t1), 'نیّه');
      expect(cat.trackDisplayTitle(t2), 'دل غافل');
    });
  });

  group('AudioTrack', () {
    test('approxSizeMb derives from sizeBytes', () {
      const track =
          AudioTrack(id: 'y', title: 'ت', file: 'y/t.opus', sizeBytes: 1048576);
      expect(track.approxSizeMb, closeTo(1.0, 0.0001));
    });

    test('JSON roundtrip preserves fields', () {
      const track = AudioTrack(
          id: 'yaqeen-01',
          title: 'معرفت شناسی',
          file: 'yaqeen/01-marefat-shenasi.opus',
          sizeBytes: 6712688);
      final restored = AudioTrack.fromJson(track.toJson());
      expect(restored.id, track.id);
      expect(restored.title, track.title);
      expect(restored.file, track.file);
      expect(restored.sizeBytes, track.sizeBytes);
    });
  });
}
