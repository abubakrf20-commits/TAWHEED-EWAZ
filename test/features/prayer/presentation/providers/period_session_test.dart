import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/prayer/presentation/providers/period_session.dart';

void main() {
  testWidgets('پس از رفتن به پس‌زمینه، نشست دوره دوباره قفل می‌شود',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(periodSessionProvider), isFalse);
    container.read(periodSessionProvider.notifier).unlock();
    expect(container.read(periodSessionProvider), isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(container.read(periodSessionProvider), isFalse);
  });

  testWidgets('زنگ تلفن، فرم نیمه‌تمام را قفل نمی‌کند', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(periodSessionProvider.notifier).unlock();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(container.read(periodSessionProvider), isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(container.read(periodSessionProvider), isTrue);
  });
}
