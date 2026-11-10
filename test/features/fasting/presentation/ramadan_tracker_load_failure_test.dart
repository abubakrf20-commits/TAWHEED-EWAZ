import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:tawheeed/features/fasting/presentation/tabs/ramadan_tracker_tab.dart';
import 'package:tawheeed/features/ramadan/presentation/providers/ramadan_provider.dart';

/// A preferences store that is always broken.
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

/// The tracker must not turn a failed read into a claim about the reader's
/// worship.
///
/// WHY: `_loadData` used to swallow the error and leave every map empty, and an
/// empty map renders as «۰/۳۰» — so a reader who had ticked twenty days was told
/// they had ticked none, with no hint that anything had gone wrong. The counters
/// and the day grid now step aside for a panel that says what happened and
/// offers a retry; the guide below them is static and stays.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap() => ProviderScope(
        overrides: [
          // The tracker's own rows are what fails here; the calendar provider
          // reads prayer settings and is not the subject of this test.
          ramadanProvider.overrideWithValue(const RamadanState()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RamadanTrackerTab()),
        ),
      );

  testWidgets('a failed read says so instead of showing 0/30', (tester) async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance = _DeadStore();

    tester.view.physicalSize = const Size(900, 9000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('failure_ramadan_tracker_load')),
        findsOneWidget);
    expect(find.text('وضعیت روزه‌ها خوانده نشد'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsOneWidget);

    // The three claims the page must not make.
    expect(find.textContaining('0/30'), findsNothing);
    expect(find.textContaining('باقی‌مانده:'), findsNothing);

    // The static guide is still there — only the unreadable part stepped aside.
    expect(find.text('فضایل ماه رمضان'), findsOneWidget);
    expect(find.text('اعتکاف'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a readable store shows the counters as usual', (tester) async {
    tester.view.physicalSize = const Size(900, 9000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('وضعیت روزه‌ها خوانده نشد'), findsNothing);
    expect(find.text('0/30'), findsWidgets);
  });
}
