import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/design_system/components/failure_view.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/core/services/app_wakelock.dart';
import 'package:tawheeed/features/tools/pomodoro/data/daos/pomodoro_session_dao.dart';
import 'package:tawheeed/features/tools/pomodoro/presentation/screens/pomodoro_screen.dart';

class _FlakyHistoryDao extends PomodoroSessionDao {
  _FlakyHistoryDao(super.db);

  bool fail = true;

  @override
  Future<List<PomodoroSessionTableData>> recentSessions({int limit = 10}) async {
    if (fail) throw StateError('history offline');
    return super.recentSessions(limit: limit);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.withConnection(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: PomodoroScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> goCountdown(WidgetTester tester) async {
    await tester.tap(find.text('شمارش معکوس'));
    await tester.pumpAndSettle();
  }

  Future<void> tapSure(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder, warnIfMissed: false);
    await tester.pump();
  }

  testWidgets('سوئیچ حالت و کنترل‌های شمارش معکوس نمایش داده می‌شوند',
      (tester) async {
    await pumpScreen(tester);

    // «پومودور» هم در عنوان و هم در دکمهٔ حالت هست
    expect(find.text('پومودور'), findsWidgets);
    expect(find.text('شمارش معکوس'), findsOneWidget);

    await goCountdown(tester);

    expect(find.text('مسابقه و شمارش معکوس'), findsOneWidget);
    expect(find.text('1 دقیقه'), findsOneWidget);
    expect(find.text('2 دقیقه'), findsOneWidget);
    expect(find.text('5 دقیقه'), findsOneWidget);
    expect(find.text('دقیقه'), findsWidgets);
    expect(find.text('ثانیه'), findsOneWidget);
    expect(find.text('تعداد دور (برای چند نفر / چند مرحله)'), findsOneWidget);
    expect(find.text('بوق شروع (آماده‌باش 3-2-1)'), findsOneWidget);
    expect(find.text('روشن نگه داشتن صفحه هنگام اجرا'), findsOneWidget);
  });

  testWidgets('انتخاب زمان آماده، نمایش شمارش را عوض می‌کند', (tester) async {
    await pumpScreen(tester);
    await goCountdown(tester);

    // پیش‌فرض ۲ دقیقه
    expect(find.text('02:00'), findsOneWidget);

    await tapSure(tester, find.text('5 دقیقه'));
    expect(find.text('05:00'), findsOneWidget);
  });

  testWidgets('پاک کردن صفحهٔ روشن‌مانده وقتی حالت عوض می‌شود یا صفحه بسته می‌شود',
      (tester) async {
    // The wakelock is a screen-on flag the process holds until it is released.
    // Releasing was behind `if (_mode != countdown || !_cdKeepAwake) return;`,
    // so the two paths that changed the mode BEFORE releasing (switching mode,
    // then disposing the screen) silently never released: the screen stayed on
    // until the process died. Both paths are covered here.
    await pumpScreen(tester);
    // The pomodoro keeps the screen on only across tests that poke it, so the
    // owner set starts clean; assert that too — a leaked owner from an earlier
    // test would silently mask a missing release.
    expect(AppWakelock.debugOwners(), isNot(contains('pomodoro')),
        reason: 'an owner must never survive the test that acquired it');

    await goCountdown(tester);
    expect(AppWakelock.debugOwners(), isNot(contains('pomodoro')),
        reason: 'merely choosing countdown must not hold the screen');

    // Play → a running countdown may hold the screen.
    await tapSure(tester, find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.pause), findsOneWidget,
        reason: 'prove the run actually started before judging the wakelock');
    expect(AppWakelock.debugOwners(), contains('pomodoro'),
        reason: 'a running session that opted in must hold the screen');

    // The exact leak: the mode is replaced first, then the release runs.
    await tester.tap(find.text('پومودور').first);
    await tester.pumpAndSettle();
    expect(AppWakelock.debugOwners(), isNot(contains('pomodoro')),
        reason: 'switching away from a running countdown must hand the screen '
            'back — the old guard skipped exactly this release');

    // …and leaving the screen from a non-countdown mode (the other path the
    // guard swallowed) must also release, not defer to a later release.
    await goCountdown(tester);
    await tapSure(tester, find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(seconds: 1));
    expect(AppWakelock.debugOwners(), contains('pomodoro'));
    await tester.tap(find.text('پومودور').first);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(AppWakelock.debugOwners(), isNot(contains('pomodoro')),
        reason: 'disposing the screen must hand the screen back in every mode');
  });

