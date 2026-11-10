import 'dart:math' as math;

import 'package:tawheeed/features/prayer/data/iran_cities.dart';
import 'package:tawheeed/features/prayer/data/world_cities.dart';

/// One offline-resolvable place, from either bundled table.
class PlaceMatch {
  final String name;

  /// Country label as the user reads it; `ایران` for the province table.
  final String country;
  final double lat;
  final double lng;

  /// IANA zone of the place; a manual pick writes it into `settings.timezone`
  /// so the picked city renders on its own clock. Null for custom lat/lng
  /// entries, which keep the device's zone semantics.
  final String? tzId;

  const PlaceMatch({
    required this.name,
    required this.country,
    required this.lat,
    required this.lng,
    this.tzId,
  });
}

/// Offline search + nearest-place index over BOTH bundled tables.
///
/// Before this existed a typed place name only resolved inside Iran: the Iran
/// province table had 1300+ towns and nothing else, so Lagos, London or
/// Jakarta fell through to the network geocoder. [search] and [nearest] now
/// cover every continent, which is what makes prayer times usable anywhere.
///
/// Entries outside Iran's bounding box are filtered out of [places] rather
/// than "fixed": a handful of village rows carry coordinates that belong to
/// another country entirely, and for a prayer-time app a wrong point is worse
/// than no point — the caller then falls back to GPS/geocoding instead of
/// silently computing times for the wrong latitude.
class PlaceIndex {
  PlaceIndex._();

  /// Iran's mainland bounding box, generously padded.
  static const double _iranMinLat = 25.0;
  static const double _iranMaxLat = 39.8;
  static const double _iranMinLng = 44.0;
  static const double _iranMaxLng = 63.4;

  static List<PlaceMatch>? _places;

  /// Every usable offline place: the Iran table (bounding-box filtered) plus
  /// the world table. Built once per process.
  static List<PlaceMatch> get places {
    if (_places != null) return _places!;
    final list = <PlaceMatch>[];
    for (final province in iranProvinces) {
      for (final city in province.cities) {
        if (city.lat < _iranMinLat ||
            city.lat > _iranMaxLat ||
            city.lng < _iranMinLng ||
            city.lng > _iranMaxLng) {
          continue;
        }
        list.add(PlaceMatch(
            name: city.name,
            country: 'ایران',
            lat: city.lat,
            lng: city.lng,
            tzId: 'Asia/Tehran'));
      }
    }
    for (final city in worldCities) {
      list.add(PlaceMatch(
          name: city.name,
          country: city.country,
          lat: city.lat,
          lng: city.lng,
          tzId: city.tzId));
    }
    return _places = List.unmodifiable(list);
  }

  /// Test seam: the bundled tables can contain rows outside their region.
  static int outOfRegionIranEntries() {
    var bad = 0;
    for (final province in iranProvinces) {
      for (final city in province.cities) {
        if (city.lat < _iranMinLat ||
            city.lat > _iranMaxLat ||
            city.lng < _iranMinLng ||
            city.lng > _iranMaxLng) {
          bad++;
        }
      }
    }
    return bad;
  }

  /// Normalizes a place name for comparison. Beyond trimming, collapsing
  /// whitespace and lowercasing Latin input, it folds the orthographic
  /// variants a user might type for the same place:
  /// • the Persian joiner (ZWNJ) and Arabic elongation (tatweel),
  /// • the Arabic harakat / tajweed marks and superscript alif,
  /// • ي↔ی and ك↔ک, the two letters whose Arabic and Persian forms differ,
  /// • Arabic-Indic (٠-٩) and Extended/Persian (۰-۹) digits onto Latin ones.
  static String normalize(String name) {
    var s = name.trim();
    s = s
        .replaceAll(_combining, '')
        .replaceAll('\u200c', '') // ZWNJ: تهران‌ → تهران
        .replaceAll('\u064A', '\u06CC') // Arabic ya  → Persian yeh
        .replaceAll('\u0643', '\u06A9'); // Arabic kaf → Persian keheh
    s = s.replaceAllMapped(_digits, (m) {
      final matched = m.group(0);
      if (matched == null || matched.isEmpty) return '';
      final c = matched.codeUnitAt(0);
      final base = c >= 0x06F0 ? 0x06F0 : 0x0660;
      return String.fromCharCode(0x30 + (c - base));
    });
    return s
        .replaceAll(RegExp(r'\s+', unicode: true), '')
        .toLowerCase();
  }

  static final RegExp _combining = RegExp(
      '[\u0640\u064B-\u065F\u0670\u06D6-\u06ED\u08D3-\u08FF\uFBF0-\uFBFC]');
  static final RegExp _digits = RegExp('[\u0660-\u0669\u06F0-\u06F9]');

  /// Ranked name matches for a typed query, best first.
  ///
  /// Tiers: exact name → name starting with the query → query starting with
  /// the name → name containing the query. Within a tier, shorter names win,
  /// so «لند» gives لندن before لندز.
  static List<PlaceMatch> search(String query, {int limit = 50}) {
    final wanted = normalize(query);
    if (wanted.isEmpty) return const [];

    final exact = <PlaceMatch>[];
    final prefix = <PlaceMatch>[];
    final shortName = <PlaceMatch>[];
    final contains = <PlaceMatch>[];

    for (final place in places) {
      final name = normalize(place.name);
      if (name == wanted) {
        exact.add(place);
      } else if (name.startsWith(wanted)) {
        prefix.add(place);
      } else if (wanted.startsWith(name)) {
        shortName.add(place);
      } else if (name.contains(wanted)) {
        contains.add(place);
      }
    }

    int byLength(PlaceMatch a, PlaceMatch b) {
      final c = a.name.length.compareTo(b.name.length);
      return c != 0 ? c : a.name.compareTo(b.name);
    }

    for (final tier in [exact, prefix, shortName, contains]) {
      tier.sort(byLength);
    }
    return [...exact, ...prefix, ...shortName, ...contains]
        .take(limit)
        .toList();
  }

  /// A single unambiguous hit for [query], or null when nothing matches or
  /// several places do — the caller must show [search] instead of guessing.
  static PlaceMatch? findUnique(String query) {
    final hits = search(query);
    if (hits.isEmpty) return null;
    final wanted = normalize(query);
    final exact = hits.where((p) => normalize(p.name) == wanted).toList();
    if (exact.length == 1) return exact.single;
    if (exact.length > 1) return null;
    return hits.length == 1 ? hits.single : null;
  }

  /// Closest bundled place to [lat]/[lng] within [maxDistanceKm], or null.
  static ({PlaceMatch place, double distanceKm})? nearest(
      double lat, double lng,
      {required double maxDistanceKm}) {
    ({PlaceMatch place, double distanceKm})? best;
    for (final place in places) {
      final d = distanceKm(lat, lng, place.lat, place.lng);
      if (best == null || d < best.distanceKm) {
        best = (place: place, distanceKm: d);
      }
    }
    if (best == null || best.distanceKm > maxDistanceKm) return null;
    return best;
  }

  /// Great-circle distance in kilometres (Haversine).
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double degrees) => degrees * (math.pi / 180.0);
}
