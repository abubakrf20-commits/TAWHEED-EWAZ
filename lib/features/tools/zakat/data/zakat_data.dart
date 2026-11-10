import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/latinize_json_digits.dart';
import 'package:tawheeed/core/theme/theme.dart';

class ZakatContent {
  ZakatContent._();

  static Map<String, dynamic>? _data;
  static bool get isLoaded => _data != null;

  static Future<void> load() async {
    if (_data != null) return;
    try {
      final jsonString =
          await rootBundle.loadString('assets/content/zakat.json');
      _data =
          latinizeJsonDigits(json.decode(jsonString)) as Map<String, dynamic>;
    } catch (_) {
      AppLogger.warning('zakat_data', 'operation failed');
      _data = {};
    }
  }

  static Color accent = AppTheme.success;

  static List<T> _list<T>(String key) {
    final v = _data?[key];
    if (v is List) return v.cast<T>();
    return [];
  }

  static String get disclaimer {
    final v = _data?['disclaimer'];
    if (v is String) return v;
    return '';
  }

  static List<Map<String, dynamic>> get intro =>
      _list<Map<String, dynamic>>('intro');
  static List<Map<String, dynamic>> get conditions =>
      _list<Map<String, dynamic>>('conditions');
  static List<Map<String, dynamic>> get assetTypes =>
      _list<Map<String, dynamic>>('assetTypes');
  static List<Map<String, dynamic>> get nisab =>
      _list<Map<String, dynamic>>('nisab');
  static List<Map<String, dynamic>> get recipients =>
      _list<Map<String, dynamic>>('recipients');
  static List<Map<String, dynamic>> get contemporary =>
      _list<Map<String, dynamic>>('contemporary');
  static List<Map<String, dynamic>> get specialRulings =>
      _list<Map<String, dynamic>>('specialRulings');
  static List<Map<String, dynamic>> get faq =>
      _list<Map<String, dynamic>>('faq');
  static Map<String, List<String>> get checklists {
    final v = _data?['checklists'];
    if (v is Map) {
      return Map<String, List<String>>.from(
        v.map((k, v) => MapEntry(k, (v as List).cast<String>())),
      );
    }
    return {};
  }
}
