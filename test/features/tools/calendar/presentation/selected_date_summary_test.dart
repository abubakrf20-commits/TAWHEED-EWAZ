import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart'
    as ew;
import 'package:tawheeed/features/tools/calendar/presentation/widgets/calendar_widgets.dart';

/// The day selected under the grid.
///
/// Two things are pinned here. First what the box must NOT contain: it used to
/// push the converter through `Navigator.push` (which left the router and with
/// it the `AmbientBackground`, painting the window black) and later carried a
/// converter chip of its own — both are gone, the app bar's one action is the
/// only entry, and the box owns no navigation and no date rows (the hero above
/// the grid prints the three calendar readings). Second the box's own
/// behaviour — one occasion table shared with the month list, and a fasting
/// control that really reaches the service.
class _MockEvaluation extends ew.Evaluation {
  _MockEvaluation({this.score, this.fasting = false});

  final int? score;
  final bool fasting;
  final List<String> taps = [];

  @override
  Future<ew.EvaluationState> build() async => ew.EvaluationState();

  @override
  int? getScoreForDate(DateTime date) => score;

  @override
  bool isWorshipDoneOnDate(String worshipId, DateTime date) =>
      worshipId == 'fasting' && fasting;

  @override
  void toggleWorshipForDate(String worshipId, DateTime date) =>
      taps.add('$worshipId@${date.toIso8601String()}');
}

Widget _box(SelectedDateSummary box) => MaterialApp(
      theme: AppTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: box)),
      ),
    );

/// Executable lines only — the guard below is about code that runs, and this
/// feature documents the removed entry in its own comments.
String _withoutComments(String source) => source.split('\n').map((line) {
      final comment = line.indexOf('//');
      return comment < 0 ? line : line.substring(0, comment);
    }).join('\n');

/// The selected day everywhere below: 30 October 2026, a Friday.
SelectedDateSummary _selected({
  List<String> events = const [],
  bool isToday = false,
}) {
  return SelectedDateSummary(
    date: DateTime(2026, 10, 30),
    dayName: 'جمعه',
    events: events,
    isToday: isToday,
  );
}

void main() {
  setUpAll(
      () => AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day));

  group('converter entry — only the app bar route is allowed', () {
    test('the calendar never pushes a screen by itself', () {
      final offenders = <String>[];
      for (final file in Directory('lib/features/tools/calendar')
          .listSync(recursive: true)
          .whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final code = _withoutComments(file.readAsStringSync());
        if (code.contains('Navigator.push') ||
            code.contains('DateConverterScreen')) {
          offenders.add(file.path);
        }
      }
      // A raw Navigator.push escapes go_router, and with it the
      // AmbientBackground wrapper — that is exactly how the black page happened.
      expect(offenders, isEmpty,
          reason:
              'calendar files must reach the converter through context.push');
    });

    test('the app bar keeps the one working entry', () {
      final screen = File(
        'lib/features/tools/calendar/presentation/screens/calendar_screen.dart',
      ).readAsStringSync();
      expect(screen, contains('context.push'));
      expect(screen, contains('RouteNames.dateConverter'));
      expect(screen, contains('مبدل تاریخ'));
    });
  });

  group('selected day box', () {
    testWidgets('carries no date rows — the hero owns the three calendars',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ew.evaluationProvider.overrideWith(_MockEvaluation.new),
          ],
          child: _box(_selected()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('جمعه'), findsOneWidget);
      // The duplicated readings are gone: the hero above the grid prints the
      // selected day in all three calendars, so the box must not repeat them.
      expect(find.text('شمسی'), findsNothing);
      expect(find.text('هجری'), findsNothing);
      expect(find.text('میلادی'), findsNothing);
      // No callback, no entry: the box never invents a navigation of its own.
      expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
    });

    testWidgets('marks the selected day when it is today', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ew.evaluationProvider.overrideWith(_MockEvaluation.new),
          ],
          child: _box(_selected(isToday: true)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('امروز'), findsOneWidget);
    });

    testWidgets('an ordinary selected day carries no today badge',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ew.evaluationProvider.overrideWith(_MockEvaluation.new),
          ],
          child: _box(_selected()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('امروز'), findsNothing);
    });

    testWidgets('occasions take the shared table, not a gold/emerald guess',
        (tester) async {
      const labels = ['روزه عاشورا (سنت)', 'عید غدیر', 'یلدا'];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ew.evaluationProvider.overrideWith(_MockEvaluation.new),
          ],
          child: _box(_selected(events: labels)),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }
      // Each chip is filled with its own family hue at chip alpha.
      final styles = labels.map(CalendarOccasionStyle.of).toList();
      expect(styles[0].hue, CalendarHues.fasting);
      expect(styles[1].hue, CalendarHues.fasting);
      expect(styles[2].hue, isNot(CalendarHues.fasting));
      expect(styles[2].icon, Icons.nights_stay);
    });

    testWidgets('shows the score of a day that already has worship',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ew.evaluationProvider
                .overrideWith(() => _MockEvaluation(score: 12)),
          ],
          child: _box(_selected()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('طاعات: 12 امتیاز'), findsOneWidget);
    });

    testWidgets('a recorded fast reads as recorded', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ew.evaluationProvider
                .overrideWith(() => _MockEvaluation(fasting: true)),
          ],
          child: _box(_selected()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ثبت شد'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('the fasting row is a real, reachable control', (tester) async {
      final eval = _MockEvaluation();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ew.evaluationProvider.overrideWith(() => eval),
          ],
          child: _box(_selected()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('روزه این روز'));
      await tester.pumpAndSettle();

      // The tap must land on 30 October 2026 at midnight, not on today.
      expect(eval.taps, ['fasting@2026-10-30T00:00:00.000']);
    });

    testWidgets('the fasting row keeps a 48dp touch target', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ew.evaluationProvider.overrideWith(_MockEvaluation.new),
          ],
          child: _box(_selected()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(FastingToggle)).height,
          greaterThanOrEqualTo(48));
    });
  });
}
