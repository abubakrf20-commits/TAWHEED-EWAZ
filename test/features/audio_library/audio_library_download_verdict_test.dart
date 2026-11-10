import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/audio_library/audio_library_player.dart';

/// A finished transfer is only a whole file when the bytes agree.
///
/// The defect this pins: the download used to be declared complete on
/// `length > 1024` alone. A connection dropped at 30 % of a 12 MB lecture left
/// 3.6 MB on disk — comfortably over a kilobyte — so the file was renamed into
/// place, the card switched to the delete icon, and playback produced silence
/// with nothing ever re-fetching it.
void main() {
  group('downloadVerdict', () {
    test('a full transfer is complete', () {
      expect(
        downloadVerdict(received: 5000000, declaredTotal: 5000000, onDisk: 5000000),
        DownloadVerdict.complete,
      );
    });

    test('a dropped transfer is truncated, not complete', () {
      // The exact case the old check got wrong: plenty of bytes, not all of them.
      expect(
        downloadVerdict(received: 3600000, declaredTotal: 12000000, onDisk: 3600000),
        DownloadVerdict.truncated,
      );
    });

    test('a transfer one byte short is still truncated', () {
      expect(
        downloadVerdict(received: 9999, declaredTotal: 10000, onDisk: 9999),
        DownloadVerdict.truncated,
      );
    });

    test('an overshoot is accepted — a decompressed stream is longer', () {
      expect(
        downloadVerdict(received: 11000, declaredTotal: 10000, onDisk: 11000),
        DownloadVerdict.complete,
      );
    });

    test('no declared length falls back to the size heuristic', () {
      // Chunked responses carry no Content-Length; a real file is still fine.
      expect(
        downloadVerdict(received: 900000, declaredTotal: -1, onDisk: 900000),
        DownloadVerdict.complete,
      );
    });

    test('nothing usable on disk is empty, whatever the counter says', () {
      expect(
        downloadVerdict(received: 0, declaredTotal: 10000, onDisk: 0),
        DownloadVerdict.empty,
      );
      expect(
        downloadVerdict(received: 1024, declaredTotal: 10000, onDisk: 1024),
        DownloadVerdict.empty,
      );
    });

    test('empty wins over truncated — there is nothing to keep either way', () {
      // Both wrong; the empty message is the truthful one, because the partial
      // file is deleted and the listener has to start over.
      expect(
        downloadVerdict(received: 300, declaredTotal: 10000, onDisk: 300),
        DownloadVerdict.empty,
      );
    });
  });
}
