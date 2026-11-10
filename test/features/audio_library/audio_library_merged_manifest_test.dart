import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/audio_library/audio_library_config.dart';
import 'package:tawheeed/features/audio_library/audio_library_manifest.dart';

/// Parses the manifest that ships to the merged ArvanCloud bucket `t.audio`.
///
/// This is the artifact the app actually downloads, so it is tested as one
/// whole rather than category by category: a category that is well-formed on
/// its own can still break the library if its ids collide with another's or if
/// a speaker is credited to the wrong teacher.
///
/// The keys here are the real uploaded object keys, all Persian except one that
/// carries an emoji and a ZWNJ. Nothing about them is ASCII-safe by accident.
void main() {
  late AudioLibraryManifest manifest;

  setUpAll(() {
    final file = File(
      'test/features/audio_library/fixtures/arvan_merged_index.json',
    );
    manifest = AudioLibraryManifest.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  });

  group('merged manifest parses', () {
    test('carries all three categories the app knows', () {
      expect(manifest.version, 4);
      expect(
        manifest.categories.map((c) => c.id),
        ['yaqeen', 'anasheed', 'lectures'],
      );
      expect(
        manifest.categories.map((c) => c.displayTitle).toSet(),
        {'رد شبهات', 'اناشید اسلامی', 'سخنرانی'},
      );
    });

    test('exposes every uploaded track', () {
      // 23 yaqeen + 29 Arabic nasheed + 11 Persian nasheed +
      // 41 Ziaei + 6 Rahimi + 1 misc.
      expect(manifest.allTracks, hasLength(111));
      expect(manifest.categories[0].tracks, hasLength(23));
      expect(manifest.categories[1].tracks, hasLength(40));
      expect(manifest.categories[2].tracks, hasLength(48));
    });

    test('track ids are unique across every category', () {
      final ids = manifest.allTracks.map((t) => t.id).toList();
      expect(ids.toSet(), hasLength(ids.length),
          reason: 'id collisions would overwrite cache files');
      expect(
        ids.where((id) => id.startsWith('an-')).toSet().length,
        40,
        reason: 'the two nasheed prefixes must not share an id series',
      );
    });

    test('object keys are unique and every track has a real size', () {
      final files = manifest.allTracks.map((t) => t.file).toList();
      expect(files.toSet(), hasLength(files.length));
      for (final t in manifest.allTracks) {
        expect(t.id, isNotEmpty);
        expect(t.title, isNotEmpty);
        expect(t.sizeBytes, greaterThan(0), reason: t.id);
        expect(t.file, endsWith('.opus'), reason: t.id);
      }
    });
  });

  group('categories are split into tappable sections', () {
    test('anasheed is separated into arabic and persian', () {
      final anasheed =
          manifest.categories.firstWhere((c) => c.id == 'anasheed');
      expect(anasheed.hasSpeakers, isTrue);
      expect(anasheed.speakers.map((s) => s.id), ['arabic', 'persian']);
      expect(anasheed.speakers.map((s) => s.title), ['عربی', 'فارسی']);
      expect(anasheed.speakers[0].tracks, hasLength(29));
      expect(anasheed.speakers[1].tracks, hasLength(11));
    });

    test('lectures split into Ziaei, Rahimi and misc sections', () {
      final lectures =
          manifest.categories.firstWhere((c) => c.id == 'lectures');
      expect(lectures.hasSpeakers, isTrue);
      expect(
        lectures.speakers.map((s) => s.id),
        ['ziaei', 'goudarzi', 'misc'],
      );
      expect(
        lectures.speakers.map((s) => s.title),
        ['شیخ ضیایی', 'شیخ محمد رحیمی', 'متفرقه'],
      );
      expect(lectures.speakers[0].tracks, hasLength(41));
      expect(lectures.speakers[1].tracks, hasLength(6));
      expect(lectures.speakers[2].tracks, hasLength(1));
      expect(
        lectures.speakers.fold(0, (sum, s) => sum + s.totalSizeBytes),
        lectures.totalSizeBytes,
      );
    });

    test('the six Rahimi Ramadan lessons arrive in lesson order', () {
      final lectures =
          manifest.categories.firstWhere((c) => c.id == 'lectures');
      final rahimi = lectures.speakers.firstWhere((s) => s.id == 'goudarzi');
      expect(
        rahimi.tracks.map((t) => t.id),
        List.generate(6, (i) => 'lec-gd-0${i + 1}'),
      );
      for (final t in rahimi.tracks) {
        expect(t.file, startsWith('sokhanrani/rahemi/'));
      }
      expect(rahimi.tracks.first.title, contains('مقدمه'));
      expect(rahimi.tracks[1].title, contains('سیرت رسول الله'));
    });

    test('the sections tile the flat list exactly, in order', () {
      // The screen hides the flat list and lists only the sections, so a track
      // in no section is unreachable and one in two sections plays twice.
      for (final c in manifest.categories.where((c) => c.hasSpeakers)) {
        expect(
          c.speakers.expand((s) => s.tracks).map((t) => t.id),
          c.tracks.map((t) => t.id),
          reason: '${c.id}: sections must match the flat list',
        );
      }
    });

    test('speakerOf resolves every track to its own section', () {
      final anasheed =
          manifest.categories.firstWhere((c) => c.id == 'anasheed');
      final arabic = anasheed.speakers.first;
      final persian = anasheed.speakers.last;
      for (final t in arabic.tracks) {
        expect(anasheed.speakerOf(t)?.id, 'arabic', reason: t.id);
      }
      for (final t in persian.tracks) {
        expect(anasheed.speakerOf(t)?.id, 'persian', reason: t.id);
      }
    });

    test('a language section is not credited to a teacher', () {
      // Anasheed has no common teacher so its cards stay plain titles; every
      // lectures section names its own speaker on the card.
      final anasheed =
          manifest.categories.firstWhere((c) => c.id == 'anasheed');
      expect(AudioCategory.bylineForCategory('anasheed'), isNull);
      for (final t in anasheed.tracks) {
        expect(anasheed.trackDisplayTitle(t), t.title, reason: t.id);
      }
      final lectures =
          manifest.categories.firstWhere((c) => c.id == 'lectures');
      for (final s in lectures.speakers) {
        for (final t in s.tracks) {
          expect(lectures.trackDisplayTitle(t), '${t.title} (${s.title})',
              reason: t.id);
        }
      }
    });

    test('single-speaker categories stay flat', () {
      final c = manifest.categories.firstWhere((c) => c.id == 'yaqeen');
      expect(c.hasSpeakers, isFalse);
      expect(c.speakers, isEmpty);
    });
  });

  group('the misc section is not a Ziaei lecture', () {
    test('holds only the Behzad Faghihi lecture', () {
      final lectures =
          manifest.categories.firstWhere((c) => c.id == 'lectures');
      final misc = lectures.speakers.firstWhere((s) => s.id == 'misc');
      expect(misc.title, 'متفرقه');
      expect(misc.tracks, hasLength(1));
      expect(misc.tracks.single.id, 'misc-01');
      expect(misc.tracks.single.file, contains('بهزاد_فقهی'));
      expect(misc.tracks.single.file, contains('مولانا'));
    });

    test('that track is not filed under the Ziaei prefix', () {
      // A Behzad Faghihi track under sokhanrani/ziaei/ would be credited to
      // the wrong teacher, so the unclaimed file lives in «متفرقه» instead.
      final lectures =
          manifest.categories.firstWhere((c) => c.id == 'lectures');
      final ziaei = lectures.speakers.firstWhere((s) => s.id == 'ziaei');
      for (final t in ziaei.tracks) {
        expect(t.file, startsWith('sokhanrani/ziaei/'));
        expect(t.file, isNot(contains('بهزاد')));
      }
      expect(AudioCategory.bylineForCategory('misc'), isNull);
    });
  });

  group('arabic nasheed is in Persian dictionary order', () {
    late List<AudioTrack> arabic;

    setUpAll(() {
      arabic = manifest.categories
          .firstWhere((c) => c.id == 'anasheed')
          .tracks
          .where((t) => t.id.startsWith('an-ar-'))
          .toList();
    });

    test('all 29 arabic tracks are present', () {
      expect(arabic, hasLength(29));
    });

    test('a code-point sort would lead with a different track', () {
      // ALEF WITH MADDA (U+0622) sorts before ALEF (U+0627) by code point, so
      // a naive generator would put "آخي لا تشكو المذلة" first. If the first
      // track ever becomes the madda one, the ordering has regressed to a
      // plain sort.
      expect(arabic.first.title, isNot(startsWith('آ')));
      expect(arabic.first.id, 'an-ar-01');
    });

    test('ids follow the same sequence as the track order', () {
      expect(
        arabic.map((t) => t.id),
        List.generate(29, (i) => 'an-ar-${(i + 1).toString().padLeft(2, '0')}'),
      );
    });

    test('every arabic key keeps its non-ASCII spelling', () {
      // The Arabic nasheed has no CSV covering all 29, so these titles came
      // from the object names themselves. A normalising generator would strip
      // the hamza and the key would stop matching the uploaded object.
      expect(
        arabic
            .map((t) => t.file)
            .where((f) => f.contains(RegExp(r'[\u0600-\u06FF]'))),
        hasLength(29),
      );
      expect(arabic.map((t) => t.title).join(),
          matches(RegExp(r'[\u0600-\u06FF]')));
    });
  });

  group('objectUrl survives every real key', () {
    test('round-trips all 111 keys out of the encoded path', () {
      for (final t in manifest.allTracks) {
        final url = AudioLibraryConfig.objectUrl(t.file);
        expect(url.contains(' '), isFalse,
            reason: 'a raw space breaks the request line: ${t.id}');
        expect(
          Uri.decodeFull(Uri.parse(url).path),
          endsWith(t.file),
          reason: 'key did not survive encoding: ${t.file}',
        );
      }
    });

    test('encodes the emoji and ZWNJ in the misc key', () {
      final lectures =
          manifest.categories.firstWhere((c) => c.id == 'lectures');
      final misc = lectures.speakers.firstWhere((s) => s.id == 'misc');
      final file = misc.tracks.single.file;
      // The name joins words with ZWNJ (U+200C) and ends a word with a heart
      // plus VARIATION SELECTOR-16, i.e. a non-BMP-adjacent astral scalar.
      // Both must reach the wire as UTF-8 octets: U+200C is %E2%80%8C, and the
      // pair U+2764 U+FE0F is %E2%9D%A4%EF%B8%8F. If either went out raw or as
      // UTF-16 the object 404s and the track silently will not play.
      expect(file, contains('\u200c'));
      expect(file, contains('\u2764\ufe0f'));
      final url = AudioLibraryConfig.objectUrl(file);
      expect(url, contains('%E2%80%8C')); // ZWNJ
      expect(url, contains('%E2%9D%A4')); // HEAVY BLACK HEART
      expect(url, contains('%EF%B8%8F')); // VARIATION SELECTOR-16
      expect(url, isNot(contains('\u200c')));
      expect(url, isNot(contains('\u2764')));
      expect(
        Uri.decodeFull(Uri.parse(url).path),
        endsWith(file),
        reason: 'the exotic characters must round-trip exactly',
      );
    });
  });
}
