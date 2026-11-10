import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/quran/services/mp3quran_service.dart';

void main() {
  group('Mp3QuranService.isPlausibleAudioResponse (Audit 9-A)', () {
    final mp3Bytes = Uint8List.fromList([
      0x49,
      0x44,
      0x33, // "ID3" tag start — a real mp3 header
      ...List.filled(200, 0x20),
    ]);
    final htmlBytes = Uint8List.fromList(
        '<!doctype html><html><body>Portal</body></html>'.codeUnits);
    final jsonBytes = Uint8List.fromList('{"error":"rate limited"}'.codeUnits);

    test('accepts a real 200 audio response', () {
      expect(
        Mp3QuranService.isPlausibleAudioResponse(200, 'audio/mpeg', mp3Bytes),
        isTrue,
      );
    });

    test('accepts a 200 audio response with a missing content-type', () {
      // Some CDNs omit the header — body sniffing must not reject real audio.
      expect(
        Mp3QuranService.isPlausibleAudioResponse(200, null, mp3Bytes),
        isTrue,
      );
    });

    test('rejects a captive-portal HTML page served with HTTP 200', () {
      expect(
        Mp3QuranService.isPlausibleAudioResponse(200, 'text/html', htmlBytes),
        isFalse,
      );
    });

    test('rejects an HTML page even when the header is missing', () {
      expect(
        Mp3QuranService.isPlausibleAudioResponse(200, null, htmlBytes),
        isFalse,
      );
    });

    test('rejects a JSON error page (header and body sniff)', () {
      expect(
        Mp3QuranService.isPlausibleAudioResponse(
            200, 'application/json', jsonBytes),
        isFalse,
      );
      expect(
        Mp3QuranService.isPlausibleAudioResponse(200, null, jsonBytes),
        isFalse,
      );
    });

    test('rejects non-200 and tiny bodies', () {
      expect(
        Mp3QuranService.isPlausibleAudioResponse(404, 'audio/mpeg', mp3Bytes),
        isFalse,
      );
      expect(
        Mp3QuranService.isPlausibleAudioResponse(
            200, 'audio/mpeg', Uint8List.fromList([0x49, 0x44])),
        isFalse,
      );
    });
  });
}
