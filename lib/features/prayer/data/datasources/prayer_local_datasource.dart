import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/services/app_secure_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/date_key.dart';

class PrayerLocalDataSource {
  final Future<SharedPreferences> _prefsFuture;
  SharedPreferences? _cachedPrefs;
  final FlutterSecureStorage _secureStorage;

  PrayerLocalDataSource(this._prefsFuture,
      {FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? appSecureStorage;

  Future<SharedPreferences> get _prefs async {
    return _cachedPrefs ??= await _prefsFuture;
  }

  // Secure-storage key names.
  static const _latKey = 'saved_lat';
  static const _lngKey = 'saved_lng';
  static const _cityKey = 'saved_city';
  static const _altitudeKey = 'saved_altitude';
  static const _altitudeLatKey = 'saved_altitude_lat';
  static const _altitudeLngKey = 'saved_altitude_lng';
  // Legacy SharedPreferences keys that used to hold a plaintext copy. Android
  // backup rules exclude per-FILE, not per-KEY, so every value in the default
  // prefs XML is copied to the user's Google cloud backup — location included.
  // These are now stored secure-only (FlutterSecureStorage.xml is excluded);
  // the readers migrate any surviving plaintext here and then purge it (G-1).

  Future<double?> _readSecureDouble(String key, {String? legacyPrefsKey}) async {
    try {
      final val = await _secureStorage.read(key: key);
      if (val != null) return double.tryParse(val);
    } catch (e) {
      AppLogger.warning('PrayerLocal', '$key secure read failed: $e');
    }
    if (legacyPrefsKey == null) return null;
    // One-time migration: promote the legacy plaintext copy into secure storage,
    // then delete it so the OS backup no longer carries the old value.
    final prefs = await _prefs;
    final legacy = prefs.getDouble(legacyPrefsKey);
    if (legacy == null) return null;
    await _writeSecure(key, legacy.toString());
    await prefs.remove(legacyPrefsKey);
    return legacy;
  }

  Future<void> _writeSecure(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      AppLogger.warning('PrayerLocal', '$key secure write failed: $e');
    }
  }

  Future<double?> getSavedLat() =>
      _readSecureDouble(_latKey, legacyPrefsKey: 'saved_lat_fallback');

  Future<double?> getSavedLng() =>
      _readSecureDouble(_lngKey, legacyPrefsKey: 'saved_lng_fallback');

  Future<String> getSavedCity() async {
    try {
      final val = await _secureStorage.read(key: _cityKey);
      if (val != null) return val;
    } catch (e) {
      AppLogger.warning('PrayerLocal', 'city secure read failed: $e');
    }
    final prefs = await _prefs;
    final legacy = prefs.getString(_cityKey);
    if (legacy == null) return '';
    await _writeSecure(_cityKey, legacy);
    await prefs.remove(_cityKey);
    return legacy;
  }

  Future<void> setSavedCity(String city) async {
    await _writeSecure(_cityKey, city);
    await (await _prefs).remove(_cityKey);
  }

  /// Altitude above sea level (meters) of the last resolved location.
  Future<double?> getSavedAltitude() => _readSecureDouble(_altitudeKey,
      legacyPrefsKey: _altitudeKey);

  Future<void> setSavedAltitude(double altitude) async {
    await _writeSecure(_altitudeKey, altitude.toString());
    await (await _prefs).remove(_altitudeKey);
  }

  Future<double?> getSavedAltitudeLat() =>
      _readSecureDouble(_altitudeLatKey, legacyPrefsKey: _altitudeLatKey);

  Future<double?> getSavedAltitudeLng() =>
      _readSecureDouble(_altitudeLngKey, legacyPrefsKey: _altitudeLngKey);

  Future<void> setSavedAltitudeCoords(double lat, double lng) async {
    await _writeSecure(_altitudeLatKey, lat.toString());
    await _writeSecure(_altitudeLngKey, lng.toString());
    final prefs = await _prefs;
    await prefs.remove(_altitudeLatKey);
    await prefs.remove(_altitudeLngKey);
  }

  Future<void> setSavedCoords(double lat, double lng) async {
    // Secure storage only. The old SharedPreferences fallback leaked the exact
    // coordinates into the Google cloud backup, so it is no longer written and
    // any legacy plaintext copy is purged here.
    await _writeSecure(_latKey, lat.toString());
    await _writeSecure(_lngKey, lng.toString());
    final prefs = await _prefs;
    await prefs.remove('saved_lat_fallback');
    await prefs.remove('saved_lng_fallback');
  }

  Future<String?> getCachedDate() async => (await _prefs).getString('date');

  Future<DateTime?> getCachedTime(String key) async {
    final raw = (await _prefs).getString(key);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> cacheToday(Map<String, DateTime> times) async {
    final p = await _prefs;
    // The cached values are device-local wall-clock times, so the day key must
    // be the device-local calendar date too — a fixed +3:30 Tehran day would
    // mismatch (and invalidate the offline cache) for users in other zones.
    final today = dateKeyOf(DateTime.now());
    await p.setString('date', today);
    for (final entry in times.entries) {
      await p.setString(entry.key, entry.value.toIso8601String());
    }
  }
}
