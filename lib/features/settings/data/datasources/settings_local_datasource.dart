import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SettingsLocalDataSource {
  final SharedPreferences prefs;

  SettingsLocalDataSource(this.prefs);

  Future<void> setOnboardingCompleted(bool completed) async {
    await prefs.setBool('onboarding_completed', completed);
  }

  Future<bool> isOnboardingCompleted() async {
    return prefs.getBool('onboarding_completed') ?? false;
  }

  Future<void> setPremiumStatus(bool isPremium) async {
    await prefs.setBool('is_premium', isPremium);
  }

  Future<bool> isPremium() async {
    return prefs.getBool('is_premium') ?? false;
  }

  Future<void> clearAll() async {
    await prefs.clear();
  }

  /// The legacy `eval_*` worship-scoring keys (pre-schema-23) lived in
  /// SharedPreferences while the settings DTO ignored them. Returns a JSON-map
  /// of the legacy values (null when none exist) so the repository can import
  /// them into the settings row exactly once.
  Map<String, dynamic>? readLegacyEvalPrefs() {
    final keys = [
      'eval_adhkar_point',
      'eval_tasbih_point',
      'eval_excluded_worship',
      'eval_custom_worship_items',
      'eval_hidden_defaults',
    ];
    if (!keys.any(prefs.containsKey)) return null;
    final map = <String, dynamic>{};
    final adhkar = prefs.getInt('eval_adhkar_point');
    if (adhkar != null) map['adhkarPoint'] = adhkar;
    final tasbih = prefs.getInt('eval_tasbih_point');
    if (tasbih != null) map['tasbihPoint'] = tasbih;
    final excluded = prefs.getString('eval_excluded_worship');
    if (excluded != null && excluded.isNotEmpty) {
      map['excludedWorship'] = excluded;
    }
    final custom = prefs.getString('eval_custom_worship_items');
    if (custom != null && custom.isNotEmpty) {
      map['customWorshipItems'] = custom;
    }
    final hidden = prefs.getString('eval_hidden_defaults');
    if (hidden != null && hidden.isNotEmpty) {
      map['hiddenWorshipItems'] = jsonEncode(hidden.split(','));
    }
    return map;
  }

  Future<void> clearLegacyEvalPrefs() async {
    for (final k in [
      'eval_adhkar_point',
      'eval_tasbih_point',
      'eval_excluded_worship',
      'eval_custom_worship_items',
      'eval_hidden_defaults',
    ]) {
      await prefs.remove(k);
    }
  }
}
