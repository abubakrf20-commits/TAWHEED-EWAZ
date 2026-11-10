/// Remembers the school the reader picked on «کفاره و فدیه».
///
/// The page's default comes from the Asr setting, which is a proxy for a
/// preference, not the preference itself: someone who reads the Hanafi column
/// was put back on the Shafi one on every visit and had to re-pick it. This
/// keeps the last explicit pick so the page opens where it was left.
///
/// A failed read is not an error: with no stored value the Asr default applies,
/// which is what the page did before this file existed.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/shared/utils/app_logger.dart';

class KaffaraChoiceStore {
  KaffaraChoiceStore._();

  static const _madhhabKey = 'personal.kaffara.madhhab';

  static Future<String?> loadMadhhab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_madhhabKey);
    } catch (e) {
      AppLogger.warning('KaffaraChoice', 'load failed: $e');
      return null;
    }
  }

  static Future<void> saveMadhhab(String madhhab) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_madhhabKey, madhhab);
    } catch (e) {
      AppLogger.warning('KaffaraChoice', 'save failed: $e');
    }
  }
}
