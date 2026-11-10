import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_tables.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_report_tab.dart';

/// The tab itself, against a real (in-memory) shop.
///
/// The report is the one shop screen whose numbers are all derived, so a
/// component-level golden would prove nothing about it: what matters is that a
/// posted invoice reaches the right figure, that a figure opens its invoices,
/// and that the five-chip period row fits 320 dp at 1.3 text scale.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late ShopDao dao;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('shop_report_widget');
    db = AppDatabase.withConnection(
        NativeDatabase(File(p.join(tempDir.path, 'shop.sqlite'))));
    dao = ShopDao(db);
    SharedPreferences.setMockInitialValues({});
    await db.customStatement('SELECT 1');
    await dao.ensureSeeded();
  });

  tearDown(() async {
    await db.close();
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds sqlite handles briefly.
    }
  });

  int ms(DateTime d) => d.millisecondsSinceEpoch;

  Future<void> seedTodaySale() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 10);
    await db.customStatement(
      'INSERT INTO ${ShopTables.invoice} (id, number, date, kind, subtotal, '
      'discount_total, rounding_adj, total, status, note, created_at) '
      'VALUES (?, ?, ?, \'sale\', 120000, 0, 0, 120000, \'posted\', \'\', ?)',
      ['inv1', 'S-1', ms(today), ms(today)],
    );
    await db.customStatement(
      'INSERT INTO ${ShopTables.invoiceItem} (id, invoice_id, product_id, '
      'name_snapshot, unit_snapshot, qty_milli, unit_price, discount, '
      'line_total, unit_cost_snapshot) VALUES (?, ?, NULL, ?, \'عدد\', '
      '2000, 60000, 0, 120000, 40000)',
      ['item1', 'inv1', 'روغن موتور'],
    );
    await db.customStatement(
      'INSERT INTO ${ShopTables.payment} (id, date, direction, method, amount, '
      'party_type, invoice_id, note, created_at) '
      'VALUES (?, ?, \'in\', \'cash\', 120000, \'none\', ?, \'\', ?)',
      ['pay1', ms(today), 'inv1', ms(today)],
    );
  }

  Widget host({double width = 360, double scale = 1}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        shopDaoProvider.overrideWithValue(dao),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1800),
            textScaler: TextScaler.linear(scale),
            devicePixelRatio: 1,
          ),
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: ShopReportTab()),
          ),
        ),
      ),
    );
  }

  testWidgets('the figures come from the posted sale', (tester) async {
    await seedTodaySale();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('فروش خالص'), findsOneWidget);
    expect(find.text('سود ناخالص'), findsOneWidget);
    expect(find.text('سود خالص'), findsOneWidget);
    expect(find.text('کالاهای کندگرد'), findsOneWidget);
    // The 7-day default window contains today, so the nuance line reports the
    // one invoice rather than the empty state.
    expect(find.text('در این دوره فروشی ثبت نشده است.'), findsNothing);
  });

  testWidgets('an empty shop still renders, with an honest empty line',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('در این دوره فروشی ثبت نشده است.'), findsOneWidget);
    expect(find.text('همهٔ موجودی در این دوره فروش داشته.'), findsOneWidget);
  });

  testWidgets('tapping net sales opens the invoices behind it', (tester) async {
    await seedTodaySale();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('فروش خالص'));
    await tester.pumpAndSettle();

    expect(find.text('فاکتورهای فروش'), findsOneWidget);
    expect(find.text('S-1'), findsOneWidget);
  });

  testWidgets('the custom range chip asks for a Jalali day', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('بازهٔ دلخواه'));
    await tester.pumpAndSettle();

    // The app's own picker — not Flutter's Gregorian date dialog.
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  for (final width in const [320.0, 360.0, 412.0]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('no overflow at ${width.toInt()}dp x$scale', (tester) async {
        await seedTodaySale();
        await tester.pumpWidget(host(width: width, scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
