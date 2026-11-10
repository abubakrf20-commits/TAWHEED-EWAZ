import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:tawheeed/features/tools/zakat/presentation/screens/zakat_screen.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';

/// A preferences store that is always broken — a full disk, a locked profile,
/// a platform channel that never answers.
class _DeadStore extends SharedPreferencesStorePlatform {
  @override
  Future<bool> clear() async => throw StateError('prefs unavailable');

  @override
  Future<Map<String, Object>> getAll() async =>
      throw StateError('prefs unavailable');

  @override
  Future<bool> remove(String key) async => throw StateError('prefs unavailable');

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw StateError('prefs unavailable');
}

/// The zakat calculator's answer must not depend on being able to remember the
/// market prices.
///
/// WHY: `_calculate` used to await `ZakatPriceStore.load` + `.save` **before**
/// `setState`, so a throwing prefs write aborted the method after the result had
/// already been computed — and threw it away. The reader tapped «محاسبه زکات»
/// and the screen did nothing at all: no answer, no error, a dead button. Saving
/// the prices is a side effect of pressing the button, not a precondition for it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CurrencyStore.calculators.notifier.value = AppCurrency.toman;
  });

  tearDown(() {
    // Reinstalls the in-memory store and drops the cached instance, so a failed
    // read here cannot poison the next test file.
    SharedPreferences.setMockInitialValues({});
    CurrencyStore.calculators.notifier.value = AppCurrency.toman;
  });

  testWidgets('a dead preferences store still yields an answer', (tester) async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance = _DeadStore();

    tester.view.physicalSize = const Size(900, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: ZakatScreen()));
    await tester.pump();

    // The screen still builds: every load in initState is guarded.
    expect(find.text('محاسبه زکات'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'شتر'), '145');
    await tester.tap(find.text('حول (یک سال قمری) کامل شده است'));
    await tester.tap(find.text('دام سائمه (چرانیده در چراگاه) است'));
    await tester.pump();

    // A market price forces the save path the store cannot serve.
    await tester.enterText(
        find.widgetWithText(TextField, 'قیمت هر گرم طلای 24 عیار'), '1000000');
    await tester.pump();

    await tester.tap(find.text('محاسبه زکات'));
    await tester.pumpAndSettle();

    // The answer is on screen — the failed write did not take it down.
    expect(find.textContaining('1 بنت لبون + 2 حِقّه'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
