import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/services/clock_ticker.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/azkar_provider.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_stats_provider.dart';
import 'package:tawheeed/features/adhkar/duas/data/hesn_db_service.dart';
import 'package:tawheeed/features/books/presentation/providers/reading_stats_provider.dart';
import 'package:tawheeed/features/home/presentation/screens/home_tab.dart';
import 'package:tawheeed/features/home/presentation/widgets/actions_timeline_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/daily_summary_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/friday_adab_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/hero_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/prayer_times_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/rawatib_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/reminders_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/worship_today_card.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/features/khatm/presentation/providers/khatm_provider.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_tracker_provider.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart'
    as ew;
import 'package:tawheeed/shared/models/day_time.dart';

import '../../../../core/database/mock_daos.dart';

/// The one instant every home baseline is pinned to (see `_pumpPage`):
/// 2026-10-09 12:00:40, the fixture schedule's own date.
final _frozenNow = DateTime(2026, 10, 9, 12, 0, 40);

/// The night prayer baseline's instant: duhr (12:10) is open, so the
/// «اکنون» row — the surface the 2026-10-17 dark-theme report was about —
/// is in the picture (the day baselines' 12:00:40 has no NOW row).
final _prayerNowInstant = DateTime(2026, 10, 9, 12, 30);

/// A later instant for the night rawatib baseline: at 20:00 the fajr +
/// dhuhr rawatibs have ended unchecked (the dashed past boxes) while
/// maghrib is still open — the mix the dark hairlines live in.
final _rawatibNightInstant = DateTime(2026, 10, 9, 20);

/// Visual baselines for the redesigned home (spec §HOME). Everything is
/// frozen: a fixed prayer schedule at a fixed instant (12:00:40 on
/// 2026-10-09), fixed tracker/evaluation/reading-stats mocks, so the arc,
/// countdown, timeline and reminders never drift between runs. The daily
/// dua follows nowOverride-less RemindersCard only through the frozen
/// minute ticker — its selection is deterministic per day. Recorded on the
/// host with `flutter test --update-goldens`; they guard layout and
/// palette drift, not on-device font shaping.
class _MockPrayerTimes extends PrayerTimes {
  final pi.PrayerTimes? _data;

  _MockPrayerTimes.data(this._data);

  @override
  Future<pi.PrayerTimes?> build() async => _data;
}

class _MockPrayerTracker extends PrayerTracker {
  @override
  Future<PrayerTrackerState> build() async => const PrayerTrackerState();
}

class _MockAzkar extends Azkar {
  @override
  Future<List<ZikrItem>> build() async => [];
}

class _MockEvaluation extends ew.Evaluation {
  _MockEvaluation(this._streak);
  final int _streak;

  @override
  Future<ew.EvaluationState> build() async =>
      ew.EvaluationState(currentStreak: _streak);
}

class _MockKhatm extends Khatm {
  @override
  Future<KhatmModel?> build() async => null;
}

pi.PrayerTimes _prayerFixture() {
  return pi.PrayerTimes(
    date: DateTime(2026, 10, 9),
    fajr: const pi.PrayerInfo(
        name: 'fajr', arabicName: 'فجر', time: DayTime(hour: 6, minute: 0)),
    shorouq: const pi.PrayerInfo(
        name: 'shorouq',
        arabicName: 'طلوع',
        time: DayTime(hour: 7, minute: 30)),
    duhr: const pi.PrayerInfo(
        name: 'duhr', arabicName: 'ظهر', time: DayTime(hour: 12, minute: 10)),
    asr: const pi.PrayerInfo(
        name: 'asr', arabicName: 'عصر', time: DayTime(hour: 15, minute: 40)),
    maghrib: const pi.PrayerInfo(
        name: 'maghrib',
        arabicName: 'مغرب',
        time: DayTime(hour: 18, minute: 20)),
    isha: const pi.PrayerInfo(
        name: 'isha', arabicName: 'عشاء', time: DayTime(hour: 19, minute: 40)),
  );
}

