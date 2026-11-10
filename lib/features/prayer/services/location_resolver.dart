import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:tawheeed/features/prayer/data/place_index.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Resolves human-readable place names and elevation for arbitrary coordinates.
///
/// Used by both the prayer repository (GPS + manual flows) and the map picker
/// screen, so the name/altitude shown right after picking a point on the map
/// matches exactly what lands in the settings and the home clock box.
class LocationResolver {
  LocationResolver._();

  /// Smallest radius (km) around a known offline city center where the offline
  /// name is considered "the same place" as the online result.
  static const double _sameCityRadiusKm = 4.0;

  /// Best-effort reverse geocoding. Queries two online sources in parallel —
  /// the device geocoder and Nominatim (OpenStreetMap) which names small
  /// towns/villages the device geocoder often misses. The most specific online
  /// name wins (روستا/شهر کوچک/محله), even when it is not in the offline
  /// database; the offline city name is only kept when it is literally the same
  /// place (same name, close to the city center). Falls back to the nearest
  /// place in the offline tables within 150km when offline — Iranian towns and
  /// world cities alike. Returns `null` when nothing can be resolved.
  static Future<String?> resolvePlaceName(double lat, double lng) async {
    // 1) Online reverse geocoding (system geocoder + Nominatim).
    try {
      final online = await _onlineName(lat, lng);
      if (online != null) {
        final nearest = _nearestCityWithDistance(lat, lng, maxDistanceKm: 15);
        final finalName = resolveFinalName(
          onlineName: online.name,
          onlineIsSmallLevel: online.isSmallLevel,
          nearestCityName: nearest?.name,
          nearestCityDistanceKm: nearest?.distanceKm,
        );
        if (finalName != null && finalName.isNotEmpty) return finalName;
      }
    } on TimeoutException catch (_) {
      AppLogger.warning('LocationResolver', 'Geocoding timed out');
    } catch (e) {
      AppLogger.warning('LocationResolver', e.toString());
    }

    // 2) Offline Iran database fallback (works without internet).
    return _nearestCity(lat, lng, maxDistanceKm: 150);
  }

  /// Queries both online sources in parallel and picks the most specific name.
  static Future<({String name, bool isSmallLevel})?> _onlineName(
      double lat, double lng) async {
    final results = await (
      _systemPlacemark(lat, lng),
      _nominatimAddress(lat, lng),
    ).wait;
    return pickOnlineName(system: results.$1, nominatim: results.$2);
  }

  /// Resolves a typed city/address to coordinates for first-run setup.
  ///
  /// The bundled offline tables are consulted first: they are instant, need no
  /// network, and cover the overwhelmingly common case. Only when the name is
  /// not in them do we ask the platform geocoder — otherwise a user typing a
  /// known city while offline was stuck on step 0 of onboarding, which has no
  /// «بعداً».
  static Future<({double lat, double lng})?> resolveCoordinates(
      String query) async {
    final value = query.trim();
    if (value.isEmpty) return null;
    final offline = findOfflinePlace(value);
    if (offline != null) return (lat: offline.lat, lng: offline.lng);
    try {
      final locations = await Geocoding()
          .locationFromAddress(value)
          .timeout(const Duration(seconds: 10));
      if (locations.isEmpty) return null;
      return (lat: locations.first.latitude, lng: locations.first.longitude);
    } catch (e) {
      AppLogger.warning('LocationResolver', 'Forward geocoding failed: $e');
      return null;
    }
  }

  /// Looks a typed name up in the bundled offline tables — Iranian towns AND
  /// the world city table, so a name typed anywhere on earth resolves without
  /// a network. Exact normalized match wins; otherwise a unique prefix match
  /// (تهران‌/تهران, اصفهان…). Returns null when nothing or more than one
  /// place matches.
  @visibleForTesting
  static PlaceMatch? findOfflinePlace(String query) =>
      PlaceIndex.findUnique(query);

  /// Every offline place whose name matches [query], best first — used by the
  /// city picker, where several hits are shown instead of guessed.
  static List<PlaceMatch> searchOfflinePlaces(String query, {int limit = 50}) =>
      PlaceIndex.search(query, limit: limit);

