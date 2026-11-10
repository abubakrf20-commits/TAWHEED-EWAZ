import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart'
    as ew;
import 'package:tawheeed/features/tools/calendar/data/day_journal_service.dart';
import 'package:tawheeed/features/tools/calendar/presentation/screens/calendar_screen.dart';
import 'package:tawheeed/features/tools/calendar/presentation/widgets/calendar_widgets.dart';

import '../../../../core/database/mock_daos.dart';

class _MockEvaluation extends ew.Evaluation {
  @override
  Future<ew.EvaluationState> build() async => ew.EvaluationState();

  @override
  int? getScoreForDate(DateTime date) => null;

  @override
  bool isWorshipDoneOnDate(String worshipId, DateTime date) => false;
}

Finder _cell(int day) => find.byWidgetPredicate(
      (w) => w is CalendarDayCell && w.cell.day == day,
    );

bool _isSelected(WidgetTester tester, int day) =>
    tester.widget<CalendarDayCell>(_cell(day)).selected;

Future<void> _pumpPage(WidgetTester tester) async {
  AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(360, 1500));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final mockRepo = MockSettingsRepository();
  mockRepo.setMockSettings(const AppSettings());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
        ew.evaluationProvider.overrideWith(_MockEvaluation.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: CalendarScreen(nowOverride: DateTime(2026, 10, 9)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // At HEAD (1a1651d) one day-cell tap rebuilt 563 elements in 93,292 us: the
  // whole page, all 30 CalendarDayCell included, because the selection lived in
  // a `setState` field. Now the grid listens to a ValueListenable and only the
  // two cells whose flag flipped repaint, next to the three blocks that print
  // the selected day; measured 214.
  testWidgets('a day tap repaints the two cells and the selection blocks only',
      (tester) async {
    await _pumpPage(tester);
    final today = Jalali.fromDateTime(DateTime(2026, 10, 9));
    expect(_isSelected(tester, today.day), isTrue,
        reason: 'the page opens on today');

    final counts = <Type, int>{};
    var total = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      total++;
      final type = element.widget.runtimeType;
      counts[type] = (counts[type] ?? 0) + 1;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    await tester.tap(_cell(20));
    await tester.pump();

    expect(_isSelected(tester, 20), isTrue);
    expect(_isSelected(tester, today.day), isFalse);

    // The grid, the month list and the page chrome carry no selection, so they
    // must not be touched at all.
    expect(counts[CalendarDayCell], 2,
        reason: 'exactly the deselected and the newly selected cell');
    expect(counts[CalendarMonthGrid], isNull);
    expect(counts[MonthlyEventsSection], isNull);
    expect(counts[SectionShell], isNull);
    expect(total, lessThan(300),
        reason: 'HEAD rebuilt 563 elements for this tap');
  });

  testWidgets('the selection blocks read the newly tapped day', (tester) async {
    await _pumpPage(tester);
    final today = Jalali.fromDateTime(DateTime(2026, 10, 9));
    final expected = Jalali(today.year, today.month, 20).toDateTime();

    await tester.tap(_cell(20));
    await tester.pump();

    expect(
        tester
            .widget<SelectedDateSummary>(find.byType(SelectedDateSummary))
            .date,
        expected);
    expect(
      tester.widget<DayJournalSection>(find.byType(DayJournalSection)).dateKey,
      DayJournalService.dateKey(expected),
    );
  });

  testWidgets('tapping the already selected day paints nothing',
      (tester) async {
    await _pumpPage(tester);
    final today = Jalali.fromDateTime(DateTime(2026, 10, 9));

    final counts = <Type, int>{};
    var total = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      total++;
      final type = element.widget.runtimeType;
      counts[type] = (counts[type] ?? 0) + 1;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    await tester.tap(_cell(today.day));
    await tester.pump();

    expect(total, 0, reason: 'publishing the same selection is a no-op');
    expect(counts, isEmpty);
  });
}
