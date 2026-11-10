import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/api/quran_api_config.dart';

void main() {
  tearDown(QuranApiConfig.debugSetContentBase);

  group('QuranApiConfig environment resolution', () {
    test('defaults to production endpoints', () {
      expect(
        QuranApiConfig.apiBase,
        'https://apis.quran.foundation/content/api/v4',
      );
      expect(
        QuranApiConfig.tokenEndpoint,
        'https://oauth2.quran.foundation/oauth2/token',
      );
    });

    test('prelive/production constants and endpoint getters exist', () {
      expect(QuranApiConfig.envPrelive, 'prelive');
      expect(QuranApiConfig.envProduction, 'production');
      expect(QuranApiConfig.apiBase, contains('apis.'));
      expect(QuranApiConfig.tokenEndpoint, contains('oauth2'));
    });

  });

  group('QuranApiConfig configured state', () {
    test('release builds are not configured (no bundled credentials)', () {
      // The release build intentionally ships without credentials — everything
      // works from the bundled data and public hosts.
      expect(QuranApiConfig.isConfigured, isFalse);
    });
  });

  group('QuranApiConfig content base', () {
    test('content base defaults to the public content host', () {
      expect(QuranApiConfig.contentBaseUrl, isNotEmpty);
      expect(
          QuranApiConfig.contentBaseUrl, contains('raw.githubusercontent.com'));
    });

    test('debugSetContentBase overrides and resets', () {
      QuranApiConfig.debugSetContentBase(base: 'https://content.example.com');
      expect(QuranApiConfig.contentBaseUrl, 'https://content.example.com');
      QuranApiConfig.debugSetContentBase();
      expect(
          QuranApiConfig.contentBaseUrl, contains('raw.githubusercontent.com'));
    });
  });
}
