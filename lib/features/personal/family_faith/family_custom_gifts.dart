/// The user's own gift list for «صله رحم» — «هدایای دلخواه من».
///
/// The bundled catalogue (`assets/data/gift_ideas.json`) is a starting point,
/// not a limit: what a family actually gives is local knowledge (the tea the
/// aunt asks for, the book the cousin wanted). Those rows live in
/// SharedPreferences as one JSON array, for the same reason the reminder
/// settings do — they are one feature's small list, not a table worth a schema
/// migration, and losing them with the app data is acceptable.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/shared/utils/app_logger.dart';

class CustomGift {
  const CustomGift({required this.id, required this.title, this.note = ''});

  final String id;
  final String title;

  /// Optional hint: size, colour, which shop, how much — free text.
  final String note;

  CustomGift copyWith({String? title, String? note}) => CustomGift(
        id: id,
        title: title ?? this.title,
        note: note ?? this.note,
      );

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'note': note};

  /// A malformed row is skipped, never fatal: one bad record must not wipe the
  /// user's whole list.
  static CustomGift? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] as String?)?.trim() ?? '';
    final title = (raw['title'] as String?)?.trim() ?? '';
    if (id.isEmpty || title.isEmpty) return null;
    return CustomGift(
      id: id,
      title: title,
      note: (raw['note'] as String?)?.trim() ?? '',
    );
  }
}

/// Parses the stored array. Unknown shapes degrade to an empty list.
List<CustomGift> parseCustomGifts(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final row in decoded)
        if (CustomGift.fromJson(row) case final gift?) gift,
    ];
  } catch (e) {
    AppLogger.warning('CustomGifts', 'stored list read failed: $e');
    return const [];
  }
}

String encodeCustomGifts(List<CustomGift> gifts) =>
    jsonEncode([for (final gift in gifts) gift.toJson()]);

class CustomGiftsStorage {
  CustomGiftsStorage._();

  static const key = 'personal.family.custom_gifts';

  static Future<List<CustomGift>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return const [];
      return parseCustomGifts(raw);
    } catch (e) {
      AppLogger.warning('CustomGifts', 'load failed: $e');
      return const [];
    }
  }

  static Future<void> save(List<CustomGift> gifts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, encodeCustomGifts(gifts));
    } catch (e) {
      AppLogger.warning('CustomGifts', 'save failed: $e');
    }
  }
}
