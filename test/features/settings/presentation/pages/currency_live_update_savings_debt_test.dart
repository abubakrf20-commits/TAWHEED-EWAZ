import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/family_faith/data/family_faith_repository.dart';
import 'package:tawheeed/features/personal/family_faith/family_faith_providers.dart';
import 'package:tawheeed/features/personal/family_faith/presentation/savings_screen.dart';
import 'package:tawheeed/features/personal/family_faith/savings/savings_models.dart';
import 'package:tawheeed/features/personal/finance/finance_models.dart';
import 'package:tawheeed/features/personal/finance/finance_providers.dart';
import 'package:tawheeed/features/personal/finance/finance_reminder_planner.dart';
import 'package:tawheeed/features/personal/finance/finance_reminder_scheduler.dart';
import 'package:tawheeed/features/personal/finance/finance_repository.dart';
import 'package:tawheeed/features/personal/finance/presentation/finance_screen.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/pages/settings_screen.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';

import '../../../../core/database/mock_daos.dart';
import '../../../personal/family_faith/family_faith_test_kit.dart';
import '../fake_notification_infra.dart';

/// The savings pages and the debt ledger are kept alive in the app's tab shell
/// while the reader changes the unit in Settings, so each of them has to follow
/// `CurrencyStore.calculators.notifier`. If that wiring breaks, the money on
/// the screen keeps speaking the old currency — a goal of 10,000,000 «تومان»
/// still reads «تومان» after the reader switched to dollars, and the debt
/// summary hides which unit its totals are in.
///
/// The harness mounts the real screens at once (the list, the detail page and
/// the finance page with the debt tab open), pushes the real settings page on
/// top, and changes the unit through the production path — row → dialog →
/// `save()` → notifier. Nothing is reopened between the write and the assert.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    CurrencyStore.calculators.notifier.value = AppCurrency.toman;
    CurrencyStore.ledger.notifier.value = AppCurrency.toman;
  });

  tearDown(() {
    CurrencyStore.calculators.notifier.value = AppCurrency.toman;
    CurrencyStore.ledger.notifier.value = AppCurrency.toman;
  });

  Future<void> pumpApp(WidgetTester tester, {int index = 0}) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
    final settings = MockSettingsRepository()
      ..setMockSettings(const AppSettings());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWith((ref) async => settings),
          dailyNotificationSchedulerProvider
              .overrideWithValue(FakeDailyNotificationScheduler()),
          savingsRepositoryProvider
              .overrideWithValue(FakeSavingsRepository(_savings())),
          savingsRemindersProvider.overrideWithValue(NoopSavingsReminders()),
          financeRepositoryProvider
              .overrideWithValue(_FakeFinanceRepo(_finance())),
          financeRemindersProvider.overrideWithValue(_NoopFinanceReminders()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: _TabShell(index: index)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Pushes the real settings page over the open screens.
  Future<void> openSettings(WidgetTester tester) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('واحد پول'), findsOneWidget);
  }

  Future<void> pickCurrency(
    WidgetTester tester, {
    String row = _calculatorsRow,
    required String currency,
    bool save = true,
  }) async {
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
    await tester.tap(find.text(currency));
    await tester.pump();
    await tester.tap(find.text(save ? 'ذخیره' : 'انصراف'));
    await tester.pumpAndSettle();
  }

  /// Text inside one screen only, so a settings row that still names «تومان»
  /// cannot make the assertion pass or fail.
  Finder inScreen(Type screen, String text) => find.descendant(
        of: find.byType(screen, skipOffstage: false),
        matching: find.textContaining(text, skipOffstage: false),
      );

  testWidgets('the savings list repaints its figures in the new unit',
      (tester) async {
    await pumpApp(tester);
    expect(_savedLine('تومان'), findsWidgets);

    await openSettings(tester);
    await pickCurrency(tester, currency: 'دلار آمریکا');

    // Still on the settings page: this is the live update, not a reload.
    expect(_savedLine('دلار'), findsWidgets);
    expect(inScreen(SavingsScreen, 'تومان'), findsNothing);
  });

  testWidgets('the savings detail page follows the same unit',
      (tester) async {
    await pumpApp(tester, index: 2);
    expect(find.text('باقی\u200cمانده: 7,500,000 تومان'), findsOneWidget);

    await openSettings(tester);
    await pickCurrency(tester, currency: 'یورو');

    expect(
      find.text('باقی\u200cمانده: 7,500,000 یورو', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('the debt ledger repaints its amounts in the new unit',
      (tester) async {
    await pumpApp(tester, index: 1);
    await tester.tap(find.text('دَین و طلب'));
    await tester.pumpAndSettle();
    expect(inScreen(FinanceScreen, 'تومان'), findsWidgets);

    await openSettings(tester);
    await pickCurrency(tester, currency: 'یورو');

    expect(inScreen(FinanceScreen, 'تومان'), findsNothing);
    expect(inScreen(FinanceScreen, 'یورو'), findsWidgets);
  });

  testWidgets('a ledger-only change leaves the calculators untouched',
      (tester) async {
    await pumpApp(tester);
    await openSettings(tester);
    await pickCurrency(
      tester,
      row: _ledgerRow,
      currency: 'افغانی افغانستان',
    );

    expect(inScreen(SavingsScreen, 'تومان'), findsWidgets);
    expect(inScreen(SavingsScreen, 'افغانی'), findsNothing);
  });

  testWidgets('cancelling the dialog changes nothing', (tester) async {
    await pumpApp(tester);
    await openSettings(tester);
    await pickCurrency(tester, currency: 'یورو', save: false);

    expect(_savedLine('تومان'), findsWidgets);
    expect(inScreen(SavingsScreen, 'یورو'), findsNothing);
  });
}

const _calculatorsRow = 'واحد حساب\u200cگرها';
const _ledgerRow = 'واحد دفتر هزینه\u200cها';

// The settings route covers the tab shell, so every assert made while it is
// open has to look at offstage widgets too — that is exactly the state the
// reader comes back to.
Finder _savedLine(String unit) => find.text(
      '2,500,000 $unit از 10,000,000 $unit',
      skipOffstage: false,
    );

Widget _TabShell({required int index}) => Directionality(
      textDirection: TextDirection.rtl,
      child: IndexedStack(
        index: index,
        children: const [
          SavingsScreen(),
          FinanceScreen(),
          SavingsGoalScreen(goalId: 'g1'),
        ],
      ),
    );

SavingsSnapshot _savings() => SavingsSnapshot(
      goals: [
        SavingsGoal(
          id: 'g1',
          title: 'سفر شمال',
          targetAmount: 10000000,
          targetDate: DateTime(2027, 3, 1),
          iconKey: 'travel',
          createdAt: DateTime(2026, 6, 1),
        ),
      ],
      deposits: [
        Deposit(
          id: 'd1',
          goalId: 'g1',
          date: DateTime(2026, 8, 1),
          amount: 2000000,
        ),
        Deposit(
          id: 'd2',
          goalId: 'g1',
          date: DateTime(2026, 9, 1),
          amount: 1000000,
        ),
        Deposit(
          id: 'd3',
          goalId: 'g1',
          date: DateTime(2026, 9, 5),
          amount: -500000,
          note: 'برداشت',
        ),
      ],
    );

FinanceSnapshot _finance() => FinanceSnapshot(
      persons: [
        Person(id: 'p1', name: 'علی', createdAt: DateTime(2026, 9, 1)),
      ],
    );

class _FakeFinanceRepo implements FinanceRepository {
  _FakeFinanceRepo(this.snapshot);

  FinanceSnapshot snapshot;

  @override
  Future<FinanceSnapshot> load() async => snapshot;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _NoopFinanceReminders implements FinanceReminders {
  @override
  Future<void> sync(
    FinanceSnapshot snapshot, {
    FinanceReminderSettings? settings,
    String currencyUnit = 'تومان',
  }) async {}
}
