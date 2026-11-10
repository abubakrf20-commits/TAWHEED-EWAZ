abstract class SettingsWriter {
  Future<void> setCity(String city);
  Future<void> setManualCoords(double lat, double lng);
  Future<void> setHasLocation(bool v);
}
