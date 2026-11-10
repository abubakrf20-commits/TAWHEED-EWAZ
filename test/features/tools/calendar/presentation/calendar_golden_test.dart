import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart'
    as ew;
import 'package:tawheeed/features/tools/calendar/domain/day_journal_entry.dart';
import 'package:tawheeed/features/tools/calendar/presentation/providers/day_journal_provider.dart';
import 'package:tawheeed/features/tools/calendar/data/day_journal_service.dart';
import 'package:tawheeed/features/tools/calendar/presentation/screens/calendar_screen.dart';
import 'package:tawheeed/features/tools/date_converter/presentation/screens/date_converter_screen.dart';

import '../../../../core/database/mock_daos.dart';

/// Visual baselines for the redesigned calendar: the page under each of the
/// four pinned ThemeKinds, the same page at the narrow 320dp, and the
/// converter it now hands its dates to.
///
/// «Today» is frozen (2026-10-9), so the grid marker, the hero, the countdown
/// and the journal key all land on the same day in every run. The evaluation
/// and the journal are faked WITH content on purpose: a baseline of an empty
/// section proves nothing about the section.
class _MockEvaluation extends ew.Evaluation {
  @override
  Future<ew.EvaluationState> build() async => ew.EvaluationState();

  @override
  int? getScoreForDate(DateTime date) => date.day == 9 ? 3 : null;

  @override
  bool isWorshipDoneOnDate(String worshipId, DateTime date) =>
      worshipId == 'fasting' && date.day == 9;
}

class _FakeJournal extends DayJournalNotifier {
  @override
  Future<Map<String, List<DayJournalEntry>>> build() async => {
        DayJournalService.dateKey(DateTime(2026, 10, 9)): [
          DayJournalEntry(
              id: '1',
              kind: DayJournalKind.task,
              text: 'ختم جزء ۳۰',
              done: true,
              createdAt: DateTime(2026, 10, 9)),
          DayJournalEntry(
              id: '2',
              kind: DayJournalKind.memory,
              text: 'یادآوری: تماس با استاد',
              createdAt: DateTime(2026, 10, 9)),
        ]
      };

  @override
  Future<void> toggleDone(String dateKey, String id) async {}

  @override
  Future<void> remove(String dateKey, String id) async {}

  @override
  Future<bool> add(String dateKey, DayJournalKind kind, String text) async =>
      true;
}

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.light,
      home: Directionality(textDirection: TextDirection.rtl, child: home),
    );

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required ThemeKind kind,
  required Widget home,
}) async {
  AppTheme.applyTheme(
      kind: kind,
      phase: kind == ThemeKind.night ? TimePhase.night : TimePhase.day);
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final mockRepo = MockSettingsRepository();
  mockRepo.setMockSettings(const AppSettings());

  await tester.pumpWidget(ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
      ew.evaluationProvider.overrideWith(_MockEvaluation.new),
      dayJournalProvider.overrideWith(_FakeJournal.new),
    ],
    child: _app(home),
  ));
  await tester.pumpAndSettle();
}

/// 30 October 2026 — a Friday whose Hijri reading lands mid-month, so a row
/// that drifted by a day would show it.
const _converter = DateConverterScreen(
  initialGregorianDay: 30,
  initialGregorianMonth: 10,
  initialGregorianYear: 2026,
  hijriOffset: 2,
);

void main() {
  for (final kind in [
    ThemeKind.dawn,
    ThemeKind.day,
    ThemeKind.sunset,
    ThemeKind.night,
  ]) {
    testWidgets('the calendar page, $kind', (tester) async {
      await _pump(
        tester,
        size: const Size(360, 1340),
        kind: kind,
        home: CalendarScreen(nowOverride: DateTime(2026, 10, 9)),
      );
      await expectLater(
        find.byType(CalendarScreen),
        matchesGoldenFile('goldens/calendar_page_${kind.name}.png'),
      );
    });
  }

  testWidgets('the calendar page at 320dp', (tester) async {
    await _pump(
      tester,
      size: const Size(320, 1340),
      kind: ThemeKind.day,
      home: CalendarScreen(nowOverride: DateTime(2026, 10, 9)),
    );
    await expectLater(
      find.byType(CalendarScreen),
      matchesGoldenFile('goldens/calendar_page_320.png'),
    );
  });

  for (final kind in [ThemeKind.day, ThemeKind.night]) {
    testWidgets('the converter page, $kind', (tester) async {
      await _pump(
        tester,
        size: const Size(360, 600),
        kind: kind,
        home: _converter,
      );
      await expectLater(
        find.byType(DateConverterScreen),
        matchesGoldenFile('goldens/converter_page_${kind.name}.png'),
      );
    });
  }
}
