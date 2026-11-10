import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/prayer/presentation/screens/prayer_screen.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart'
    as ew;

/// A mock Evaluation that flips worship items on toggle — lets the test
/// verify the prayer checklist syncs completion into today's worship without
/// booting the full (database-backed) provider graph.
class _MockEvaluation extends ew.Evaluation {
  @override
  Future<ew.EvaluationState> build() async => ew.EvaluationState(
        worshipItems: [
          const ew.WorshipItem(
              id: 'quran',
              label: 'قرائت قرآن',
              icon: Icons.menu_book,
              points: 15),
          const ew.WorshipItem(id: 'prayer', label: 'نماز', icon: Icons.mosque),
        ],
      );

  @override
  void toggleWorship(String id) {
    final cur = state.requireValue;
    final items = cur.worshipItems
        .map((w) => w.id == id ? w.copyWith(done: !w.done) : w)
        .toList();
    state = AsyncData(cur.copyWith(worshipItems: items));
  }

  @override
  void addCustomWorshipItem(String label, IconData icon, int points) {}

  @override
  void removeCustomWorshipItem(String id) {}
}

const List<String> _prayerStepTitles = [
  'نیت نماز',
  'تکبیرة الاحرام',
  'ایستادن (قیام)',
  'قرائت سوره حمد',
  'قرائت سوره بعد از حمد',
  'رکوع',
  'اعتدال از رکوع',
  'سجده اول',
  'نشستن بین دو سجده',
  'سجده دوم',
  'تشهد پایانی',
  'صلوات بر پیامبر',
  'سلام پایانی',
  'رعایت ترتیب',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pumpPrayerScreen(WidgetTester tester) async {
    final container = ProviderContainer(overrides: [
      ew.evaluationProvider.overrideWith(_MockEvaluation.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PrayerScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Switch to the آموزش (steps) tab.
    await tester.tap(find.text('آموزش'));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> checkAllSteps(WidgetTester tester) async {
    for (final title in _prayerStepTitles) {
      final finder = find.text(title);
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  bool isPrayerDone(ProviderContainer container) {
    final state = container.read(ew.evaluationProvider).value;
    return state != null &&
        state.worshipItems.firstWhere((w) => w.id == 'prayer').done;
  }

  testWidgets('prayer checklist registers completion in today\u2019s worship',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = await pumpPrayerScreen(tester);

    expect(find.text('چک\u200cلیست قدم\u200cبه\u200cقدم نماز'), findsOneWidget);
    expect(find.text('0/14'), findsOneWidget);
    expect(isPrayerDone(container), isFalse);

    await checkAllSteps(tester);

    expect(find.text('14/14'), findsOneWidget);
    expect(find.textContaining('در طاعات امروز ثبت شد'), findsOneWidget);
    expect(isPrayerDone(container), isTrue);
  });

  testWidgets('unchecking a step unregisters prayer from worship',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = await pumpPrayerScreen(tester);

    await checkAllSteps(tester);
    expect(isPrayerDone(container), isTrue);

    await tester.ensureVisible(find.text('رکوع'));
    await tester.pump();
    await tester.tap(find.text('رکوع'));
    await tester.pumpAndSettle();

    expect(find.text('13/14'), findsOneWidget);
    expect(find.textContaining('در طاعات امروز ثبت شد'), findsNothing);
    expect(isPrayerDone(container), isFalse);
  });

  testWidgets('prayer progress is restored from saved preferences',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      // Pre-save 5 checked steps for today: indices 0..4.
      'prayer_steps_${_todayKey()}': '0,1,2,3,4',
    });
    final container = await pumpPrayerScreen(tester);

    expect(find.text('5/14'), findsOneWidget);
    expect(find.textContaining('در طاعات امروز ثبت شد'), findsNothing);
    expect(isPrayerDone(container), isFalse);
  });
}

String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}
