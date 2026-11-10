import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/adhkar/data/daos/azkar_status_dao.dart';
import 'package:tawheeed/features/prayer/data/daos/period_record_dao.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_tracker_provider.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart'
    as ew;
import 'package:tawheeed/features/worship/presentation/widgets/evaluation_stats_widget.dart';

import '../../../../core/database/mock_daos.dart';

/// The evaluation page's period switch (روزانه / هفتگی / ماهانه) must stay a
/// body swap: the tab's `setState` rebuilds the new body in place, and nothing
/// outside the body — the page shell, the segmented chrome — is rebuilt more
/// than the one time the new state demands.
///
/// Measured at `dd128b0` on a 360×1600 surface (debug/JIT, so the wall clock is
/// not a budget): day→week rebuilt 132 elements, week→day 113, day→month 385.
/// The two fixed points are the composition itself — one `Table` for the
/// eight-cell ring grid and nine `RingView`s (eight cells + the score hero) —
/// so the ceiling below only catches the page regressing to a whole-tree
/// rebuild, not a wall-clock flake.
///
/// The same file sweeps the three tabs at 320/360/412 dp with the bundled
/// Persian face, up to text scale 1.8 — `AppTextScale.maxScale`, the reachable
/// ceiling. The monthly tab's month selector used to overflow there: at 320 dp
/// × 1.8 its label Row measured 147×38 with the text's right edge at 150.3 px,
/// a 3.3 px overhang past the card (`dd128b0`). It is now capped at the Row
/// level with `Flexible(FittedBox(scaleDown))` — the `SectionHeader` recipe; a
/// `Flexible` nested inside the label can never bound it. Post-fix all three
/// tabs are clean at every width and scale below, and a one-time probe of the
/// four selectable faces (Calibri, Vazirmatn, TKT-Tika, Harir) at 320/360 dp ×
/// 1.8 was clean 24/24.
///
/// The sweep asserts *layout geometry*, not `takeException()`: that call
/// returned null for the 3.3 px overhang above, so an exception-based guard
/// could never bite. The heatmap header is clean at 1.8 with a real face — do
/// not re-fix it on the strength of a test-font reading.
class _MockEvaluation extends ew.Evaluation {
  @override
  Future<ew.EvaluationState> build() async => ew.EvaluationState(
        worshipItems: [
          const ew.WorshipItem(
              id: 'quran',
              label: 'Quran',
              icon: Icons.menu_book,
              points: 15,
              done: true),
          const ew.WorshipItem(
              id: 'sadaqa', label: 'Sadaqa', icon: Icons.favorite, points: 20),
        ],
        dailyScore: 35,
        todayCompleted: 1,
      );

  @override
  String generateMonthlyReport() => 'Monthly Report';

  @override
  int countFastingDaysInMonth(int year, int month) => 0;

  @override
  int countFastingDaysInWeek() => 0;

  @override
  void toggleWorship(String id) {}
}

class _MockPrayerTracker extends PrayerTracker {
  @override
  Future<PrayerTrackerState> build() async => const PrayerTrackerState();

  @override
  PrayerStatus getStatus(FardhPrayer prayer) => PrayerStatus.pending;

  @override
  void toggleSunnah(SunnahPrayer prayer) {}
}

