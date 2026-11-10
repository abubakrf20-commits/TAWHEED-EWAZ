import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';

class AzkarData {
  AzkarData._();

  static List<ZikrItem>? _cached;

  @visibleForTesting
  static void setTestData(List<ZikrItem> items) {
    _cached = items;
  }

  /// Drops the cache so a test can simulate a cold start (the state the home
  /// summary meets on its first frame).
  @visibleForTesting
  static void resetTestData() {
    _cached = null;
  }

  static Future<List<ZikrItem>> loadAll() async {
    if (_cached != null) return _cached!;
    final jsonStr = await rootBundle.loadString('assets/azkar_content.json');
    final list = await compute(_decodeAzkarJson, jsonStr);
    _cached = list.map(ZikrItem.fromJson).toList();
    return _cached!;
  }

  /// Decodes the raw azkar JSON off the main isolate to avoid blocking the UI
  /// thread on the initial load. Only JSON primitives cross the isolate, so the
  /// [ZikrItem] mapping happens safely back on the main isolate.
  static List<Map<String, dynamic>> _decodeAzkarJson(String source) {
    return (jsonDecode(source) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  static List<ZikrItem> getByPeriod(PrayerPeriod period) {
    final all = _cached;
    if (all == null) return [];
    return all.where((z) => z.period.name == period.name).toList();
  }

  static List<ZikrItem> get allAzkar => _cached ?? [];

  static Future<void> ensureLoaded() async {
    await loadAll();
  }
}
