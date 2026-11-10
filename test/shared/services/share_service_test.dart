import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/services/share_service.dart';

void main() {
  group('ShareService brand', () {
    test('channel block/line share one URL', () {
      expect(ShareService.channelBlock, contains(ShareService.channelUrl));
      expect(ShareService.channelLine, contains(ShareService.channelUrl));
      expect(ShareService.appLine('قرآن'), contains('برنامه توحید'));
    });

    test('the image signature carries no dash; the text line keeps it', () {
      expect(ShareService.signatureLine(), ShareService.signatureName);
      expect(ShareService.signatureLine('قرآن'), 'برنامه توحید | قرآن');
      expect(ShareService.signatureLine('قرآن'), isNot(contains('—')));
      // A text share has no logo above it, so its separator stays.
      expect(ShareService.appLine('قرآن'), '— برنامه توحید | قرآن');
      expect(ShareService.logoAsset, 'assets/logo2.png');
    });
  });

  group('ShareService.cardBoundary', () {
    testWidgets('resolves the on-screen card and its content size',
        (tester) async {
      final cardKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: cardKey,
                child: Container(
                  width: 300,
                  height: 200,
                  color: const Color(0xFFFDF6EC),
                  alignment: Alignment.center,
                  child: const Text('بسم الله',
                      style: TextStyle(fontSize: 32, color: Colors.black)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // NOTE: no toImage() rasterization here — software-test surfaces hang
      // on read-back in this environment. Boundary lookup (the crash site
      // this service fixes) is fully covered.
      final card = ShareService.cardBoundary(cardKey);
      expect(card.size, const Size(300, 200));
    });

    testWidgets('missing context throws ShareCaptureException (no crash)',
        (tester) async {
      final cardKey = GlobalKey();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      await tester.pumpAndSettle();

      expect(
        () => ShareService.captureCard(cardKey),
        throwsA(isA<ShareCaptureException>()),
      );
    });
  });
}
