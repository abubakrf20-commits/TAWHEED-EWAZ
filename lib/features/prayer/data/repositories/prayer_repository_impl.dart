import 'dart:async';
import 'dart:math';
import 'package:adhan/adhan.dart' as adhan;
import 'package:tawheeed/features/prayer/services/elevation_correction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tawheeed/core/services/location_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/prayer/data/datasources/prayer_local_datasource.dart';
import 'package:tawheeed/features/prayer/data/prayer_method_by_country.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:tawheeed/features/prayer/services/location_resolver.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/domain/repositories/settings_writer.dart';
import 'package:tawheeed/shared/models/day_time.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/date_key.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

final prayerLocalDataSourceProvider = Provider<PrayerLocalDataSource>((ref) {
  ref.keepAlive();
  return PrayerLocalDataSource(SharedPreferences.getInstance());
});

final prayerRepositoryProvider = Provider<PrayerRepository>((ref) {
  ref.keepAlive();
  return PrayerRepositoryImpl(ref.read(prayerLocalDataSourceProvider));
});

class PrayerRepositoryImpl implements PrayerRepository {
  final PrayerLocalDataSource _ds;
  final _cityNameListeners = <void Function()>[];

  adhan.PrayerTimes? _adhanTimes;
  adhan.SunnahTimes? _sunnahTimes;
  pi.PrayerTimes? _cachedTimes;
  adhan.Coordinates? _coordinates;
  adhan.CalculationParameters? _lastParams;

  /// Parameters that actually produced [_adhanTimes], elevation dip included.
  /// Notifications and the home widget recompute from these so their times
  /// match what the screen shows ([calculationParams] is the raw method
  /// output, kept for the calculation-details view).
  adhan.CalculationParameters? _effectiveParams;

  /// `[sunriseMinutes, maghribMinutes]` baked by the last elevation pass.
  List<int> _elevationAdjustments = const [0, 0];

  /// وقت دلخواهٔ نماز جمعه از تنظیمات؛ `null` یعنی همان وقت محاسبه‌شدهٔ ظهر.
  DayTime? _fridayPrayerTime;
  String _error = '';
  bool _loading = false;
  String _cityName = '';
  double? _altitude;
  double? _altitudeLat;
  double? _altitudeLng;
  bool _altitudeLoaded = false;
  Position? _cachedPosition;
  DateTime? _cachedPositionTime;

  /// Platform geolocation calls carry no timeout of their own, and a wedged
  /// location service used to leave the home skeleton up indefinitely. Every
  /// non-human step is bounded here; the permission dialog itself waits on the
  /// user and is deliberately left unbounded.
  static const Duration _locationCheckTimeout = Duration(seconds: 5);
  static const Duration _locationFixTimeout = Duration(seconds: 25);

  PrayerRepositoryImpl(this._ds);

  Future<bool> _locationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled().timeout(_locationCheckTimeout);

  Future<LocationPermission> _checkLocationPermission() =>
      Geolocator.checkPermission().timeout(_locationCheckTimeout);

  /// Register a callback for city name changes. Returns a dispose function.
  @override
  void Function() listenCityName(void Function() cb) {
    _cityNameListeners.add(cb);
    return () => _cityNameListeners.remove(cb);
  }

  void _notifyCityName() {
    for (final cb in _cityNameListeners) {
      cb();
    }
  }

  @override
  adhan.PrayerTimes? get adhanTimes => _adhanTimes;

  @override
  adhan.SunnahTimes? get sunnahTimes => _sunnahTimes;

  @override
  pi.PrayerTimes? get cachedPrayerTimes => _cachedTimes;

  @override
  adhan.Coordinates? get coordinates => _coordinates;

  @override
  adhan.CalculationParameters? get calculationParams => _lastParams;

  @override
  adhan.CalculationParameters? get effectiveParams =>
      _effectiveParams ?? _lastParams;

  @override
  List<int> get elevationAdjustments => _elevationAdjustments;

  @override
  String get cityName => _cityName;

  @override
  double? get altitude => _altitude;

  @override
  Future<void> setAltitude(double? altitude) async {
    _altitude = altitude;
    _altitudeLoaded = true;
    if (altitude != null) {
      try {
        await _ds.setSavedAltitude(altitude);
      } catch (e) {
        AppLogger.warning('PrayerRepository', 'Save altitude failed: $e');
      }
    }
    _notifyCityName();
  }

