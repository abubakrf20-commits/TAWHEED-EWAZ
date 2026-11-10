import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/core/services/clock_ticker.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/personal2/kids/data/kids_dao.dart';
import 'package:tawheeed/features/personal2/kids/domain/kid_logic.dart';
import 'package:tawheeed/features/personal2/kids/presentation/providers/kids_providers.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/child_mode_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/kids_approvals_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/kids_rewards_screen.dart';
import 'package:tawheeed/features/personal2/kids/services/kid_evening_summary.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';

import '../../../core/database/mock_daos.dart';

/// «جایزه‌ها», «صف تأیید» and «حالت کودک» — the three screens a parent and a
/// child actually decide things on.
///
/// What each one promises, and what a regression would look like:
///
/// * **The shop tells the truth about what the child can afford.** A reward
///   costs more than the spendable stars is not requestable, and a request
///   reserves its stars the moment it is placed — so the row that funded it
///   turns into «لغو درخواست» instead of offering a second request.
/// * **The approval queue names the work, not its id.** A log row stores only
///   `habit_id`; the screen has to resolve it, or the parent reads
///   «سارا · hab_1729…» and cannot tell what they are approving.
/// * **Deciding credits once.** Both the single decision and «تأیید همه» go
///   through the DAO's guarded UPDATE, so the star ledger must move exactly by
///   the approved stars.
/// * **Child mode marks without shaming.** Tap → «انجام شد · +N» plus a 10 s
///   undo window; undo returns the balance to what it was.
/// * **They fit a 320 dp phone at 1.3× text** — the size the app's own
///   accessibility pass checks.
///
/// The database is real (in-memory drift) and the DAO is the production one:
/// these screens' whole job is the SQL behind them, and a fake would let the
/// SQL drift away from what the screen prints.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late KidsDao dao;

  final todayKey = kidDayKey(DateTime.now());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // No PIN configured: ParentLock's documented policy is «no PIN = no lock»,
    // and a test binding has no Keystore behind flutter_secure_storage.
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    db = AppDatabase.withConnection(NativeDatabase.memory());
    dao = KidsDao(db);
    await db.customStatement('SELECT 1');
    await dao.settings();
  });

  tearDown(() async => db.close());

  Future<void> seedChild({String id = 'k1', String name = 'سارا'}) =>
      dao.upsertKid(id: id, name: name, colorKey: 'orange');

  Future<void> seedHabit({
    String id = 'h1',
    String title = 'مسواک زدن',
    int stars = 1,
    bool requiresApproval = false,
  }) =>
      dao.saveHabit(
        id: id,
        kidId: 'k1',
        title: title,
        stars: stars,
        schedule: HabitSchedule.daily,
        requiresApproval: requiresApproval,
        iconKey: 'brush',
      );

  /// A mark through the same call the screens make, so the log, its dedupe key
  /// and the star ledger agree.
  Future<void> markHabit({
    String habitId = 'h1',
    int stars = 1,
    bool requiresApproval = false,
  }) async {
    final result = await dao.markLog(
      kidId: 'k1',
      dayKey: todayKey,
      date: DateTime.now(),
      habitId: habitId,
      stars: stars,
      late: false,
      requiresApproval: requiresApproval,
    );
    expect(result.ok, isTrue, reason: 'the seed row must exist exactly once');
  }

  Future<void> seedReward({
    String id = 'r1',
    String title = 'بستنی',
    int cost = 3,
  }) =>
      dao.saveReward(
        id: id,
        kidId: 'k1',
        title: title,
        costStars: cost,
      );

  Future<String?> requestReward({String rewardId = 'r1', int cost = 3}) async {
    final result = await dao.requestReward(
      kidId: 'k1',
      rewardId: rewardId,
      costStars: cost,
      dayKey: todayKey,
    );
    expect(result.error, isNull, reason: 'seeding the request must not fail');
    return result.id;
  }

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    bool ready = true,
    double width = 420,
    double scale = 1.0,
    double height = 1800,
  }) async {
    tester.view.physicalSize = Size(width * 3, height * 3);
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
            data: MediaQueryData(
              size: Size(width, height),
              textScaler: TextScaler.linear(scale),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: screen,
            ),
          ),
        ),
      ),
    );
    await _settle(tester, () => ready);
    FlutterError.onError = previous;
    tester.takeException();
    expect(errors, isEmpty,
        reason: errors.map((e) => e.toString()).join(' | '));
  }

  group('the star shop', () {
    testWidgets('turns an unaffordable reward into «ادامه بده»', (tester) async {
      await seedChild();
      await seedHabit();
      await markHabit(stars: 5);
      await seedReward();
      await seedReward(id: 'r2', title: 'دوچرخه', cost: 9);

      await pump(tester, const KidsRewardsScreen());

      expect(find.text('سارا · فروشگاه ستاره‌ها'), findsOneWidget);
      expect(find.text('موجودی قابل خرج: 5 ستاره'), findsOneWidget);
      expect(find.text('بستنی'), findsOneWidget);
      expect(find.text('دوچرخه'), findsOneWidget);
      // 3 is payable, 9 is not — and the unaffordable one is disabled, not a
      // button that fails after the tap.
      expect(find.text('درخواست'), findsOneWidget);
      expect(find.text('ادامه بده'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'ادامه بده'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a request reserves its stars and waits for the parent',
        (tester) async {
      await seedChild();
      await seedHabit();
      await markHabit(stars: 5);
      await seedReward();

      await pump(tester, const KidsRewardsScreen());
      await tester.tap(find.text('درخواست'));
      await _settle(tester, () => find.text('لغو درخواست').evaluate().isNotEmpty);

      // The reservation is visible: the row cannot be requested twice, and the
      // parent's card says who asked for how much.
      expect(find.text('لغو درخواست'), findsOneWidget);
      expect(find.text('درخواست‌های در انتظار'), findsOneWidget);
      expect(find.text('سارا می‌خواهد 3 ستاره خرج کند'), findsOneWidget);
      expect(find.text('موجودی قابل خرج: 2 ستاره'), findsOneWidget);
    });

    testWidgets('«تأیید» spends the stars once and clears the request',
        (tester) async {
      await seedChild();
      await seedHabit();
      await markHabit(stars: 5);
      await seedReward();
      await requestReward();

      await pump(tester, const KidsRewardsScreen());
      expect(find.text('درخواست‌های در انتظار'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'تأیید'));
      await _settle(
          tester, () => find.text('درخواست‌های در انتظار').evaluate().isEmpty);

      expect(find.text('درخواست‌های در انتظار'), findsNothing);
      expect(await dao.pendingRewardRequests(), isEmpty);
      // 5 earned − 3 spent, and the reservation is gone.
      expect(await dao.balance('k1'), 2);
      expect(await dao.reserved('k1'), 0);
      expect(find.text('موجودی قابل خرج: 2 ستاره'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says so instead of drawing an empty shop', (tester) async {
      await pump(tester, const KidsRewardsScreen(), ready: false);
      await _settle(
          tester, () => find.text('فرزندی ثبت نشده').evaluate().isNotEmpty);

      expect(find.text('فرزندی ثبت نشده'), findsOneWidget);
      expect(find.textContaining('· فروشگاه ستاره‌ها'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the approval queue', () {
    testWidgets('names the habit by its title, not its id', (tester) async {
      await seedChild();
      await seedHabit(requiresApproval: true);
      await markHabit(requiresApproval: true);

      await pump(tester, const KidsApprovalsScreen());

      expect(find.text('صف تأیید'), findsOneWidget);
      expect(find.text('سارا · مسواک زدن'), findsOneWidget);
      expect(find.text('عادت · 1 ستاره'), findsOneWidget);
      // The id itself is never shown.
      expect(find.text('سارا · h1'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one approval credits the log’s stars and empties the row',
        (tester) async {
      await seedChild();
      await seedHabit(requiresApproval: true);
      await markHabit(requiresApproval: true);

      await pump(tester, const KidsApprovalsScreen());
      await tester.tap(find.byTooltip('تأیید'));
      await _settle(tester,
          () => find.text('چیزی برای تأیید نیست').evaluate().isNotEmpty);

      expect(find.text('چیزی برای تأیید نیست'), findsOneWidget);
      expect(find.text('سارا · مسواک زدن'), findsNothing);
      expect(await dao.pendingApprovals(), isEmpty);
      expect(await dao.balance('k1'), 1,
          reason: 'approving is what credits the stars');
    });

    testWidgets('«تأیید همه» decides every pending row once', (tester) async {
      await seedChild();
      await seedHabit(requiresApproval: true);
      await seedHabit(id: 'h2', title: 'مرتب کردن اتاق', requiresApproval: true);
      await markHabit(requiresApproval: true);
      await markHabit(habitId: 'h2', requiresApproval: true);

      await pump(tester, const KidsApprovalsScreen());
      expect(find.text('تأیید همه'), findsOneWidget);

      await tester.tap(find.text('تأیید همه'));
      await _settle(tester,
          () => find.text('چیزی برای تأیید نیست').evaluate().isNotEmpty);

      expect(find.text('چیزی برای تأیید نیست'), findsOneWidget);
      expect(await dao.pendingApprovals(), isEmpty);
      expect(await dao.balance('k1'), 2, reason: 'one star per habit, once');
    });

    testWidgets('says so when nothing is waiting', (tester) async {
      await seedChild();

      await pump(tester, const KidsApprovalsScreen());

      expect(find.text('چیزی برای تأیید نیست'), findsOneWidget);
      expect(find.text('تأیید همه'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('child mode', () {
    testWidgets('a tap marks the habit, and the undo window takes it back',
        (tester) async {
      await seedChild();
      await seedHabit();
      await seedReward();

      await pump(tester, const ChildModeScreen(kidId: 'k1'));
      expect(find.text('سلام سارا'), findsOneWidget);
      expect(find.text('کارهای خوب امروز'), findsOneWidget);
      expect(find.text('مسواک زدن'), findsOneWidget);
      expect(find.text('+1 ستاره'), findsOneWidget);
      expect(find.text('تا «بستنی» فقط 3 ستاره مانده'), findsOneWidget);

      await tester.tap(find.text('مسواک زدن'));
      await _settle(
          tester, () => find.text('بازگرداندن').evaluate().isNotEmpty);

      expect(find.text('انجام شد · +1'), findsOneWidget);
      expect(find.text('ثبت شد'), findsOneWidget);
      expect(find.text('تا «بستنی» فقط 2 ستاره مانده'), findsOneWidget);
      expect(await dao.balance('k1'), 1);

      await tester.tap(find.text('بازگرداندن'));
      await _settle(tester, () => find.text('بازگرداندن').evaluate().isEmpty);

      // Undo removes the ledger row the mark created: the balance is exactly
      // what it was, not one star less.
      expect(await dao.balance('k1'), 0);
      expect(find.text('+1 ستاره'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a child that was already marked reads as done, not shamed',
        (tester) async {
      await seedChild();
      await seedHabit();
      await markHabit();

      await pump(tester, const ChildModeScreen(kidId: 'k1'));

      expect(find.text('انجام شد · +1'), findsOneWidget);
      // The brief: a missed day says «مانده», never a red X; a done one says
      // done. Nothing in the tile asks the child to redo it.
      expect(find.text('+1 ستاره'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('at 320 dp with the text at 1.3×', () {
    testWidgets('the shop, the queue and child mode all fit', (tester) async {
      await seedChild();
      // Earned stars, so the shop has something affordable to lay out…
      await seedHabit();
      await markHabit(stars: 5);
      // …and a second, still-pending mark, so the queue has a row to draw.
      await seedHabit(id: 'h2', title: 'مرتب کردن اتاق', requiresApproval: true);
      await markHabit(habitId: 'h2', requiresApproval: true);
      await seedReward();
      await seedReward(id: 'r2', title: 'دوچرخه', cost: 9);
      await requestReward();

      await pump(tester, const KidsRewardsScreen(), width: 320, scale: 1.3);
      expect(find.text('درخواست‌های در انتظار'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await pump(tester, const KidsApprovalsScreen(), width: 320, scale: 1.3);
      expect(find.text('سارا · مرتب کردن اتاق'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await pump(tester, const ChildModeScreen(kidId: 'k1'),
          width: 320, scale: 1.3);
      expect(find.text('سلام سارا'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Waits for a screen's database futures.
///
/// Never `pumpAndSettle`: these screens hold a mark/undo timer and a provider
/// that is invalidated after each decision, and drift completes off the test
/// clock — the futures only advance inside `runAsync`.
Future<void> _settle(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 400; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
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
