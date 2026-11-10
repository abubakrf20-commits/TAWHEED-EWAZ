import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/finance/finance_models.dart';
import 'package:tawheeed/features/personal/finance/finance_providers.dart';
import 'package:tawheeed/features/personal/finance/finance_reminder_planner.dart';
import 'package:tawheeed/features/personal/finance/finance_reminder_scheduler.dart';
import 'package:tawheeed/features/personal/finance/finance_repository.dart';
import 'package:tawheeed/features/personal/finance/presentation/finance_screen.dart';

final _now = DateTime(2026, 10, 12);

class _FakeRepo implements FinanceRepository {
  _FakeRepo(this.snapshot);

  FinanceSnapshot snapshot;

  @override
  Future<FinanceSnapshot> load() async => snapshot;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _NoopReminders implements FinanceReminders {
  @override
  Future<void> sync(
    FinanceSnapshot snapshot, {
    FinanceReminderSettings? settings,
    String currencyUnit = 'تومان',
  }) async {}
}

FinanceSnapshot _snapshot() => FinanceSnapshot(
      obligations: [
        Obligation(
          id: 'late',
          kind: ObligationKind.cheque,
          direction: ObligationDirection.pay,
          title: 'چک اجاره',
          counterparty: 'مالک',
          amount: 12000000,
          dueDate: DateTime(2026, 10, 8),
          createdAt: DateTime(2026, 9),
        ),
        Obligation(
          id: 'today',
          kind: ObligationKind.installment,
          direction: ObligationDirection.pay,
          title: 'قسط وام مسکن',
          counterparty: 'بانک',
          amount: 4300000,
          dueDate: DateTime(2026, 10, 12),
          createdAt: DateTime(2026, 9),
        ),
        Obligation(
          id: 'next',
          kind: ObligationKind.loan,
          direction: ObligationDirection.pay,
          title: 'قسط خودرو',
          amount: 2500000,
          dueDate: DateTime(2026, 10, 20),
          createdAt: DateTime(2026, 9),
        ),
        Obligation(
          id: 'in',
          kind: ObligationKind.other,
          direction: ObligationDirection.receive,
          title: 'طلب از فروشنده',
          amount: 1800000,
          dueDate: DateTime(2026, 10, 18),
          createdAt: DateTime(2026, 9),
        ),
      ],
      persons: [
        Person(
          id: 'p1',
          name: 'علی رضایی',
          createdAt: DateTime(2026),
        ),
      ],
      entries: [
        DebtEntry(
          id: 'e1',
          personId: 'p1',
          direction: DebtDirection.owedToMe,
          amount: 5000000,
          createdDate: DateTime(2026, 3),
          dueDate: DateTime(2026, 10),
        ),
      ],
      payments: [
        DebtPayment(
          id: 'pay1',
          entryId: 'e1',
          date: DateTime(2026, 9, 20),
          amount: 2000000,
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  required FinanceSnapshot snapshot,
  Size size = const Size(360, 1400),
  double scale = 1,
  bool empty = false,
}) async {
  AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeRepositoryProvider.overrideWithValue(
          _FakeRepo(empty ? const FinanceSnapshot() : snapshot),
        ),
        financeRemindersProvider.overrideWithValue(_NoopReminders()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: FinanceScreen(nowOverride: _now),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the hero, the timeline and the month preview at 360',
      (tester) async {
    await _pump(tester, snapshot: _snapshot());
    expect(find.text('دفتر مالی'), findsOneWidget);
    expect(find.text('تعهدات ۳۰ روز آینده'), findsOneWidget);
    expect(find.text('چک اجاره'), findsOneWidget);
    expect(find.text('عقب‌افتاده'), findsOneWidget);
    expect(find.text('پیش‌نمایش ماه‌های آینده'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at 320 dp', (tester) async {
    await _pump(tester, snapshot: _snapshot(), size: const Size(320, 1400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at 412 dp and text scale 1.3', (tester) async {
    await _pump(
      tester,
      snapshot: _snapshot(),
      size: const Size(412, 1500),
      scale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state offers the add action', (tester) async {
    await _pump(tester, snapshot: const FinanceSnapshot(), empty: true);
    expect(find.text('هنوز چیزی ثبت نشده'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the debt tab shows the three totals and the person row',
      (tester) async {
    await _pump(tester, snapshot: _snapshot());
    await tester.tap(find.text('دَین و طلب'));
    await tester.pumpAndSettle();
    expect(find.text('طلب من'), findsOneWidget);
    expect(find.text('بدهی من'), findsOneWidget);
    expect(find.text('خالص'), findsOneWidget);
    expect(find.text('علی رضایی'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a kind filter narrows the timeline', (tester) async {
    await _pump(tester, snapshot: _snapshot());
    expect(find.text('چک اجاره'), findsOneWidget);
    await tester.tap(find.text('قسط').first);
    await tester.pumpAndSettle();
    expect(find.text('چک اجاره'), findsNothing);
    expect(find.text('قسط وام مسکن'), findsOneWidget);
  });

  testWidgets('golden: finance timeline, day 360', (tester) async {
    await _pump(tester, snapshot: _snapshot());
    await expectLater(
      find.byType(FinanceScreen),
      matchesGoldenFile('goldens/finance_timeline_day.png'),
    );
  });

  testWidgets('golden: debt tab, day 360', (tester) async {
    await _pump(tester, snapshot: _snapshot());
    await tester.tap(find.text('دَین و طلب'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(FinanceScreen),
      matchesGoldenFile('goldens/finance_debt_day.png'),
    );
  });
}
