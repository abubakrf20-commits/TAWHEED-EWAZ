import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/latinize_json_digits.dart';

class SawmData {
  SawmData._();

  static Map<String, dynamic>? _data;

  static bool get isLoaded => _data != null;

  static Future<void> load() async {
    if (_data != null) return;
    try {
      final jsonString =
          await rootBundle.loadString('assets/content/sawm.json');
      _data =
          latinizeJsonDigits(json.decode(jsonString)) as Map<String, dynamic>;
    } catch (_) {
      AppLogger.warning('fasting_content', 'operation failed');
      _data = {};
    }
  }

  static const Color accent = TopicHues.fasting;

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
  static List<Map<String, dynamic>> get arkan =>
      _list<Map<String, dynamic>>('arkan');
  static List<Map<String, dynamic>> get nullifiers =>
      _list<Map<String, dynamic>>('nullifiers');
  static List<String> get doesNotNullify => _list<String>('doesNotNullify');
  static List<Map<String, dynamic>> get qadaKaffarah =>
      _list<Map<String, dynamic>>('qadaKaffarah');
  static List<String> get makruhat => _list<String>('makruhat');
  static List<Map<String, dynamic>> get makruhatDetails =>
      _list<Map<String, dynamic>>('makruhatDetails');
  static List<String> get sunan => _list<String>('sunan');
  static List<Map<String, dynamic>> get specialCases =>
      _list<Map<String, dynamic>>('specialCases');
  static List<Map<String, dynamic>> get contemporaryIssues =>
      _list<Map<String, dynamic>>('contemporaryIssues');
  static List<Map<String, dynamic>> get faq =>
      _list<Map<String, dynamic>>('faq');
}
