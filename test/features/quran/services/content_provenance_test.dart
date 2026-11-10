import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/services/content_provenance.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('content_prov');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  test('write then verify reads back verified', () async {
    final content = File('${tmp.path}${Platform.pathSeparator}t.json');
    final bytes = List<int>.generate(5000, (i) => i % 251);
    await content.writeAsBytes(bytes);

    await ContentProvenance.write(content.path, bytes,
        id: 't', remoteUrl: 'https://example.test/t.json');

    expect(
        await ContentProvenance.verify(content.path),
        ContentVerification.verified);
    final recorded = await ContentProvenance.recordedSha256(content.path);
    expect(recorded, isNotNull);
    expect(recorded!.length, 64);
  });

  test('a flipped byte reads mismatch', () async {
    final content = File('${tmp.path}${Platform.pathSeparator}t.json');
    final bytes = List<int>.generate(5000, (i) => i % 251);
    await content.writeAsBytes(bytes);
    await ContentProvenance.write(content.path, bytes,
        id: 't', remoteUrl: 'https://example.test/t.json');

    // Flip one byte deep inside — the bit-rot / tamper case.
    final corrupted = List<int>.of(bytes)..[2500] ^= 0xFF;
    await content.writeAsBytes(corrupted);

    expect(await ContentProvenance.verify(content.path),
        ContentVerification.mismatch);
  });

  test('no sidecar reads absent (legacy downloads stay usable)', () async {
    final content = File('${tmp.path}${Platform.pathSeparator}t.db');
    await content.writeAsBytes(List<int>.filled(2000, 7));
    expect(await ContentProvenance.verify(content.path),
        ContentVerification.absent);
    expect(await ContentProvenance.recordedSha256(content.path), isNull);
  });

  test('a corrupt sidecar reads mismatch — fail closed, not absent', () async {
    // Audit B02/B14: a sidecar that exists but cannot be read proves
    // nothing, so the content must be re-downloaded instead of being
    // served as «unverified but usable».
    final content = File('${tmp.path}${Platform.pathSeparator}t.json');
    await content.writeAsBytes(List<int>.filled(2000, 1));
    await File('${content.path}.prov.json')
        .writeAsString('not json at all {');
    expect(await ContentProvenance.verify(content.path),
        ContentVerification.mismatch);
  });

  test('a schema-unknown sidecar reads mismatch', () async {
    final content = File('${tmp.path}${Platform.pathSeparator}t.json');
    await content.writeAsBytes(List<int>.filled(2000, 1));
    await File('${content.path}.prov.json').writeAsString('{"schema": 99}');
    expect(await ContentProvenance.verify(content.path),
        ContentVerification.mismatch);
  });

  test('a sidecar with an empty digest reads mismatch', () async {
    final content = File('${tmp.path}${Platform.pathSeparator}t.json');
    await content.writeAsBytes(List<int>.filled(2000, 1));
    await File('${content.path}.prov.json')
        .writeAsString('{"schema": 1, "sha256": ""}');
    expect(await ContentProvenance.verify(content.path),
        ContentVerification.mismatch);
  });

  test('the sidecar records the source URL and size', () async {
    final content = File('${tmp.path}${Platform.pathSeparator}t.json');
    final bytes = List<int>.filled(3000, 9);
    await content.writeAsBytes(bytes);
    await ContentProvenance.write(content.path, bytes,
        id: 'persian_translation',
        remoteUrl: 'https://example.test/tafsir/t.json.gz');
    final raw =
        await File('${content.path}.prov.json').readAsString();
    expect(raw, contains('persian_translation'));
    expect(raw, contains('https://example.test/tafsir/t.json.gz'));
    expect(raw, contains('"sizeBytes": 3000'));
  });
}
