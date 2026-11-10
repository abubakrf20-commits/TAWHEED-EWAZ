import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/audio_library/audio_library_config.dart';
import 'package:tawheeed/features/audio_library/audio_library_repository.dart';

Map<String, dynamic> _manifestJson() => {
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
          ],
        },
      ],
    };

http.Response _okResponse() => http.Response.bytes(
      utf8.encode(jsonEncode(_manifestJson())),
      200,
      headers: {'content-type': 'application/json'},
    );

/// Runs [AudioLibraryRepository.load] and returns the typed failure it raises.
Future<AudioLibraryException> _failureOf(AudioLibraryRepository repo) async {
  try {
    await repo.load();
  } on AudioLibraryException catch (e) {
    return e;
  }
  fail('expected an AudioLibraryException');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AudioLibraryRepository.instance.debugClearCache();
  });

  group('AudioLibraryRepository.load', () {
    test('loads and parses the manifest over the network', () async {
      final repo = AudioLibraryRepository.instance
        ..debugSetClient(MockClient((request) async {
          expect(request.url.toString(), AudioLibraryConfig.manifestUrl);
          return _okResponse();
        }));

      final manifest = await repo.load();
      expect(manifest.version, 1);
      expect(manifest.categories.single.tracks.single.title,
          'معرفت شناسی');
    });

    test('falls back to the disk cache when offline', () async {
      final repo = AudioLibraryRepository.instance
        ..debugSetClient(MockClient((_) async => _okResponse()));
      final online = await repo.load();
      expect(online.allTracks.length, 1);
      // Let the unawaited disk write settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));

// Forget the in-memory copy and go offline.
      repo.debugForgetMemory();
      repo.debugSetClient(MockClient((_) async {
        throw http.ClientException('offline');
      }));

      final cached = await repo.load();
      expect(cached.allTracks.length, 1);
      expect(cached.categories.single.tracks.single.title,
          'معرفت شناسی');
    });

    test('throws when offline and no cache exists', () async {
      final repo = AudioLibraryRepository.instance
        ..debugSetClient(MockClient((_) async {
          throw http.ClientException('offline');
        }));

      expect(repo.load(), throwsA(isA<Exception>()));
    });

    test('a restricted host is blamed on the host, never on the connection',
        () async {
      final repo = AudioLibraryRepository.instance
        ..debugSetClient(
            MockClient((_) async => http.Response('{"message":"quota"}', 402)));

      final failure = await _failureOf(repo);
      expect(failure.failure, AudioLibraryFailure.server);
      expect(failure.statusCode, 402);
      expect(failure.message, contains('402'));
      expect(failure.message, isNot(contains('اینترنت')));
    });

    test('a transport failure with no cache is reported as offline', () async {
      final repo = AudioLibraryRepository.instance
        ..debugSetClient(MockClient((_) async {
          throw http.ClientException('Connection closed before header');
        }));

      final failure = await _failureOf(repo);
      expect(failure.failure, AudioLibraryFailure.offline);
      expect(failure.message, contains('اینترنت'));
      // Named, not blamed: a host that is down or misrouted must not read as
      // the listener's own connection being off.
      expect(failure.message, contains(AudioLibraryConfig.host));
    });

    test('a 200 that is not a manifest is a data failure, not a dead host',
        () async {
      final repo = AudioLibraryRepository.instance
        ..debugSetClient(MockClient(
            (_) async => http.Response(jsonEncode(['not', 'a', 'map']), 200)));

      final failure = await _failureOf(repo);
      expect(failure.failure, AudioLibraryFailure.data);
    });

    test('serves from disk cache when the server returns an error', () async {
      final repo = AudioLibraryRepository.instance
        ..debugSetClient(MockClient((_) async => _okResponse()));
      await repo.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      repo.debugForgetMemory();
      repo.debugSetClient(MockClient((_) async => http.Response('', 500)));

      final cached = await repo.load();
      expect(cached.allTracks.length, 1);
    });

    test('re-entry serves the in-memory copy instantly without the network',
        () async {
      final repo = AudioLibraryRepository.instance
        ..debugSetClient(MockClient((_) async => _okResponse()));
      final first = await repo.load();
      expect(first.allTracks.length, 1);

      // Simulate a slow/broken network on re-entry: the UI still gets the
      // cached copy immediately and the background refresh failure is silent.
      repo.debugSetClient(MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        throw http.ClientException('offline');
      }));

      final second = await repo.load();
      expect(identical(first, second), isTrue);

      // Let the background refresh finish so no work dangles.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    test('cold start with a disk cache serves instantly (cache-first)',
        () async {
      final repo = AudioLibraryRepository.instance
        ..debugSetClient(MockClient((_) async => _okResponse()));
      // Warm the disk cache, then simulate an app restart (memory cleared).
      await repo.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      repo.debugForgetMemory();

      // Even when the network is VERY slow, the cached manifest returns
      // immediately — the network fetch is never awaited on the open path.
      repo.debugSetClient(MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 10));
        return _okResponse();
      }));
      final sw = Stopwatch()..start();
      final cached = await repo.load();
      sw.stop();
      expect(cached.allTracks.length, 1);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)),
          reason: 'cold open must serve the disk cache, not wait for network');

      // Let the background refresh finish so no work dangles.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });
}
