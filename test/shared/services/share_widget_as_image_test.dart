import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/services/share_widget_as_image.dart';

void main() {
  testWidgets('capture boundary wraps the full 900px-wide content',
      (tester) async {
    final boundaryKey = GlobalKey();
    // The host surface is 800x600 — a RepaintBoundary that mistakenly hugs
    // the screen instead of the content would report 800x600 and crop the
    // shared image; the real card here is 900px wide like share cards are.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildShareCaptureScene(
            boundaryKey: boundaryKey,
            width: 900,
            height: 500,
            child: Container(
              width: 900,
              height: 500,
              color: const Color(0xFF00ACC1),
              alignment: Alignment.center,
              child: const Text('تسویهٔ هزینه‌ها',
                  style: TextStyle(fontSize: 40, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تسویهٔ هزینه‌ها'), findsOneWidget);
    expect(tester.getSize(find.byKey(boundaryKey)), const Size(900, 500),
        reason: 'boundary must be content-sized so the PNG is not cropped '
            'to the 800px-wide test surface');
  });

  testWidgets('measure pass (no height) keeps the natural content height',
      (tester) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildShareCaptureScene(
            boundaryKey: boundaryKey,
            width: 900,
            child: Container(
              width: 900,
              height: 500,
              color: const Color(0xFF00ACC1),
              alignment: Alignment.center,
              child: const Text('تسویهٔ هزینه‌ها',
                  style: TextStyle(fontSize: 40, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(boundaryKey)), const Size(900, 500));
  });
}
