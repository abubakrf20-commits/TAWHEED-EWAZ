import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/audio_library/audio_library_config.dart';

void main() {
  group('AudioLibraryConfig.objectUrl', () {
    test('builds public URLs for ASCII keys', () {
      expect(
        AudioLibraryConfig.objectUrl('yaqeen/01-marefat-shenasi.opus'),
        'https://s3.ir-thr-at1.arvanstorage.ir/'
        't.audio/'
        'yaqeen/01-marefat-shenasi.opus',
      );
    });

    test('the default host is the live Arvan bucket, addressed path-style', () {
      // The Supabase project this used to point at no longer resolves, and a
      // name the device cannot resolve is reported as «no internet» even when
      // the connection is fine. Path style is part of the contract, not a
      // preference: the wildcard certificate is
      // `*.s3.<region>.arvanstorage.ir` and matches exactly one label, so
      // `t.audio.s3.<region>.arvanstorage.ir` fails the TLS handshake.
      expect(AudioLibraryConfig.storagePublicBaseUrl,
          'https://s3.ir-thr-at1.arvanstorage.ir/t.audio');
      expect(AudioLibraryConfig.host, 's3.ir-thr-at1.arvanstorage.ir');
    });

    test('URL-encodes each path segment so Persian keys still work', () {
      final url = AudioLibraryConfig.objectUrl('lectures/درس-یک.opus');
      expect(url, contains('lectures'));
      expect(url, isNot(contains('درس')));
      expect(url, contains(Uri.encodeComponent('درس-یک.opus')));
    });

    test('trims a leading slash so the base is never doubled', () {
      expect(
        AudioLibraryConfig.objectUrl('/yaqeen/01.opus'),
        AudioLibraryConfig.objectUrl('yaqeen/01.opus'),
      );
    });

    test('the manifest lives on the same base as the files', () {
      // Repointing AUDIO_LIBRARY_BASE_URL must move listing AND streaming
      // together; a split host would play files the list never promised.
      expect(AudioLibraryConfig.manifestUrl,
          '${AudioLibraryConfig.storagePublicBaseUrl}/index.json');
      expect(
        AudioLibraryConfig.objectUrl('a/b.opus'),
        startsWith(AudioLibraryConfig.storagePublicBaseUrl),
      );
    });

    test('an absolute https key is streamed verbatim, never re-hosted', () {
      // «تفسیر مولانا بدری» is served by the content owner's own host: the
      // user's decision is that these files are never re-uploaded, so the
      // manifest carries the third-party URL as the `file` and this resolver
      // must not prepend the Arvan base or re-encode a path that is already
      // a legal URL.
      const url = 'https://sunnatmedia.ir/download/Abdulghani-Badri/'
          '001-Al-Fatihah/001-Al-Fatihah.mp3';
      expect(AudioLibraryConfig.objectUrl(url), url);
    });

    test('the absolute key keeps its escapes and hamza underscores', () {
      // `%20` and `Al-Ma_idah` are the host's own spelling. Percent-encoding
      // an already-encoded segment turns `%20` into `%2520` and a 404 follows.
      final url = AudioLibraryConfig.objectUrl('https://sunnatmedia.ir/'
          'download/Abdulghani-Badri/036-Ya-Sin/036-Ya%20Seen.mp3');
      expect(url, contains('%20'));
      expect(url, isNot(contains('%25')));
      expect(
        AudioLibraryConfig.objectUrl('http://sunnatmedia.ir/a/005-Al-Ma_idah/'
            '05-ma-ida1.mp3'),
        'http://sunnatmedia.ir/a/005-Al-Ma_idah/05-ma-ida1.mp3',
      );
    });

    test('a relative key still resolves against the bucket base', () {
      // Only absolute keys bypass the base; yaqeen/anasaehd/lectures keep
      // living in t.audio exactly as before.
      expect(
        AudioLibraryConfig.objectUrl('yaqeen/01.opus'),
        '${AudioLibraryConfig.storagePublicBaseUrl}/yaqeen/01.opus',
      );
    });
  });
}
