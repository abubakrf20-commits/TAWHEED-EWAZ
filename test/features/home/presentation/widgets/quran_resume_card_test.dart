import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/features/home/presentation/widgets/quran_resume_card.dart';
import 'package:tawheeed/features/quran/data/quran_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpCard(WidgetTester tester) async {
    // The surah-name courtesy goes through `loadQuranData`, whose decode runs
    // in a REAL isolate — the repo's recorded fake-async trap. Pre-loading it
    // here (real async zone) seeds the module so the card's own await returns
    // instantly; the same hook the azkar tests use.
    await tester.runAsync(loadQuranData);
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: Scaffold(body: QuranResumeCard())),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('is hidden until the reader has ever been opened', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpCard(tester);

    expect(find.text('ادامهٔ مطالعه'), findsNothing);
  });

  testWidgets('shows the persisted page and jumps the shell to it',
      (tester) async {
    SharedPreferences.setMockInitialValues({'quran_last_page': 42});
    await pumpCard(tester);

    expect(find.text('ادامهٔ مطالعه'), findsOneWidget);
    expect(find.textContaining('صفحهٔ 42'), findsOneWidget);
    // The surah name is a courtesy, not a requirement — the bundled page map
    // names page 42's opening surah when the asset is reachable.
    expect(find.textContaining('سورهٔ'), findsOneWidget);

    // The tap goes through the SAME channel the global search uses: a
    // QuranNavRequest the quran tab consumes, then the shell switches to
    // the Quran tab (index 1).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(QuranResumeCard)),
    );
    final navRequest = container.read(quranNavRequestProvider);
    expect(navRequest.value, isNull);

    await tester.tap(find.text('ادامهٔ مطالعه'));
    await tester.pump();

    expect(navRequest.value?.page, 42);
  });
}
