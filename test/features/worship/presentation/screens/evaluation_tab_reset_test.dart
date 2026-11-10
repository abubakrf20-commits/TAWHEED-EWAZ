import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/features/worship/data/evaluation_reset_backup.dart';
import 'package:tawheeed/features/adhkar/data/azkar_data.dart';
import 'package:tawheeed/features/adhkar/data/daos/azkar_status_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/features/worship/presentation/screens/evaluation_tab.dart';
import 'package:tawheeed/features/prayer/data/daos/prayer_tracker_dao.dart';
import 'package:tawheeed/features/prayer/data/daos/period_record_dao.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/shared/utils/date_key.dart';
import '../../../../core/database/mock_daos.dart';

class _MockSettings extends Settings {
  @override
  Future<AppSettings> build() async => const AppSettings();

  @override
  Future<void> patch(AppSettings Function(AppSettings) updater) async {}
}

/// Pumps real frames until the loading spinner is gone.
///
/// `pumpAndSettle` cannot be used to mount this tab. While the evaluation is
/// loading the body is an indeterminate [CircularProgressIndicator], and an
/// indeterminate spinner schedules a frame on every tick — so a settle never
/// sees a quiet frame and dies on its timeout instead of returning the first
/// painted state. Bounded pumping is the only way to wait out a spinner.
Future<void> _waitForLoad(WidgetTester tester, {int maxFrames = 80}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
  fail('the evaluation never finished loading after $maxFrames frames');
}

/// Pumps until [finder] matches — again without requiring a quiet tree.
Future<void> _pumpUntil(WidgetTester tester, Finder finder,
    {int maxFrames = 80}) async {
  for (var i = 0; i < maxFrames; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('$finder did not appear after $maxFrames frames');
}

/// Pumps a fixed span of frames: enough for a dialog to open or close, or for a
/// snackbar to slide in, without waiting for anything to stop moving.
Future<void> _pumpFrames(
  WidgetTester tester, {
  int frames = 8,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

Future<MockDailyStatusDao> _mount(
  WidgetTester tester, {
  MockDailyStatusDao? dao,
}) async {
  // The reset button lives at the bottom of the tab's scroll; a tall surface
  // keeps it on screen so the tests can tap it without scrolling.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final dailyDao = dao ?? MockDailyStatusDao();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      azkarStatusDaoProvider.overrideWithValue(MockAzkarStatusDao()),
      tasbihDaoProvider.overrideWithValue(MockTasbihDao()),
      dailyStatusDaoProvider.overrideWithValue(dailyDao),
      prayerTrackerDaoProvider.overrideWithValue(MockPrayerTrackerDao()),
      periodRecordDaoProvider.overrideWithValue(MockPeriodRecordDao()),
      settingsProvider.overrideWith(_MockSettings.new),
    ],
    child: const MaterialApp(home: Scaffold(body: EvaluationTab())),
  ));
  await _waitForLoad(tester);
  return dailyDao;
}

Future<void> _switchTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await _pumpFrames(tester);
}

