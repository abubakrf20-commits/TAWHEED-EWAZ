import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/prayer/data/datasources/prayer_local_datasource.dart';

/// Audit G-1: location must not sit in the SharedPreferences file that Android
/// copies wholesale into the user's Google cloud backup. Coordinates, city and
/// altitude are now secure-storage only; the readers migrate any pre-fix
/// plaintext copy and purge it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PrayerLocalDataSource ds;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    ds = PrayerLocalDataSource(SharedPreferences.getInstance());
  });

  test('setSavedCoords stores nothing in SharedPreferences', () async {
    await ds.setSavedCoords(35.6892, 51.3890);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('saved_lat_fallback'), isNull);
    expect(prefs.getDouble('saved_lng_fallback'), isNull);

    expect(await ds.getSavedLat(), closeTo(35.6892, 1e-9));
    expect(await ds.getSavedLng(), closeTo(51.3890, 1e-9));
  });

  test('a legacy plaintext coord fallback is promoted then purged', () async {
    SharedPreferences.setMockInitialValues({
      'saved_lat_fallback': 21.4225,
      'saved_lng_fallback': 39.8262,
    });
    ds = PrayerLocalDataSource(SharedPreferences.getInstance());

    expect(await ds.getSavedLat(), closeTo(21.4225, 1e-9));
    expect(await ds.getSavedLng(), closeTo(39.8262, 1e-9));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('saved_lat_fallback'), isNull,
        reason: 'the backed-up plaintext copy must be removed');
    expect(prefs.getDouble('saved_lng_fallback'), isNull);

    // Still readable, now from secure storage only.
    expect(await ds.getSavedLat(), closeTo(21.4225, 1e-9));
  });

  test('city and altitude are secure-only and migrate legacy prefs', () async {
    SharedPreferences.setMockInitialValues({
      'saved_city': 'تهران',
      'saved_altitude': 1189.0,
    });
    ds = PrayerLocalDataSource(SharedPreferences.getInstance());

    expect(await ds.getSavedCity(), 'تهران');
    expect(await ds.getSavedAltitude(), closeTo(1189.0, 1e-9));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('saved_city'), isNull);
    expect(prefs.getDouble('saved_altitude'), isNull);
  });

  test('writing a fresh city leaves the prefs file clean', () async {
    await ds.setSavedCity('اصفهان');
    await ds.setSavedAltitude(1574.0);
    await ds.setSavedAltitudeCoords(32.654, 51.668);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('saved_city'), isNull);
    expect(prefs.getDouble('saved_altitude'), isNull);
    expect(prefs.getDouble('saved_altitude_lat'), isNull);
    expect(prefs.getDouble('saved_altitude_lng'), isNull);

    expect(await ds.getSavedCity(), 'اصفهان');
    expect(await ds.getSavedAltitude(), closeTo(1574.0, 1e-9));
    expect(await ds.getSavedAltitudeLat(), closeTo(32.654, 1e-9));
    expect(await ds.getSavedAltitudeLng(), closeTo(51.668, 1e-9));
  });
}