  testWidgets('شمارش معکوس اجرا می‌شود و بعد از پایان دور به دور بعد می‌رود',
      (tester) async {
    await pumpScreen(tester);
    await goCountdown(tester);

    // بوق شروع را خاموش می‌کنیم تا تست ساده باشد
    await tapSure(tester, find.text('بوق شروع (آماده‌باش 3-2-1)'));

    // زمان ۱ دقیقه
    await tapSure(tester, find.text('1 دقیقه'));

    // دو دور
    final roundsRow = find
        .ancestor(
            of: find.text('تعداد دور (برای چند نفر / چند مرحله)'),
            matching: find.byType(Row))
        .first;
    await tapSure(
        tester,
        find.descendant(
            of: roundsRow, matching: find.byIcon(Icons.add_circle_outline)));
    expect(find.text('دور 1 از 2'), findsOneWidget);

    // شروع
    await tapSure(tester, find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(seconds: 1));
    // شمارش علاوه بر تیک، با ساعتِ واقعی هم هم‌گام می‌شود (PomodoroScreen._tick)،
    // پس روی ماشینِ پربار ممکن است چند ثانیه جلوتر باشد؛ مهم «شروع شدن» است،
    // نه تساویِ دقیق با 00:59.
    expect(
      find.byWidgetPredicate((w) =>
          w is Text &&
          w.data != null &&
          RegExp(r'^00:5[0-9]$').hasMatch(w.data!)),
      findsOneWidget,
    );

    // پایان دور اول
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();

    // دور دوم آماده است
    expect(find.text('دور 2 از 2'), findsOneWidget);
    expect(find.text('آماده'), findsWidgets);

    // دور دوم تا پایان
    await tapSure(tester, find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();

    // دیالوگ پایان مسابقه
    expect(find.text('🎉 مسابقه تمام شد'), findsOneWidget);
  });

  testWidgets('آماده‌باش 3-2-1 قبل از شروع اجرا می‌شود', (tester) async {
    await pumpScreen(tester);
    await goCountdown(tester);

    // بوق شروع پیش‌فرض روشن است
    await tapSure(tester, find.byIcon(Icons.play_arrow));

    expect(find.text('00:03'), findsOneWidget);
    expect(find.text('آماده…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:02'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01'), findsOneWidget);

    // پایان آماده‌باش → شروع واقعی ۲ دقیقه‌ای
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('02:00'), findsOneWidget);
    expect(find.text('در حال اجرا…'), findsOneWidget);
  });

  testWidgets('جلسهٔ کامل شمارش معکوس در تاریخچه ثبت می‌شود', (tester) async {
    await pumpScreen(tester);
    await goCountdown(tester);

    // بوق را خاموش می‌کنیم و یک دور یک‌دقیقه‌ای اجرا می‌کنیم
    await tapSure(tester, find.text('بوق شروع (آماده‌باش 3-2-1)'));
    await tapSure(tester, find.text('1 دقیقه'));
    await tapSure(tester, find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(seconds: 4)); // آماده‌باش 3-2-1
    await tester.pump(const Duration(seconds: 61)); // یک دور کامل
    await tester.pump();

    expect(find.text('🎉 مسابقه تمام شد'), findsOneWidget);

    // جلسه باید در دیتابیس ثبت شده باشد و در تاریخچه دیده شود
    final rows = await db.select(db.pomodoroSessionTable).get();
    expect(rows, hasLength(1));
    expect(rows.first.mode, 'countdown');
    expect(rows.first.durationMinutes, 1);
  });

  testWidgets('بازگشت به حالت کلاسیک، پومودور را نشان می‌دهد', (tester) async {
    await pumpScreen(tester);
    await goCountdown(tester);

    await tester.tap(find.text('پومودور').first);
    await tester.pumpAndSettle();

    // ignore: avoid_print

    expect(find.text('تمرکز'), findsOneWidget);
    expect(find.textContaining('جلسات تکمیل‌شده'), findsOneWidget);
    expect(find.textContaining('چرخه:'), findsOneWidget);
  });

  testWidgets('تایمر در حال اجرا از ددلاین ذخیره‌شده ادامه می‌یابد',
      (tester) async {
    // اپ وسط یک فاز کش شده: ددلاین ۲۵ دقیقهٔ دیگر ثبت شده است.
    SharedPreferences.setMockInitialValues({
      'pomodoro_deadline_ms': DateTime.now()
          .add(const Duration(minutes: 25))
          .millisecondsSinceEpoch,
      'pomodoro_focus_type': 'قرآن',
    });
    await pumpScreen(tester);

    // چند میلی‌ثانیهٔ اجرا گذشته → حدود ۲۴:۵۹ (نه ۲۵:۰۰ کامل).
    expect(find.textContaining('24:5'), findsOneWidget);
    expect(find.text('در حال اجرا…'), findsOneWidget);
    expect(find.text('قرآن'), findsWidgets);
  });

  testWidgets('توقف ذخیره‌شده برمی‌گردد و دوباره اجرا نمی‌شود', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pomodoro_paused_s': 300, // ۵:۰۰ مانده، وسط فاز تمرکز
    });
    await pumpScreen(tester);

    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('در حال اجرا…'), findsNothing);
  });

  testWidgets('ددلاین گذشته فاز را تمام می‌کند و جلسه را ثبت می‌کند',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'pomodoro_deadline_ms': DateTime.now()
          .subtract(const Duration(seconds: 10))
          .millisecondsSinceEpoch,
    });
    await pumpScreen(tester);
    // پایان فاز در post-frame اول اجرا می‌شود.
    await tester.pump();
    await tester.pumpAndSettle();

    // فاز بعدی: استراحت کوتاه پیش‌فرض ۵ دقیقه.
    expect(find.text('استراحت کوتاه'), findsWidgets);
    expect(find.text('05:00'), findsOneWidget);

    // جلسهٔ تمرکزی که واقعاً سپری شده ثبت شده است.
    final rows = await db.select(db.pomodoroSessionTable).get();
    expect(rows, hasLength(1));
    expect(rows.first.mode, 'classic');
    expect(rows.first.durationMinutes, 25);
  });

  testWidgets('«شروع سیکل تازه» چرخه را به نخستین جلسه برمی‌گرداند',
      (tester) async {
    // دو جلسهٔ صبح انجام شده و کاربر بعد از چند ساعت برمی‌گردد: چرخه نباید
    // از جلسهٔ سوم ادامه پیدا کند تا استراحت طولانی زودتر برسد.
    SharedPreferences.setMockInitialValues({
      'pomodoro_cycle': 2,
      'pomodoro_completed': 2,
    });
    await pumpScreen(tester);

    final fresh = find.text('شروع سیکل تازه');
    await tester.ensureVisible(fresh);
    await tester.pumpAndSettle();
    expect(fresh, findsOneWidget, reason: 'with a cycle underway it is offered');

    await tester.tap(fresh);
    await tester.pumpAndSettle();

    // Back at a first focus session, clock at the full focus length.
    expect(find.text('تمرکز'), findsWidgets);
    expect(find.text('25:00'), findsOneWidget);
    // Nothing left to reset, so the offer goes away.
    expect(find.text('شروع سیکل تازه'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('pomodoro_cycle'), 0);
    expect(prefs.getString('pomodoro_phase'), 'focus');
    // The tally of finished sessions is a record of work, not of the cycle.
    expect(prefs.getInt('pomodoro_completed'), 2);
  });

  testWidgets('without a cycle the reset offer is not shown', (tester) async {
    await pumpScreen(tester);
    expect(find.text('شروع سیکل تازه'), findsNothing);
  });

  testWidgets('خطای تاریخچه با «تلاش دوباره» به وضعیت واقعی برمی‌گردد',
      (tester) async {
    final dao = _FlakyHistoryDao(db);
    final flaky = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      pomodoroSessionDaoProvider.overrideWithValue(dao),
    ]);
    addTearDown(flaky.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: flaky,
        child: const MaterialApp(
          home: PomodoroScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // خواندن ناموفق باید خودش را نام ببرد؛ حق ندارد به‌جای تاریخچهٔ خالی جا بزند.
    expect(find.byKey(const ValueKey('failure_pomodoro_history')),
        findsOneWidget);
    expect(find.text('بارگذاری تاریخچهٔ جلسات ممکن نشد'), findsOneWidget);
    expect(find.textContaining('هنوز جلسه‌ای ثبت نشده'), findsNothing);
    expect(find.text('0 دقیقه'), findsNothing);

    dao.fail = false;
    final retry = find.text(FailureView.retryLabel);
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();

    // خواندن تازه موفق شد: پیام خطا رفت و صفرِ واقعی اعلام می‌شود.
    expect(find.byKey(const ValueKey('failure_pomodoro_history')),
        findsNothing);
    expect(find.textContaining('هنوز جلسه‌ای ثبت نشده'), findsOneWidget);
    expect(find.text('0 دقیقه'), findsOneWidget);
  });
}
