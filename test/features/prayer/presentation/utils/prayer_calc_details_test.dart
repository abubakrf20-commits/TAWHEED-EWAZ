import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/presentation/utils/prayer_calc_details.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';

void main() {
  group('buildCalculationDetails', () {
    test('custom method: shows user angles, madhab, altitude and adjustments',
        () {
      const settings = AppSettings(
        calculationMethod: CalculationMethodOption.custom,
        customFajrAngle: 17.5,
        customIshaAngle: 14,
        asrMethod: AsrMethod.hanafi,
        fajrOffset: 2,
        maghribOffset: 3,
      );
      // Mirrors PrayerRepositoryImpl._getCalculationParams for the custom path.
      final params = adhan.CalculationParameters(
        fajrAngle: settings.customFajrAngle,
        ishaAngle: settings.customIshaAngle,
        madhab: adhan.Madhab.hanafi,
      );
      final rows = buildCalculationDetails(
        settings: settings,
        cityName: 'تهران',
        coordinates: adhan.Coordinates(35.6892, 51.3890),
        params: params,
        altitude: 1190.5,
        date: DateTime(2026, 8, 11),
      );

      String valueOf(String label) =>
          rows.firstWhere((r) => r.label == label).value;

      expect(valueOf('شهر'), 'تهران');
      expect(valueOf('مختصات'), '35.6892، 51.3890');
      expect(valueOf('ارتفاع از سطح دریا'), '1191 متر');
      expect(valueOf('روش محاسبه'), 'روش محاسبه مخصص');
      expect(valueOf('زاویه فجر'), '17.5 درجه');
      expect(valueOf('زاویه / فاصله عشاء'), '14 درجه');
      expect(valueOf('مذهب عصر'), 'حنفی (سایه دو برابر)');
      expect(valueOf('قانون عرض‌های بالا'), 'نیمهٔ شب');
      expect(valueOf('تنظیمات دستی اذان (دقیقه)'), 'فجر +2، مغرب +3');
      expect(valueOf('تاریخ محاسبه'), '2026/08/11');
    });

    test('um al-qura: isha is expressed as minutes after maghrib', () {
      final params = adhan.CalculationMethod.umm_al_qura.getParameters();
      expect(params.ishaAngle, isNull);
      expect(params.ishaInterval, 90);
      final rows = buildCalculationDetails(
        settings: const AppSettings(
            calculationMethod: CalculationMethodOption.ummAlQura),
        params: params,
      );
      String valueOf(String label) =>
          rows.firstWhere((r) => r.label == label).value;
      expect(valueOf('زاویه / فاصله عشاء'), '90 دقیقه پس از مغرب');
      expect(valueOf('زاویه فجر'), '18.5 درجه');
    });

    test('shafi madhab and integer angles render cleanly', () {
      final params =
          adhan.CalculationMethod.muslim_world_league.getParameters();
      final rows = buildCalculationDetails(
        settings: const AppSettings(),
        params: params,
      );
      String valueOf(String label) =>
          rows.firstWhere((r) => r.label == label).value;
      expect(valueOf('مذهب عصر'), 'شافعی (سایه یک برابر)');
      expect(valueOf('زاویه فجر'), '18 درجه');
      expect(valueOf('زاویه / فاصله عشاء'), '17 درجه');
      expect(valueOf('تنظیمات دستی اذان (دقیقه)'), 'بدون تغییر');
    });

    test('missing data falls back to placeholders', () {
      final rows = buildCalculationDetails(
        settings: const AppSettings(),
      );
      String valueOf(String label) =>
          rows.firstWhere((r) => r.label == label).value;
      expect(valueOf('شهر'), '—');
      expect(valueOf('مختصات'), '—');
      expect(valueOf('ارتفاع از سطح دریا'), 'نامشخص');
      expect(valueOf('تاریخ محاسبه'), '—');
      // No params → angle/madhab/high-latitude rows are omitted entirely.
      expect(rows.any((r) => r.label == 'زاویه فجر'), isFalse);
    });

    test('auto method names the country method it applied', () {
      final rows = buildCalculationDetails(
        settings: const AppSettings(city: 'مکه'),
      );
      String valueOf(String label) =>
          rows.firstWhere((r) => r.label == label).value;
      expect(
          valueOf('روش محاسبه'), 'خودکار — بر اساس کشور ← ام‌القرا (عربستان)');
    });

    test('an unknown country under auto shows the MWL fallback', () {
      final rows = buildCalculationDetails(
        settings: const AppSettings(city: 'دهکدهٔ ناشناخته'),
      );
      String valueOf(String label) =>
          rows.firstWhere((r) => r.label == label).value;
      expect(valueOf('روش محاسبه'),
          'خودکار — بر اساس کشور ← رابطه عالم اسلامی');
    });
  });
}
