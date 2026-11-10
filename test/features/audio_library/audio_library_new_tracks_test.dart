import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/audio_library/audio_library_manifest.dart';
import 'package:tawheeed/features/audio_library/audio_library_player.dart';

AudioLibraryManifest _manifest(List<String> ids) => AudioLibraryManifest(
      version: 1,
      categories: [
        AudioCategory(
          id: 'cat',
          tracks: [
            for (final id in ids)
              AudioTrack(id: id, title: id, file: '$id.opus', sizeBytes: 1000),
          ],
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('new-content tracking', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AudioLibraryPlayer.instance.debugResetForTest();
    });

    test('first ever load marks nothing new (fresh install)', () async {
      final p = AudioLibraryPlayer.instance;
      await p.configureCategories(_manifest(['a', 'b', 'c']).categories);
      expect(p.isNewTrack('a'), isFalse);
      expect(p.isNewTrack('b'), isFalse);
      expect(p.newCountForCategory('cat'), 0);
    });

    test('tracks added in a later manifest are flagged new', () async {
      final p = AudioLibraryPlayer.instance;
      await p.configureCategories(_manifest(['a', 'b']).categories);
      p.debugResetForTest();
      await p.configureCategories(_manifest(['a', 'b', 'c', 'd']).categories);
      expect(p.isNewTrack('a'), isFalse);
      expect(p.isNewTrack('c'), isTrue);
      expect(p.isNewTrack('d'), isTrue);
      expect(p.newCountForCategory('cat'), 2);
    });

    test('markAllTracksSeen clears the flags and persists', () async {
      final p = AudioLibraryPlayer.instance;
      await p.configureCategories(_manifest(['a']).categories);
      p.debugResetForTest();
      await p.configureCategories(_manifest(['a', 'x']).categories);
      expect(p.isNewTrack('x'), isTrue);
      await p.markAllTracksSeen();
      expect(p.isNewTrack('x'), isFalse);
      // Re-configure with the same manifest: still not new.
      p.debugResetForTest();
      await p.configureCategories(_manifest(['a', 'x']).categories);
      expect(p.isNewTrack('x'), isFalse);
    });

    test('removed-then-re-added track counts as new again', () async {
      final p = AudioLibraryPlayer.instance;
      await p.configureCategories(_manifest(['a', 'b']).categories);
      p.debugResetForTest();
      await p.configureCategories(_manifest(['a']).categories);
      p.debugResetForTest();
      await p.configureCategories(_manifest(['a', 'b']).categories);
      expect(p.isNewTrack('b'), isTrue);
    });
  });
}
