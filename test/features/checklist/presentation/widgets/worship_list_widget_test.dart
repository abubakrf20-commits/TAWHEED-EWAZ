import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/checklist/presentation/widgets/worship_list_widget.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart'
    as ew;

class _MockEvaluation extends ew.Evaluation {
  @override
  Future<ew.EvaluationState> build() async => ew.EvaluationState(
        worshipItems: [
          const ew.WorshipItem(
              id: 'quran', label: 'Quran', icon: Icons.menu_book, points: 15),
          const ew.WorshipItem(
              id: 'sadaqa',
              label: 'Sadaqa',
              icon: Icons.favorite,
              points: 20,
              done: true),
        ],
      );

  @override
  void toggleWorship(String id) {}

  @override
  void addCustomWorshipItem(String label, IconData icon, int points) {}

  @override
  void removeCustomWorshipItem(String id) {}
}

void main() {
  testWidgets('WorshipListWidget renders worship items', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ew.evaluationProvider.overrideWith(_MockEvaluation.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: WorshipListWidget()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(WorshipListWidget), findsOneWidget);
    expect(find.text('Quran'), findsOneWidget);
    expect(find.text('Sadaqa'), findsOneWidget);
  });
}
