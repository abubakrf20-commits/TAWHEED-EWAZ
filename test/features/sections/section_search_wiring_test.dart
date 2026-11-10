import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/fasting/data/fasting_content.dart';
import 'package:tawheeed/features/fasting/presentation/screens/fasting_screen.dart';
import 'package:tawheeed/features/prayer/data/salah_data.dart';
import 'package:tawheeed/features/prayer/presentation/screens/prayer_screen.dart';
import 'package:tawheeed/features/tools/purification/data/taharah_data.dart';
import 'package:tawheeed/features/tools/purification/presentation/screens/purification_screen.dart';

/// The in-section search on the three big reading sections.
///
/// WHY: the More page's search stops at the door. A reader standing inside
/// «تیمم» who wants one ruling had to go back to the shell, search, and
/// re-enter — so in practice they scrolled. Each section now supplies its own
/// index, and these tests prove the index is really wired to the page.
///
/// Two test-environment constraints, both deliberate:
///
/// * the content is loaded inside `tester.runAsync`, because `salah.json` is
///   over 50 KB and `AssetBundle.loadString` hands big payloads to `compute()`
///   — an isolate whose completion fake-async never delivers;
/// * every wait is a bounded `pump`, never `pumpAndSettle`, because the fasting
///   page's countdown card runs a periodic timer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: page),
      ),
    ));
    await settle(tester);
  }

  /// Opens the sheet and types [query].
  Future<void> search(WidgetTester tester, String query) async {
    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, query);
    await settle(tester);
  }

  testWidgets('روزه indexes its rulings and the disliked acts', (tester) async {
    await tester.runAsync(SawmData.load);
    await pump(tester, const FastingScreen());

    // «مکروهات» sits under the «قضا و کفاره» tab, where nobody looks for it.
    await search(tester, 'خمیردندان');
    expect(find.textContaining('خمیردندان'), findsWidgets);

    // The hit carries the tab it came from, so the chip is never blank.
    expect(find.text('قضا و کفاره'), findsWidgets);
  });

  testWidgets('وضو indexes the plain lists, not just the titled rulings',
      (tester) async {
    await tester.runAsync(TaharahData.load);
    await pump(tester, const PurificationScreen());

    // A bare list item — its own title, no body.
    await search(tester, 'بول و غائط');
    expect(find.text('بول و غائط'), findsWidgets);
  });

  testWidgets('نماز finds a makruh act under احکام', (tester) async {
    await tester.runAsync(SalahData.load);
    await pump(tester, const PrayerScreen());

    await search(tester, 'نگاه کردن به آسمان');
    expect(find.textContaining('نگاه کردن به آسمان'), findsWidgets);
    expect(find.text('احکام'), findsWidgets);
  });

  testWidgets('a query that matches nothing says so', (tester) async {
    await tester.runAsync(SalahData.load);
    await pump(tester, const PrayerScreen());

    await search(tester, 'ززززز');
    expect(find.textContaining('پیدا نشد'), findsOneWidget);
  });
}
