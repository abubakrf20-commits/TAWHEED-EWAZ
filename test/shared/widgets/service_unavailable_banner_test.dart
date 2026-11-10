import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/widgets/service_unavailable_banner.dart';

void main() {
  Future<void> pumpBanner(WidgetTester tester, String detail,
      {double height = 800}) async {
    tester.view.physicalSize = Size(900, height);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ServiceUnavailableBanner(detail: detail),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the title, icon and the page-specific detail',
      (tester) async {
    await pumpBanner(tester, 'اتصال اینترنت را بررسی کنید.');

    expect(find.text('سرویس آنلاین در دسترس نیست'), findsOneWidget);
    expect(find.text('اتصال اینترنت را بررسی کنید.'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });

  testWidgets('long detail text wraps instead of overflowing', (tester) async {
    // A very long detail must wrap inside the banner (Expanded > Column),
    // not overflow the Row/Column pair. A tall viewport gives the single
    // child of the scroll-free test body enough height for the wrapped text.
    await pumpBanner(tester, 'متن بسیار بلند ' * 12, height: 2000);
    expect(find.textContaining('متن بسیار بلند'), findsOneWidget);
  });
}
