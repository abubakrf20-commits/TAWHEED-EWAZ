import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';
import 'package:tawheeed/features/quran/mushaf/quran_search_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The count line sits between the field and the results (upgrade wave-1
  // #5): an honest number, and an explicit truncation notice when the
  // service's 80-result page is hit.
  testWidgets('a result list carries its count, capped at 80',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SearchResultCountHeader(
          count: 81,
          palette: MushafPalette.light,
        ),
      ),
    ));

    expect(find.text('نمایش 80 نتیجهٔ نخست — عبارت را دقیق‌تر کنید'),
        findsOneWidget);
  });

  testWidgets('below the cap the plain count is shown', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SearchResultCountHeader(
          count: 3,
          palette: MushafPalette.light,
        ),
      ),
    ));

    expect(find.text('3 نتیجه'), findsOneWidget);
    expect(find.text('نمایش 80 نتیجهٔ نخست — عبارت را دقیق‌تر کنید'),
        findsNothing);
  });

  testWidgets('the count is exactly at the cap, not above it', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SearchResultCountHeader(
          count: 80,
          palette: MushafPalette.light,
        ),
      ),
    ));

    expect(find.text('نمایش 80 نتیجهٔ نخست — عبارت را دقیق‌تر کنید'),
        findsOneWidget);
  });
}
