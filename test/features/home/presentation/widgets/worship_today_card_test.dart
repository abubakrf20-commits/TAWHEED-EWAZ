import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/home/presentation/widgets/worship_today_card.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart'
    as ew;
import 'package:tawheeed/shared/utils/number_format.dart';

class _MockEvaluation extends ew.Evaluation {
  final List<ew.WorshipItem> _items;
  final int _score;
  final int _streak;
  final List<String> addedLabels = [];
  final List<String> removedIds = [];
  final List<String> hiddenIds = [];

  _MockEvaluation({
    List<ew.WorshipItem> items = const [],
    int score = 0,
    int streak = 0,
  })  : _items = items,
        _score = score,
        _streak = streak;

  @override
  Future<ew.EvaluationState> build() async => ew.EvaluationState(
        worshipItems: _items,
        dailyScore: _score,
        currentStreak: _streak,
      );

  @override
  void addCustomWorshipItem(String label, IconData icon, int points) {
    addedLabels.add(label);
  }

  @override
  void removeCustomWorshipItem(String id) {
    removedIds.add(id);
  }

  @override
  void toggleHideDefaultItem(String id) {
    hiddenIds.add(id);
  }
}

Future<void> _pumpCardWith(WidgetTester tester, _MockEvaluation mock) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        ew.evaluationProvider.overrideWith(() => mock),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(child: WorshipTodayCard()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpCard(
  WidgetTester tester, {
  List<ew.WorshipItem> items = const [],
  int score = 0,
  int streak = 0,
}) {
  return _pumpCardWith(
    tester,
    _MockEvaluation(items: items, score: score, streak: streak),
  );
}

void main() {
  testWidgets('one row: ring percent, single-line title and count subtitle',
      (tester) async {
    await _pumpCard(
      tester,
      items: const [
        ew.WorshipItem(
            id: 'a', label: 'نماز صبح', icon: Icons.mosque, done: true),
        ew.WorshipItem(id: 'b', label: 'اذکار صبح', icon: Icons.wb_sunny),
      ],
      score: 20,
      streak: 5,
    );
    expect(find.text('طاعات روزانه'), findsOneWidget);
    expect(find.textContaining(NumberFormat.fraction(1, 2)), findsOneWidget);
    expect(find.textContaining('20'), findsOneWidget);
    // Nothing else shows: no per-item chips, no add button, no streak.
    expect(find.text('نماز صبح'), findsNothing);
    expect(find.text('اذکار صبح'), findsNothing);
    expect(find.text('افزودن طاعت جدید'), findsNothing);
    expect(find.text('روز پیوسته'), findsNothing);
    expect(find.text('5'), findsNothing);
    // …but the percent ring is there.
    expect(find.byType(RingView), findsOneWidget);
  });

  testWidgets('an empty day renders zeros without crashing', (tester) async {
    await _pumpCard(tester);
    expect(find.text('طاعات روزانه'), findsOneWidget);
    expect(find.textContaining(NumberFormat.fraction(0, 0)), findsOneWidget);
  });

  testWidgets('a fully done day turns the ring emerald', (tester) async {
    await _pumpCard(
      tester,
      items: const [
        ew.WorshipItem(
            id: 'a', label: 'نماز صبح', icon: Icons.mosque, done: true),
      ],
    );
    final ring = tester.widget<RingView>(find.byType(RingView));
    expect(ring.color, AppPalette.emerald);
  });
}
