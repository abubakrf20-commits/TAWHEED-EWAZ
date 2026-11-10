import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import '../../../../core/database/mock_daos.dart';

void main() {
  late ProviderContainer container;
  late MockSettingsRepository mockRepo;

  setUp(() {
    mockRepo = MockSettingsRepository();
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  test('build returns default AppSettings when repository has defaults',
      () async {
    mockRepo.setMockSettings(const AppSettings());
    final settings = await container.read(settingsProvider.future);
    expect(settings.id, equals('default'));
    expect(settings.calculationMethod, equals(CalculationMethodOption.auto));
    expect(settings.themeMode, equals(ThemeModeOption.light));
  });

  test('build returns custom settings from repository', () async {
    const custom = AppSettings(
      themeMode: ThemeModeOption.dark,
      showArabicText: false,
    );
    mockRepo.setMockSettings(custom);
    final settings = await container.read(settingsProvider.future);
    expect(settings.calculationMethod, equals(CalculationMethodOption.auto));
    expect(settings.themeMode, equals(ThemeModeOption.dark));
    expect(settings.showArabicText, isFalse);
  });

  Future<void> initSettings() async {
    mockRepo.setMockSettings(const AppSettings());
    await container.read(settingsProvider.future);
  }

  test('setCalcMethod updates calculation method', () async {
    await initSettings();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setCalcMethod(CalculationMethodOption.karachi);
    final settings = await container.read(settingsProvider.future);
    expect(settings.calculationMethod, equals(CalculationMethodOption.karachi));
  });

  test('setThemeMode updates theme mode', () async {
    await initSettings();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setThemeMode(ThemeModeOption.dark);
    final settings = await container.read(settingsProvider.future);
    expect(settings.themeMode, equals(ThemeModeOption.dark));
  });

  test('setPrayerNotifications toggles prayer notifications', () async {
    await initSettings();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setPrayerNotifications(false);
    final settings = await container.read(settingsProvider.future);
    expect(settings.prayerNotifications, isFalse);
  });

  test('setAzanSound updates azan sound', () async {
    await initSettings();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setAzanSound('makkah');
    final settings = await container.read(settingsProvider.future);
    expect(settings.azanSound, equals('makkah'));
  });

  test('setHijriOffset updates hijri offset', () async {
    await initSettings();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setHijriOffset(2);
    final settings = await container.read(settingsProvider.future);
    expect(settings.hijriOffset, equals(2));
  });

  test('setUse12Hour toggles 12 hour format', () async {
    await initSettings();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setUse12Hour(false);
    final settings = await container.read(settingsProvider.future);
    expect(settings.use12Hour, isFalse);
  });

  test('setFontFamily updates font family', () async {
    await initSettings();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setFontFamily(FontFamilyOption.amiri);
    final settings = await container.read(settingsProvider.future);
    expect(settings.fontFamily, equals(FontFamilyOption.amiri));
  });

  test('setFontScale keeps fontScale and appFontSize in sync', () async {
    await initSettings();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setFontScale(18.0);
    final settings = await container.read(settingsProvider.future);
    expect(settings.appFontSize, equals(18.0));
    expect(settings.fontScale, equals(18.0 / 15.0));
  });

  test('resetPreferences restores defaults but keeps onboarding + premium',
      () async {
    mockRepo.setMockSettings(const AppSettings(
      themeMode: ThemeModeOption.dark,
      accentPreset: 'gold',
      hijriOffset: 5,
      fontFamily: FontFamilyOption.amiri,
      onboardingCompleted: true,
      isPremium: true,
    ));
    await container.read(settingsProvider.future);
    final notifier = container.read(settingsProvider.notifier);

    await notifier.resetPreferences();

    final saved = mockRepo.getMockSettings();
    // Preferences are back to their factory defaults...
    expect(saved.themeMode, ThemeModeOption.light);
    expect(saved.accentPreset, 'night');
    expect(saved.hijriOffset, 2);
    expect(saved.fontFamily, FontFamilyOption.calibri);
    // ...while the two non-preference fields survive (a reset must never log
    // the user out of onboarding or drop premium).
    expect(saved.onboardingCompleted, isTrue);
    expect(saved.isPremium, isTrue);
  });

  test('importPreferences applies the file values but keeps onboarding + premium',
      () async {
    mockRepo.setMockSettings(const AppSettings(
      themeMode: ThemeModeOption.dark,
      accentPreset: 'gold',
      hijriOffset: 5,
      onboardingCompleted: true,
      isPremium: true,
    ));
    await container.read(settingsProvider.future);
    final notifier = container.read(settingsProvider.notifier);

    await notifier.importPreferences(const AppSettings(
      hijriOffset: 7,
      customFajrAngle: 17.5,
    ));

    final saved = mockRepo.getMockSettings();
    // Preferences come from the file...
    expect(saved.themeMode, ThemeModeOption.light);
    expect(saved.accentPreset, 'night');
    expect(saved.hijriOffset, 7);
    expect(saved.customFajrAngle, 17.5);
    // ...while the two non-preference fields survive.
    expect(saved.onboardingCompleted, isTrue);
    expect(saved.isPremium, isTrue);
  });
}
