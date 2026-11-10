import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/core/services/clock_ticker.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/personal2/kids/data/kids_dao.dart';
import 'package:tawheeed/features/personal2/kids/domain/kid_logic.dart';
import 'package:tawheeed/features/personal2/kids/presentation/providers/kids_providers.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/kids_habits_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/kids_home_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/kids_report_screen.dart';
import 'package:tawheeed/features/personal2/kids/services/kid_evening_summary.dart';
import 'package:tawheeed/features/personal2/shared/mini_charts.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/more/more_registry.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/screens/more_screen.dart';

import '../../../core/database/mock_daos.dart';

/// «دفتر عادت کودک» — the two ways a parent meets the tool, and the report
/// they read at the end of the week.
///
/// 1. The More page is the only door into the tool, so its registry row is the
///    entry point that actually matters: a tile whose `destination` no longer
///    matches a route leaves the whole section unreachable while every screen
///    test still passes.
/// 2. Inside the tool the three shortcuts are the real navigation — «عادت‌ها»
///    is where habits are edited and «گزارش» is the only way a parent sees the
///    week. Both are asserted by landing on the screen, not on the label.
/// 3. The report itself is a stack of derived numbers (prayer chips, stars,
///    active days, per-habit bars, the soft tip) over a 7- or 30-day window.
///    A wrong window still renders perfectly, so the tests pin the window and
///    the numbers it produces from seeded rows.
///
/// The DB is real: the report reads through [KidsDao]'s own SQL, and a fake
/// would let that SQL drift away from the screen printing it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late KidsDao dao;

  /// Today's Jalali day key, the same one the screens derive, so the seeded
  /// row lands inside the window the report computes.
  final todayKey = kidDayKey(DateTime.now());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // In memory: a memory database cannot be left holding a file handle
    // between tests, which matters on Windows.
    db = AppDatabase.withConnection(NativeDatabase.memory());
    dao = KidsDao(db);
    await db.customStatement('SELECT 1');
    await dao.settings();
  });

  tearDown(() async => db.close());

  Future<void> seedChild({
    String id = 'k1',
    String name = 'سارا',
    String colorKey = 'orange',
  }) async {
    await dao.upsertKid(id: id, name: name, colorKey: colorKey);
  }

  Future<void> seedHabit({
    String id = 'h1',
    String kidId = 'k1',
    String title = 'مسواک زدن',
    int stars = 1,
  }) async {
    await dao.saveHabit(
      id: id,
      kidId: kidId,
      title: title,
      stars: stars,
      schedule: HabitSchedule.daily,
      iconKey: 'brush',
    );
  }

  /// One approved mark for today, worth [stars], through the same call the UI
  /// makes — the log, the dedupe key and the star ledger all have to agree.
  Future<void> markToday({String habitId = 'h1', int stars = 1}) async {
    final result = await dao.markLog(
      kidId: 'k1',
      dayKey: todayKey,
      date: DateTime.now(),
      habitId: habitId,
      stars: stars,
      late: false,
      requiresApproval: false,
    );
    expect(result.ok, isTrue, reason: 'the seed row must exist exactly once');
  }

  group('opening from the More grid', () {
    test('the registry files the tool at its own route', () {
      final item = kMoreItems.firstWhere((i) => i.id == 'kids-habits');
      expect(item.kind, MoreKind.route);
      expect(item.destination, RouteNames.kidsHome,
          reason: 'a tile whose route drifted leaves the section unreachable');
      // The grid section is a product decision, not an accident: the ledger
      // counts the day's prayers and good deeds, so it sits with the rites
      // (user's move, 2026-11-09) and keeps its locks inside.
      expect(item.group, MoreGroup.worship);
    });

    testWidgets('its tile opens the real kids home, not a placeholder',
        (tester) async {
      await seedChild();
      final router = GoRouter(
        initialLocation: '/more',
        routes: [
          GoRoute(path: '/more', builder: (_, __) => const MoreScreen()),
          GoRoute(
            path: RouteNames.kidsHome,
            builder: (_, __) => const KidsHomeScreen(),
          ),
        ],
      );

      await _pump(tester, db, MaterialApp.router(routerConfig: router),
          ready: () => find.text('دفتر عادت کودک').evaluate().isNotEmpty);

      // The tile is on the page before the tap, so a failure says which half
      // broke: the grid or the route behind it.
      expect(find.text('دفتر عادت کودک'), findsOneWidget);

      await tester.tap(find.text('دفتر عادت کودک'));
      await _settle(tester, () => find.text('سارا').evaluate().isNotEmpty);

      expect(find.text('سارا'), findsWidgets,
          reason: 'the real home lists the seeded child');
      expect(find.text('حالت کودک'), findsWidgets);
      expect(find.text('برای شروع یک فرزند اضافه کنید'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the tool’s own shortcut grid', () {
    testWidgets('«عادت‌ها» opens the habits page with today’s row',
        (tester) async {
      await seedChild();
      await seedHabit();
      await markToday();

      await _pump(tester, db, _routerWidget(), ready: _homeReady);
      await tester.tap(find.text('عادت‌ها'));
      await _settle(tester,
          () => find.text('اصلاح ستاره‌ها (موجودی: 1)').evaluate().isNotEmpty);

      expect(find.text('مسواک زدن'), findsOneWidget);
      // 1 of the last 7 days: the row's own weekly rate, not a month figure.
      expect(find.text('1 ★ · (1 از 7 روز)'), findsOneWidget);
      expect(find.text('نرخ انجام هفتگی: 14%'), findsOneWidget);
      expect(find.text('عادتی ندارد.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('«گزارش» opens the weekly report', (tester) async {
      await seedChild();
      await seedHabit();
      await markToday();

      await _pump(tester, db, _routerWidget(), ready: _homeReady);
      await tester.tap(find.text('گزارش'));
      await _settle(
          tester, () => find.text('گزارش هفتگی').evaluate().isNotEmpty);

      expect(find.text('گزارش هفتگی'), findsOneWidget);
      expect(find.text('سارا'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('the child report', () {
    testWidgets('prints the week’s numbers from the child’s own rows',
        (tester) async {
      await seedChild();
      await seedHabit();
      await markToday();

      await _pump(
        tester,
        db,
        const KidsReportScreen(),
        ready: () => find.text('گزارش هفتگی').evaluate().isNotEmpty &&
            find.text('نماز 0 از 35').evaluate().isNotEmpty,
      );

      expect(find.text('گزارش هفتگی'), findsOneWidget);
      expect(find.text('سارا'), findsOneWidget);
      expect(find.text('هفت روز گذشته'), findsOneWidget);

      // Chips: 5 enabled prayers × 7 days, 1 star from today's mark, 1 day
      // with any activity.
      expect(find.text('نماز 0 از 35'), findsOneWidget);
      expect(find.text('1 ستاره'), findsOneWidget);
      expect(find.text('1 روز فعال'), findsOneWidget);

      // Per-habit bars carry the habit's own name and its 1-of-7 figure.
      expect(find.text('هر عادت'), findsOneWidget);
      expect(find.text('مسواک زدن'), findsOneWidget);

      final chart = tester.widget<MiniColumnChart>(
        find.byType(MiniColumnChart),
      );
      expect(chart.values, hasLength(7),
          reason: 'the default window is a week, one bar per day');
      expect(chart.values.reduce((a, b) => a + b), 1);

      // The tip is chosen, not invented: the only habit is under threshold.
      expect(find.textContaining('کمتر انجام شده'), findsOneWidget);
      expect(find.textContaining('آفرین به او'), findsNothing);

      // Sibling comparison is off by default.
      expect(find.textContaining('مقایسهٔ خانگی'), findsNothing);

      // The two export doors are offered.
      expect(find.text('اشتراک تصویر'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the month switch widens the window, it does not reword the page',
        (tester) async {
      await seedChild();
      await seedHabit();
      await markToday();

      await _pump(
        tester,
        db,
        const KidsReportScreen(),
        ready: () => find.text('نماز 0 از 35').evaluate().isNotEmpty,
      );

      await tester.tap(find.text('سی روز'));
      await _settle(tester,
          () => find.text('نماز 0 از 150').evaluate().isNotEmpty);

      expect(find.text('گزارش ماهانه'), findsOneWidget);
      expect(find.text('سی روز گذشته'), findsOneWidget);
      // 30 days instead of 7 — the month is the same roll-up, longer.
      expect(find.text('نماز 0 از 150'), findsOneWidget);
      expect(find.text('نماز 0 از 35'), findsNothing);

      final chart = tester.widget<MiniColumnChart>(find.byType(MiniColumnChart));
      expect(chart.values, hasLength(30));
      expect(chart.values.reduce((a, b) => a + b), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compares siblings only when the parent turned it on',
        (tester) async {
      await seedChild();
      await seedChild(id: 'k2', name: 'علی', colorKey: 'teal');
      await seedHabit();
      await markToday();

      await _pump(
        tester,
        db,
        const KidsReportScreen(),
        ready: () => find.textContaining('مقایسهٔ خانگی').evaluate().isEmpty &&
            find.text('گزارش هفتگی').evaluate().isNotEmpty &&
            find.text('سارا').evaluate().isNotEmpty,
      );
      expect(find.textContaining('مقایسهٔ خانگی'), findsNothing,
          reason: 'two children are not an invitation to compare them');

      await dao.saveSettings(const KidSettingsRecord(
        showSiblingComparison: true,
      ));
      // A fresh ProviderScope: the previous one still holds the settings row
      // it read before the switch, and an updated element tree would keep it.
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(
        tester,
        db,
        const KidsReportScreen(),
        ready: () => find.textContaining('مقایسهٔ خانگی').evaluate().isNotEmpty,
      );

      // One block per child's card: each card compares its own child.
      expect(find.textContaining('مقایسهٔ خانگی'), findsNWidgets(2));
      expect(find.text('علی'), findsWidgets,
          reason: 'the block names the other children, not just the current one');
      expect(tester.takeException(), isNull);
    });

    testWidgets('says so instead of drawing an empty report', (tester) async {
      await _pump(
        tester,
        db,
        const KidsReportScreen(),
        ready: () => find.text('فرزندی ثبت نشده').evaluate().isNotEmpty,
      );

      expect(find.text('فرزندی ثبت نشده'), findsOneWidget);
      expect(find.byType(MiniColumnChart), findsNothing);
      expect(find.text('اشتراک تصویر'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

bool _homeReady() =>
    find.text('عادت‌ها').evaluate().isNotEmpty &&
    find.text('گزارش').evaluate().isNotEmpty;

/// The routes the shortcut tests navigate into: home, habits and the report.
Widget _routerWidget() {
  final router = GoRouter(
    initialLocation: RouteNames.kidsHome,
    routes: [
      GoRoute(
        path: RouteNames.kidsHome,
        builder: (_, __) => const KidsHomeScreen(),
      ),
      GoRoute(
        path: RouteNames.kidsHabits,
        builder: (_, __) => const KidsHabitsScreen(),
      ),
      GoRoute(
        path: RouteNames.kidsReport,
        builder: (_, __) => const KidsReportScreen(),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

/// Pumps a kids screen over the real database.
///
/// The evening nudge service is silenced: its job is to post notifications,
/// and a test binding has no plugin behind them. Nothing under test depends
/// on it either way.
Future<void> _pump(
  WidgetTester tester,
  AppDatabase db,
  Widget child, {
  required bool Function() ready,
}) async {
  // Tall enough that a two-child report builds every block: the comparison
  // strip sits last, and a lazy ListView would leave it unbuilt and unfindable.
  tester.view.physicalSize = const Size(420 * 3, 3600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final idleTicker = clockTickerProvider.overrideWith((ref) {
    final ticker = ClockTicker.idle();
    ref.onDispose(ticker.dispose);
    return ticker;
  });
  final mockRepo = MockSettingsRepository()
    ..setMockSettings(const AppSettings());

  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
        kidEveningSummaryServiceProvider.overrideWith((ref) => _SilentNudges()),
        idleTicker,
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(420, 3600),
            textScaler: TextScaler.linear(1.0),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child,
          ),
        ),
      ),
    ),
  );
  await _settle(tester, ready);
  FlutterError.onError = previous;
  tester.takeException();
  expect(errors, isEmpty,
      reason: errors.map((e) => e.toString()).join(' | '));
}

/// Waits for the screens' database futures.
///
/// Never `pumpAndSettle`: the More page's hero strip keeps a ticker attached
/// and "settled" is a state it never reaches. Drift completes off the test
/// clock, so the futures only advance inside `runAsync`.
Future<void> _settle(
  WidgetTester tester,
  bool Function() ready,
) async {
  for (var i = 0; i < 400; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    if (i >= 4 && ready()) break;
  }
  await tester.pump(const Duration(milliseconds: 200));
}

/// Schedules nothing: the real service posts notifications through a plugin
/// that does not exist under `flutter test`.
class _SilentNudges extends KidEveningSummaryService {
  @override
  Future<int> sync({
    required KidSettingsRecord settings,
    required String kidName,
    required int done,
    required int total,
    required int stars,
    required DateTime now,
  }) async =>
      0;
}
