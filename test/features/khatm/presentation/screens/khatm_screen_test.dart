import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/khatm/presentation/screens/khatm_screen.dart';
import 'package:tawheeed/features/khatm/presentation/widgets/khatm/khatm_cards.dart';
import 'package:tawheeed/features/khatm/presentation/providers/khatm_provider.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';

class _MockKhatm extends Khatm {
  @override
  Future<KhatmModel?> build() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (methodCall) async {
      if (methodCall.method == 'getAll') return <String, dynamic>{};
      // shared_preferences v2 uses typed setters (setBool/setString/...).
      return true;
    },
  );

  testWidgets('KhatmScreen shows empty state with title', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          khatmProvider.overrideWith(_MockKhatm.new),
          allKhatmsProvider.overrideWith((ref) async => <KhatmModel>[]),
        ],
        child: const MaterialApp(home: KhatmScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(KhatmScreen), findsOneWidget);
    expect(find.text('ختم قرآن'), findsWidgets);
  });

  testWidgets('KhatmReminderCard toggles on and offers time picker',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: KhatmReminderCard(dailyTarget: 8),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Default: disabled, no time row.
    expect(find.text('خاموش'), findsOneWidget);
    expect(find.text('ساعت یادآوری'), findsNothing);

    // Enable → badge shows the default time and the time row appears.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('خاموش'), findsNothing);
    expect(find.text('روزانه 08:00'), findsOneWidget);
    expect(find.text('ساعت یادآوری'), findsOneWidget);

    // Time row opens the numeric time dialog.
    await tester.tap(find.text('ساعت یادآوری'));
    await tester.pumpAndSettle();
    expect(find.text('ساعت یادآوری روزانه'), findsOneWidget);

    // Changing the time updates the badge.
    await tester.enterText(find.byType(TextField).at(0), '21');
    await tester.enterText(find.byType(TextField).at(1), '30');
    await tester.tap(find.text('تأیید'));
    await tester.pumpAndSettle();
    expect(find.text('روزانه 21:30'), findsOneWidget);
  });
}
