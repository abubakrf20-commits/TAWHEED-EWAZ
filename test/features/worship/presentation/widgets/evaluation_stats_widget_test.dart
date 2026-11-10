import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/worship/presentation/widgets/evaluation_stats_widget.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart'
    as ew;
import 'package:tawheeed/features/adhkar/data/daos/azkar_status_dao.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_tracker_provider.dart';
import 'package:tawheeed/features/prayer/data/daos/period_record_dao.dart';
import '../../../../core/database/mock_daos.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';

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

void main() {
  Future<void> pumpReport(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ew.evaluationProvider.overrideWith(_MockEvaluation.new),
          prayerTrackerProvider.overrideWith(_MockPrayerTracker.new),
          settingsProvider.overrideWith(_MockSettings.new),
          periodRecordDaoProvider.overrideWithValue(MockPeriodRecordDao()),
          azkarStatusDaoProvider.overrideWithValue(MockAzkarStatusDao()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: EvaluationStatsWidget()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('EvaluationStatsWidget renders stats', (tester) async {
    await pumpReport(tester);
    expect(find.byType(EvaluationStatsWidget), findsOneWidget);
  });

  testWidgets('weekly and monthly tabs render their charts', (tester) async {
    await pumpReport(tester);

    await tester.tap(find.text('هفتگی'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.byType(EvaluationStatsWidget), findsOneWidget);

    await tester.tap(find.text('ماهانه'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.byType(EvaluationStatsWidget), findsOneWidget);
  });

  testWidgets('the score hero is a full circle, not the old arc rail',
      (tester) async {
    await pumpReport(tester);

    final hero = find.ancestor(
      of: find.text('امتیاز امروز'),
      matching: find.byType(HeroCardShell),
    );
    final ring = find.descendant(of: hero, matching: find.byType(RingView));
    expect(ring, findsOneWidget);

    // The arc needed a 306/92 letterbox to sit in; a circle does not, and a
    // leftover AspectRatio here means the old composition came back.
    expect(find.descendant(of: hero, matching: find.byType(AspectRatio)),
        findsNothing);

    final view = tester.widget<RingView>(ring);
    expect(tester.getRect(ring).size, const Size(132, 132));
    expect(view.progress, greaterThan(0));
    expect(view.color, AppPalette.heroGold);
    expect(view.trackColor, Colors.white.withValues(alpha: .20));
    expect(view.semanticLabel, isNotNull);
    expect(tester.takeException(), isNull);

    // The verdict sits UNDER the dial and centred on the card — its
    // horizontal centre shares the ring's centre line, not a corner inset.
    final chipRect = tester.getRect(find.text('نیاز به تلاش بیشتر'));
    expect(chipRect.top, greaterThan(tester.getRect(ring).bottom));
    expect(chipRect.center.dx, closeTo(tester.getRect(ring).center.dx, 2));
    // The label keeps the top line to itself.
    expect(tester.getRect(find.text('امتیاز امروز')).top,
        lessThan(tester.getRect(ring).top));

    // The counter inside the dial reads on TWO lines: the score above, the
    // target under it, both stacked on the same centre line.
    final scoreRect =
        tester.getRect(find.descendant(of: ring, matching: find.text('35')));
    final targetRect = tester.getRect(
        find.descendant(of: ring, matching: find.text('/ 150')));
    expect(targetRect.top, greaterThanOrEqualTo(scoreRect.bottom - 1));
    expect(targetRect.center.dx, closeTo(scoreRect.center.dx, 1));
    // Neither line crosses the stroke.
    final ringRect = tester.getRect(ring);
    expect(scoreRect.top, greaterThan(ringRect.top));
    expect(targetRect.bottom, lessThan(ringRect.bottom));

    // The denominator is disclosed, not just printed. «۳۵ / ۱۵۰» alone leaves
    // the reader unable to audit the 150 — and it moves when an item is hidden
    // or its points are edited, so the number has to carry its own account.
    final caption = find.descendant(
      of: hero,
      matching: find.textContaining('سقف روز:'),
    );
    expect(caption, findsOneWidget);
    final captionText = tester.widget<Text>(caption).data!;
    expect(captionText, contains('طاعت'));
    expect(captionText, contains('نماز'));
    // It sits under the verdict, on the same centre line, inside the card.
    expect(tester.getRect(caption).top, greaterThan(chipRect.bottom - 1));
    expect(tester.getRect(caption).center.dx, closeTo(ringRect.center.dx, 2));
    expect(tester.getRect(caption).bottom, lessThanOrEqualTo(
        tester.getRect(hero).bottom));

    await expectLater(
      hero,
      matchesGoldenFile('goldens/evaluation_score_hero.png'),
    );
  });

  testWidgets('the score fits a 320dp phone at 1.3 text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 720 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ew.evaluationProvider.overrideWith(_MockEvaluation.new),
          prayerTrackerProvider.overrideWith(_MockPrayerTracker.new),
          settingsProvider.overrideWith(_MockSettings.new),
          periodRecordDaoProvider.overrideWithValue(MockPeriodRecordDao()),
          azkarStatusDaoProvider.overrideWithValue(MockAzkarStatusDao()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: EvaluationStatsWidget(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    // The number scales down inside the ring rather than crossing the stroke.
    final ring = find.descendant(
      of: find.ancestor(
        of: find.text('امتیاز امروز'),
        matching: find.byType(HeroCardShell),
      ),
      matching: find.byType(RingView),
    );
    expect(tester.getRect(ring).size, const Size(132, 132));
    final box = tester
        .getRect(find.descendant(of: ring, matching: find.textContaining('35')));
    expect(box.width, lessThan(132 - 8 * 2));
  });
}
