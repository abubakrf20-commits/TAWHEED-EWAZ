import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/audio_library/audio_library_manifest.dart';
import 'package:tawheeed/features/audio_library/audio_library_player.dart';

AudioCategory _cat(String id, List<String> trackIds) => AudioCategory(
      id: id,
      tracks: [
        for (final t in trackIds)
          AudioTrack(
            id: t,
            title: t,
            file: '$t.opus',
            sizeBytes: 1000,
          ),
      ],
    );

void main() {
  late AudioLibraryPlayer player;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    player = AudioLibraryPlayer.instance;
  });

  group('configureCategories', () {
    test('maps every track to its next sibling and category', () async {
      final cats = [
        _cat('yaqeen', ['t1', 't2', 't3']),
        _cat('anasheed', ['t4', 't5']),
      ];
      await player.configureCategories(cats);

      expect(player.debugNextOf, {
        't1': 't2',
        't2': 't3',
        't3': isNull,
        't4': 't5',
        't5': isNull,
      });
      expect(player.categoryOf('t1'), 'yaqeen');
      expect(player.categoryOf('t4'), 'anasheed');
      expect(player.categoryOf('unknown'), isNull);
      expect(player.categoryOf(null), isNull);
    });

    test('reconfigure replaces the previous wiring', () async {
      await player.configureCategories([
        _cat('a', ['x', 'y'])
      ]);
      await player.configureCategories([
        _cat('b', ['p', 'q', 'r'])
      ]);

      expect(player.debugNextOf, {'p': 'q', 'q': 'r', 'r': isNull});
      expect(player.categoryOf('x'), isNull);
      expect(player.categoryOf('r'), 'b');
    });
  });

  group('repeat mode', () {
    test('cycles off → one → category → off', () {
      expect(player.repeatMode, AudioPlaybackMode.off);
      player.cycleRepeatMode();
      expect(player.repeatMode, AudioPlaybackMode.one);
      player.cycleRepeatMode();
      expect(player.repeatMode, AudioPlaybackMode.category);
      player.cycleRepeatMode();
      expect(player.repeatMode, AudioPlaybackMode.off);
    });

    test('setRepeatMode notifies and ignores same value', () {
      var calls = 0;
      player.addListener(() => calls++);
      player.setRepeatMode(AudioPlaybackMode.category);
      expect(player.repeatMode, AudioPlaybackMode.category);
      expect(calls, 1);
      player.setRepeatMode(AudioPlaybackMode.category);
      expect(calls, 1);
    });
  });

  group('playback speed', () {
    test('clamps to the 0.5x–2x range', () async {
      await player.setSpeed(5);
      expect(player.speed, 2.0);
      await player.setSpeed(0.1);
      expect(player.speed, 0.5);
    });

    test('persists the chosen speed across configure calls', () async {
      await player.setSpeed(1.5);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('audio_lib_speed'), 1.5);

      // Simulates a fresh app start: configureCategories reloads the speed.
      final fresh = AudioLibraryPlayer.instance;
      await fresh.configureCategories([
        _cat('a', ['t1'])
      ]);
      expect(fresh.speed, 1.5);
    });
  });

  group('speaker wiring', () {
    AudioCategory speakerCat(
            List<({String id, List<String> tracks})> speakers) =>
        AudioCategory(
          id: 'lectures',
          tracks: [
            for (final s in speakers)
              for (final t in s.tracks)
                AudioTrack(id: t, title: t, file: 'x/$t.opus', sizeBytes: 100),
          ],
          speakers: [
            for (final s in speakers)
              AudioSpeaker(
                id: s.id,
                title: s.id == 'ziaei' ? 'شیخ ضیایی' : s.id,
                tracks: [
                  for (final t in s.tracks)
                    AudioTrack(
                        id: t, title: t, file: 'x/$t.opus', sizeBytes: 100),
                ],
              ),
          ],
        );

    test('nextOf chains within speakers and not across', () async {
      await player.configureCategories([
        _cat('yaqeen', ['y1', 'y2']),
        speakerCat([
          (id: 'ziaei', tracks: ['z1', 'z2', 'z3']),
          (id: 'other', tracks: ['o1', 'o2']),
        ]),
      ]);
      expect(player.debugNextOf, {
        'y1': 'y2',
        'y2': isNull,
        'z1': 'z2',
        'z2': 'z3',
        'z3': isNull,
        'o1': 'o2',
        'o2': isNull,
      });
    });

    test('categoryOf stays the parent category for all tracks', () async {
      await player.configureCategories([
        speakerCat([
          (id: 's', tracks: ['a1', 'a2'])
        ]),
      ]);
      expect(player.categoryOf('a1'), 'lectures');
      expect(player.categoryOf('a2'), 'lectures');
    });

    test('speakerOf and speakerTitleOf map correctly', () async {
      await player.configureCategories([
        speakerCat([
          (id: 'ziaei', tracks: ['z1'])
        ]),
      ]);
      expect(player.speakerOf('z1'), 'ziaei');
      expect(player.speakerTitleOf('z1'), 'شیخ ضیایی');
    });

    test('bylineOf keeps no byline for categories without teacher', () async {
      await player.configureCategories([
        speakerCat([
          (id: 'ziaei', tracks: ['z1'])
        ]),
        const AudioCategory(
          id: 'anasheed',
          tracks: [
            AudioTrack(
                id: 'a1', title: 'نیّه', file: 'a/a1.opus', sizeBytes: 100),
            AudioTrack(
                id: 'f1', title: 'دل غافل', file: 'a/f1.opus', sizeBytes: 100),
          ],
          speakers: [
            AudioSpeaker(id: 'arabi', title: 'عربی', tracks: [
              AudioTrack(
                  id: 'a1', title: 'نیّه', file: 'a/a1.opus', sizeBytes: 100),
            ]),
            AudioSpeaker(id: 'farsi', title: 'فارسی', tracks: [
              AudioTrack(
                  id: 'f1',
                  title: 'دل غافل',
                  file: 'a/f1.opus',
                  sizeBytes: 100),
            ]),
          ],
        ),
      ]);
      expect(player.bylineOf('z1'), 'شیخ ضیایی');
      expect(player.bylineOf('a1'), isNull);
      expect(player.bylineOf('f1'), isNull);
    });

    test('firstOfGroup wraps within the same speaker', () async {
      await player.configureCategories([
        speakerCat([
          (id: 's1', tracks: ['s1a', 's1b']),
          (id: 's2', tracks: ['s2a']),
        ]),
      ]);
      expect(player.firstOfGroup('s1a'), 's1a');
      expect(player.firstOfGroup('s1b'), 's1a');
      expect(player.firstOfGroup('s2a'), 's2a');
    });

    test('reconfigure clears previous speaker maps', () async {
      await player.configureCategories([
        speakerCat([
          (id: 'a', tracks: ['x'])
        ]),
      ]);
      expect(player.speakerOf('x'), 'a');
      await player.configureCategories([
        _cat('b', ['y'])
      ]);
      expect(player.speakerOf('y'), isNull);
      expect(player.speakerTitleOf('y'), isNull);
    });
  });

  group('sleep timer', () {
    test('arms and reports remaining time', () {
      player.setSleepTimer(const Duration(seconds: 30));
      expect(player.sleepTimerActive, isTrue);
      expect(player.sleepRemaining, const Duration(seconds: 30));
    });

    test('null and zero both cancel the timer', () {
      player.setSleepTimer(const Duration(seconds: 30));
      player.setSleepTimer(null);
      expect(player.sleepTimerActive, isFalse);
      expect(player.sleepRemaining, isNull);

      player.setSleepTimer(const Duration(seconds: 30));
      player.setSleepTimer(Duration.zero);
      expect(player.sleepTimerActive, isFalse);
    });
  });

  group('autoNext', () {
    test('toggles and notifies', () {
      var calls = 0;
      player.addListener(() => calls++);
      player.setAutoNext(true);
      expect(player.autoNext, isTrue);
      expect(calls, 1);
      player.setAutoNext(true);
      expect(calls, 1);
      player.setAutoNext(false);
      expect(player.autoNext, isFalse);
    });
  });

  group('seek limit', () {
    test('uses the persisted duration when the stream has not reported one',
        () async {
      const track =
          AudioTrack(id: 's1', title: 's1', file: 's1.opus', sizeBytes: 1);
      SharedPreferences.setMockInitialValues(
          {'audio_lib_dur_s1': 420000}); // 7 minutes
      final p = AudioLibraryPlayer.instance;
      await p.configureCategories([
        _cat('a', ['s1'])
      ]);

      expect(p.seekLimitOf(track), const Duration(minutes: 7));

      // The state has no duration yet, so this must be purely the persisted one.
      final st = p.stateOf(track);
      expect(st.hasDuration, isFalse);
    });

    test('reports zero for a track never seen before', () {
      const track = AudioTrack(
          id: 'nope', title: 'nope', file: 'nope.opus', sizeBytes: 1);
      expect(player.seekLimitOf(track), Duration.zero);
      expect(player.seekLimitOf(track) > Duration.zero, isFalse);
    });
  });

  group('shuffle', () {
    test('defaults off and toggles with notification', () {
      expect(player.shuffle, isFalse);
      var notified = 0;
      player.addListener(() => notified++);
      player.setShuffle(true);
      expect(player.shuffle, isTrue);
      player.setShuffle(true); // same value → no extra notify
      expect(notified, 1);
      player.setShuffle(false);
      expect(player.shuffle, isFalse);
    });

    test('shuffled next stays inside the same group and differs from current',
        () async {
      await player.configureCategories([
        _cat('lectures', ['a1', 'a2', 'a3', 'a4']),
      ]);
      player.setShuffle(true);
      // با ۴ درس در یک گروه، شافل روی ۱۶ نمونه هرگز به خودی خود ثابت نمی‌ماند
      // و هرگز از گروه خارج نمیشود (اینجا فقط یک گروه وجود دارد).
      final picks = <String>{};
      for (var i = 0; i < 16; i++) {
        final id = player.debugShuffledNextOf('a1');
        expect(id, isNotNull);
        expect(id, isNot('a1'));
        picks.add(id!);
      }
      expect(picks.difference({'a2', 'a3', 'a4'}), isEmpty);
    });

    test('shuffle respects speaker boundaries', () async {
      const cat = AudioCategory(
        id: 'misc',
        tracks: [],
        speakers: [
          AudioSpeaker(id: 's1', title: 'یک', tracks: [
            AudioTrack(id: 's1a', title: 'a', file: 'a.opus', sizeBytes: 1),
            AudioTrack(id: 's1b', title: 'b', file: 'b.opus', sizeBytes: 1),
          ]),
          AudioSpeaker(id: 's2', title: 'دو', tracks: [
            AudioTrack(id: 's2a', title: 'c', file: 'c.opus', sizeBytes: 1),
          ]),
        ],
      );
      await player.configureCategories([cat]);
      player.setShuffle(true);
      for (var i = 0; i < 8; i++) {
        expect(player.debugShuffledNextOf('s1a'), 's1b');
        expect(player.debugShuffledNextOf('s2a'), isNull,
            reason: 'گروه تک‌درسی جای شافل ندارد');
      }
    });
  });

  group('storage management', () {
    test('downloadedBytes is zero with no files on disk', () async {
      expect(await player.downloadedBytes(), 0);
    });

    test('deleteAllDownloaded on an empty library completes and returns >= 0',
        () async {
      final removed = await player.deleteAllDownloaded([
        const AudioTrack(id: 'ghost', title: 'g', file: 'g.opus', sizeBytes: 1),
      ]);
      expect(removed, greaterThanOrEqualTo(0));
    });
  });
}
