import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/prayer/services/silent_mode_service.dart';
import 'package:tawheeed/features/settings/presentation/widgets/silent_after_iqamah_tile.dart';

/// Widget tests for the silent-after-iqamah tile (Audit 8.21-4).
///
/// The service reads/writes SharedPreferences directly, so
/// `SharedPreferences.setMockInitialValues` is the real seam: the tile's
/// loaded value and every −/+ write can be asserted through the store.
///
/// The reschedule path (DailyNotificationScheduler through
/// prayerTimeServiceProvider) is best-effort by contract; the test
/// environment throws MissingPluginException on the method channel, which the
/// tile must swallow (the "channel tweak failed" warning) without breaking
/// the UI — asserted implicitly by every test completing without an
/// unhandled exception.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpTile(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: Scaffold(body: SilentAfterIqamahTile())),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads the persisted value and shows it with its subtitle',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {SilentModeService.afterIqamahMinutesKey: 7});
    await pumpTile(tester);

    expect(find.text('7'), findsOneWidget);
    expect(find.textContaining('باز شدن صدا 7 دقیقه بعد از اقامه'),
        findsOneWidget);
  });

  testWidgets('zero shows the exact-iqamah subtitle', (tester) async {
    await pumpTile(tester);

    expect(find.text('0'), findsOneWidget);
    expect(find.text('باز شدن صدا دقیقاً هنگام اقامه'), findsOneWidget);
  });

  testWidgets('the + button persists the new value through the service',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {SilentModeService.afterIqamahMinutesKey: 118});
    await pumpTile(tester);

    // Audit 8.21-4: the cap is the service's 0..120 — 118 → 119 must work
    // (the old UI-side 60 cap greyed the button far below the real limit).
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('119'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(SilentModeService.afterIqamahMinutesKey), 119);
  });

  testWidgets('at zero the − button is disabled and nothing is written',
      (tester) async {
    await pumpTile(tester);

    final minus = find
        .ancestor(
          of: find.byIcon(Icons.remove_rounded),
          matching: find.byType(GestureDetector),
        )
        .first;
    expect(tester.widget<GestureDetector>(minus).onTap, isNull);
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(SilentModeService.afterIqamahMinutesKey), isNull);
  });
}