Widget _app(double textScale, {Widget? card, bool night = false}) {
  // AppTheme.scaledFontSize reads the user's factor off bodyMedium — the
  // same knob the overflow-matrix tests turn.
  final base = night ? AppTheme.dark : AppTheme.light;
  final theme = textScale == 1
      ? base
      : base.copyWith(
          textTheme: base.textTheme.copyWith(
            bodyMedium: base.textTheme.bodyMedium
                ?.copyWith(fontSize: base.textTheme.bodyMedium!.fontSize! * textScale),
          ),
        );
  // A single card gets its OWN RepaintBoundary: without one,
  // matchesGoldenFile captures the nearest boundary ancestor — the whole
  // page — and every per-card golden becomes the same picture.
  final home = card == null
      ? const Directionality(textDirection: TextDirection.rtl, child: HomeTab())
      : Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: RepaintBoundary(
              key: const ValueKey('golden-card'),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: card,
              ),
            ),
          ),
        );
  return MaterialApp(theme: theme, home: home);
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
  bool lite = false,
  bool night = false,
  Widget? card,
}) async {
  // Statics first, ThemeData getter second (the settings_golden order
  // lesson): _app's AppTheme.dark/light reads what applyTheme just set.
  AppTheme.applyTheme(
      kind: night ? ThemeKind.night : ThemeKind.day,
      phase: night ? TimePhase.night : TimePhase.day);
  SharedPreferences.setMockInitialValues({});

  // RemindersCard loads the daily dua from HesnDbService, which copies the
  // bundled asset via path_provider — point it at a real temp dir (a
  // missing platform handler HANGS under the widget-test binding) and
  // pre-warm the singleton outside fake async.
  final tmp = Directory.systemTemp.createTempSync('home_golden');
  addTearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {
      // best-effort cleanup; the temp dir may already be gone
    }
  });
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => tmp.path,
  );
  await tester.runAsync(() => HesnDbService().init());

  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  // BOTH notifiers are frozen. The hero's tiles, date chips and countdown
  // read `minute` (not `second`), and every card derives "now" from it — so
  // freezing only the seconds notifier left the baselines pinned to the
  // wall-clock minute and the real calendar date of the recording session.
  final ticker = ClockTicker.idle()
    ..second.value = DateTime(2026, 10, 9, 12, 0, 40)
    ..minute.value = DateTime(2026, 10, 9, 12, 0, 40);
  addTearDown(ticker.dispose);

  final mockRepo = MockSettingsRepository();
  mockRepo.setMockSettings(const AppSettings());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
        clockTickerProvider.overrideWith((ref) => ticker),
        prayerTimesProvider
            .overrideWith(() => _MockPrayerTimes.data(_prayerFixture())),
        prayerTrackerProvider.overrideWith(_MockPrayerTracker.new),
        azkarProvider.overrideWith(_MockAzkar.new),
        ew.evaluationProvider.overrideWith(() => _MockEvaluation(3)),
        tasbihStatsProvider.overrideWith(
            (ref) async => const TasbihStatsData(
                weekTotal: 250, todayTotal: 34, sumTargets: 100)),
        readingStatsProvider.overrideWith((ref) async => {'2026-10-09': 2}),
        khatmProvider.overrideWith(_MockKhatm.new),
        if (lite) liteModeProvider.overrideWith((ref) async => true),
      ],
      child: _app(textScale, card: card, night: night),
    ),
  );
  await tester.pumpAndSettle();
}

/// A viewport no home page can fill, so every row is built before measuring.
const double _measureSurface = 24000;

/// Sizes the surface to the page's own height, so the full-page baseline shows
/// the whole page and nothing but the page.
///
/// The fixed heights this replaced (2600/3600) were guesses, not measurements:
/// the page is ~2923dp at 412dp and ~4009dp at 360dp with text scale 1.3, so
/// four of the five baselines cut their own bottom off — at 412dp the whole
/// QuickActions block and 1112dp of the Friday card fell outside the picture.
/// A clipped baseline cannot guard anything below the cut.
///
/// `maxScrollExtent + viewportDimension` is exact only while a list's rows have
/// the same height, so measure the way `golden_page_fit.dart` does: lay the page
/// out at a viewport far taller than any page, then walk the sliver's children
/// and take the last bottom.
Future<void> _fitPageHeight(WidgetTester tester, double width) async {
  final scrollable = find.byType(Scrollable).first;

  await tester.binding.setSurfaceSize(Size(width, _measureSurface));
  await tester.pumpAndSettle();

  final sliver = tester.renderObject<RenderSliverMultiBoxAdaptor>(
    find.descendant(of: scrollable, matching: find.byType(SliverList)).first,
  );
  var extent = 0.0;
  for (var child = sliver.firstChild;
      child != null;
      child = sliver.childAfter(child)) {
    final data = child.parentData! as SliverMultiBoxAdaptorParentData;
    final end = (data.layoutOffset ?? 0) + child.size.height;
    if (end > extent) extent = end;
  }

  await tester.binding.setSurfaceSize(Size(width, extent.ceilToDouble()));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  // The picture must fit the page. A page that still scrolls here means the
  // measurement above was wrong and the baseline would cut its bottom off.
  final pos =
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  expect(
    pos.maxScrollExtent,
    lessThanOrEqualTo(1),
    reason: 'the golden viewport must show the whole page, '
        '${pos.maxScrollExtent.toStringAsFixed(0)}px are still below the fold',
  );
}

