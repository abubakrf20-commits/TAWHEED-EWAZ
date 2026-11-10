import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/audio_library/audio_library_manifest.dart';
import 'package:tawheeed/features/audio_library/audio_library_player.dart';

/// The audio host can go down (a storage quota, a CDN outage) while the user's
/// own connection is fine. These tests prove the library they already
/// downloaded stays listable and playable from the device index alone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  late AudioLibraryPlayer player;

  AudioTrack track(String id) => AudioTrack(
        id: id,
        title: 'درس $id',
        file: 'lectures/$id.opus',
        sizeBytes: 2048,
      );

  /// Two speakers in `lectures` (grouped) plus a flat `anasheed` category, so
  /// the rebuilt manifest has to reproduce both shapes.
  final lectures = AudioCategory(
    id: 'lectures',
    tracks: [track('l1'), track('l2'), track('l3')],
    speakers: [
      AudioSpeaker(id: 'ziaei', title: 'شیخ ضیایی', tracks: [
        track('l1'),
        track('l2'),
      ]),
      AudioSpeaker(id: 'other', title: 'استاد دیگر', tracks: [track('l3')]),
    ],
  );
  final anasheed = AudioCategory(id: 'anasheed', tracks: [track('a1')]);
  final allTracks = [...lectures.tracks, ...anasheed.tracks];

  /// Writes a real file (>1KB, the threshold [AudioLibraryPlayer.isDownloaded]
  /// uses) at the path the player itself would have downloaded to.
  Future<void> putOnDisk(String id) async {
    final file = File(await player.localPath(id));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List<int>.filled(2048, 7));
  }

  Future<void> removeFromDisk(String id) async {
    final file = File(await player.localPath(id));
    if (file.existsSync()) await file.delete();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('tawheeed_audio_index');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    player = AudioLibraryPlayer.instance..debugResetForTest();
    await player.configureCategories([lectures, anasheed]);
  });

  tearDown(() async {
    player.debugResetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('an empty device stores no local library', () async {
    await player.refresh(allTracks);
    expect(await player.buildLocalManifest(), isNull);
  });

  test('the index survives an app restart with titles and grouping', () async {
    await putOnDisk('l1');
    await putOnDisk('l2');
    await player.refresh(allTracks);

    // Simulate a restart: session maps and the cached dir are forgotten, only
    // SharedPreferences and the files on disk remain.
    player.debugResetForTest();
    final local = await player.buildLocalManifest();

    expect(local, isNotNull);
    expect(local!.version, 0);
    expect(local.categories.map((c) => c.id), ['lectures']);
    final category = local.categories.single;
    expect(category.tracks.map((t) => t.id), ['l1', 'l2']);
    expect(category.tracks.first.title, 'درس l1');
    expect(category.tracks.first.file, 'lectures/l1.opus');
    // The speaker split is remembered, so the tab layout does not collapse.
    expect(category.speakers.single.id, 'ziaei');
    expect(category.speakers.single.title, 'شیخ ضیایی');
    expect(category.speakers.single.tracks.length, 2);
  });

  test('a category without speakers stays flat', () async {
    await putOnDisk('a1');
    await player.refresh(allTracks);
    player.debugResetForTest();

    final category = (await player.buildLocalManifest())!.categories.single;
    expect(category.id, 'anasheed');
    expect(category.speakers, isEmpty);
    expect(category.tracks.single.id, 'a1');
  });

  test('a file deleted after indexing disappears from the library', () async {
    await putOnDisk('l1');
    await putOnDisk('l3');
    await player.refresh(allTracks);
    await removeFromDisk('l3');

    player.debugResetForTest();
    final local = await player.buildLocalManifest();

    expect(local!.allTracks.map((t) => t.id), ['l1']);
    expect(local.categories.single.speakers.single.id, 'ziaei');
  });

  test('deleting every file leaves no half-empty library behind', () async {
    await putOnDisk('l1');
    await player.refresh(allTracks);
    await removeFromDisk('l1');

    player.debugResetForTest();
    expect(await player.buildLocalManifest(), isNull);
  });

  test('the index rewrites itself when a download lands', () async {
    await putOnDisk('l1');
    await player.refresh(allTracks);
    await putOnDisk('a1');
    await player.refresh(allTracks);

    // The second refresh must add, not replace: both tracks stay listed.
    final local = await player.buildLocalManifest();
    expect(local!.allTracks.map((t) => t.id).toSet(), {'l1', 'a1'});
    expect(
        local.categories.map((c) => c.id).toList(), ['lectures', 'anasheed']);

    // And the local file is what playback resolves to.
    expect(p.basename(await player.localPath('a1')), 'a1.opus');
  });
}