class _MockSettings extends Settings {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

Future<void> _loadVazirmatn() async {
  final loader = FontLoader('Vazirmatn')
    ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
  await loader.load();
}

Future<void> _pumpPage(
  WidgetTester tester, {
  double width = 360,
  double textScale = 1.0,
}) async {
  AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
  await tester.binding.setSurfaceSize(Size(width, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ew.evaluationProvider.overrideWith(_MockEvaluation.new),
        prayerTrackerProvider.overrideWith(_MockPrayerTracker.new),
        settingsProvider.overrideWith(_MockSettings.new),
        periodRecordDaoProvider.overrideWithValue(MockPeriodRecordDao()),
        azkarStatusDaoProvider.overrideWithValue(MockAzkarStatusDao()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: EvaluationStatsWidget()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  // Grow the viewport to the page's own measured height so a cell below the
  // fold is laid out (a lazy list never reports an overflow it never built).
  final pos =
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  final content = pos.maxScrollExtent + pos.viewportDimension;
  await tester.binding.setSurfaceSize(Size(width, content + 40));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Every flex child laid out past its flex's own box — the layout truth of an
/// overflow. `tester.takeException()` returned null for the 3.3 px overhang
/// this file guards, so the sweep reads geometry instead of the error channel.
List<String> _flexOverflows(WidgetTester tester) {
  final found = <String>[];
  void scan(RenderObject node) {
    if (node is RenderFlex) {
      RenderBox? child = node.firstChild;
      while (child != null) {
        final data = child.parentData! as FlexParentData;
        final right = data.offset.dx + child.size.width;
        final bottom = data.offset.dy + child.size.height;
        if (right > node.size.width + 0.01 ||
            bottom > node.size.height + 0.01) {
          found.add('RenderFlex ${node.size.width.toStringAsFixed(1)}×'
              '${node.size.height.toStringAsFixed(1)}: child at '
              '(${data.offset.dx.toStringAsFixed(1)}, '
              '${data.offset.dy.toStringAsFixed(1)}) size '
              '${child.size.width.toStringAsFixed(1)}×'
              '${child.size.height.toStringAsFixed(1)}');
        }
        child = data.nextSibling;
      }
    }
    node.visitChildren(scan);
  }

  for (final view in tester.binding.renderViews) {
    scan(view);
  }
  return found;
}

void main() {
  testWidgets('a period switch rebuilds the new body, not the page around it',
      (tester) async {
    await _pumpPage(tester);

    final counts = <Type, int>{};
    var total = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      total++;
      final type = element.widget.runtimeType;
      counts[type] = (counts[type] ?? 0) + 1;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    await tester.tap(find.text('هفتگی'));
    await tester.pump();

    // The page reacts once, the chrome repaints once, and the new body is the
    // only content that rebuilds — in place, at the ring grid it shares with
    // the day tab. (`Table` is a RenderObjectWidget, so the debug hook — which
    // only sees component elements — cannot count it; `RingView` covers the
    // grid: eight cells + the score hero.)
    expect(counts[EvaluationStatsWidget], 1);
    expect(counts[SegmentedTabs], 1);
    expect(counts[HeroCardShell], 1);
    expect(counts[RingView], 9,
        reason: 'eight ring cells + the score hero; a missing one means the '
            'body stopped building in place');
    expect(counts[BarChart], 1);
    expect(total, lessThan(300),
        reason: 'day→week rebuilt $total elements at dd128b0 (measured 132); '
            'this ceiling only catches a whole-page rebuild');

    debugOnRebuildDirtyWidget = null;
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // Re-tapping the already-selected tab is a no-op, not a page rebuild.
    final again = <Type, int>{};
    var againTotal = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      againTotal++;
      final type = element.widget.runtimeType;
      again[type] = (again[type] ?? 0) + 1;
    };
    await tester.tap(find.text('هفتگی'));
    await tester.pump();
    debugOnRebuildDirtyWidget = null;

    expect(again[EvaluationStatsWidget], isNull);
    expect(again[SegmentedTabs], isNull);
    expect(againTotal, lessThan(30),
        reason: 'tapping the active tab rebuilt $againTotal elements');
  });

  for (final width in <double>[320, 360, 412]) {
    for (final scale in <double>[1.0, 1.3, 1.8]) {
      testWidgets(
          'no overflow in any evaluation tab — '
          'Vazirmatn ${width.toInt()}dp ×$scale', (tester) async {
        await _loadVazirmatn();
        AppTheme.fontFamily = 'Vazirmatn';
        addTearDown(() => AppTheme.fontFamily = AppTheme.defaultFontFamily);

        await _pumpPage(tester, width: width, textScale: scale);
        expect(_flexOverflows(tester), isEmpty,
            reason: 'the daily tab overflowed at ${width.toInt()}dp ×$scale');

        await _openTab(tester, 'هفتگی');
        expect(_flexOverflows(tester), isEmpty,
            reason: 'the weekly tab overflowed at ${width.toInt()}dp ×$scale');

        await _openTab(tester, 'ماهانه');
        expect(_flexOverflows(tester), isEmpty,
            reason: 'the monthly tab overflowed at ${width.toInt()}dp ×$scale');
      });
    }
  }
}