  /// The device (Android/iOS) reverse-geocoded placemark, or `null`.
  static Future<Placemark?> _systemPlacemark(double lat, double lng) async {
    try {
      final geocoding = Geocoding();
      final placemarks = await geocoding
          .placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 15));
      return placemarks.isNotEmpty ? placemarks.first : null;
    } on TimeoutException catch (_) {
      AppLogger.warning('LocationResolver', 'System geocoding timed out');
      return null;
    } catch (e) {
      AppLogger.warning('LocationResolver', 'System geocoding failed: $e');
      return null;
    }
  }

  /// Nominatim (OpenStreetMap) reverse lookup, restricted to Persian names.
  /// Returns the `address` map (village/town/city/municipality/county/...) or
  /// `null` on any failure — callers treat it as an optional better source.
  static Future<Map<String, String>?> _nominatimAddress(
      double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': lat.toStringAsFixed(6),
        'lon': lng.toStringAsFixed(6),
        'zoom': '18',
        'accept-language': 'fa',
      });
      final res = await http.get(uri, headers: const {
        'User-Agent': 'TawheeedApp/1.0 (islamic-prayer-location-picker)',
      }).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) return null;
      final address = data['address'];
      if (address is! Map<String, dynamic>) return null;
      return address.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (e) {
      AppLogger.warning('LocationResolver', 'Nominatim lookup failed: $e');
      return null;
    }
  }

  /// Picks the most specific online name. Preference order:
  /// 1. Nominatim village / town (the small town itself — the point of the
  ///    online lookup)
  /// 2. Device subLocality (محله)
  /// 3. Nominatim city
  /// 4. Device locality
  /// 5. Nominatim municipality / county
  /// 6. Device subAdministrativeArea
  ///
  /// Names from levels 1-2 are "small level": they describe the exact place
  /// tapped and must never be replaced by a nearby offline city name.
  @visibleForTesting
  static ({String name, bool isSmallLevel})? pickOnlineName({
    required Placemark? system,
    required Map<String, String>? nominatim,
  }) {
    for (final key in const ['village', 'town']) {
      final v = nominatim?[key];
      if (v != null && v.trim().isNotEmpty) {
        return (name: v.trim(), isSmallLevel: true);
      }
    }
    final subLocality = system?.subLocality;
    if (subLocality != null && subLocality.trim().isNotEmpty) {
      return (name: subLocality.trim(), isSmallLevel: true);
    }
    final city = nominatim?['city'];
    if (city != null && city.trim().isNotEmpty) {
      return (name: city.trim(), isSmallLevel: false);
    }
    final locality = system?.locality;
    if (locality != null && locality.trim().isNotEmpty) {
      return (name: locality.trim(), isSmallLevel: false);
    }
    for (final key in const ['municipality', 'county']) {
      final v = nominatim?[key];
      if (v != null && v.trim().isNotEmpty) {
        return (name: v.trim(), isSmallLevel: false);
      }
    }
    final subAdmin = system?.subAdministrativeArea;
    if (subAdmin != null && subAdmin.trim().isNotEmpty) {
      return (name: subAdmin.trim(), isSmallLevel: false);
    }
    return null;
  }

  /// Final name decision between the online result and the offline database.
  ///
  /// The offline city name is returned only when it is literally the same
  /// place: the online name is at city level or coarser (not a small town /
  /// neighborhood), the point is within [_sameCityRadiusKm] of the offline
  /// city center, and the names match (after ZWNJ normalization). Otherwise
  /// the online name wins — so a small city keeps its own name even when it
  /// is not in the offline list.
  @visibleForTesting
  static String? resolveFinalName({
    required String? onlineName,
    required bool onlineIsSmallLevel,
    required String? nearestCityName,
    required double? nearestCityDistanceKm,
  }) {
    if (onlineName == null || onlineName.isEmpty) return nearestCityName;
    if (!onlineIsSmallLevel &&
        nearestCityName != null &&
        nearestCityDistanceKm != null &&
        nearestCityDistanceKm <= _sameCityRadiusKm &&
        normalizeName(onlineName) == normalizeName(nearestCityName)) {
      return nearestCityName;
    }
    return onlineName;
  }

  /// Normalizes Persian place names for comparison: trims, removes zero-width
  /// non-joiners (ZWNJ) and collapses repeated whitespace.
  @visibleForTesting
  static String normalizeName(String name) {
    return name.trim().replaceAll('\u200c', '').replaceAll(RegExp(r'\s+'), '');
  }

  /// Elevation above sea level in meters from the Open-Meteo elevation API.
  /// Returns `null` when the network call fails — callers treat elevation as
  /// optional metadata, so being offline only hides the number.
  static Future<double?> fetchElevation(double lat, double lng) async {
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/elevation', {
        'latitude': lat.toStringAsFixed(4),
        'longitude': lng.toStringAsFixed(4),
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['elevation'] as num?)?.toDouble();
    } catch (e) {
      AppLogger.warning('LocationResolver', 'Elevation fetch failed: $e');
      return null;
    }
  }

  static String? _nearestCity(double lat, double lng,
      {required double maxDistanceKm}) {
    return _nearestCityWithDistance(lat, lng, maxDistanceKm: maxDistanceKm)
        ?.name;
  }

  static ({String name, double distanceKm})? _nearestCityWithDistance(
      double lat, double lng,
      {required double maxDistanceKm}) {
    final nearest = PlaceIndex.nearest(lat, lng, maxDistanceKm: maxDistanceKm);
    if (nearest == null) return null;
    return (name: nearest.place.name, distanceKm: nearest.distanceKm);
  }
}
