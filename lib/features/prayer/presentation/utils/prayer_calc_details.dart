import 'package:adhan/adhan.dart' as adhan;
import 'package:tawheeed/features/prayer/data/prayer_method_by_country.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';

/// One row of the calculation-details sheet: a label and its human-readable
/// value (e.g. «زاویه فجر» → «17.7 درجه»).
typedef CalcDetailRow = ({String label, String value});

/// Formats [value] dropping a trailing `.0` (17.0 → «17», 17.5 → «17.5»).
String _num(double value) {
  final rounded = value.roundToDouble();
  return value == rounded ? rounded.toStringAsFixed(0) : value.toString();
}

String _angleLabel(double v) => '${_num(v)} درجه';

String _madhabLabel(adhan.Madhab madhab) => switch (madhab) {
      adhan.Madhab.hanafi => 'حنفی (سایه دو برابر)',
      adhan.Madhab.shafi => 'شافعی (سایه یک برابر)',
    };

String _highLatitudeLabel(adhan.HighLatitudeRule rule) => switch (rule) {
      adhan.HighLatitudeRule.middle_of_the_night => 'نیمهٔ شب',
      adhan.HighLatitudeRule.seventh_of_the_night => 'یک‌هفتم شب',
      adhan.HighLatitudeRule.twilight_angle => 'زاویهٔ گرگومیش',
    };

/// Builds the rows shown in the «جزئیات محاسبه» sheet — every input that went
/// into today's calculation, so the user can trust (and verify) the result.
///
/// Pure and unit-testable: [params] are the resolved adhan parameters actually
/// used by the engine, [coordinates]/[altitude]/[cityName] come from the
/// prayer service, and [settings] carries the user's explicit choices.
/// [timezone]/[timezoneOffset]/[appVersion] are the diagnostic inputs for
/// remote support: with them a screenshot of this sheet pinpoints a wrong-time
/// report without any further tooling.
List<CalcDetailRow> buildCalculationDetails({
  required AppSettings settings,
  String? cityName,
  adhan.Coordinates? coordinates,
  adhan.CalculationParameters? params,
  double? altitude,
  DateTime? date,
  String? timezone,
  Duration? timezoneOffset,
  String? appVersion,
}) {
  final coords = coordinates != null
      ? '${coordinates.latitude.toStringAsFixed(4)}، '
          '${coordinates.longitude.toStringAsFixed(4)}'
      : null;

  // The angles actually used: for the custom method these are the user's own
  // values; otherwise the method's defaults.
  final fajrAngle = params?.fajrAngle;
  final ishaAngle = params?.ishaAngle;
  final ishaInterval = params?.ishaInterval ?? 0;
  final ishaValue = ishaAngle != null
      ? _angleLabel(ishaAngle)
      : (ishaInterval > 0 ? '$ishaInterval دقیقه پس از مغرب' : null);

  // Manual adhan offsets — only the five prayers shown in the settings UI.
  final manualAdjustments = <String>[
    if (settings.fajrOffset != 0) 'فجر ${_signed(settings.fajrOffset)}',
    if (settings.dhuhrOffset != 0) 'ظهر ${_signed(settings.dhuhrOffset)}',
    if (settings.asrOffset != 0) 'عصر ${_signed(settings.asrOffset)}',
    if (settings.maghribOffset != 0) 'مغرب ${_signed(settings.maghribOffset)}',
    if (settings.ishaOffset != 0) 'عشاء ${_signed(settings.ishaOffset)}',
  ];

  // «خودکار» resolves to the selected city's country method; naming it here
  // keeps the sheet self-explanatory (auto ← the method actually applied).
  final methodValue =
      settings.calculationMethod == CalculationMethodOption.auto
          ? '${settings.calculationMethod.label} ← '
              '${calculationMethodForCity(settings.city, lat: settings.manualLat, lng: settings.manualLng).label}'
          : settings.calculationMethod.label;

  final rows = <CalcDetailRow>[
    (
      label: 'شهر',
      value: (cityName != null && cityName.isNotEmpty) ? cityName : '—',
    ),
    (label: 'مختصات', value: coords ?? '—'),
    (
      label: 'ارتفاع از سطح دریا',
      value: altitude != null ? '${altitude.round()} متر' : 'نامشخص',
    ),
    (
      label: 'روش محاسبه',
      value: methodValue,
    ),
    if (fajrAngle != null) (label: 'زاویه فجر', value: _angleLabel(fajrAngle)),
    if (ishaValue != null) (label: 'زاویه / فاصله عشاء', value: ishaValue),
    if (params != null) (label: 'مذهب عصر', value: _madhabLabel(params.madhab)),
    if (params != null)
      (
        label: 'قانون عرض‌های بالا',
        value: _highLatitudeLabel(params.highLatitudeRule),
      ),
    (
      label: 'تنظیمات دستی اذان (دقیقه)',
      value: manualAdjustments.isEmpty
          ? 'بدون تغییر'
          : manualAdjustments.join('، '),
    ),
    (
      label: 'تاریخ محاسبه',
      value: date != null
          ? '${date.year}/${date.month.toString().padLeft(2, '0')}/'
              '${date.day.toString().padLeft(2, '0')}'
          : '—',
    ),
    (
      label: 'منطقهٔ زمانی',
      value: timezone != null
          ? '$timezone (UTC${_offsetLabel(timezoneOffset)})'
          : '—',
    ),
    if (appVersion != null) (label: 'نسخهٔ برنامه', value: appVersion),
  ];
  return rows;
}

/// Formats a UTC offset compactly: 210 min → «+3:30», -420 min → «-7:00».
String _offsetLabel(Duration? offset) {
  if (offset == null) return '?';
  final total = offset.inMinutes;
  final sign = total < 0 ? '-' : '+';
  final h = (total.abs() ~/ 60).toString();
  final m = (total.abs() % 60).toString().padLeft(2, '0');
  return '$sign$h:$m';
}

String _signed(int v) => v > 0 ? '+$v' : '$v';
