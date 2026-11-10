import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/photo_gallery_screen.dart';

void main() {
  Future<void> pumpViewer(
    WidgetTester tester, {
    int initialIndex = 0,
    String? title,
  }) async {
    // A tall viewport keeps the page and its app bar fully visible.
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: PhotoGalleryScreen(
        imagePaths: const ['/missing/a.jpg', '/missing/b.jpg'],
        initialIndex: initialIndex,
        title: title,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the requested page with a share button',
      (tester) async {
    await pumpViewer(tester, initialIndex: 1);

    expect(find.byType(PhotoGalleryScreen), findsOneWidget);
    // "photo 2 of 2" counter + share action; the missing file must not
    // crash the viewer (its placeholder is timing-dependent in tests).
    expect(find.textContaining('\u0639\u06a9\u0633 2 \u0627\u0632 2'),
        findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
  });

  testWidgets('clamps an out-of-range initial index to the last page',
      (tester) async {
    await pumpViewer(tester, initialIndex: 9);

    expect(find.textContaining('\u0639\u06a9\u0633 2 \u0627\u0632 2'),
        findsOneWidget);
  });
}