  Future<void> setAltitudeForCoords(
      double altitude, double lat, double lng) async {
    _altitude = altitude;
    _altitudeLat = lat;
    _altitudeLng = lng;
    _altitudeLoaded = true;
    try {
      await _ds.setSavedAltitude(altitude);
      await _ds.setSavedAltitudeCoords(lat, lng);
    } catch (e) {
      AppLogger.warning('PrayerRepository', 'Save altitude coords failed: $e');
    }
    _notifyCityName();
  }

  @override
  pi.PrayerTimes? prayerTimesForDate(DateTime date, {AppSettings? settings}) {
    if (_coordinates == null) return null;
    _fridayPrayerTime = settings?.fridayPrayerTime;
    final params = settings != null
        ? _getCalculationParams(settings)
        : _lastParams ?? _getDefaultParams();
    final zone = _resolveZone(settings);
    final components = _dateComponentsIn(zone, date);
    var pt = adhan.PrayerTimes(_coordinates!, components, params,
        utcOffset: zone.offsetForDate(date));
    // Pure form on purpose: this is a read for an arbitrary day, and the
    // mutating variant would republish today's elevation state as this day's.
    pt = _correctedForElevation(settings, pt, components).times;
    return _toDomain(pt, _coordinates, zone.wallOf(date));
  }

  Future<void> _ensureAltitudeLoaded() async {
    if (_altitudeLoaded) return;
    _altitudeLoaded = true;
    try {
      _altitude = await _ds.getSavedAltitude();
      _altitudeLat = await _ds.getSavedAltitudeLat();
      _altitudeLng = await _ds.getSavedAltitudeLng();
    } catch (e) {
      AppLogger.warning('PrayerRepository', 'Load altitude failed: $e');
    }
  }

  @override
  String get error => _error;

  @override
  bool get loading => _loading;

  @override
  Future<PrayerResult> loadPrayerTimes({
    required AppSettings? settings,
    SettingsWriter? writer,
    bool forceRefresh = false,
  }) async {
    _loading = true;
    _error = '';
    await _ensureAltitudeLoaded();

    try {
      // Manual location mode — use saved coordinates directly
      if (settings != null && !settings.useLocation) {
        final lat = settings.manualLat;
        final lng = settings.manualLng;
        if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
          _coordinates = adhan.Coordinates(lat, lng);
          // Resolve elevation BEFORE the first calculation so the correction
          // applies on this very load (not only after the next reload).
          await _resolveElevationForCalc(lat, lng, settings);
          _lastParams = _getCalculationParams(settings);
          _cityName = settings.city ?? '';
          _recalculatePrayerTimes(settings);
          await _saveAllForOffline(settings, writer: writer);
          _updateCityInBackground(settings, writer: writer);
          _loading = false;
          return _result();
        }
        // Manual mode but no coords saved yet — fall through to defaults
        _loadDefaultTimes();
        _loading = false;
        return _result();
      }

      // GPS mode — use the 30-min cached position unless a refresh is requested.
      try {
        final position =
            await _getLocationWithTimeout(forceRefresh: forceRefresh);
        _coordinates = adhan.Coordinates(position.latitude, position.longitude);
        // GPS fixes often report altitude 0.0 — resolve a real elevation
        // (one online lookup, cached) before computing times so the enabled
        // correction is not silently a no-op.
        await _resolveElevationForCalc(
            position.latitude, position.longitude, settings);
        _lastParams = settings != null
            ? _getCalculationParams(settings)
            : _getDefaultParams();
        _recalculatePrayerTimes(settings);
        final resolvedCity = settings?.city;
        _cityName = (resolvedCity != null && resolvedCity.isNotEmpty)
            ? resolvedCity
            : await _ds.getSavedCity();
        await _saveAllForOffline(settings, writer: writer);
        _updateCityInBackground(settings, writer: writer);
      } catch (e) {
        AppLogger.warning('PrayerRepository', 'GPS failed: $e');
        // Fallback: try saved coordinates
        if (!await _loadSavedCoordinates(settings)) {
          // Fallback: try today's cache
          await _loadTodayCache(settings);
          if (_cachedTimes == null) {
            _loadDefaultTimes();
            _error =
                'خطا در دریافت موقعیت: لطفاً مطمئن شوید که GPS فعال است و دسترسی به موقعیت را داده‌اید.';
          }
        } else {
          if (_coordinates != null) {
            await _resolveElevationForCalc(
                _coordinates!.latitude, _coordinates!.longitude, settings);
          }
          _lastParams = settings != null
              ? _getCalculationParams(settings)
              : _getDefaultParams();
          _recalculatePrayerTimes(settings);
          await _saveAllForOffline(settings, writer: writer);
          _updateCityInBackground(settings, writer: writer);
        }
      }
    } catch (e) {
      AppLogger.warning('prayer_repository_impl', 'error: $e');
      if (_cachedTimes == null) {
        _error = 'خطا در محاسبه اوقات نماز. لطفاً تنظیمات را بررسی کنید.';
        final loaded = await _loadSavedCoordinates(settings);
        if (!loaded) {
          await _loadTodayCache(settings);
          if (_cachedTimes == null) {
            _loadDefaultTimes();
          }
        } else {
          if (_coordinates != null) {
            await _resolveElevationForCalc(
                _coordinates!.latitude, _coordinates!.longitude, settings);
          }
          _lastParams = settings != null
              ? _getCalculationParams(settings)
              : _getDefaultParams();
          _recalculatePrayerTimes(settings);
          await _saveAllForOffline(settings, writer: writer);
          _updateCityInBackground(settings, writer: writer);
        }
      }
    }

