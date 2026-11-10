import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/shared/services/widget_calc_params.dart';

void main() {
  const settings = AppSettings();

  test('preset methods resolve to the adhan package angles + adjustments', () {
    final mwl = widgetCalcParamsFor(
        CalculationMethodOption.muslimWorldLeague, settings);
    expect(mwl.fajrAngle, 18.0);
    expect(mwl.ishaAngle, 17.0);
    expect(mwl.maghribAngle, 0);
    expect(mwl.ishaInterval, 0);
    expect(mwl.methodAdjustments, [0, 0, 1, 0, 0, 0]);

    final tehran =
        widgetCalcParamsFor(CalculationMethodOption.tehran, settings);
    expect(tehran.fajrAngle, 17.7);
    expect(tehran.ishaAngle, 14.0);
    expect(tehran.maghribAngle, 4.5);
    expect(tehran.methodAdjustments, [0, 0, 0, 0, 0, 0]);
  });

  test('interval-based methods use ishaInterval instead of the isha angle', () {
    final ummAlQura =
        widgetCalcParamsFor(CalculationMethodOption.ummAlQura, settings);
    expect(ummAlQura.fajrAngle, 18.5);
    expect(ummAlQura.ishaInterval, 90);

    final qatar = widgetCalcParamsFor(CalculationMethodOption.qatar, settings);
    expect(qatar.fajrAngle, 18.0);
    expect(qatar.ishaInterval, 90);
  });

  test('turkey and dubai carry their method adjustments', () {
    final turkey =
        widgetCalcParamsFor(CalculationMethodOption.turkey, settings);
    expect(turkey.methodAdjustments, [0, -7, 5, 4, 7, 0]);

    final dubai = widgetCalcParamsFor(CalculationMethodOption.dubai, settings);
    expect(dubai.methodAdjustments, [0, -3, 3, 3, 3, 0]);
  });

  test('custom method uses the user angles', () {
    const customSettings = AppSettings(
        calculationMethod: CalculationMethodOption.custom,
        customFajrAngle: 19.5,
        customIshaAngle: 16.5);
    final custom =
        widgetCalcParamsFor(CalculationMethodOption.custom, customSettings);
    expect(custom.fajrAngle, 19.5);
    expect(custom.ishaAngle, 16.5);
    expect(custom.maghribAngle, 0);
    expect(custom.ishaInterval, 0);
    expect(custom.methodAdjustments, [0, 0, 0, 0, 0, 0]);
  });

  test('gulf region uses Fajr 19.5° and a 90-minute Isha interval', () {
    final gulf =
        widgetCalcParamsFor(CalculationMethodOption.gulfRegion, settings);
    expect(gulf.fajrAngle, 19.5);
    expect(gulf.ishaInterval, 90);
    expect(gulf.maghribAngle, 0);
    expect(gulf.methodAdjustments, [0, 0, 0, 0, 0, 0]);
  });

  test('jafari, france and russia carry their published angles', () {
    final jafari = widgetCalcParamsFor(CalculationMethodOption.jafari, settings);
    expect(jafari.fajrAngle, 16.0);
    expect(jafari.ishaAngle, 14.0);
    expect(jafari.maghribAngle, 4.0);
    expect(jafari.ishaInterval, 0);

    final france = widgetCalcParamsFor(CalculationMethodOption.france, settings);
    expect(france.fajrAngle, 12.0);
    expect(france.ishaAngle, 12.0);
    expect(france.maghribAngle, 0);

    final russia = widgetCalcParamsFor(CalculationMethodOption.russia, settings);
    expect(russia.fajrAngle, 16.0);
    expect(russia.ishaAngle, 15.0);
    expect(russia.maghribAngle, 0);
  });

  group('auto resolves to the city country method', () {
    // No `calculationMethod:` argument here on purpose: `auto` IS the default,
    // so these also pin that the out-of-the-box settings resolve per country.
    test('Mecca → ummAlQura params', () {
      const autoMecca = AppSettings(city: 'مکه');
      final p =
          widgetCalcParamsFor(CalculationMethodOption.auto, autoMecca);
      expect(p.fajrAngle, 18.5);
      expect(p.ishaInterval, 90);
    });

    test('Tehran → MWL params (user decision), unknown → MWL', () {
      const autoTehran = AppSettings(city: 'تهران');
      final tehran =
          widgetCalcParamsFor(CalculationMethodOption.auto, autoTehran);
      final unknown =
          widgetCalcParamsFor(CalculationMethodOption.auto, settings);
      expect(tehran.fajrAngle, 18.0);
      expect(tehran.ishaAngle, 17.0);
      expect(unknown.fajrAngle, 18.0);
      expect(unknown.ishaAngle, 17.0);
    });

    test('Île-de-France → france params', () {
      const autoParis = AppSettings(city: 'پاریس');
      final p = widgetCalcParamsFor(CalculationMethodOption.auto, autoParis);
      expect(p.fajrAngle, 12.0);
      expect(p.ishaAngle, 12.0);
    });
  });

  group('widget params reproduce the app engine (Dart↔Kotlin parity)', () {
    // Reference coordinates/date used by the Kotlin PrayerTimesCalculatorTest.
    const lat = 35.6892;
    const lng = 51.3890;

    String fmt(DateTime t) {
      final wall = t.add(const Duration(hours: 3, minutes: 30));
      return '${wall.hour.toString().padLeft(2, '0')}:${wall.minute.toString().padLeft(2, '0')}';
    }

    /// Applies the widget-side adjustment pipeline exactly like the Kotlin
    /// `finalize`: adj + methodAdj minutes, then round to the minute.
    DateTime finalize(DateTime utcAdjusted, int adj, int methodAdj) {
      final shifted = utcAdjusted.add(Duration(minutes: adj + methodAdj));
      return DateTime(
        shifted.year,
        shifted.month,
        shifted.day,
        shifted.hour,
        shifted.minute,
      ); // wall-clock minutes (no seconds in engine output)
    }

    List<String> expectedTimes(WidgetCalcParams p,
        {List<int> userAdj = const [0, 0, 0, 0, 0, 0]}) {
      final params = adhan.CalculationParameters(
        fajrAngle: p.fajrAngle,
        ishaAngle: p.ishaAngle,
      )
        ..maghribAngle = p.maghribAngle
        ..ishaInterval = p.ishaInterval
        ..highLatitudeRule = adhan.HighLatitudeRule.middle_of_the_night;
      final pt = adhan.PrayerTimes(
        adhan.Coordinates(lat, lng),
        adhan.DateComponents(2026, 8, 11),
        params,
        utcOffset: Duration.zero,
      );
      final adj = [
        userAdj[0] + p.methodAdjustments[0],
        userAdj[1] + p.methodAdjustments[1],
        userAdj[2] + p.methodAdjustments[2],
        userAdj[3] + p.methodAdjustments[3],
        userAdj[4] + p.methodAdjustments[4],
        userAdj[5] + p.methodAdjustments[5],
      ];
      return [
        fmt(finalize(pt.fajr, adj[0], 0)),
        fmt(finalize(pt.dhuhr, adj[2], 0)),
        fmt(finalize(pt.asr, adj[3], 0)),
        fmt(finalize(pt.maghrib, adj[4], 0)),
        fmt(finalize(pt.isha, adj[5], 0)),
      ];
    }

    test('muslimWorldLeague widget params == adhan engine times', () {
      final p = widgetCalcParamsFor(
          CalculationMethodOption.muslimWorldLeague, settings);
      // Reference: Kotlin PrayerTimesCalculatorTest expects (Tehran wall time)
      // fajr 03:45, dhuhr 12:11, asr 15:54, maghrib 18:59, isha 20:28.
      expect(
        expectedTimes(p),
        ['03:45', '12:11', '15:54', '18:59', '20:28'],
      );
    });

    test('tehran widget params == adhan engine times', () {
      final p = widgetCalcParamsFor(CalculationMethodOption.tehran, settings);
      // Kotlin reference: 03:47, 12:10, 15:54, 19:18, 20:10.
      expect(
        expectedTimes(p),
        ['03:47', '12:10', '15:54', '19:18', '20:10'],
      );
    });

    test('user offsets are additive on top of method adjustments', () {
      final p = widgetCalcParamsFor(
          CalculationMethodOption.muslimWorldLeague, const AppSettings());
      final base = expectedTimes(p);
      final withUser = expectedTimes(
        p,
        userAdj: const [2, 0, -3, 0, 5, 0],
      );
      // fajr +2, dhuhr −3, maghrib +5; others unchanged.
      expect(withUser[0], '03:47'); // 03:45 + 2
      expect(withUser[1], '12:08'); // 12:11 − 3
      expect(withUser[3], '19:04'); // 18:59 + 5 (maghrib)
      expect(withUser[4], base[4]); // isha unchanged
      expect(withUser[2], base[2]); // asr unchanged
    });
  });
}
