import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/prayer/data/daos/period_record_dao.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_provider.dart';
import 'package:tawheeed/features/prayer/presentation/widgets/period_widgets.dart';

import '../../../../core/database/mock_daos.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> pumpHost(
      WidgetTester tester, DateTime day) async {
    final container = ProviderContainer(overrides: [
      periodRecordDaoProvider.overrideWithValue(MockPeriodRecordDao()),
    ]);
    addTearDown(container.dispose);
    // The sheet holds the notifier across a route push; without a live
    // listener the auto-disposing provider would drop it before it builds.
    final subscription =
        container.listen(periodProvider, (previous, next) {});
    addTearDown(subscription.close);
    await container.read(periodProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(builder: (context, ref, _) {
              return Center(
                child: ElevatedButton(
                  onPressed: () => showPeriodDayActions(
                      context, ref.read(periodProvider.notifier), day),
                  child: const Text('open-sheet'),
                ),
              );
            }),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-sheet'));
    return container;
  }

  testWidgets('a future day explains itself instead of opening the sheet',
      (tester) async {
    await pumpHost(
        tester, DateTime.now().add(const Duration(days: 1)));
    await tester.pump();

    expect(find.text('روزهای آینده را نمی‌توان ثبت کرد.'), findsOneWidget);
    expect(find.text('شروع حیض'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('today still opens the actions sheet', (tester) async {
    await pumpHost(tester, DateTime.now());
    await tester.pumpAndSettle();

    expect(find.text('شروع حیض'), findsOneWidget);
    expect(find.text('روزهای آینده را نمی‌توان ثبت کرد.'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
