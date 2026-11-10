import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/models/day_time.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('constructor sets default values', () {
      const settings = AppSettings();
      expect(settings.id, 'default');
      expect(settings.calculationMethod, CalculationMethodOption.auto);
      expect(settings.asrMethod, AsrMethod.shafi);
      expect(settings.useLocation, true);
      expect(settings.city, isNull);
      expect(settings.hasLocation, false);
      expect(settings.customFajrAngle, 18.0);
      expect(settings.customIshaAngle, 17.0);
      expect(settings.fajrOffset, 0);
      expect(settings.maghribOffset, 0);
      expect(settings.iqamahOffsetFajr, 30);
      expect(settings.iqamahOffsetMaghrib, 10);
      expect(settings.prayerNotifications, true);
      expect(settings.morningAzkarTime, const DayTime(hour: 6, minute: 0));
      expect(settings.eveningAzkarTime, const DayTime(hour: 20, minute: 0));
      expect(settings.quranReminderTime, const DayTime(hour: 8, minute: 0));
      expect(settings.themeMode, ThemeModeOption.light);
      expect(settings.fontFamily, FontFamilyOption.calibri);
      expect(settings.fontScale, 1.0);
      expect(settings.showArabicText, true);
      expect(settings.showDaleel, true);
      expect(settings.largeArabicFont, false);
      expect(settings.showEnglishTranslation, false);
      expect(settings.quranFontSize, 22.0);
      expect(settings.appFontSize, 15.0);
      expect(settings.accentPreset, 'night');
      expect(settings.isPremium, false);
      expect(settings.use12Hour, true);
      expect(settings.azanSound, 'takbir');
      expect(settings.azanVolume, 1.0);
      expect(settings.azanEnabledForFajr, false);
      expect(settings.widgetRefreshMinutes, 30);
      expect(settings.tafsirId, 169);
      expect(settings.firstLaunch, true);
      expect(settings.onboardingCompleted, false);
      expect(settings.hijriOffset, 2);
      expect(settings.quickActions, ['qibla', 'khatm']);
      expect(settings.tasbihDhikrSource, 'own');
      expect(settings.timezone, 'Asia/Tehran');
    });

    test(
        'azan is disabled by default and anyAzanEnabled reflects per-prayer toggles',
        () {
      const settings = AppSettings();
      // Default: azan for prayers must be OFF.
      expect(settings.azanEnabledForFajr, false);
      expect(settings.azanEnabledForDhuhr, false);
      expect(settings.azanEnabledForAsr, false);
      expect(settings.azanEnabledForMaghrib, false);
      expect(settings.azanEnabledForIsha, false);
      expect(settings.anyAzanEnabled, false);

      // Enabling any single prayer makes the audible azan active.
      expect(
          settings.copyWith(azanEnabledForFajr: true).anyAzanEnabled, isTrue);
      expect(
          settings.copyWith(azanEnabledForIsha: true).anyAzanEnabled, isTrue);

      // Toggling it back off disables it again (all five off).
      expect(
          settings
              .copyWith(azanEnabledForFajr: true)
              .copyWith(azanEnabledForFajr: false)
              .anyAzanEnabled,
          isFalse);
    });

    test('constructor sets custom values', () {
      const settings = AppSettings(
        id: 'custom',
        useLocation: false,
        city: 'Qom',
        manualLat: 34.64,
        manualLng: 50.88,
        hasLocation: true,
        customFajrAngle: 17.0,
        customIshaAngle: 14.0,
        fajrOffset: 2,
        maghribOffset: 3,
        iqamahOffsetFajr: 20,
        prayerNotifications: false,
        themeMode: ThemeModeOption.dark,
        fontFamily: FontFamilyOption.amiri,
        fontScale: 1.2,
        showArabicText: false,
        isPremium: true,
        use12Hour: false,
        azanSound: 'makkah',
        customAzanPath: '/custom/azan.mp3',
        azanVolume: 0.8,
        firstLaunch: false,
        onboardingCompleted: true,
      );
      expect(settings.id, 'custom');
      expect(settings.calculationMethod, CalculationMethodOption.auto);
      expect(settings.asrMethod, AsrMethod.shafi);
      expect(settings.useLocation, false);
      expect(settings.city, 'Qom');
      expect(settings.manualLat, 34.64);
      expect(settings.manualLng, 50.88);
      expect(settings.customFajrAngle, 17.0);
      expect(settings.customAzanPath, '/custom/azan.mp3');
      expect(settings.themeMode, ThemeModeOption.dark);
    });

    group('copyWith', () {
      test('creates new object with same field values when no args', () {
        const settings = AppSettings();
        final copy = settings.copyWith();
        expect(copy.id, settings.id);
        expect(copy.calculationMethod, settings.calculationMethod);
      });

      test('replaces single field', () {
        const settings = AppSettings();
        final copy = settings.copyWith(city: 'Mashhad');
        expect(copy.city, 'Mashhad');
        expect(copy.id, 'default');
      });

      test('replaces calculation method', () {
        const settings = AppSettings();
        final copy = settings.copyWith(
          calculationMethod: CalculationMethodOption.ummAlQura,
        );
        expect(copy.calculationMethod, CalculationMethodOption.ummAlQura);
      });

      test('replaces quickActions list', () {
        const settings = AppSettings();
        final copy = settings.copyWith(quickActions: ['qibla']);
        expect(copy.quickActions, ['qibla']);
      });
    });
  });

  group('CalculationMethodOption', () {
    test('has all values', () {
      expect(CalculationMethodOption.values.length, 18);
    });

    test('index order is frozen: DB stores index, append-only', () {
      // The Drift settings table stores the int index, so inserting a value in
      // the middle silently reinterprets every stored row. Append only.
      expect(
        CalculationMethodOption.values.take(13).map((e) => e.name).toList(),
        [
          'muslimWorldLeague',
          'karachi',
          'ummAlQura',
          'egyptian',
          'tehran',
          'turkey',
          'dubai',
          'kuwait',
          'qatar',
          'singapore',
          'northAmerica',
          'moonsightingCommittee',
          'custom',
        ],
      );
      expect(
        CalculationMethodOption.values.sublist(13).map((e) => e.name).toList(),
        ['jafari', 'france', 'russia', 'gulfRegion', 'auto'],
      );
    });

    test('muslimWorldLeague label', () {
      expect(
          CalculationMethodOption.muslimWorldLeague.label, contains('اسلامی'));
    });

    test('karachi label is Pakistan-only (Iran is the Tehran method)', () {
      final label = CalculationMethodOption.karachi.label;
      expect(label, contains('کراچی'));
      expect(label, contains('پاکستان'));
      expect(label, isNot(contains('ایران')));
    });

    test('auto label names the by-country behaviour', () {
      final label = CalculationMethodOption.auto.label;
      expect(label, contains('خودکار'));
      expect(label, contains('کشور'));
    });

    test('tehran label', () {
      expect(CalculationMethodOption.tehran.label, contains('تهران'));
    });

    test('custom label', () {
      expect(CalculationMethodOption.custom.label, contains('مخصص'));
    });
  });

  group('AsrMethod', () {
    test('has both values', () {
      expect(AsrMethod.values.length, 2);
    });

    test('hanafi label', () {
      expect(AsrMethod.hanafi.label, contains('حنفی'));
    });

    test('shafi label', () {
      expect(AsrMethod.shafi.label, contains('شافعی'));
    });
  });

  group('HighLatitudeRuleOption', () {
    test('has all three values with labels', () {
      expect(HighLatitudeRuleOption.values.length, 3);
      expect(HighLatitudeRuleOption.middleOfTheNight.label, isNotEmpty);
      expect(HighLatitudeRuleOption.seventhOfTheNight.label, isNotEmpty);
      expect(HighLatitudeRuleOption.twilightAngle.label, isNotEmpty);
    });

    test('index order is frozen: DB stores index, native widget reads 0/1/2',
        () {
      // Changing this order (or inserting a value in the middle) silently
      // reinterprets every stored setting AND the Kotlin widget contract
      // (0 = middle, 1 = seventh, 2 = twilight). Append-only.
      expect(HighLatitudeRuleOption.values.map((e) => e.name).toList(), [
        'middleOfTheNight',
        'seventhOfTheNight',
        'twilightAngle',
      ]);
    });

    test('copyWith carries the rule', () {
      const base = AppSettings();
      final updated = base.copyWith(
          highLatitudeRule: HighLatitudeRuleOption.seventhOfTheNight);
      expect(
          updated.highLatitudeRule, HighLatitudeRuleOption.seventhOfTheNight);
      expect(base.highLatitudeRule, HighLatitudeRuleOption.middleOfTheNight);
    });
  });

  group('ThemeModeOption', () {
    test('has all values', () {
      expect(ThemeModeOption.values.length, 3);
      expect(
          ThemeModeOption.values,
          containsAll([
            ThemeModeOption.light,
            ThemeModeOption.dark,
            ThemeModeOption.system,
          ]));
    });
  });

  group('FontFamilyOption', () {
    test('has all values', () {
      // Appended last, so every stored value keeps its position: the enum is
      // persisted by NAME, and the four user-supplied faces joined after Harir.
      expect(FontFamilyOption.values.length, 9);
      expect(
          FontFamilyOption.values,
          containsAll([
            FontFamilyOption.vazirmatn,
            FontFamilyOption.amiri,
            FontFamilyOption.calibri,
            FontFamilyOption.tktTika,
            FontFamilyOption.harir,
            FontFamilyOption.parastoo,
            FontFamilyOption.sakkalMajalla,
            FontFamilyOption.sultanMedium,
            FontFamilyOption.tabliq,
          ]));
    });

    test('vazirmatn name', () {
      expect(FontFamilyOption.vazirmatn.name, 'Vazirmatn');
    });

    test('amiri name', () {
      expect(FontFamilyOption.amiri.name, 'Amiri');
    });

    test('calibri name', () {
      expect(FontFamilyOption.calibri.name, 'Calibri');
    });

    test('tiktika family name matches the pubspec family', () {
      expect(FontFamilyOption.tktTika.name, 'TKT-Tika');
    });

    test('harir family name matches the pubspec family', () {
      expect(FontFamilyOption.harir.name, 'Harir');
    });
  });
}
