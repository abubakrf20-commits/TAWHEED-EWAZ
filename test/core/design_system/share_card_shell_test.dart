import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/share_card_shell.dart';
import 'package:tawheeed/shared/services/share_service.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(child: child),
        ),
      ),
    );

void main() {
  testWidgets('the footer paints the mark beside a dash-free signature',
      (tester) async {
    await tester.pumpWidget(_wrap(const ShareCardFooter(section: 'میراث')));
    await tester.pump();

    final logo = tester.widget<Image>(find.byType(Image));
    expect(logo.image, ShareCardLogo.providerFor(ShareCardLogo.defaultSize));
    expect(logo.height, ShareCardLogo.defaultSize,
        reason: 'the mark rides beside an 11 sp line, so it stays near the '
            'line height — at 48 dp it dwarfed the text');
    expect(ShareCardLogo.defaultSize,
        lessThan(ShareCardSignature.defaultFontSize * 2),
        reason: 'past two text lines the mark stops reading as part of the row');
    expect(logo.fit, BoxFit.contain);
    expect(logo.semanticLabel, ShareService.signatureName);

    final signature = find.text(ShareService.signatureLine('میراث'));
    final line = tester.widget<Text>(signature);
    expect(line.textAlign, TextAlign.center);
    expect(find.text(ShareService.appLine('میراث')), findsNothing,
        reason: 'the em dash belongs to text shares; the mark marks the card');

    final logoRect = tester.getRect(find.byType(Image));
    final lineRect = tester.getRect(signature);

    expect(
      tester.getRect(find.byType(ShareCardDivider)).top,
      lessThanOrEqualTo(logoRect.top),
      reason: 'the hairline opens the footer, above the mark',
    );
    expect(
      (logoRect.center.dy - lineRect.center.dy).abs(),
      lessThanOrEqualTo(1),
      reason: 'the mark and the signature share one line',
    );
    expect(
      logoRect.left,
      greaterThanOrEqualTo(lineRect.right - 0.5),
      reason: 'in RTL the first row child (the mark) sits at the right of '
          'the signature it marks',
    );
  });

  testWidgets('the footer follows the dark brightness', (tester) async {
    await tester.pumpWidget(_wrap(
      const ShareCardFooter(section: 'قرآن'),
      brightness: Brightness.dark,
    ));
    await tester.pump();

    final line = tester.widget<Text>(
      find.text(ShareService.signatureLine('قرآن')),
    );
    expect(line.style?.color, Colors.white.withValues(alpha: 0.9));
  });

  test('the mark decodes for the export, not for the 1× preview', () {
    expect(ShareCardLogo.defaultSize, 18);
    final provider =
        ShareCardLogo.providerFor(ShareCardLogo.defaultSize) as ResizeImage;
    expect(provider.width, 108, reason: '18 dp × the 6× capture ceiling');
    expect(provider.imageProvider, const AssetImage(ShareService.logoAsset));
    expect(ShareCardLogo.providerFor(ShareCardLogo.defaultSize), provider,
        reason: 'the cache key must match what build() paints');
    expect((ShareCardLogo.providerFor(60) as ResizeImage).width, 360);
  });
}