    _loading = false;
    return _result();
  }

  PrayerResult _result() => PrayerResult(
        prayerTimes: _cachedTimes,
        cityName: _cityName,
        error: _error,
      );

  @override
  Future<pi.PrayerTimes?> loadCachedTimes({AppSettings? settings}) async {
    await _ensureAltitudeLoaded();
    final lat = settings?.manualLat;
    final lng = settings?.manualLng;
    if (settings != null &&
        !settings.useLocation &&
        lat != null &&
        lng != null &&
        (lat != 0.0 || lng != 0.0)) {
      _coordinates = adhan.Coordinates(lat, lng);
      _cityName = settings.city ?? '';
      _recalculatePrayerTimes(settings);
      return _cachedTimes;
    }
    if (settings != null && !settings.useLocation) {
      // Manual mode without saved coordinates — the same Tehran fallback the
      // full load uses, so the two paths can never disagree.
      _loadDefaultTimes();
      return _cachedTimes;
    }
    await _loadTodayCache(settings);
    return _cachedTimes;
  }

  Future<bool> _loadSavedCoordinates(AppSettings? settings) async {
    try {
      final lat = await _ds.getSavedLat();
      final lng = await _ds.getSavedLng();
      final city = await _ds.getSavedCity();

      if (lat == null || lng == null) return false;

      _coordinates = adhan.Coordinates(lat, lng);
      // Prefer settings city, fall back to saved city
      final resolvedCity = settings?.city;
      _cityName = (resolvedCity != null && resolvedCity.isNotEmpty)
          ? resolvedCity
          : city;
      return true;
    } catch (e) {
      AppLogger.warning('PrayerRepository', e.toString());
      return false;
    }
  }

  _ResolvedZone _resolveZone(AppSettings? settings) {
    try {
      tzdata.initializeTimeZones();
    } catch (e) {
      AppLogger.warning('PrayerRepository', 'tz init failed: $e');
    }
    // settings.timezone is kept in sync with the device's real Olson zone by
    // the Settings notifier (see _reconcileTimezone), or with the picked
    // city's own zone in manual mode. Asia/Tehran is only the DEFAULT
    // location fallback (the default coordinates are Tehran's).
    final name = settings?.timezone ?? 'Asia/Tehran';
    try {
      return _ResolvedZone(tz.getLocation(name), Duration.zero);
    } catch (e) {
      // The device's numeric offset is valid even when the Olson name is not
      // (Android `timeZoneName` abbreviations, background isolates) — a much
      // better last resort than the old hard Tehran, which rendered every
      // foreign city on Tehran's clock.
      AppLogger.warning('PrayerRepository',
          'timezone "$name" invalid — using the device offset: $e');
      return _ResolvedZone(null, DateTime.now().timeZoneOffset);
    }
  }

  /// Calendar date of [base] (or now) on [zone]'s clock.
  adhan.DateComponents _dateComponentsIn(_ResolvedZone zone, [DateTime? base]) {
    final wall = zone.wallOf(base);
    return adhan.DateComponents(wall.year, wall.month, wall.day);
  }

  void _recalculatePrayerTimes(AppSettings? settings) {
    if (_coordinates == null) return;
    _fridayPrayerTime = settings?.fridayPrayerTime;
    final params = settings != null
        ? _getCalculationParams(settings)
        : _getDefaultParams();
    _lastParams = params;
    final zone = _resolveZone(settings);
    final date = _dateComponentsIn(zone);
    var pt = adhan.PrayerTimes(_coordinates!, date, params,
        utcOffset:
            zone.offsetForDate(DateTime(date.year, date.month, date.day)));
    pt = _applyElevationCorrection(settings, pt, date);
    _adhanTimes = pt;
    _sunnahTimes = adhan.SunnahTimes(pt);
    _cachedTimes = _toDomain(pt, _coordinates);
  }

  /// Second-pass elevation (horizon-dip) correction: solves the true
  /// sunrise/maghrib horizon crossing for the observer's altitude and bakes
  /// the delta into a FRESH set of parameters (user offsets preserved — the
  /// shared [_lastParams] object is never mutated), then recomputes once.
  /// No-op when disabled, when altitude is unknown/sea-level, or when the
  /// solver declines to produce a sane result.
  ///
  /// This is the *mutating* form: it publishes the parameters it used as
  /// [_effectiveParams], because the notification scheduler and the home
  /// widget must recompute with exactly the parameters the screen shows. Only
  /// the two paths that compute **today** may call it — see
  /// [_correctedForElevation] for why.
  adhan.PrayerTimes _applyElevationCorrection(AppSettings? settings,
      adhan.PrayerTimes base, adhan.DateComponents date) {
    final corrected = _correctedForElevation(settings, base, date);
    _effectiveParams = corrected.params;
    _elevationAdjustments = corrected.adjustments;
    return corrected.times;
  }

  /// The same correction, with **no** writes to shared state.
  ///
  /// WHY this split exists: `prayerTimesForDate` is a read — the calendar asks
  /// it for whatever day the user tapped. It used to go through
  /// [_applyElevationCorrection], which assigns `_effectiveParams` and
  /// `_elevationAdjustments`; those describe *today*, and the horizon-dip
  /// minutes are solved per date, so opening the calendar on a far-away day
  /// would quietly leave the widget and the notification scheduler computing
  /// with another day's dip. A read that rewrites the state other surfaces
  /// depend on is a bug even when the numbers usually agree.
  ({adhan.PrayerTimes times, adhan.CalculationParameters? params, List<int> adjustments})
      _correctedForElevation(AppSettings? settings, adhan.PrayerTimes base,
          adhan.DateComponents date) {
    final enabled = settings?.elevationCorrection ?? false;
    final alt = _altitude ?? 0.0;
    if (!enabled || alt <= 0 || _coordinates == null) {
      return (times: base, params: _lastParams, adjustments: const [0, 0]);
    }
    try {
      // Fresh parameters built from settings — user's manual offsets stay in
      // effect and no shared object is mutated.
      final params = settings != null
          ? _getCalculationParams(settings)
          : _getDefaultParams();
      final adj = ElevationCorrection.computeAdjustments(
        uncorrectedSunrise: base.sunrise,
        uncorrectedMaghrib: base.maghrib,
        latitude: _coordinates!.latitude,
        longitude: _coordinates!.longitude,
        altitudeMeters: alt,
        maghribAngle: params.maghribAngle,
      );
      if (adj == null || (adj.sunriseMinutes == 0 && adj.maghribMinutes == 0)) {
        return (times: base, params: _lastParams, adjustments: const [0, 0]);
      }
      AppLogger.info('PrayerRepository',
          'Elevation correction (${alt.round()}m): sunrise ${adj.sunriseMinutes}m, maghrib +${adj.maghribMinutes}m');
      params.adjustments.sunrise += adj.sunriseMinutes;
      params.adjustments.maghrib += adj.maghribMinutes;
      return (
        times: adhan.PrayerTimes(
          _coordinates!,
          date,
          params,
          utcOffset: base.utcOffset,
        ),
        params: params,
        adjustments: [adj.sunriseMinutes, adj.maghribMinutes],
      );
    } catch (e) {
      AppLogger.warning('PrayerRepository', 'Elevation correction failed: $e');
      return (times: base, params: _lastParams, adjustments: const [0, 0]);
    }
  }

  /// Makes sure a usable altitude exists BEFORE computing times while the
  /// elevation correction is enabled. GPS fixes frequently report altitude
  /// 0.0 (no sensor data), which silently disabled the whole feature for GPS
  /// users — fall back to one online lookup per coordinate pair instead.
  /// No-op (instant) when disabled or when an altitude is already known for
  /// the same coordinates (within ~5km). Re-fetches when city/coords change
  /// so همه شهرها 952 نشان ندهد.
  Future<void> _resolveElevationForCalc(
      double lat, double lng, AppSettings? settings) async {
    if (!(settings?.elevationCorrection ?? false)) return;
    await _ensureAltitudeLoaded();
    if ((_altitude ?? 0) > 0 && _altitudeLat != null && _altitudeLng != null) {
      final dist = _haversineDistance(_altitudeLat!, _altitudeLng!, lat, lng);
      if (dist < 5.0) return;
    } else if ((_altitude ?? 0) > 0 && _altitudeLat == null) {
      // Legacy cache without coords — keep for same city, otherwise refetch
      // if saved coords differ >5km from requested
      try {
        final savedLat = await _ds.getSavedLat();
        final savedLng = await _ds.getSavedLng();
        if (savedLat != null && savedLng != null) {
          final dist = _haversineDistance(savedLat, savedLng, lat, lng);
          if (dist < 5.0) return;
        }
      } catch (e) {
        AppLogger.warning(
            'PrayerRepository', 'cached position save failed: $e');
      }
    }
    try {
      final elevation = await LocationResolver.fetchElevation(lat, lng);
      if (elevation != null && elevation > 0) {
        await setAltitudeForCoords(elevation, lat, lng);
      }
    } catch (e) {
      AppLogger.warning('PrayerRepository', 'Elevation lookup failed: $e');
    }
  }

  Future<void> _updateCityInBackground(AppSettings? settings,
      {SettingsWriter? writer}) async {
    if (_coordinates == null) return;

    // If user has set a custom city name, only overwrite if position changed significantly (>5km)
    if (settings?.city?.isNotEmpty == true) {
      final savedLat = await _ds.getSavedLat();
      final savedLng = await _ds.getSavedLng();
      if (savedLat != null && savedLng != null) {
        final distance = _haversineDistance(
          savedLat,
          savedLng,
          _coordinates!.latitude,
          _coordinates!.longitude,
        );
        if (distance < 5.0) return; // Less than 5km — keep custom name
      }
    }

    final name = await LocationResolver.resolvePlaceName(
      _coordinates!.latitude,
      _coordinates!.longitude,
    );
    if (name == null || name.isEmpty) return;

    _cityName = name;
    await writer?.setCity(name);
    await _ds.setSavedCity(name);
    _notifyCityName();
  }

  /// Calculate distance between two coordinates in kilometers (Haversine formula)
  double _haversineDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371.0; // km
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (3.141592653589793 / 180.0);

  Future<void> _loadTodayCache(AppSettings? settings) async {
    try {
      final lat = await _ds.getSavedLat();
      final lng = await _ds.getSavedLng();
      final city = await _ds.getSavedCity();

      // If we have saved coordinates, always recalculate from them (works for any day)
      if (lat != null && lng != null) {
        _coordinates = adhan.Coordinates(lat, lng);
        _fridayPrayerTime = settings?.fridayPrayerTime;
        _lastParams = settings != null
            ? _getCalculationParams(settings)
            : _getDefaultParams();
        final zone = _resolveZone(settings);
        final date = _dateComponentsIn(zone);
        var pt = adhan.PrayerTimes(_coordinates!, date, _lastParams!,
            utcOffset:
                zone.offsetForDate(DateTime(date.year, date.month, date.day)));
        pt = _applyElevationCorrection(settings, pt, date);
        _adhanTimes = pt;
        _sunnahTimes = adhan.SunnahTimes(pt);
        _cachedTimes = _toDomain(pt, _coordinates);
        _cityName = settings?.city?.isNotEmpty == true ? settings!.city! : city;
        return;
      }

      // Fallback: no saved coordinates — restore today's cached times directly.
      // We must NOT recompute from (0,0), which would return times for the
      // middle of the ocean instead of the user's real location. The day key is
      // the device-local date (matches PrayerLocalDataSource.cacheToday).
      final today = dateKeyOf(DateTime.now());
      final cachedDate = await _ds.getCachedDate();
      if (cachedDate != today) return;

      final fajr = await _ds.getCachedTime('fajr');
      final dhuhr = await _ds.getCachedTime('dhuhr');
      final asr = await _ds.getCachedTime('asr');
      final maghrib = await _ds.getCachedTime('maghrib');
      final isha = await _ds.getCachedTime('isha');
      final sunrise = await _ds.getCachedTime('sunrise');

      if (fajr != null &&
          dhuhr != null &&
          asr != null &&
          maghrib != null &&
          isha != null &&
          sunrise != null) {
        _coordinates = null;
        _lastParams = settings != null
            ? _getCalculationParams(settings)
            : _getDefaultParams();
        _cachedTimes = _buildDomainFromCached(
          date: _resolveZone(settings).wallOf(),
          fajr: fajr,
          sunrise: sunrise,
          dhuhr: dhuhr,
          asr: asr,
          maghrib: maghrib,
          isha: isha,
          city: settings?.city?.isNotEmpty == true ? settings!.city! : city,
        );
      }
    } catch (e) {
      AppLogger.error('PrayerRepository._loadTodayCache', e);
    }
  }

  /// Build a domain [pi.PrayerTimes] from cached wall-clock values. Used only
  /// when there are no saved coordinates so offline users still see the times
  /// that were cached for today.
  pi.PrayerTimes _buildDomainFromCached({
    required DateTime date,
    required DateTime fajr,
    required DateTime sunrise,
    required DateTime dhuhr,
    required DateTime asr,
    required DateTime maghrib,
    required DateTime isha,
    required String city,
  }) {
    pi.PrayerInfo info(String name, String arabicName, DateTime time) =>
        pi.PrayerInfo(
          name: name,
          arabicName: arabicName,
          time: DayTime(hour: time.hour, minute: time.minute),
        );
    return pi.PrayerTimes(
      date: date,
      fajr: info('fajr', 'فجر', fajr),
      shorouq: info('shorouq', 'طلوع', sunrise),
      duhr: info('duhr', 'ظهر', dhuhr),
      asr: info('asr', 'عصر', asr),
      maghrib: info('maghrib', 'مغرب', maghrib),
      isha: info('isha', 'عشاء', isha),
      locationCity: _cityName.isNotEmpty ? _cityName : city,
    );
  }

  Future<void> _saveAllForOffline(AppSettings? settings,
      {SettingsWriter? writer}) async {
    try {
      final pt = _adhanTimes;
      if (pt != null && _coordinates != null) {
        await _ds.cacheToday({
          'fajr': pt.fajr,
          'sunrise': pt.sunrise,
          'dhuhr': pt.dhuhr,
          'asr': pt.asr,
          'maghrib': pt.maghrib,
          'isha': pt.isha,
        });
        await _ds.setSavedCoords(
            _coordinates!.latitude, _coordinates!.longitude);
        // Save city name: prefer resolved name, fall back to settings city
        final cityToSave =
            _cityName.isNotEmpty ? _cityName : (settings?.city ?? '');
        if (cityToSave.isNotEmpty) await _ds.setSavedCity(cityToSave);
        if (writer != null) {
          await writer.setManualCoords(
              _coordinates!.latitude, _coordinates!.longitude);
          await writer.setHasLocation(true);
        }
      }
    } catch (e) {
      AppLogger.error('PrayerRepository._saveAllForOffline', e);
    }
  }

  adhan.CalculationParameters _getCalculationParams(AppSettings settings) {
    // «خودکار — بر اساس کشور» resolves to the selected city's country method
    // before the switch below; a manual pick always wins. A country we cannot
    // place falls back to the world-wide default (MWL) inside the resolver.
    final method = settings.calculationMethod == CalculationMethodOption.auto
        ? calculationMethodForCity(settings.city,
            lat: settings.manualLat, lng: settings.manualLng)
        : settings.calculationMethod;
    final params = switch (method) {
      CalculationMethodOption.custom => adhan.CalculationParameters(
          fajrAngle: settings.customFajrAngle,
          ishaAngle: settings.customIshaAngle,
        ),
      CalculationMethodOption.muslimWorldLeague =>
        adhan.CalculationMethod.muslim_world_league.getParameters(),
      CalculationMethodOption.karachi =>
        adhan.CalculationMethod.karachi.getParameters(),
      CalculationMethodOption.ummAlQura =>
        adhan.CalculationMethod.umm_al_qura.getParameters(),
      CalculationMethodOption.egyptian =>
        adhan.CalculationMethod.egyptian.getParameters(),
      CalculationMethodOption.tehran =>
        adhan.CalculationMethod.tehran.getParameters(),
      CalculationMethodOption.turkey =>
        adhan.CalculationMethod.turkey.getParameters(),
      CalculationMethodOption.dubai =>
        adhan.CalculationMethod.dubai.getParameters(),
      CalculationMethodOption.kuwait =>
        adhan.CalculationMethod.kuwait.getParameters(),
      CalculationMethodOption.qatar =>
        adhan.CalculationMethod.qatar.getParameters(),
      CalculationMethodOption.singapore =>
        adhan.CalculationMethod.singapore.getParameters(),
      CalculationMethodOption.northAmerica =>
        adhan.CalculationMethod.north_america.getParameters(),
      CalculationMethodOption.moonsightingCommittee =>
        adhan.CalculationMethod.moon_sighting_committee.getParameters(),
      // Not in the `adhan` enum — constructed from their published angles.
      CalculationMethodOption.jafari => adhan.CalculationParameters(
          fajrAngle: 16.0,
          ishaAngle: 14.0,
          maghribAngle: 4.0,
        ),
      CalculationMethodOption.france => adhan.CalculationParameters(
          fajrAngle: 12.0,
          ishaAngle: 12.0,
        ),
      CalculationMethodOption.russia => adhan.CalculationParameters(
          fajrAngle: 16.0,
          ishaAngle: 15.0,
        ),
      // Gulf: Fajr 19.5°, Isha 90 minutes after Maghrib. `ishaAngle` is kept
      // alongside the interval for the twilight-angle high-latitude rule.
      CalculationMethodOption.gulfRegion => adhan.CalculationParameters(
          fajrAngle: 19.5,
          ishaAngle: 18.0,
          ishaInterval: 90,
        ),
      // Unreachable: `auto` is resolved above.
      CalculationMethodOption.auto =>
        adhan.CalculationMethod.muslim_world_league.getParameters(),
    };

    params.madhab = settings.asrMethod == AsrMethod.hanafi
        ? adhan.Madhab.hanafi
        : adhan.Madhab.shafi;

    params.highLatitudeRule = switch (settings.highLatitudeRule) {
      HighLatitudeRuleOption.middleOfTheNight =>
        adhan.HighLatitudeRule.middle_of_the_night,
      HighLatitudeRuleOption.seventhOfTheNight =>
        adhan.HighLatitudeRule.seventh_of_the_night,
      HighLatitudeRuleOption.twilightAngle =>
        adhan.HighLatitudeRule.twilight_angle,
    };

    final global = settings.globalPrayerOffset;
    params.adjustments = adhan.PrayerAdjustments(
      fajr: settings.fajrOffset + global,
      sunrise: settings.sunriseOffset + global,
      dhuhr: settings.dhuhrOffset + global,
      asr: settings.asrOffset + global,
      maghrib: settings.maghribOffset + global,
      isha: settings.ishaOffset + global,
    );
    return params;
  }

  adhan.CalculationParameters _getDefaultParams() {
    final params = adhan.CalculationMethod.muslim_world_league.getParameters();
    params.madhab = adhan.Madhab.shafi;
    return params;
  }

  void _loadDefaultTimes() {
    final coordinates = adhan.Coordinates(35.6892, 51.3890);
    _coordinates = coordinates;
    final params = _getDefaultParams();
    _lastParams = params;
    final zone = _resolveZone(null);
    final date = _dateComponentsIn(zone);
    final pt = adhan.PrayerTimes(coordinates, date, params,
        utcOffset:
            zone.offsetForDate(DateTime(date.year, date.month, date.day)));
    _adhanTimes = pt;
    _sunnahTimes = adhan.SunnahTimes(pt);
    _cachedTimes = _toDomain(pt, coordinates);
    _cityName = 'تهران';
  }

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<String?> forceRefreshLocation({
    required AppSettings? settings,
    SettingsWriter? writer,
  }) async {
    try {
      final serviceEnabled = await _locationServiceEnabled();
      if (!serviceEnabled) {
        return 'سرویس موقعیت فعال نیست. لطفاً GPS را فعال کنید.';
      }

      LocationPermission permission = await _checkLocationPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return 'دسترسی به موقعیت رد شد. لطفاً از تنظیمات دسترسی به موقعیت را فعال کنید.';
      }
      if (permission == LocationPermission.deniedForever) {
        return 'دسترسی به موقعیت دائماً رد شده. لطفاً از تنظیمات سیستم دسترسی را فعال کنید.';
      }

      final position = await _getLocationWithTimeout(forceRefresh: true);
      _coordinates = adhan.Coordinates(position.latitude, position.longitude);
      _lastParams = settings != null
          ? _getCalculationParams(settings)
          : _getDefaultParams();
      _recalculatePrayerTimes(settings);
      await _saveAllForOffline(settings, writer: writer);
      if (writer != null) {
        await writer.setManualCoords(position.latitude, position.longitude);
        await writer.setHasLocation(true);
      }
      _updateCityInBackground(settings, writer: writer);
      return null;
    } catch (e) {
      AppLogger.warning('prayer_repository_impl', 'error: $e');
      return 'خطا در دریافت موقعیت: لطفاً اتصال اینترنت و دسترسی GPS را بررسی کنید.';
    }
  }

  @override
  void invalidateCache() {
    _adhanTimes = null;
    _sunnahTimes = null;
    _cachedTimes = null;
    _cachedPosition = null;
    _cachedPositionTime = null;
  }

  Future<Position> _getLocationWithTimeout({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedPosition != null &&
        _cachedPositionTime != null) {
      final cacheAge = DateTime.now().difference(_cachedPositionTime!);
      if (cacheAge < const Duration(minutes: 30)) {
        return _cachedPosition!;
      }
    }

    final serviceEnabled = await _locationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
          'سرویس موقعیت فعال نیست. لطفاً از تنظیمات GPS استفاده کنید.');
    }

    LocationPermission permission = await _checkLocationPermission();
    if (permission == LocationPermission.denied) {
      // Not bounded on purpose: this opens the system dialog and waits on the
      // user, not on a platform call that could wedge.
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
            'دسترسی به موقعیت مکانی رد شد. برای محاسبه دقیق اوقات نماز، دسترسی را فعال کنید.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'دسترسی به موقعیت مکانی دائماً رد شده. لطفاً از تنظیمات سیستم دسترسی را فعال کنید.');
    }

    final position = await getCurrentPositionWithFallback(
      logTag: 'PrayerRepository',
    ).timeout(_locationFixTimeout);
    _cachedPosition = position;
    _cachedPositionTime = DateTime.now();
    await _captureGpsAltitude(position);
    return position;
  }

  /// Save the GPS altitude (meters) when the fix actually reported one.
  /// A value of 0.0 usually means the sensor had no altitude data.
  Future<void> _captureGpsAltitude(Position position) async {
    if (position.altitude != 0.0) {
      await setAltitudeForCoords(
          position.altitude, position.latitude, position.longitude);
    }
  }

  pi.PrayerTimes _toDomain(adhan.PrayerTimes pt, adhan.Coordinates? coords,
      [DateTime? date]) {
    final d = date ?? DateTime.now();
    // وقت نماز جمعه: در روزهای جمعه، ساعتِ ذخیره‌شدهٔ کاربر جای وقت محاسبه‌شدهٔ
    // ظهر را می‌گیرد. `null` یعنی کاربر چیزی انتخاب نکرده و همان ظهرِ
    // محاسبه‌شده مبناست (پیش‌فرض).
    var dhuhrAt = pt.dhuhr;
    final friday = _fridayPrayerTime;
    if (friday != null && d.weekday == DateTime.friday) {
      dhuhrAt = DateTime(d.year, d.month, d.day, friday.hour, friday.minute);
    }
    pi.PrayerInfo info(String name, String arabicName, DateTime time) =>
        pi.PrayerInfo(
          name: name,
          arabicName: arabicName,
          time: DayTime(hour: time.hour, minute: time.minute),
        );
    return pi.PrayerTimes(
      date: d,
      fajr: info('fajr', 'فجر', pt.fajr),
      shorouq: info('shorouq', 'طلوع', pt.sunrise),
      duhr: info('duhr', 'ظهر', dhuhrAt),
      asr: info('asr', 'عصر', pt.asr),
      maghrib: info('maghrib', 'مغرب', pt.maghrib),
      isha: info('isha', 'عشاء', pt.isha),
      locationCity: _cityName.isNotEmpty ? _cityName : null,
      latitude: coords?.latitude,
      longitude: coords?.longitude,
    );
  }
}

