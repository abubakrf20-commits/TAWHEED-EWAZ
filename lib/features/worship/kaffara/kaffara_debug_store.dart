/// Tiny persistence for the kaffara debug (draft-preview) toggle.
///
/// Lives with the kaffara feature now that it has moved into «عبادات و مناسک».
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/shared/utils/app_logger.dart';

class KaffaraDebugStore {
  KaffaraDebugStore._();

  static const _key = 'personal.kaffara.show_drafts';

  static Future<bool> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (e) {
      AppLogger.warning('KaffaraDebug', 'load failed: $e');
      return false;
    }
  }

  static Future<void> save(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (e) {
      AppLogger.warning('KaffaraDebug', 'save failed: $e');
    }
  }
}
