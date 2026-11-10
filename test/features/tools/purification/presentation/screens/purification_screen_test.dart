import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/tools/purification/presentation/screens/purification_screen.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart'
    as ew;

/// A mock Evaluation that flips worship items on toggle — lets the test
/// verify the purification checklists sync completion into today's worship
/// without booting the full (database-backed) provider graph.
class _MockEvaluation extends ew.Evaluation {
  @override
  Future<ew.EvaluationState> build() async => ew.EvaluationState(
        worshipItems: [
          const ew.WorshipItem(
              id: 'quran',
              label: 'قرائت قرآن',
              icon: Icons.menu_book,
              points: 15),
          const ew.WorshipItem(
              id: 'wudu', label: 'وضو', icon: Icons.clean_hands),
          const ew.WorshipItem(id: 'ghusl', label: 'غسل', icon: Icons.shower),
          const ew.WorshipItem(
              id: 'tayammum', label: 'تیمم', icon: Icons.back_hand),
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

const List<String> _wuduStepTitles = [
  'نیت وضو',
  'شستن کف دست\u200cها',
  'مضمضه',
  'استنشاق',
  'شستن صورت',
  'شستن دست\u200cها تا آرنج',
  'مسح سر',
  'مسح گوش\u200cها',
  'شستن پاها تا مچ',
  'رعایت ترتیب',
];

const List<String> _ghuslStepTitles = [
  'نیت غسل',
  'تسمیه',
  'شستن دست\u200cها قبل از ورود',
  'مضمضه و استنشاق',
  'تخلیل مو',
  'شستن تمام بدن',
  'مسح بدن با دست',
];

const List<String> _tayammumStepTitles = [
  'نیت تیمم',
  'ضربه اول بر خاک پاک',
  'مسح تمام صورت',
  'ضربه دوم بر خاک پاک',
  'مسح دست راست و چپ',
  'رعایت ترتیب',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pumpPurificationScreen(WidgetTester tester) async {
    final container = ProviderContainer(overrides: [
      ew.evaluationProvider.overrideWith(_MockEvaluation.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PurificationScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  Future<void> openTab(WidgetTester tester, String tab) async {
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();
  }

  Future<void> checkAllSteps(WidgetTester tester, List<String> titles) async {
    for (final title in titles) {
      final finder = find.text(title);
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  bool isWorshipDone(ProviderContainer container, String id) {
    final state = container.read(ew.evaluationProvider).value;
    return state != null &&
        state.worshipItems.firstWhere((w) => w.id == id).done;
  }

  testWidgets('wudu checklist registers completion in today\u2019s worship',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = await pumpPurificationScreen(tester);
    await openTab(tester, 'وضو');

    expect(find.text('چک\u200cلیست قدم\u200cبه\u200cقدم وضو'), findsOneWidget);
    expect(find.text('0/10'), findsOneWidget);
    expect(isWorshipDone(container, 'wudu'), isFalse);

    await checkAllSteps(tester, _wuduStepTitles);

    expect(find.text('10/10'), findsOneWidget);
    expect(find.textContaining('در طاعات امروز ثبت شد'), findsOneWidget);
    expect(isWorshipDone(container, 'wudu'), isTrue);
  });

  testWidgets('unchecking a step unregisters wudu from worship',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = await pumpPurificationScreen(tester);
    await openTab(tester, 'وضو');

    await checkAllSteps(tester, _wuduStepTitles);
    expect(isWorshipDone(container, 'wudu'), isTrue);

    await tester.ensureVisible(find.text('مضمضه'));
    await tester.pump();
    await tester.tap(find.text('مضمضه'));
    await tester.pumpAndSettle();

    expect(find.text('9/10'), findsOneWidget);
    expect(find.textContaining('در طاعات امروز ثبت شد'), findsNothing);
    expect(isWorshipDone(container, 'wudu'), isFalse);
  });

  testWidgets('progress is restored from saved preferences', (tester) async {
    SharedPreferences.setMockInitialValues({
      // Pre-save 3 checked steps for today: indices 0,1,2.
      'wudu_steps_${_todayKey()}': '0,1,2',
    });
    final container = await pumpPurificationScreen(tester);
    await openTab(tester, 'وضو');

    expect(find.text('3/10'), findsOneWidget);
    expect(find.textContaining('در طاعات امروز ثبت شد'), findsNothing);
    expect(isWorshipDone(container, 'wudu'), isFalse);
  });

  testWidgets('ghusl checklist registers completion in today\u2019s worship',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = await pumpPurificationScreen(tester);
    await openTab(tester, 'غسل');

    expect(find.text('چک\u200cلیست قدم\u200cبه\u200cقدم غسل'), findsOneWidget);
    expect(find.text('0/7'), findsOneWidget);
    expect(isWorshipDone(container, 'ghusl'), isFalse);

    await checkAllSteps(tester, _ghuslStepTitles);

    expect(find.text('7/7'), findsOneWidget);
    expect(find.textContaining('در طاعات امروز ثبت شد'), findsOneWidget);
    expect(isWorshipDone(container, 'ghusl'), isTrue);
  });

  testWidgets('unchecking a ghusl step unregisters it from worship',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = await pumpPurificationScreen(tester);
    await openTab(tester, 'غسل');

    await checkAllSteps(tester, _ghuslStepTitles);
    expect(isWorshipDone(container, 'ghusl'), isTrue);

    await tester.ensureVisible(find.text('تخلیل مو'));
    await tester.pump();
    await tester.tap(find.text('تخلیل مو'));
    await tester.pumpAndSettle();

    expect(find.text('6/7'), findsOneWidget);
    expect(isWorshipDone(container, 'ghusl'), isFalse);
  });

  testWidgets('tayammum checklist registers completion in today\u2019s worship',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = await pumpPurificationScreen(tester);
    await openTab(tester, 'تیمم');

    expect(find.text('چک\u200cلیست قدم\u200cبه\u200cقدم تیمم'), findsOneWidget);
    expect(find.text('0/6'), findsOneWidget);
    expect(isWorshipDone(container, 'tayammum'), isFalse);

    await checkAllSteps(tester, _tayammumStepTitles);

    expect(find.text('6/6'), findsOneWidget);
    expect(find.textContaining('در طاعات امروز ثبت شد'), findsOneWidget);
    expect(isWorshipDone(container, 'tayammum'), isTrue);
  });

  testWidgets('ghusl progress uses its own storage key', (tester) async {
    SharedPreferences.setMockInitialValues({
      // Pre-save 2 checked ghusl steps for today — must not leak from wudu.
      'ghusl_steps_${_todayKey()}': '0,1',
    });
    final container = await pumpPurificationScreen(tester);
    await openTab(tester, 'غسل');

    expect(find.text('2/7'), findsOneWidget);
    expect(isWorshipDone(container, 'ghusl'), isFalse);
  });
}

String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}
