import 'package:tawheeed/features/prayer/data/prayer_method_by_country.dart';
import 'package:tawheeed/features/settings/settings.dart';

/// Effective prayer-calculation inputs sent to the native widget so it can
/// recompute today's times by itself (midnight / stale sync) without the app.
///
/// Mirrors exactly what the app's prayer engine (the `adhan` package, see
/// `PrayerRepository._getCalculationParams`) feeds into the calculation:
/// angles, the maghrib-angle/isha-interval special cases and the per-method
/// minute adjustments from `CalculationMethod.getParameters()`.
typedef WidgetCalcParams = ({
  double fajrAngle,
  double ishaAngle,
  double maghribAngle,
  int ishaInterval,
  List<int> methodAdjustments,
});

/// Resolves the effective calculation inputs for [method] (with the user's
/// custom angles when the custom method is selected).
WidgetCalcParams widgetCalcParamsFor(
    CalculationMethodOption method, AppSettings settings) {
  // «خودکار — بر اساس کشور» resolves to the selected city's country method
  // before the switch; a manual pick always wins.
  final resolved = method == CalculationMethodOption.auto
      ? calculationMethodForCity(settings.city,
          lat: settings.manualLat, lng: settings.manualLng)
      : method;
  switch (resolved) {
    case CalculationMethodOption.muslimWorldLeague:
      return (
        fajrAngle: 18.0,
        ishaAngle: 17.0,
        maghribAngle: 0,
        ishaInterval: 0,
        methodAdjustments: const [0, 0, 1, 0, 0, 0]
      );
    case CalculationMethodOption.karachi:
      return (
        fajrAngle: 18.0,
        ishaAngle: 18.0,
        maghribAngle: 0,
        ishaInterval: 0,
        methodAdjustments: const [0, 0, 1, 0, 0, 0]
      );
    case CalculationMethodOption.ummAlQura:
      return (
        fajrAngle: 18.5,
        ishaAngle: 18.0,
        maghribAngle: 0,
        ishaInterval: 90,
        methodAdjustments: const [0, 0, 0, 0, 0, 0]
      );
    case CalculationMethodOption.egyptian:
      return (
        fajrAngle: 19.5,
        ishaAngle: 17.5,
        maghribAngle: 0,
        ishaInterval: 0,
        methodAdjustments: const [0, 0, 1, 0, 0, 0]
      );
    case CalculationMethodOption.tehran:
      return (
        fajrAngle: 17.7,
        ishaAngle: 14.0,
        maghribAngle: 4.5,
        ishaInterval: 0,
        methodAdjustments: const [0, 0, 0, 0, 0, 0]
      );
    case CalculationMethodOption.turkey:
      return (
        fajrAngle: 18.0,
        ishaAngle: 17.0,
        maghribAngle: 0,
        ishaInterval: 0,
        methodAdjustments: const [0, -7, 5, 4, 7, 0]
      );
    case CalculationMethodOption.dubai:
      return (
        fajrAngle: 18.2,
        ishaAngle: 18.2,
        maghribAngle: 0,
        ishaInterval: 0,
        methodAdjustments: const [0, -3, 3, 3, 3, 0]
      );
    case CalculationMethodOption.kuwait:
      return (
        fajrAngle: 18.0,
        ishaAngle: 17.5,
        maghribAngle: 0,
        ishaInterval: 0,
        methodAdjustments: const [0, 0, 0, 0, 0, 0]
      );
    case CalculationMethodOption.qatar:
      return (
        fajrAngle: 18.0,
        ishaAngle: 18.0,
        maghribAngle: 0,
        ishaInterval: 90,
        methodAdjustments: const [0, 0, 0, 0, 0, 0]
      );
    case CalculationMethodOption.singapore:
      return (
        fajrAngle: 20.0,
        ishaAngle: 18.0,
        maghribAngle: 0,
        ishaInterval: 0,
        methodAdjustments: const [0, 0, 1, 0, 0, 0]
      );
    case CalculationMethodOption.northAmerica:
      return (
        fajrAngle: 15.0,
        ishaAngle: 15.0,
        maghribAngle: 0,
        ishaInterval: 0,
        methodAdjustments: const [0, 0, 1, 0, 0, 0]
      );
    case CalculationMethodOption.moonsightingCommittee:
      return (
        fajrAngle: 18.0,
        ishaAngle: 18.0,
        maghribAngle: 0,
        ishaInterval: 0,
        methodAdjustments: const [0, 0, 5, 0, 3, 0]
      );
    case CalculationMethodOption.custom:
      return (
        fajrAngle: settings.customFajrAngle,
        ishaAngle: settings.customIshaAngle,
        maghribAngle: 0,
        ishaInterval: 0,
        methodAdjustments: const [0, 0, 0, 0, 0, 0]
      );
    // Not in the `adhan` enum — constructed from their published angles, to
    // mirror `PrayerRepository._getCalculationParams` exactly.
    case CalculationMethodOption.jafari:
      return (
        fajrAngle: 16.0,
        ishaAngle: 14.0,
        maghribAngle: 4.0,
        ishaInterval: 0,
        methodAdjustments: const [0, 0, 0, 0, 0, 0]
      );
    case CalculationMethodOption.france:
      return (
        fajrAngle: 12.0,
        ishaAngle: 12.0,
        maghribAngle: 0,
        ishaInterval: 0,
        methodAdjustments: const [0, 0, 0, 0, 0, 0]
      );
    case CalculationMethodOption.russia:
      return (
        fajrAngle: 16.0,
        ishaAngle: 15.0,
        maghribAngle: 0,
        ishaInterval: 0,
        methodAdjustments: const [0, 0, 0, 0, 0, 0]
      );
    // Gulf: Fajr 19.5°, Isha 90 minutes after Maghrib. `ishaAngle` mirrors the
    // ummAlQura/qatar rows: native prefers the interval, and the angle keeps the
    // twilight-angle high-latitude rule defined.
    case CalculationMethodOption.gulfRegion:
      return (
        fajrAngle: 19.5,
        ishaAngle: 18.0,
        maghribAngle: 0,
        ishaInterval: 90,
        methodAdjustments: const [0, 0, 0, 0, 0, 0]
      );
    // Unreachable: `auto` is resolved above.
    case CalculationMethodOption.auto:
      return (
        fajrAngle: 18.0,
        ishaAngle: 17.0,
        maghribAngle: 0,
        ishaInterval: 0,
        methodAdjustments: const [0, 0, 1, 0, 0, 0]
      );
  }
}
