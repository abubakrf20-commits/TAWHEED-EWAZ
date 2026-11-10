import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';

abstract class SettingsRepository {
  Future<AppSettings> getSettings();
  Future<void> updateSettings(AppSettings settings);
  Future<void> resetSettings();
  Future<void> setOnboardingCompleted(bool completed);
  Future<bool> isOnboardingCompleted();
  Future<void> setPremiumStatus(bool isPremium);
  Future<bool> isPremium();
  Stream<AppSettings> watchSettings();
}
