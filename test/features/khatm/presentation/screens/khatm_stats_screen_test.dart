import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/features/khatm/presentation/screens/khatm_stats_screen.dart';

String _key(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setPhoneViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  KhatmModel buildKhatm() {
    final now = DateTime.now();
    final daily = <String, int>{};
    // 7 days of reading: today 10, yesterday 8, 3 days ago 5, rest 0.
    daily[_key(now)] = 10;
    daily[_key(now.subtract(const Duration(days: 1)))] = 8;
    daily[_key(now.subtract(const Duration(days: 3)))] = 5;

    final pages = List.filled(604, false);
    for (var i = 0; i < 23; i++) {
      pages[i] = true;
    }
    return KhatmModel(
      id: '1',
      title: 'ختم قرآن',
      startDate: now.subtract(const Duration(days: 30)),
      targetDays: 30,
      pagesRead: pages,
      dailyRead: daily,
    );
  }

  testWidgets('renders weekly stats and switches to monthly heatmap',
      (tester) async {
    await setPhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(home: KhatmStatsScreen(khatm: buildKhatm())),
    );
    await tester.pumpAndSettle();

    expect(find.text('گزارش پیشرفت ختم'), findsOneWidget);
    expect(find.text('مجموع صفحات هفته'), findsOneWidget);
    expect(find.text('آمار روزهای گذشته'), findsOneWidget);
    // Past-day row with today's pages.
    expect(find.text('10 صفحه'), findsWidgets);
    expect(find.text('8 صفحه'), findsWidgets);

    // Switch to monthly view.
    await tester.tap(find.text('ماهانه'));
    await tester.pumpAndSettle();

    expect(find.text('مجموع صفحات ماه'), findsOneWidget);
    expect(find.text('نقشه حرارتی ماه'), findsOneWidget);
  });
}
