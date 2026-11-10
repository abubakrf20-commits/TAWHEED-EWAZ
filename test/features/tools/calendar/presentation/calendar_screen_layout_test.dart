import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart'
    as ew;
import 'package:tawheeed/features/tools/calendar/presentation/screens/calendar_screen.dart';
import 'package:tawheeed/features/tools/calendar/presentation/widgets/calendar_widgets.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

import '../../../../core/database/mock_daos.dart';

/// The calendar page as a whole, at the sizes the design has to survive.
///
/// The hero is the risky one: its top Row hands its children an unbounded
/// width, so a chip there only caps when the ROW wraps it in Flexible. These
/// tests pump the real page (not the widget in isolation) at 320dp and at the
/// 1.3 text scale, which is where that mistake turns into a yellow stripe.
///
/// `nowOverride` freezes «today»: the grid marks it, the hero names it and the
/// countdown counts to it, so the assertions below never depend on the wall
/// clock.
class _MockEvaluation extends ew.Evaluation {
  @override
  Future<ew.EvaluationState> build() async => ew.EvaluationState();

  @override
  int? getScoreForDate(DateTime date) => null;

  @override
  bool isWorshipDoneOnDate(String worshipId, DateTime date) => false;
}

Widget _app(double textScale) {
  final base = AppTheme.light.textTheme;
  final theme = textScale == 1
      ? AppTheme.light
      : AppTheme.light.copyWith(
          textTheme: base.copyWith(
            bodyMedium: base.bodyMedium
                ?.copyWith(fontSize: base.bodyMedium!.fontSize! * textScale),
          ),
        );
  return MaterialApp(
    theme: theme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: CalendarScreen(nowOverride: DateTime(2026, 10, 9)),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
}) async {
  AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final mockRepo = MockSettingsRepository();
  mockRepo.setMockSettings(const AppSettings());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
        ew.evaluationProvider.overrideWith(_MockEvaluation.new),
      ],
      child: _app(textScale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the page renders without overflow at 320dp', (tester) async {
    await _pump(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the page renders without overflow at 320dp and scale 1.3',
      (tester) async {
    await _pump(tester, size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the hero prints the selected day in three calendars',
      (tester) async {
    await _pump(tester, size: const Size(360, 720));

    final today = Jalali.fromDateTime(DateTime(2026, 10, 9));
    // Each of the three readings appears once, in the hero, and carries the
    // month number («9 اکتبر (10) 2026») — the selected-day box no longer
    // repeats them. The month number is derived through the same LTR-isolate
    // helper the widget uses, so the invisible marks compare equal.
    final jalali =
        '${today.day} ${DateConstants.persianMonths[today.month - 1]} '
        '${NumberFormat.ltrIsolated('(${today.month})')} ${today.year}';
    final h = HijriUtils.hijriFromGreg(2026, 10, 9,
        offset: const AppSettings().hijriOffset);
    final hijri = '${h.day} ${DateConstants.hijriMonths[h.month - 1]} '
        '${NumberFormat.ltrIsolated('(${h.month})')} ${h.year}';
    final gregorian = '9 ${DateConstants.gregorianMonths[9]} '
        '${NumberFormat.ltrIsolated('(10)')} 2026';
    expect(find.text(jalali), findsOneWidget);
    expect(find.text(hijri), findsOneWidget);
    expect(find.text(gregorian), findsOneWidget);
    // Month navigation, the jump sheet and the occasion countdown are all here.
    // Scoped to the hero: the selected-day box carries a second `OutlineChip`
    // now (the converter, reachable after the header has scrolled away), and
    // an unscoped count would make this assertion about the wrong widget.
    expect(
      find.descendant(
        of: find.byType(CalendarMonthHeader),
        matching: find.byType(OutlineChip),
      ),
      findsOneWidget,
    );
    expect(find.text('پرش'), findsOneWidget);
    expect(find.byType(GlassChip), findsWidgets);
  });

  testWidgets('the grid prints the Persian week, Saturday first',
      (tester) async {
    await _pump(tester, size: const Size(360, 720));
    for (final letter in kWeekdayLetters) {
      expect(find.text(letter), findsWidgets, reason: 'header $letter');
    }
    expect(find.byType(CalendarDayCell), findsAtLeastNWidgets(28));
  });

  testWidgets('tapping a day moves the whole page to it', (tester) async {
    await _pump(tester, size: const Size(360, 720));

    final today = Jalali.fromDateTime(DateTime(2026, 10, 9));
    const targetDay = 20;
    final cells = tester
        .widgetList<CalendarDayCell>(find.byType(CalendarDayCell))
        .toList();
    final cell = cells.firstWhere((c) => c.cell.day == targetDay);
    await tester.tap(find.byWidget(cell));
    await tester.pumpAndSettle();

    // The hero title follows the tap (the box keeps only occasions/worship,
    // so the hero is the single place the Jalali date is printed).
    final selected =
        '$targetDay ${DateConstants.persianMonths[today.month - 1]} '
        '${NumberFormat.ltrIsolated('(${today.month})')} ${today.year}';
    expect(find.text(selected), findsOneWidget);
    expect(find.byType(SelectedDateSummary), findsOneWidget);
  });
}
