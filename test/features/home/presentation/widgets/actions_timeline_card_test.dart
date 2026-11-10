import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/adhkar/adhkar.dart';
import 'package:tawheeed/features/adhkar/data/azkar_data.dart' as data;
import 'package:tawheeed/features/home/presentation/widgets/actions_timeline_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/adhkar_category_page.dart';
import 'package:tawheeed/features/home/presentation/widgets/home_tokens.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/shared/models/day_time.dart';

class _MockSettings extends Settings {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

class _MockAzkar extends Azkar {
  @override
  Future<List<ZikrItem>> build() async => [];
}

class _MockPrayerTimes extends PrayerTimes {
  final pi.PrayerTimes? _data;

  _MockPrayerTimes.data(this._data);

  @override
  Future<pi.PrayerTimes?> build() async => _data;
}

pi.PrayerTimes _mockPrayerTimes() => pi.PrayerTimes(
      date: DateTime(2026, 10, 3),
      fajr: const pi.PrayerInfo(
          name: 'fajr', arabicName: 'فجر', time: DayTime(hour: 4, minute: 30)),
      shorouq: const pi.PrayerInfo(
          name: 'shorouq',
          arabicName: 'طلوع',
          time: DayTime(hour: 6, minute: 0)),
      duhr: const pi.PrayerInfo(
          name: 'duhr', arabicName: 'ظهر', time: DayTime(hour: 13, minute: 0)),
      asr: const pi.PrayerInfo(
          name: 'asr', arabicName: 'عصر', time: DayTime(hour: 16, minute: 30)),
      maghrib: const pi.PrayerInfo(
          name: 'maghrib',
          arabicName: 'مغرب',
          time: DayTime(hour: 19, minute: 30)),
      isha: const pi.PrayerInfo(
          name: 'isha', arabicName: 'عشاء', time: DayTime(hour: 21, minute: 0)),
    );

Future<void> _pumpCard(
  WidgetTester tester, {
  required DateTime at,
  bool withTimes = true,
  bool use12 = false,
  bool dark = false,
  VoidCallback? onNavigateToAzkar,
}) async {
  ThemeData? theme;
  if (dark) {
    // Statics first, ThemeData getter second (the settings_golden order
    // lesson): AppTheme.dark reads what applyTheme just set.
    AppTheme.applyTheme(kind: ThemeKind.night, phase: TimePhase.night);
    addTearDown(() =>
        AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day));
    theme = AppTheme.dark;
  }
  await tester.pumpWidget(
    // UniqueKey: a second pumpWidget in one test must remount the scope —
    // updating ProviderScope in place keeps the old container (and the old
    // mock) alive.
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        settingsProvider.overrideWith(_MockSettings.new),
        prayerTimesProvider.overrideWith(
            () => _MockPrayerTimes.data(withTimes ? _mockPrayerTimes() : null)),
        use12HourProvider.overrideWithValue(use12),
        azkarProvider.overrideWith(_MockAzkar.new),
      ],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: ActionsTimelineCard(
                nowOverride: at,
                onNavigateToAzkar: onNavigateToAzkar,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

BoxDecoration _chipDecoration(WidgetTester tester, int node) {
  final finder = find.descendant(
    of: find.byKey(ValueKey('timeline_node_$node')),
    matching: find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).borderRadius ==
            BorderRadius.circular(14)),
  );
  expect(finder, findsOneWidget, reason: 'node $node chip');
  return (tester.widget<Container>(finder).decoration as BoxDecoration);
}

