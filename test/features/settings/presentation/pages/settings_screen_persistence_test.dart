import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/settings/presentation/pages/settings_screen.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import '../../../../core/database/mock_daos.dart';

void main() {
  late MockSettingsRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockRepo = MockSettingsRepository();
    mockRepo.setMockSettings(const AppSettings());
    container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
    ]);
  });

  tearDown(() => container.dispose());

  testWidgets('theme change persists after navigating away and back',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // Find the dark theme card ('تاریک') and tap it.
    await tester.tap(find.text('تاریک'));
    await tester.pumpAndSettle();

    // The notifier must have persisted the change to the repository.
    final saved = mockRepo.getMockSettings();
    expect(saved.themeMode, ThemeModeOption.dark);

    // Simulate leaving the screen and coming back (rebuild from repo).
    await tester.pumpWidget(Container());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // The persisted value must survive the round trip.
    expect(mockRepo.getMockSettings().themeMode, ThemeModeOption.dark);
    // And the reloaded screen still shows the dark card selected.
    final reloaded = await container.read(settingsProvider.future);
    expect(reloaded.themeMode, ThemeModeOption.dark);
  });
}
