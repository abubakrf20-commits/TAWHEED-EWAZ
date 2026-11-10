import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/fasting/presentation/tabs/fitr_zakat_tab.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/pages/settings_screen.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/screens/inheritance_screen.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';

import '../../../../core/database/mock_daos.dart';
import '../fake_notification_infra.dart';

/// The same proof as [currency_live_update_test] for the other two calculators
/// that share [CurrencyStore.calculators]: زکات فطر and میراث.
///
/// Both hold their own copy of the unit (one with the mixin, one by hand) and
/// both stay open behind Settings, so a write there must reach them through
/// the notifier — no reopen, no prefs re-read, no stale label. The labels are
/// read off the fields themselves (`suffixText` / the estate field's own label),
/// because those are what the reader is actually looking at.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await InheritanceContent.load();
  });

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
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: _Shell(index: index),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Pushes the real settings page over the open calculators, the way the tab
  /// shell does when the reader goes to Settings and comes back.
  Future<NavigatorState> openSettings(WidgetTester tester) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('واحد پول'), findsOneWidget);
    return navigator;
  }

  Future<void> pickCurrency(
    WidgetTester tester, {
    required String row,
    required String currency,
  }) async {
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
    await tester.tap(find.text(currency));
    await tester.pump();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
  }

  String? suffixWhere(
    WidgetTester tester,
    bool Function(InputDecoration) test,
  ) {
    for (final field in tester.widgetList<TextField>(
      find.byType(TextField, skipOffstage: false),
    )) {
      final decoration = field.decoration;
      if (decoration != null && test(decoration)) return decoration.suffixText;
    }
    return null;
  }

  /// The fitr tab's price field carries the unit as its suffix.
  String? fitrPriceUnit(WidgetTester tester) =>
      suffixWhere(tester, (d) => d.hintText == 'قیمت روز');

  /// The inheritance estate field states the unit in its own label AND suffix.
  String? estateUnit(WidgetTester tester) => suffixWhere(
        tester,
        (d) => d.labelText?.startsWith('مبلغ کل ترکه') ?? false,
      );

  group('زکات فطر', () {
    testWidgets('its price field and cash chip follow the settings unit',
        (tester) async {
      await pumpApp(tester);
      expect(fitrPriceUnit(tester), 'تومان');
      expect(find.text('نقدی (تومان)', skipOffstage: false), findsWidgets);

      await openSettings(tester);
      await pickCurrency(tester, row: 'واحد حساب‌گرها', currency: 'دلار آمریکا');

      // The tab is under the settings route and was never rebuilt from prefs:
      // the listener is what moved the label.
      expect(fitrPriceUnit(tester), 'دلار',
          reason: 'فیلد قیمت باید همان لحظه واحد تازه را نشان دهد');
      expect(find.text('نقدی (دلار)', skipOffstage: false), findsWidgets);
      expect(find.text('نقدی (تومان)', skipOffstage: false), findsNothing);
    });

    testWidgets('keeps the new unit after settings closes', (tester) async {
      await pumpApp(tester);
      final navigator = await openSettings(tester);
      await pickCurrency(tester, row: 'واحد حساب‌گرها', currency: 'یورو');

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(fitrPriceUnit(tester), 'یورو');
      expect(find.text('نقدی (یورو)'), findsWidgets);
    });
  });

  group('میراث', () {
    testWidgets('the estate field relabels itself from settings', (tester) async {
      await pumpApp(tester, index: 1);
      expect(estateUnit(tester), 'تومان');
      expect(find.textContaining('مبلغ کل ترکه (تومان)', skipOffstage: false),
          findsWidgets);

      await openSettings(tester);
      await pickCurrency(tester, row: 'واحد حساب‌گرها', currency: 'دلار آمریکا');

      expect(estateUnit(tester), 'دلار');
      expect(find.textContaining('مبلغ کل ترکه (دلار)', skipOffstage: false),
          findsWidgets);
      expect(find.textContaining('مبلغ کل ترکه (تومان)', skipOffstage: false),
          findsNothing);
    });
  });

  group('the two units stay apart', () {
    testWidgets('a ledger change moves neither calculator', (tester) async {
      await pumpApp(tester);
      expect(fitrPriceUnit(tester), 'تومان');

      await openSettings(tester);
      await pickCurrency(
        tester,
        row: 'واحد دفتر هزینه‌ها',
        currency: 'افغانی افغانستان',
      );

      expect(CurrencyStore.ledger.current, AppCurrency.afghani);
      expect(fitrPriceUnit(tester), 'تومان',
          reason: 'زکات فطر واحد حساب‌گرها را می‌خواند، نه دفتر را');
      expect(estateUnit(tester), 'تومان');
    });

    testWidgets('«انصراف» leaves both on the old unit', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.text('واحد حساب‌گرها'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('دلار آمریکا'));
      await tester.pump();
      await tester.tap(find.text('انصراف'));
      await tester.pumpAndSettle();

      expect(CurrencyStore.calculators.current, AppCurrency.toman);
      expect(fitrPriceUnit(tester), 'تومان');
      expect(estateUnit(tester), 'تومان');
      expect(tester.takeException(), isNull);
    });
  });
}

/// Both calculators mounted at once, like two live tabs: the unselected one
/// stays built and listening.
class _Shell extends StatelessWidget {
  const _Shell({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          FitrZakatTab(),
          InheritanceScreen(),
        ],
      ),
    );
  }
}
