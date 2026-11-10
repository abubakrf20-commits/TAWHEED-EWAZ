import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/widgets/tasbih_counter_widget.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/widgets/tasbih_dhikr_sheet.dart';
import 'package:tawheeed/features/home/services/widget_sync.dart';
import 'package:tawheeed/features/home/services/widget_sync_provider.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/shared/utils/date_key.dart';
import '../../../../../core/database/mock_daos.dart';

/// Applies renames the way the real DAO does — one `dhikrText` column — so the
/// sheet's "re-read the provider" step sees a real change.
class _RenamingTasbihDao extends MockTasbihDao {
  @override
  Future<void> rename(String id, String text) async {
    final row = await getTasbih(id);
    if (row == null) return;
    await upsertTasbih(row.copyWith(dhikrText: text));
  }
}

/// A history read that fails, for the honesty path.
class _FailingHistoryDao extends MockDailyStatusDao {
  @override
  Future<List<DailyStatusTableData>> getAllInDateRange(
      String category, String startDate, String endDate) async {
    throw StateError('history unavailable');
  }
}

class _SpyWidgetSync extends WidgetSync {
  final List<String> dhikrs = [];

  @override
  Future<void> updateTasbihWidget({
    required String dhikr,
    required int count,
    required int target,
    required bool isActive,
    int? zikrIndex,
    String? zikrId,
  }) async {
    dhikrs.add(dhikr);
  }
}

Future<void> _seedDhikr(MockTasbihDao dao) =>
    dao.upsertTasbih(TasbihTableData(
      id: 'a',
      dhikrText: 'سبحان الله',
      count: 7,
      target: 33,
      totalLifetimeCount: 900,
      createdAt: DateTime(2026),
      isDefault: false,
      isEnabled: true,
    ));

Future<void> _pumpCounter(
  WidgetTester tester, {
  required MockTasbihDao tasbihDao,
  required DailyStatusDao dailyDao,
  WidgetSync? widgetSync,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tasbihDaoProvider.overrideWithValue(tasbihDao),
        dailyStatusDaoProvider.overrideWithValue(dailyDao),
        if (widgetSync != null) widgetSyncProvider.overrideWithValue(widgetSync),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SizedBox(height: 800, child: TasbihCounterWidget())),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// The chip strip is the only horizontal `ListView` in the tab, and the dhikr
/// name also appears on the counter card — narrowing by that list is what
/// makes the long-press land on the chip.
Finder _chip(String label) => find.descendant(
      of: find.byType(ListView),
      matching: find.text(label),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The counter runs the daily-reset decision on load; pinning it off keeps
    // every case on the counts it seeds.
    SharedPreferences.setMockInitialValues(const {'azkar_autoReset': false});
  });

  testWidgets('long-pressing a chip opens the dhikr sheet with its numbers',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final daily = MockDailyStatusDao();
    final now = DateTime.now();
    await daily.set('tasbih_daily_a', dateKeyOf(now), '', 12);
    await daily.set(
        'tasbih_daily_a', dateKeyOf(now.subtract(const Duration(days: 1))), '', 5);
    final tasbihDao = _RenamingTasbihDao();
    await _seedDhikr(tasbihDao);

    await _pumpCounter(tester, tasbihDao: tasbihDao, dailyDao: daily);
    await tester.longPress(_chip('سبحان الله'));
    await tester.pumpAndSettle();

    final sheet = find.byType(TasbihDhikrSheet);
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('امروز')),
        findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('12')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('17')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('900')),
        findsOneWidget);
    // 33 − 12: plain arithmetic on the day's target, never a religious claim.
    expect(find.textContaining('21 ذکر تا رسیدن به هدف امروز'), findsOneWidget);
  });

  testWidgets('the active chip carries a visible manage door', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tasbihDao = _RenamingTasbihDao();
    await _seedDhikr(tasbihDao);
    await _pumpCounter(
      tester,
      tasbihDao: tasbihDao,
      dailyDao: MockDailyStatusDao(),
    );

    // A long-press alone would be an invisible gesture; the active chip shows
    // the door too.
    final door = find.byTooltip('مدیریت ذکر');
    expect(door, findsOneWidget);
    await tester.tap(door);
    await tester.pumpAndSettle();
    expect(find.byType(TasbihDhikrSheet), findsOneWidget);
  });

  testWidgets('renaming from the sheet reaches the DAO and the widget',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tasbihDao = _RenamingTasbihDao();
    await _seedDhikr(tasbihDao);
    final spy = _SpyWidgetSync();
    await _pumpCounter(
      tester,
      tasbihDao: tasbihDao,
      dailyDao: MockDailyStatusDao(),
      widgetSync: spy,
    );

    await tester.longPress(_chip('سبحان الله'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تغییر نام'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'سبحان الله وبحمده');
    // Repo idiom: a focused field's decorator is still marked dirty while the
    // dialog pops, and the next frame asserts on the torn-down element.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    final saved = (await tasbihDao.getAllDomain()).single;
    expect(saved.name, 'سبحان الله وبحمده');
    expect(saved.targetDhikr, 'سبحان الله وبحمده');
    // The lifetime count is the thing the old delete-and-recreate path lost.
    expect(saved.totalLifetimeCount, 900);

    await tester.tap(find.text('بستن'));
    await tester.pumpAndSettle();

    expect(spy.dhikrs, isNotEmpty);
    expect(spy.dhikrs.last, 'سبحان الله وبحمده');
  });

  testWidgets('a failed history read says so instead of printing zeros',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tasbihDao = _RenamingTasbihDao();
    await _seedDhikr(tasbihDao);
    await _pumpCounter(
      tester,
      tasbihDao: tasbihDao,
      dailyDao: _FailingHistoryDao(),
    );

    await tester.longPress(_chip('سبحان الله'));
    await tester.pumpAndSettle();

    final sheet = find.byType(TasbihDhikrSheet);
    // Asserted by the panel's key, not by its prose: the copy can be reworded
    // without the test claiming the failure went away.
    expect(
        find.descendant(
            of: sheet,
            matching: find.byKey(const ValueKey('failure_tasbih_history'))),
        findsOneWidget);
    expect(
        find.descendant(
            of: sheet, matching: find.text(FailureView.retryLabel)),
        findsOneWidget);
    // A zero would claim "you counted nothing"; the cells must stay unknown.
    expect(find.descendant(of: sheet, matching: find.text('امروز')),
        findsNothing);
    expect(find.descendant(of: sheet, matching: find.text('0')), findsNothing);
  });
}