Future<void> _tapReset(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The evaluation loads the azkar corpus through `AzcarData.loadAll`, which
  // decodes the JSON with `compute()` — a real isolate. A real isolate's future
  // only completes on the real event loop, and a widget test runs inside a fake
  // async zone where `pump` advances fake time and never sees that message. Left
  // to load for real, the provider stays `AsyncLoading` forever and the body
  // shows its spinner for the rest of the test. Seeding the cache is the hook
  // the rest of the suite uses (`daily_summary_card_test`, `azkar_provider_test`);
  // an empty corpus is enough here because no test in this file reads a zikr.
  Directory? _backupTemp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AzkarData.setTestData(const []);
    // Every resetRange writes its undo snapshot; point it at a temp dir.
    _backupTemp = await Directory.systemTemp.createTemp('eval_backup_test');
    final temp = _backupTemp!;
    backupDirectoryResolver = () async => temp;
  });
  tearDown(() async {
    backupDirectoryResolver = null;
    // Best-effort: Windows keeps the directory handle open briefly, and a
    // temp dir that survives the test run is not worth a red test.
    try {
      await _backupTemp?.delete(recursive: true);
    } catch (_) {}
    _backupTemp = null;
    AzkarData.resetTestData();
  });

  testWidgets('each tab carries its own reset action, the header carries none',
      (tester) async {
    await _mount(tester);

    // The old global reset lived in the page header; it is gone.
    expect(find.byTooltip('ریست کردن ارزیابی'), findsNothing);
    expect(find.byTooltip('ریست ارزیابی روزانه'), findsOneWidget);

    await _switchTab(tester, 'هفتگی');
    expect(find.byTooltip('ریست ارزیابی هفتگی'), findsOneWidget);

    await _switchTab(tester, 'ماهانه');
    expect(find.byTooltip('ریست ارزیابی ماهانه'), findsOneWidget);
  });

  testWidgets('the daily reset asks before doing anything', (tester) async {
    final dao = await _mount(tester);

    await _tapReset(tester, 'ریست ارزیابی روزانه');
    await _pumpUntil(tester, find.text('ریست ارزیابی روزانه؟'));

    expect(find.text('ریست ارزیابی روزانه؟'), findsOneWidget);
    // Nothing is deleted by merely opening the question.
    expect(await dao.getAllForCategory('worship'), isEmpty);
  });

  testWidgets('cancelling leaves the records alone', (tester) async {
    final dao = MockDailyStatusDao();
    final yesterday =
        dateKeyOf(DateTime.now().subtract(const Duration(days: 1)));
    await dao.set('worship_score', yesterday, '', 40);

    await _mount(tester, dao: dao);
    await _tapReset(tester, 'ریست ارزیابی روزانه');
    await _pumpUntil(tester, find.byKey(const ValueKey('evaluation_reset_cancel')));
    await tester.tap(find.byKey(const ValueKey('evaluation_reset_cancel')));
    await _pumpFrames(tester);

    expect(await dao.getValue('worship_score', yesterday, ''), 40);
  });

  testWidgets('confirming wipes the day and says so', (tester) async {
    final dao = MockDailyStatusDao();
    final today = dateKeyOf(DateTime.now());
    final yesterday =
        dateKeyOf(DateTime.now().subtract(const Duration(days: 1)));
    await dao.set('worship', today, 'quran', 1);
    await dao.set('worship_score', today, '', 40);
    await dao.set('worship_score', yesterday, '', 40);

    await _mount(tester, dao: dao);
    await _tapReset(tester, 'ریست ارزیابی روزانه');
    await _pumpUntil(tester, find.byKey(const ValueKey('evaluation_reset_confirm')));
    // The dialog quotes the history it is about to destroy.
    expect(find.textContaining('1 روز امتیاز ثبت‌شده'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('evaluation_reset_confirm')));
    await tester.pump(const Duration(milliseconds: 100));
    // ignore: avoid_print
    print('RST-DBG rows-worship=${(await dao.getAllForDate("worship", today)).length} snacks=${find.byType(SnackBar).evaluate().length}');
    await _pumpUntil(tester, find.textContaining('پاک شد'));

    // The day is gone; the day before it is not this reset's to erase.
    expect(await dao.getAllForDate('worship', today), isEmpty);
    expect(await dao.getValue('worship_score', today, ''), isNull);
    expect(await dao.getValue('worship_score', yesterday, ''), 40);
    expect(find.textContaining('ارزیابی امروز پاک شد'), findsOneWidget);
  });

  testWidgets('the monthly reset targets the displayed month', (tester) async {
    final dao = MockDailyStatusDao();
    // The month tab speaks JALALI months, so the in/out days are derived from
    // the Jalali calendar — a Gregorian yesterday can still sit inside the
    // same Jalali month.
    final nowJ = Jalali.fromDateTime(DateTime.now());
    final insideMonth = Jalali(nowJ.year, nowJ.month, 2).toDateTime();
    // One Gregorian day before Jalali day 1 — safely outside the month.
    final outsideMonth =
        Jalali(nowJ.year, nowJ.month).toDateTime().subtract(const Duration(days: 1));
    await dao.set('worship_score', dateKeyOf(insideMonth), '', 40);
    await dao.set('worship_score', dateKeyOf(outsideMonth), '', 40);

    await _mount(tester, dao: dao);
    await _switchTab(tester, 'ماهانه');
    await _tapReset(tester, 'ریست ارزیابی ماهانه');
    await _pumpUntil(tester, find.byKey(const ValueKey('evaluation_reset_confirm')));
    await tester.tap(find.byKey(const ValueKey('evaluation_reset_confirm')));
    await _pumpUntil(tester, find.textContaining('پاک شد'));

    expect(await dao.getValue('worship_score', dateKeyOf(insideMonth), ''),
        isNull);
    // Outside the browsed month: untouched.
    expect(await dao.getValue('worship_score', dateKeyOf(outsideMonth), ''),
        40);
  });
}
