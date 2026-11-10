import 'package:tawheeed/features/prayer/data/iran_cities.dart';
import 'package:tawheeed/features/prayer/data/world_cities.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings_options.dart';
import 'package:tawheeed/shared/utils/arabic_search.dart';

/// The default calculation method of each country, for the «خودکار — بر اساس
/// کشور» option (the app's out-of-the-box default).
///
/// Only the countries whose method is a named, well-established convention are
/// listed; every other place falls back to [CalculationMethodOption
/// .muslimWorldLeague], the world-wide default. Adding a row here is a
/// religious-content decision: keep it to the officially applied method.
///
/// Notes on the deliberate non-obvious rows:
/// - `مالزی` / `اندونزی` use [CalculationMethodOption.singapore] because JAKIM
///   and Kemenag apply the same 20°/18° pair that the Singapore method encodes.
/// - `ایران` maps to [CalculationMethodOption.muslimWorldLeague] by the user's
///   explicit decision (2026-10-13). The «تهران (ایران رسمی)» and «جعفری»
///   methods stay available as manual picks.
const Map<String, CalculationMethodOption> methodByCountry = {
  'عربستان': CalculationMethodOption.ummAlQura,
  'امارات': CalculationMethodOption.dubai,
  'قطر': CalculationMethodOption.qatar,
  'کویت': CalculationMethodOption.kuwait,
  'مصر': CalculationMethodOption.egyptian,
  'ترکیه': CalculationMethodOption.turkey,
  'پاکستان': CalculationMethodOption.karachi,
  'هند': CalculationMethodOption.karachi,
  'بنگلادش': CalculationMethodOption.karachi,
  'ایران': CalculationMethodOption.muslimWorldLeague,
  'آمریکا': CalculationMethodOption.northAmerica,
  'کانادا': CalculationMethodOption.northAmerica,
  'سنگاپور': CalculationMethodOption.singapore,
  'مالزی': CalculationMethodOption.singapore,
  'اندونزی': CalculationMethodOption.singapore,
  'فرانسه': CalculationMethodOption.france,
  'روسیه': CalculationMethodOption.russia,
};

String _key(String name) => normalizeSearchKey(name).trim();

/// One bundled place: the country it belongs to and where it is, so a name the
/// two tables share can be told apart by position.
class _Place {
  const _Place(this.country, this.lat, this.lng);
  final String country;
  final double lat;
  final double lng;
}

/// City name (as stored in settings) → Persian country label, matched against
/// the two bundled offline place tables: [worldCities] and [iranProvinces].
///
/// Four names live in both tables (حلب، آستانه، هرات، احمدآباد); when the caller
/// supplies the picked city's position, the *nearest* candidate wins, so an
/// Iranian «احمدآباد» cannot inherit India's Karachi method (and vice versa).
/// Without a position the first table's entry (the world list) is used.
///
/// Returns null when the name is unknown — a GPS point whose reverse-geocoded
/// name is a village neither table holds. That is not an error: the caller
/// falls back to the world-wide default.
String? countryOfCity(String? cityName, {double? lat, double? lng}) {
  if (cityName == null || cityName.isEmpty) return null;
  final key = _key(cityName);
  if (key.isEmpty) return null;
  final places = _placesByCityKey[key];
  if (places == null || places.isEmpty) return null;
  if (places.length == 1 || lat == null || lng == null) {
    return places.first.country;
  }
  // Squared planar distance is enough to separate bundled towns; every pair
  // here is hundreds of kilometres apart.
  var best = places.first;
  var bestDistance = double.infinity;
  for (final place in places) {
    final dLat = place.lat - lat;
    final dLng = place.lng - lng;
    final distance = dLat * dLat + dLng * dLng;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = place;
    }
  }
  return best.country;
}

/// The calculation method the selected city's country applies, or
/// [CalculationMethodOption.muslimWorldLeague] when the country is unknown.
CalculationMethodOption calculationMethodForCity(
  String? cityName, {
  double? lat,
  double? lng,
}) =>
    methodByCountry[countryOfCity(cityName, lat: lat, lng: lng)] ??
    CalculationMethodOption.muslimWorldLeague;

/// Every bundled city name → its candidate places (Iranian towns are added
/// under the «ایران» country). Built once per process.
final Map<String, List<_Place>> _placesByCityKey = () {
  final map = <String, List<_Place>>{};

  void add(String name, _Place place) {
    final key = _key(name);
    if (key.isEmpty) return;
    (map[key] ??= <_Place>[]).add(place);
  }

  for (final city in worldCities) {
    add(city.name, _Place(city.country, city.lat, city.lng));
  }
  for (final province in iranProvinces) {
    for (final city in province.cities) {
      add(city.name, _Place('ایران', city.lat, city.lng));
    }
  }
  return map;
}();
