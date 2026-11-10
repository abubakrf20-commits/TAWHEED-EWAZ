import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/checklist/presentation/screens/worship_checklist_screen.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart'
    as ew;

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
              id: 'salawat', label: 'صلوات', icon: Icons.star, done: true),
        ],
        dailyScore: 10,
        currentStreak: 3,
      );

  @override
  void toggleWorship(String id) {}

  @override
  void addCustomWorshipItem(String label, IconData icon, int points) {}

  @override
  void removeCustomWorshipItem(String id) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('WorshipChecklistScreen renders hero header and checklist',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ew.evaluationProvider.overrideWith(_MockEvaluation.new),
        ],
        child: const MaterialApp(home: WorshipChecklistScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(WorshipChecklistScreen), findsOneWidget);
    expect(find.text('طاعات روزانه'), findsWidgets);
    expect(find.text('قرائت قرآن'), findsOneWidget);
    expect(find.text('صلوات'), findsOneWidget);
  });

  testWidgets('the taharat/evaluation shortcut rows are gone', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ew.evaluationProvider.overrideWith(_MockEvaluation.new),
        ],
        child: const MaterialApp(home: WorshipChecklistScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Deleted 2026-10-13 per the user's request — purification lives in More
    // and the ارزیابی tab is one tab away, so neither row may come back.
    expect(find.text('راهنمای طهارت'), findsNothing);
    expect(find.text('گام‌به‌گام وضو، غسل و تیمم — با تیک هر مرحله'), findsNothing);
    expect(find.text('ارزیابی و گزارش'), findsNothing);
    expect(find.text('امتیاز هفتگی و ماهانه‌ات را ببین'), findsNothing);
  });
}
