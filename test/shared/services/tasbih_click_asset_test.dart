import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Guards the tasbih click asset: it must stay a short, loud WAV so rapid
/// taps each produce an audible tick with minimal latency. A long or quiet
/// file regresses straight back to "clicks have no sound".
void main() {
  test('tick.wav is a short, loud, low-latency click', () {
    final file = File('assets/sounds/tick.wav');
    expect(file.existsSync(), isTrue,
        reason: 'assets/sounds/tick.wav is missing');
    final bytes = file.readAsBytesSync();
    final data = ByteData.sublistView(bytes);

    String tag(int offset) =>
        String.fromCharCodes(bytes.sublist(offset, offset + 4));
    expect(tag(0), 'RIFF');
    expect(tag(8), 'WAVE');

    // Walk the chunks: fmt must be 16-bit mono PCM at 44.1 kHz.
    var offset = 12;
    var sampleRate = 0;
    var dataStart = -1;
    var dataLength = 0;
    while (offset + 8 <= bytes.length) {
      final id = tag(offset);
      final size = data.getUint32(offset + 4, Endian.little);
      if (id == 'fmt ') {
        expect(data.getUint16(offset + 8, Endian.little), 1,
            reason: 'tick.wav must be PCM');
        expect(data.getUint16(offset + 10, Endian.little), 1,
            reason: 'tick.wav must be mono');
        sampleRate = data.getUint32(offset + 12, Endian.little);
        expect(sampleRate, 44100);
        expect(data.getUint16(offset + 22, Endian.little), 16,
            reason: 'tick.wav must be 16-bit');
      } else if (id == 'data') {
        dataStart = offset + 8;
        dataLength = size;
      }
      offset += 8 + size + (size.isOdd ? 1 : 0);
    }
    expect(dataStart, isNot(-1), reason: 'tick.wav has no data chunk');

    // Short enough that bursts never pile up: 60 ms at most.
    final frames = dataLength ~/ 2;
    final durationMs = 1000 * frames / sampleRate;
    expect(durationMs, lessThanOrEqualTo(60),
        reason: 'tick.wav is ${durationMs.toStringAsFixed(1)} ms');

    // Loud enough to hear at mid volume: peak at least half-scale.
    var peak = 0;
    for (var i = 0; i < frames; i++) {
      final sample = data.getInt16(dataStart + i * 2, Endian.little).abs();
      if (sample > peak) peak = sample;
    }
    expect(peak / 32768, greaterThanOrEqualTo(0.5),
        reason: 'tick.wav peak is only ${(100 * peak / 32768).toStringAsFixed(1)}%');
  });
}
