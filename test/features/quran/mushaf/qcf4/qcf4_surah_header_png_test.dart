import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_config.dart';

/// The surah-header banner is the user's full-color PNG artwork — these tests
/// pin the bundled asset (decodable, expected pixel size) and the geometry
/// contract the viewer relies on, so a bad export fails here instead of
/// misplacing the Mushaf header at runtime.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('header PNG is bundled with the expected pixel size', () async {
    final bytes = (await rootBundle.load(Qcf4Config.surahHeaderAsset))
        .buffer
        .asUint8List();
    expect(bytes.length, greaterThan(1000));
    // PNG signature.
    expect(
        bytes.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    // IHDR width/height (big-endian uint32 at offsets 16/20).
    final w = ByteData.sublistView(bytes, 16, 20).getUint32(0);
    final h = ByteData.sublistView(bytes, 20, 24).getUint32(0);
    expect(w, Qcf4Config.surahHeaderVbW.toInt());
    expect(h, Qcf4Config.surahHeaderVbH.toInt());
  });

  testWidgets('header PNG paints without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          child: SizedBox(
            width: 279,
            height: 279 * Qcf4Config.surahHeaderAspect,
            child: Image.asset(
              Qcf4Config.surahHeaderAsset,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('banner layout: name cartouche stays clear of side cartouches', () {
    // Geometry contract used by the viewer: three disjoint text boxes —
    // name middle (32.2..67.8%), revelation-place left, verse-count right.
    const leftL = Qcf4Config.surahHeaderPanelLeftL;
    const leftR = Qcf4Config.surahHeaderPanelLeftR;
    const nameL = Qcf4Config.surahHeaderInnerL;
    const nameR = Qcf4Config.surahHeaderInnerR;
    const rightL = Qcf4Config.surahHeaderPanelRightL;
    const rightR = Qcf4Config.surahHeaderPanelRightR;
    expect(leftL, lessThan(leftR));
    expect(leftR, lessThan(nameL));
    expect(nameL, lessThan(nameR));
    expect(nameR, lessThan(rightL));
    expect(rightL, lessThan(rightR));
    // All boxes well inside the ornament.
    for (final v in [leftL, leftR, nameL, nameR, rightL, rightR]) {
      expect(v, greaterThan(0));
      expect(v, lessThan(1));
    }
    // Middle field vertically inside the ornament band (0.236..0.764).
    expect(Qcf4Config.surahHeaderInnerT, greaterThanOrEqualTo(0.23));
    expect(Qcf4Config.surahHeaderInnerB, lessThanOrEqualTo(0.77));
  });
}