void main() {
  testWidgets('ten nodes with window START times at 09:00; no remaining-time',
      (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 9));
    for (final time in [
      '03:30', // فضائل فجر (fajr − 1h)
      '04:30', // اذکار صبح (fajr)
      '06:00', // ضحی (sunrise)
      '13:00', // فضائل ظهر (dhuhr)
      '15:00', // فضائل عصر (dhuhr + 2h)
      '17:30', // فضائل مغرب (asr + 1h)
      '20:30', // اذکار شب (maghrib + 1h)
      '21:00', // فضائل عشاء (isha)
      '22:00', // اذکار خواب (isha + 1h)
    ]) {
      expect(find.text(time), findsOneWidget, reason: time);
    }
    expect(find.text('بعد هر نماز'), findsOneWidget);
    // The chips carry event start times only — never «H:MM دیگر».
    expect(find.textContaining('دیگر'), findsNothing);
  });

  testWidgets('exactly one «اکنون» — on ضحی in the sunrise→dhuhr stretch',
      (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 9));
    expect(find.text('اکنون'), findsOneWidget);
    // 09:00 is inside the ضحی window (sunrise→11am) and the latest-started
    // one, so node 2 wears the pill — not the still-open morning node 1,
    // and never the ride-along node 9.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('timeline_node_2')),
        matching: find.text('اکنون'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('timeline_node_1')),
        matching: find.text('اکنون'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('timeline_node_9')),
        matching: find.text('اکنون'),
      ),
      findsNothing,
    );
  });

  testWidgets(
      'vertical metrics: pill above rail above chip; card wraps (bug #3)',
      (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 9));
    final pill = tester.getRect(find.text('اکنون'));
    final name = tester.getRect(find.text('ضحی'));
    // The tag row sits fully above the chip content — no overlap.
    expect(pill.bottom, lessThan(name.top));

    final node = tester.getRect(find.byKey(const ValueKey('timeline_node_2')));
    // The node hugs its content (~86dp after the 2026-10-12 tightening):
    // no 122dp of dead space below.
    expect(node.height, greaterThan(80));
    expect(node.height, lessThan(100));
    final listRect = tester.getRect(find.byType(ListView).first);
    expect(listRect.height, lessThan(120));
    // The exact-metric allocation may carry a few dp of border slack.
    expect(listRect.height, closeTo(node.height, 5));
    // The whole chip stays inside the list viewport.
    expect(name.bottom, lessThanOrEqualTo(listRect.bottom));
  });

  testWidgets('past chip is the muted cream, upcoming the plain one',
      (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 9));
    // Node 1 (اذکار صبح) started earlier than the current node → past.
    expect(
      _chipDecoration(tester, 1).color,
      HomeColors.timelinePastBg.withValues(alpha: .80),
    );
    // Node 3 (فضائل ظهر) has not started → upcoming.
    expect(
      _chipDecoration(tester, 3).color,
      HomeColors.timelineUpcomingBg,
    );
    // The current node wears the warm gold ground.
    expect(
      _chipDecoration(tester, 2).color,
      HomeColors.nowRowStart(false),
    );
  });

  testWidgets('the current chip under DARK wears the gold wash, not the cream',
      (tester) async {
    // The 2026-10-17 dark-theme report, timeline half.
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 9), dark: true);
    expect(
      _chipDecoration(tester, 2).color,
      HomeColors.nowRowStart(true),
    );
    expect(
      _chipDecoration(tester, 2).color,
      isNot(HomeColors.nowRowStart(false)),
    );
    // The name inside the current chip flips to the hero gold.
    final nameStyle = tester
        .widget<Text>(find.descendant(
      of: find.byKey(const ValueKey('timeline_node_2')),
      matching: find.text('ضحی'),
    ))
        .style!;
    expect(nameStyle.color, HomeColors.nowRowTime(true));
  });

  testWidgets('before fajr the night node is current (yesterday\'s cycle)',
      (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 2));
    expect(find.text('اکنون'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('timeline_node_8')),
        matching: find.text('اکنون'),
      ),
      findsOneWidget,
    );
    // The night window still renders its start time (yesterday's isha + 1h).
    expect(find.text('22:00'), findsOneWidget);
  });

  testWidgets('no prayer times: fallback hour picks the node, anchors show',
      (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 9), withTimes: false);
    // Hour 9 → fallback set {2} → ضحی is current.
    expect(find.text('اکنون'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('timeline_node_2')),
        matching: find.text('اکنون'),
      ),
      findsOneWidget,
    );
    // Without a schedule every secondary line is the static anchor text.
    expect(find.text('بعد از اذان صبح'), findsOneWidget);
    expect(find.text('بعد از اذان ظهر'), findsOneWidget);
    expect(find.text('04:30'), findsNothing);
  });

  testWidgets('tapping a node routes to the azkar category page',
      (tester) async {
    // The static category data loads from the asset bundle at boot; tests
    // seed it directly (the same pattern daily_adhkar_box_test uses).
    const duhrItem = ZikrItem(
      id: 'test_duhr',
      title: 'اذکار بعد ظهر',
      arabicText: 'سُبْحَانَ اللَّهِ',
      translation: 'پاک و منزه است الله.',
      source: 'مسلم',
      period: PrayerPeriod.duhr,
    );
    data.AzkarData.setTestData([duhrItem]);
    addTearDown(() => data.AzkarData.setTestData([]));
    // The card navigates with context.push, so the harness needs a real
    // (minimal) GoRouter — a bare MaterialApp has no router to push on.
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                child: ActionsTimelineCard(
                    nowOverride: DateTime(2026, 10, 3, 9)),
              ),
            ),
          ),
        ),
        GoRoute(
          path: RouteNames.azkarCategory,
          builder: (context, state) {
            final args = state.extra as AdhkarCategoryArgs?;
            if (args == null) return const SizedBox.shrink();
            return AdhkarCategoryPage(
              title: args.title,
              period: args.period,
              items: args.items,
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          settingsProvider.overrideWith(_MockSettings.new),
          prayerTimesProvider.overrideWith(
              () => _MockPrayerTimes.data(_mockPrayerTimes())),
          use12HourProvider.overrideWithValue(false),
          azkarProvider.overrideWith(_MockAzkar.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('timeline_node_3')));
    await tester.pumpAndSettle();
    expect(find.byType(AdhkarCategoryPage), findsOneWidget);
    expect(find.text('فضائل ظهر'), findsWidgets);
  });

  testWidgets('auto-scroll centers the current node on a phone-width screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 21, 30));
    // 21:30 → isha (21:00) is the latest started window → node 7.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('timeline_node_7')),
        matching: find.text('اکنون'),
      ),
      findsOneWidget,
    );
    final position = tester
        .state<ScrollableState>(
          find.descendant(
              of: find.byType(ListView), matching: find.byType(Scrollable)),
        )
        .position;
    // Ten 84dp nodes at 412dp: centering node 7 leaves the list far from 0.
    expect(position.pixels, greaterThan(300));
  });

  testWidgets('12h setting formats the window times', (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 9), use12: true);
    expect(find.text('1:00 ب.ظ'), findsOneWidget); // فضائل ظهر (13:00)
    expect(find.text('13:00'), findsNothing);
    expect(find.text('3:30 ق.ظ'), findsOneWidget); // فضائل فجر (03:30)
  });
}
