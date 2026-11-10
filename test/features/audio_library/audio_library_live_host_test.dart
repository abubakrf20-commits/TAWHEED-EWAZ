@Tags(<String>['network'])
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:tawheeed/features/audio_library/audio_library_config.dart';
import 'package:tawheeed/features/audio_library/audio_library_manifest.dart';

/// Talks to the real audio-library host through the production URL builder and
/// manifest parser.
///
/// «وقتی می‌خواهم صدایی پخش یا دانلود کنم می‌گوید دسترسی به اینترنت نداری» was
/// not a player bug: the configured host had stopped resolving, every request
/// died in name resolution, and a host that cannot be resolved looks exactly
/// like a dead connection from inside the app. From the outside, a dead host
/// and a code bug are the same report, so this test answers the hosting half —
/// it asks the configured base for the manifest and for a byte range, which are
/// the two things the player needs.
///
/// Deliberately no `TestWidgetsFlutterBinding.ensureInitialized()`: the widget
/// binding installs HttpOverrides that answer every real request with 400, so
/// this test would never reach the host.
///
/// Tagged `network`; an offline run skips it with
/// `flutter test --exclude-tags network`.
void main() {
  test('the configured host serves a manifest and seekable tracks', () async {
    final client = http.Client();
    addTearDown(client.close);

    // Transport-only retry (F-15): a dropped connection or a slow handshake is
    // not a code regression, so it gets a second attempt and a 45 s ceiling
    // instead of the app's tighter default. An HTTP *error status* is NOT
    // retried — on 2026-10-12 this host answered 504 and the tripwire must say
    // so out loud rather than hide it.
    Future<http.Response> getWithOneRetry(Uri uri) async {
      Future<http.Response> run() =>
          client.get(uri).timeout(const Duration(seconds: 45));
      try {
        return await run();
      } on TimeoutException {
        return await run();
      } on http.ClientException {
        return await run();
      }
    }

    // 1) The listing. `load()` is cache-first, so a manifest failure shows the
    // listener a local library at best and «no internet» at worst — either way
    // the host has to answer this.
    final manifestRes =
        await getWithOneRetry(Uri.parse(AudioLibraryConfig.manifestUrl));
    expect(
      manifestRes.statusCode,
      200,
      reason: 'manifest host ${AudioLibraryConfig.host} did not answer with a '
          'manifest (${AudioLibraryConfig.manifestUrl})',
    );
    final manifest = AudioLibraryManifest.fromJson(
      jsonDecode(utf8.decode(manifestRes.bodyBytes)) as Map<String, dynamic>,
    );
    expect(manifest.allTracks, isNotEmpty,
        reason: 'a manifest that lists nothing empties the library');

    // 2) Streaming. A key with a space or Persian letters is the interesting
    // case: if the encoding drifts, the object 404s and the track silently
    // will not play. Ranges are what make the seek bar work; a host that
    // ignores Range answers 200 and seeking breaks.
    final track = manifest.allTracks.firstWhere(
      (t) => t.file.contains(' ') || t.file.codeUnits.any((c) => c > 127),
      orElse: () => manifest.allTracks.first,
    );
    final url = AudioLibraryConfig.objectUrl(track.file);
    final req = http.Request('GET', Uri.parse(url))
      ..headers['Range'] = 'bytes=0-1023';
    final res = await client.send(req).timeout(const Duration(seconds: 45));

    expect(res.statusCode, 206,
        reason: '${track.id} is not seekable: $url -> HTTP ${res.statusCode}');
    // ArvanCloud repeats `Content-Range` but not `Accept-Ranges` on a partial
    // response, so the range header is what proves the bytes came from the
    // middle of the object rather than from the whole file.
    expect(res.headers['content-range'], matches(RegExp(r'^bytes 0-1023/\d+$')),
        reason: 'host ignored the range: $url');
  });
}