void main() {
  // Per-card baselines pump the card ALONE inside its own RepaintBoundary
  // (key 'golden-card'): matched against a bare card widget, the comparator
  // would capture the nearest boundary ancestor — the whole page — and every
  // card golden would be the same picture.
  Future<void> cardGolden(
    WidgetTester tester,
    Widget card,
    String file, {
    bool night = false,
  }) async {
    await _pumpPage(tester, size: const Size(412, 1400), card: card, night: night);
    await expectLater(
      find.byKey(const ValueKey('golden-card')),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('home hero golden — day',
      (tester) => cardGolden(tester, const HeroCard(), 'home_hero_day.png'));

  testWidgets(
      'home prayer card golden — day',
      (tester) =>
          cardGolden(tester, const PrayerTimesCard(), 'home_prayer_day.png'));

  testWidgets(
      'home rawatib card golden — day',
      (tester) =>
          cardGolden(tester, const RawatibCard(), 'home_rawatib_day.png'));

  testWidgets(
      'home summary card golden — day',
      (tester) =>
          cardGolden(tester, const DailySummaryCard(), 'home_summary_day.png'));

  testWidgets(
      'home timeline card golden — day',
      (tester) => cardGolden(
          tester, const ActionsTimelineCard(), 'home_timeline_day.png'));

  testWidgets('home reminders card golden — day',
      (tester) => cardGolden(tester, RemindersCard(nowOverride: _frozenNow),
          'home_reminders_day.png'));

  testWidgets(
      'home friday card golden — day',
      (tester) =>
          cardGolden(tester, const FridayAdabCard(), 'home_friday_day.png'));

  testWidgets(
      'home worship card golden — day',
      (tester) => cardGolden(
          tester, const WorshipTodayCard(), 'home_worship_day.png'));

  // Night baselines: the dark-theme surfaces the 2026-10-17 report covered
  // (the open prayer window's cream row, the timeline's active chip, the
  // rawatib past dashes). The prayer one is pumped at 12:30 so duhr's
  // window is open and the «اکنون» row is actually in the picture.
  testWidgets('home prayer card golden — night, dhuhr window open',
      (tester) => cardGolden(
          tester,
          PrayerTimesCard(nowOverride: _prayerNowInstant),
          'home_prayer_night_open.png',
          night: true));

  testWidgets('home timeline card golden — night',
      (tester) => cardGolden(tester,
          ActionsTimelineCard(nowOverride: _prayerNowInstant),
          'home_timeline_night.png',
          night: true));

  testWidgets('home rawatib card golden — night',
      (tester) => cardGolden(tester,
          RawatibCard(nowOverride: _rawatibNightInstant),
          'home_rawatib_night.png',
          night: true));

  // Full-page baselines: the pinned instant (2026-10-09 12:00:40) is a
  // FRIDAY, so «آداب و فضایل روز جمعه» is part of every one of them — the
  // page renders it directly under the reminders card. A re-pin after the
  // pinned clock moves to a non-Friday would legitimately lose that card.

  testWidgets('home full page golden — day, 412dp', (tester) async {
    await _pumpPage(tester, size: const Size(412, _measureSurface));
    await _fitPageHeight(tester, 412);
    await expectLater(find.byType(HomeTab),
        matchesGoldenFile('goldens/home_page_day_412.png'));
  });

  testWidgets('home full page golden — day, 320dp', (tester) async {
    await _pumpPage(tester, size: const Size(320, _measureSurface));
    await _fitPageHeight(tester, 320);
    await expectLater(find.byType(HomeTab),
        matchesGoldenFile('goldens/home_page_day_320.png'));
  });

  testWidgets('home full page golden — day, 360dp, text scale 1.3',
      (tester) async {
    await _pumpPage(tester,
        size: const Size(360, _measureSurface), textScale: 1.3);
    await _fitPageHeight(tester, 360);
    await expectLater(find.byType(HomeTab),
        matchesGoldenFile('goldens/home_page_day_360_scale13.png'));
  });

  testWidgets('home full page golden — day, lite mode', (tester) async {
    await _pumpPage(tester, size: const Size(412, _measureSurface), lite: true);
    await _fitPageHeight(tester, 412);
    await expectLater(find.byType(HomeTab),
        matchesGoldenFile('goldens/home_page_day_lite.png'));
  });

  testWidgets('home full page golden — night, 412dp', (tester) async {
    await _pumpPage(tester,
        size: const Size(412, _measureSurface), night: true);
    await _fitPageHeight(tester, 412);
    await expectLater(find.byType(HomeTab),
        matchesGoldenFile('goldens/home_page_night_412.png'));
  });

  // Overflow matrix: every width × text-scale combination must lay the
  // page out with zero exceptions. The surface is tall enough that the
  // lazy ListView builds every card inside the viewport — the tallest case
  // (320dp × 1.3) is ~4309dp, so an overflow below a phone fold cannot hide.
  const widths = [320.0, 360.0, 412.0];
  const scales = [1.0, 1.3];
  for (final w in widths) {
    for (final s in scales) {
      testWidgets('no overflow — ${w.round()}dp × $s', (tester) async {
        await _pumpPage(tester, size: Size(w, _measureSurface), textScale: s);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
