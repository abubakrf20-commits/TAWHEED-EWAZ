import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/home/presentation/widgets/period_hayz_banner.dart';
import 'package:tawheeed/features/prayer/data/daos/period_record_dao.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_provider.dart';

import '../../../../core/database/mock_daos.dart';

void main() {
  late MockPeriodRecordDao mockDao;
  late ProviderContainer container;

  setUp(() {
    mockDao = MockPeriodRecordDao();
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(overrides: [
      periodRecordDaoProvider.overrideWithValue(mockDao),
    ]);
    addTearDown(container.dispose);
  });

  Future<void> pumpBanner(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: PeriodHayzBanner())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Unmount the tree and pump a frame so Riverpod's scheduled provider
  /// disposal (vsync timer) runs inside the test — otherwise the framework
  /// reports a pending timer at teardown.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('banner is hidden when no period covers today', (tester) async {
    await pumpBanner(tester);

    expect(find.textContaining('ایام حیض'), findsNothing);
    await unmount(tester);
  });

  testWidgets(
      'banner appears right after a new period covering today is recorded',
      (tester) async {
    await pumpBanner(tester);
    expect(find.textContaining('ایام حیض'), findsNothing);

    // Record a new period starting today — the banner must show up without
    // any manual refresh, driven by the same periodProvider as the scores.
    final notifier = container.read(periodProvider.notifier);
    await notifier.startPeriod(DateTime.now());
    await tester.pump();

    expect(find.textContaining('ایام حیض'), findsOneWidget);
    expect(find.textContaining('نماز و روزه ساقط است'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('banner hides when the active period is deleted', (tester) async {
    await pumpBanner(tester);
    expect(find.textContaining('ایام حیض'), findsNothing);

    final notifier = container.read(periodProvider.notifier);
    await notifier.startPeriod(DateTime.now());
    await tester.pump();
    expect(find.textContaining('ایام حیض'), findsOneWidget);

    final state = container.read(periodProvider).value!;
    await notifier.deleteRecord(state.records.first.id);
    await tester.pump();

    expect(find.textContaining('ایام حیض'), findsNothing);
    await unmount(tester);
  });

  testWidgets('banner ignores a period that ended before today',
      (tester) async {
    await pumpBanner(tester);
    expect(find.textContaining('ایام حیض'), findsNothing);

    final notifier = container.read(periodProvider.notifier);

    // A completed period that does not cover today must not show the banner.
    final pastStart = DateTime.now().subtract(const Duration(days: 20));
    await notifier.startPeriod(pastStart);
    await notifier.endPeriod(pastStart.add(const Duration(days: 6)));
    await tester.pump();

    expect(find.textContaining('ایام حیض'), findsNothing);
    await unmount(tester);
  });
}
