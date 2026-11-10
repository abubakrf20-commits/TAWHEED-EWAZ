import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/settings/data/models/app_settings_model.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/services/settings_transfer_service.dart';
import 'package:tawheeed/shared/models/day_time.dart';

/// Settings-only transfer («انتقال تنظیمات») — encodes the AppSettings entity
/// into a small versioned JSON document and decodes it back. The service is
/// pure (string in / string out) so every boundary — envelope, version,
/// damaged payloads — is testable without IO or plugins.
void main() {
  Map<String, dynamic> dtoJson(AppSettings s) =>
      AppSettingsDto.fromEntity(s).toJson();

  /// `AppSettings` has no ==, and the DTO map holds live `List` values
  /// (`quickActions`), which `mapEquals` would compare by identity — so the
  /// canonical JSON strings are the exact-equality check here.
  void expectSameSettings(AppSettings a, AppSettings b) {
    expect(jsonEncode(dtoJson(a)), jsonEncode(dtoJson(b)),
        reason: 'setting fields differ after transfer');
  }

  test('round-trips a fully customised entity', () {
    const settings = AppSettings(
      calculationMethod: CalculationMethodOption.karachi,
      asrMethod: AsrMethod.hanafi,
      highLatitudeRule: HighLatitudeRuleOption.twilightAngle,
      useLocation: false,
      city: 'مشهد',
      manualLat: 36.31,
      manualLng: 59.56,
      hasLocation: true,
      customFajrAngle: 17.5,
      customIshaAngle: 16.0,
      fajrOffset: 1,
      ishaOffset: -1,
      globalPrayerOffset: 2,
      iqamahOffsetFajr: 15,
      iqamahOffsetIsha: 20,
      fardhPoint: 12,
      sunnahPoint: 6,
      worshipMultiplier: 1.5,
      excludedWorship: ['nocte'],
      hiddenWorshipItems: ['tasbih'],
      prayerNotifications: false,
      prayerNotifMinutes: 10,
      morningAzkarNotification: false,
      eveningAzkarTime: DayTime(hour: 21, minute: 30),
      quranReminder: true,
      quranReminderTime: DayTime(hour: 9, minute: 15),
      silentDuringPrayer: true,
      silentDuration: 20,
      silentBeforeIqamah: true,
      silentBeforeIqamahMinutes: 5,
      dailyVerse: false,
      dailyHadith: false,
      themeMode: ThemeModeOption.dark,
      quranThemeMode: QuranThemeMode.dark,
      fontFamily: FontFamilyOption.amiri,
      showArabicText: false,
      showDaleel: false,
      quranFontSize: 26.0,
      appFontSize: 18.0,
      accentPreset: 'gold',
      isPremium: true,
      use12Hour: false,
      azanSound: 'makkah',
      azanVolume: 0.8,
      azanEnabledForFajr: true,
      azanEnabledForIsha: true,
      widgetRefreshMinutes: 60,
      tafsirId: 300,
      elevationCorrection: true,
      onboardingCompleted: true,
      hijriOffset: 5,
      quickActions: ['qibla'],
      tasbihDhikrSource: 'tasbih',
    );

    final decoded = decodeSettingsTransfer(encodeSettingsTransfer(settings));

    expect(decoded, isNotNull);
    expectSameSettings(decoded!, settings);
  });

  test('round-trips the factory defaults', () {
    const settings = AppSettings();
    final decoded = decodeSettingsTransfer(encodeSettingsTransfer(settings));
    expect(decoded, isNotNull);
    expectSameSettings(decoded!, settings);
  });

  test('envelope carries type, version and a parseable timestamp', () {
    final raw = encodeSettingsTransfer(const AppSettings());
    final map = jsonDecode(raw) as Map<String, dynamic>;

    expect(map['type'], kSettingsTransferType);
    expect(map['version'], kSettingsTransferVersion);
    final exportedAt = map['exportedAt'] as String;
    expect(DateTime.tryParse(exportedAt), isNotNull);
  });

  test('rejects non-JSON input', () {
    expect(decodeSettingsTransfer('not json at all'), isNull);
  });

  test('rejects a JSON that is not a transfer document', () {
    expect(
      decodeSettingsTransfer(jsonEncode({'type': 'something_else'})),
      isNull,
    );
    expect(
      decodeSettingsTransfer(jsonEncode({'type': kSettingsTransferType})),
      isNull, // missing settings payload
    );
  });

  test('rejects a newer transfer version (never silently misread)', () {
    final future = jsonEncode({
      'type': kSettingsTransferType,
      'version': kSettingsTransferVersion + 1,
      'settings': AppSettingsDto.fromEntity(const AppSettings()).toJson(),
    });
    expect(decodeSettingsTransfer(future), isNull);
  });

  test('rejects a non-integer version', () {
    expect(
      decodeSettingsTransfer(jsonEncode({
        'type': kSettingsTransferType,
        'version': '1',
        'settings': <String, dynamic>{},
      })),
      isNull,
    );
  });

  test('rejects a damaged settings payload', () {
    expect(
      decodeSettingsTransfer(jsonEncode({
        'type': kSettingsTransferType,
        'version': 1,
        'settings': {'hijriOffset': 'not-an-int'},
      })),
      isNull,
    );
  });

  test('unknown extra fields still import (forward compatibility)', () {
    final doc = jsonEncode({
      'type': kSettingsTransferType,
      'version': 1,
      'exportedAt': '2026-10-13T00:00:00.000Z',
      'settings': {
        ...AppSettingsDto.fromEntity(const AppSettings()).toJson(),
        'futureSetting': 'from-a-newer-build',
      },
    });
    final decoded = decodeSettingsTransfer(doc);
    expect(decoded, isNotNull);
    expectSameSettings(decoded!, const AppSettings());
  });
}