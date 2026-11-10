import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/latinize_json_digits.dart';

/// Static content for Wudu/Purification education module — based on Shafi'i fiqh.
class TaharahData {
  TaharahData._();

  static Map<String, dynamic>? _data;
  static bool get isLoaded => _data != null;

  static Future<void> load() async {
    if (_data != null) return;
    try {
      final jsonString =
          await rootBundle.loadString('assets/content/taharah.json');
      _data =
          latinizeJsonDigits(json.decode(jsonString)) as Map<String, dynamic>;
    } catch (_) {
      AppLogger.warning('taharah_data', 'operation failed');
      _data = {};
    }
  }

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
  static List<Map<String, dynamic>> get wudu =>
      _list<Map<String, dynamic>>('wudu');
  static List<Map<String, dynamic>> get wuduConditions =>
      _list<Map<String, dynamic>>('wuduConditions');
  static List<Map<String, dynamic>> get wuduArkan =>
      _list<Map<String, dynamic>>('wuduArkan');
  static List<String> get wuduSunan => _list<String>('wuduSunan');
  static List<Map<String, dynamic>> get nullifiers =>
      _list<Map<String, dynamic>>('nullifiers');
  static List<String> get doNotNullify => _list<String>('doNotNullify');
  static List<Map<String, dynamic>> get ghusl =>
      _list<Map<String, dynamic>>('ghusl');
  static List<Map<String, dynamic>> get ghuslObligations =>
      _list<Map<String, dynamic>>('ghuslObligations');
  static List<String> get ghuslMustahabb => _list<String>('ghuslMustahabb');
  static List<Map<String, dynamic>> get ghuslArkan =>
      _list<Map<String, dynamic>>('ghuslArkan');
  static List<String> get ghuslSunan => _list<String>('ghuslSunan');
  static List<Map<String, dynamic>> get tayammum =>
      _list<Map<String, dynamic>>('tayammum');
  static List<Map<String, dynamic>> get tayammumConditions =>
      _list<Map<String, dynamic>>('tayammumConditions');
  static List<Map<String, dynamic>> get tayammumArkan =>
      _list<Map<String, dynamic>>('tayammumArkan');
  static String get tayammumNote {
    final v = _data?['tayammumNote'];
    if (v is String) return v;
    return '';
  }

  static String get tayammumNullifiers {
    final v = _data?['tayammumNullifiers'];
    if (v is String) return v;
    return '';
  }

  static List<Map<String, dynamic>> get najasah =>
      _list<Map<String, dynamic>>('najasah');
  static List<Map<String, dynamic>> get najasahTypes =>
      _list<Map<String, dynamic>>('najasahTypes');
  static List<Map<String, dynamic>> get tathir =>
      _list<Map<String, dynamic>>('tathir');
  static List<Map<String, dynamic>> get miscellaneous =>
      _list<Map<String, dynamic>>('miscellaneous');
}
