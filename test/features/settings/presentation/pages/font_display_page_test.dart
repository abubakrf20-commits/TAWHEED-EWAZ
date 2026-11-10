import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/pages/settings_screen.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import '../../../../core/database/mock_daos.dart';

void main() {
  late MockSettingsRepository mockRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockRepo = MockSettingsRepository()..setMockSettings(const AppSettings());
  });

  Widget wrap() => ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
        ],
        child: const MaterialApp(home: FontDisplayPage()),
      );

  testWidgets('font tile shows the display label, not the raw enum name',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Regression: options used to be PascalCase strings compared against
    // `fontFamily.name` (lowercase), so the checkmark never matched and the
    // raw enum name leaked into the subtitle.
    // Default AppSettings.fontFamily is calibri.
    expect(find.text('Calibri (Bold)'), findsOneWidget);
    expect(find.text('calibri'), findsNothing);
    expect(find.text('vazirmatn'), findsNothing);

    // Open the picker — every option shows its display label.
    await tester.tap(find.text('فونت برنامه'));
    await tester.pumpAndSettle();
    expect(find.text('Vazirmatn'), findsOneWidget);
    expect(find.text('Amiri'), findsOneWidget);
    // Subtitle still shows the current selection while the sheet is open.
    expect(find.text('Calibri (Bold)'), findsNWidgets(2));

    // Choose Vazirmatn: the sheet closes, the subtitle updates and the
    // change is persisted through the canonical settings notifier.
    await tester.tap(find.text('Vazirmatn'));
    await tester.pumpAndSettle();

    expect(mockRepo.getMockSettings().fontFamily, FontFamilyOption.vazirmatn);
    expect(find.text('Vazirmatn'), findsOneWidget);
    expect(find.text('calibri'), findsNothing);
  });
}
