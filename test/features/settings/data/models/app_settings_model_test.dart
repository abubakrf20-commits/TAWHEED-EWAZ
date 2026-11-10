import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/settings/data/models/app_settings_model.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';

void main() {
  group('AppSettingsDto', () {
    test('should create from JSON', () {
      final json = {
        'id': 'default',
        'calculationMethod': 'muslimWorldLeague',
        'asrMethod': 'shafi',
        'useLocation': true,
        'prayerNotifications': true,
        'prayerNotifMinutes': 5,
        'themeMode': 'system',
        'fontFamily': 'vazirmatn',
        'fontScale': 1.0,
        'isPremium': false,
      };

      final model = AppSettingsDto.fromJson(json);

      expect(model.id, 'default');
      expect(
          model.calculationMethod, CalculationMethodOption.muslimWorldLeague);
      expect(model.prayerNotifications, true);
      expect(model.fontScale, 1.0);
    });

    test('should convert to JSON', () {
      const model = AppSettingsDto(
        calculationMethod: CalculationMethodOption.tehran,
        asrMethod: AsrMethod.hanafi,
        useLocation: false,
        prayerNotifMinutes: 10,
        themeMode: ThemeModeOption.dark,
        fontFamily: FontFamilyOption.amiri,
        fontScale: 1.2,
        isPremium: true,
      );

      final json = model.toJson();

      expect(json['calculationMethod'], 'tehran');
      expect(json['asrMethod'], 'hanafi');
      expect(json['themeMode'], 'dark');
      expect(json['fontFamily'], 'Amiri');
    });

    test('constructor defaults match entity defaults', () {
      const entity = AppSettings();
      const dto = AppSettingsDto();

      final mapped = dto.toEntity();
      expect(mapped.iqamahOffsetMaghrib, entity.iqamahOffsetMaghrib);
      expect(mapped.dailyHadithTime, entity.dailyHadithTime);
      expect(mapped.themeMode, entity.themeMode);
      expect(mapped.quranThemeMode, entity.quranThemeMode);
      expect(mapped.fontFamily, entity.fontFamily);
    });

    test('fromJson fallbacks match entity defaults', () {
      const entity = AppSettings();
      final dto = AppSettingsDto.fromJson(const {});

      final mapped = dto.toEntity();
      expect(mapped.iqamahOffsetMaghrib, entity.iqamahOffsetMaghrib);
      expect(mapped.dailyHadithTime, entity.dailyHadithTime);
      expect(mapped.themeMode, entity.themeMode);
      expect(mapped.quranThemeMode, entity.quranThemeMode);
      expect(mapped.fontFamily, entity.fontFamily);
    });

    test('highLatitudeRule defaults to middle of the night', () {
      const entity = AppSettings();
      expect(entity.highLatitudeRule, HighLatitudeRuleOption.middleOfTheNight);
      const dto = AppSettingsDto();
      expect(dto.highLatitudeRule, HighLatitudeRuleOption.middleOfTheNight);
      expect(AppSettingsDto.fromJson(const {}).highLatitudeRule,
          HighLatitudeRuleOption.middleOfTheNight);
    });

    test('highLatitudeRule survives JSON and entity round-trips', () {
      const dto = AppSettingsDto(
          highLatitudeRule: HighLatitudeRuleOption.twilightAngle);
      final json = dto.toJson();
      expect(json['highLatitudeRule'], 'twilightAngle');
      final back = AppSettingsDto.fromJson(json);
      expect(back.highLatitudeRule, HighLatitudeRuleOption.twilightAngle);
      expect(back.toEntity().highLatitudeRule,
          HighLatitudeRuleOption.twilightAngle);

      // Unknown/garbage values fall back to the default, never throw.
      final fallback =
          AppSettingsDto.fromJson(const {'highLatitudeRule': 'bogus'});
      expect(
          fallback.highLatitudeRule, HighLatitudeRuleOption.middleOfTheNight);
    });
  });
}
