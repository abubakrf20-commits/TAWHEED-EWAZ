import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/latinize_json_digits.dart';

class SalahData {
  SalahData._();

  static Map<String, dynamic>? _data;
  static bool get isLoaded => _data != null;

  static Future<void> load() async {
    if (_data != null) return;
    try {
      final jsonString =
          await rootBundle.loadString('assets/content/salah.json');
      _data =
          latinizeJsonDigits(json.decode(jsonString)) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.warning('SalahData', 'bundled salah data load failed: $e');
      _data = {};
    }
  }

  static const Color accent = Color(0xFF4A7C5A);

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
  static List<Map<String, dynamic>> get times =>
      _list<Map<String, dynamic>>('times');
  static List<Map<String, dynamic>> get conditions =>
      _list<Map<String, dynamic>>('conditions');
  static List<Map<String, dynamic>> get steps =>
      _list<Map<String, dynamic>>('steps');
  static List<String> get arkans => _list<String>('arkans');
  static List<String> get wajibat => _list<String>('wajibat');
  static List<String> get sunan => _list<String>('sunan');
  static List<String> get makruhat => _list<String>('makruhat');
  static List<String> get mubtilat => _list<String>('mutabilat');
  static List<String> get commonMistakes => _list<String>('commonMistakes');
  static List<Map<String, dynamic>> get types =>
      _list<Map<String, dynamic>>('types');
  static List<Map<String, dynamic>> get specialRulings =>
      _list<Map<String, dynamic>>('specialRulings');
  static List<Map<String, dynamic>> get faq =>
      _list<Map<String, dynamic>>('faq');
  static List<Map<String, dynamic>> get checklistSections =>
      _list<Map<String, dynamic>>('checklistSections');
}