/// A resolved timezone for prayer calculations: a real tz database location,
/// or — when the stored id is missing/unparseable — a fixed device offset.
class _ResolvedZone {
  final tz.Location? location;
  final Duration fixedOffset;

  const _ResolvedZone(this.location, this.fixedOffset);

  /// UTC offset for the calendar day of [forDate] (its y/m/d fields are the
  /// zone's wall date, matching DateComponents). Anchored at local NOON:
  /// local midnight sits on the wrong side of a 02:00/03:00 DST transition
  /// (Sydney starts DST at 02:00 on the changeover day), so the whole day's
  /// events — which all fall within ±7h of noon — resolve on one offset.
  Duration offsetForDate(DateTime forDate) {
    final loc = location;
    if (loc == null) return fixedOffset;
    return tz.TZDateTime(loc, forDate.year, forDate.month, forDate.day, 12)
        .timeZoneOffset;
  }

  /// Wall-clock fields of [base] (or now) on this zone's clock.
  DateTime wallOf([DateTime? base]) {
    final loc = location;
    if (loc == null) {
      final utc = (base ?? DateTime.now()).toUtc().add(fixedOffset);
      return DateTime(
          utc.year, utc.month, utc.day, utc.hour, utc.minute, utc.second);
    }
    final inTz =
        base != null ? tz.TZDateTime.from(base, loc) : tz.TZDateTime.now(loc);
    return DateTime(
        inTz.year, inTz.month, inTz.day, inTz.hour, inTz.minute, inTz.second);
  }
}
