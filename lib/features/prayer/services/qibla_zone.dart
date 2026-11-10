import 'dart:math';

import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:tawheeed/features/prayer/data/iran_cities.dart';
import 'package:tawheeed/features/prayer/data/world_cities.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// The IANA zone a QIBLA page must render its times in.
///
/// The compass shows sun/sun-sign/moon times FOR A PLACE. Formatting them on
/// the device's own clock was the 1.7.2 bug: a Tehran coordinate opened on a
/// UTC-clock device printed sunrise 02:36 instead of 06:06. So the zone is
/// resolved from the LOCATION itself, not from the device:
///
///  1. the nearest known city within ~1° (~110 km) — Iranian towns all use
///     `Asia/Tehran` (Iran is one zone), world cities carry their own IANA id;
///  2. the user's prayer-location zone (`settings.timezone`, kept in sync with
///     the device zone or the picked city) — better than nothing for far-away
///     pins with no city match(e.g. desert coordinates);
///  3. the DEVICE's offset, the legacy fallback.
class ResolvedQiblaZone {
  /// Real tz database location, or null when only [fixedOffset] is known.
  final tz.Location? location;

  /// Fixed offset fallback when no IANA zone resolved.
  final Duration fixedOffset;

  const ResolvedQiblaZone(this.location, this.fixedOffset);

  /// UTC offset of this zone for the WALL date of [forDate], anchored at local
  /// NOON — the same convention the prayer repository uses, so events (which
  /// all fall within ±7 h of noon) resolve on one offset even across a 02:00
  /// DST transition on the changeover day.
  int offsetMinutesForWallDate(DateTime forDate) {
    final loc = location;
    if (loc == null) return fixedOffset.inMinutes;
    try {
      return tz.TZDateTime(loc, forDate.year, forDate.month, forDate.day, 12)
          .timeZoneOffset
          .inMinutes;
    } catch (e) {
      AppLogger.warning('qibla_zone', 'zone offset lookup failed: $e');
      return fixedOffset.inMinutes;
    }
  }

  /// Wall fields of [instant] on this zone's clock.
  DateTime wallOf(DateTime instant) {
    final loc = location;
    if (loc == null) {
      final utc = instant.toUtc().add(fixedOffset);
      return DateTime(
          utc.year, utc.month, utc.day, utc.hour, utc.minute, utc.second);
    }
    try {
      final inTz = tz.TZDateTime.from(instant, loc);
      return DateTime(inTz.year, inTz.month, inTz.day, inTz.hour, inTz.minute,
          inTz.second);
    } catch (e) {
      AppLogger.warning('qibla_zone', 'wall time conversion failed: $e');
      final utc = instant.toUtc().add(fixedOffset);
      return DateTime(
          utc.year, utc.month, utc.day, utc.hour, utc.minute, utc.second);
    }
  }

  /// The provider-visible zone id (for tests / diagnostics), diagnostic only.
  String? get zoneId => location?.name;
}

ResolveDiagnostics? _lastDiagnostics;

/// Diagnostics of the last [resolveQiblaZone] call — surfaced by tests.
class ResolveDiagnostics {
  final String source; // 'nearest-city' | 'settings' | 'device'
  final String? zoneId;
  const ResolveDiagnostics(this.source, this.zoneId);
}

ResolveDiagnostics? get lastQiblaZoneDiagnostics => _lastDiagnostics;

/// Resolves the zone for a qibla location: nearest known city first, then the
/// user's stored zone, then the device. Pure on the caller side: a null
/// [settingsTimezone] just skips that ladder step.
ResolvedQiblaZone resolveQiblaZone({
  required double lat,
  required double lng,
  required String? settingsTimezone,
}) {
  try {
    tzdata.initializeTimeZones();
  } catch (e) {
    // Already initialized by other services — safe to continue with whatever
    // state the database is in; lookups below have their own guards.
    AppLogger.warning('qibla_zone', 'tz init failed: $e');
  }

  // 1. Nearest known city within ~1 degree of arc (~110 km). Planar compare
  // is fine at this radius: cos(lat) error over 1° is under 2%.
  String? cityZone;
  double best = double.infinity;
  void visit(double clat, double clng, String? zoneId) {
    if (zoneId == null) return;
    final d = max((clat - lat).abs(), (clng - lng).abs() * 0.85);
    if (d < best) {
      best = d;
      cityZone = zoneId;
    }
  }

  try {
    for (final province in iranProvinces) {
      for (final c in province.cities) {
        visit(c.lat, c.lng, 'Asia/Tehran');
      }
    }
  } catch (e) {
    AppLogger.warning('qibla_zone', 'iran cities scan failed: $e');
  }
  try {
    for (final c in worldCities) {
      visit(c.lat, c.lng, c.tzId);
    }
  } catch (e) {
    AppLogger.warning('qibla_zone', 'world cities scan failed: $e');
  }
  if (cityZone != null && best <= 1.0) {
    try {
      final loc = tz.getLocation(cityZone!);
      _lastDiagnostics = ResolveDiagnostics('nearest-city', cityZone);
      return ResolvedQiblaZone(loc, DateTime.now().timeZoneOffset);
    } catch (e) {
      AppLogger.warning('qibla_zone',
          'nearest-city zone "$cityZone" invalid: $e — falling back');
    }
  }

  // 2. The user's own zone (device-synced or the picked city's zone).
  if (settingsTimezone != null && settingsTimezone.isNotEmpty) {
    try {
      final loc = tz.getLocation(settingsTimezone);
      _lastDiagnostics = ResolveDiagnostics('settings', settingsTimezone);
      return ResolvedQiblaZone(loc, DateTime.now().timeZoneOffset);
    } catch (e) {
      AppLogger.warning('qibla_zone',
          'settings timezone "$settingsTimezone" invalid: $e — falling back');
    }
  }

  // 3. Device offset — the legacy fallback, never a silent Tehran.
  _lastDiagnostics = const ResolveDiagnostics('device', null);
  return ResolvedQiblaZone(null, DateTime.now().timeZoneOffset);
}

/// A zone resolved directly by IANA id (tests / pinned coordinates).
ResolvedQiblaZone qiblaZoneById(String id) {
  try {
    tzdata.initializeTimeZones();
  } catch (e) {
    AppLogger.warning('qibla_zone', 'tz init failed: $e');
  }
  final loc = tz.getLocation(id);
  return ResolvedQiblaZone(loc, DateTime.now().timeZoneOffset);
}

/// The device zone, expressed the way the math functions expect it.
ResolvedQiblaZone qiblaZoneDevice({
  Duration? fallback,
}) {
  _lastDiagnostics = const ResolveDiagnostics('device', null);
  return ResolvedQiblaZone(null, fallback ?? DateTime.now().timeZoneOffset);
}
