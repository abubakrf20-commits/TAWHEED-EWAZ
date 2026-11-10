import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tawheeed/features/suggestions/data/suggestion_device_tag.dart';
import 'package:tawheeed/features/suggestions/domain/entities/suggestion.dart';
import 'package:tawheeed/features/suggestions/domain/repositories/suggestions_repository.dart';

/// پیاده‌سازی Firestore مخزن پیشنهادها.
///
/// اگر Firebase راه‌اندازی نشده باشد (مثلاً فایل google-services.json
/// ناقص باشد) [isAvailable] برابر false است و همهٔ عملیات خاموشانه
/// اجرا می‌شوند تا برنامه از کار نیفتد.
class FirestoreSuggestionsRepository implements SuggestionsRepository {
  FirestoreSuggestionsRepository();

  static const _collectionName = 'suggestions';

  CollectionReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection(_collectionName);

  @override
  bool get isAvailable => Firebase.apps.isNotEmpty;

  @override
  Future<void> submit({
    required String text,
    SuggestionCategory category = SuggestionCategory.suggestion,
    String? name,
  }) async {
    if (!isAvailable) return;
    final tag = await SuggestionDeviceTag.get();
    final trimmedName = (name ?? '').trim();
    await _ref.add({
      'text': text,
      'category': category.code,
      'deviceTag': tag,
      // Only store a name when the user actually typed one, so the admin panel
      // can tell "anonymous" apart from "empty string".
      if (trimmedName.isNotEmpty) 'name': trimmedName,
      'createdAt': FieldValue.serverTimestamp(),
      'isPublic': false,
    });
  }

  @override
  Stream<List<Suggestion>> watchAll() {
    if (!isAvailable) {
      return const Stream<List<Suggestion>>.empty();
    }
    return _ref
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Suggestion.fromMap(d.id, d.data())).toList(),
        );
  }

  /// Equality on a single field only — Firestore serves that from the automatic
  /// index, so no composite index has to be provisioned for this query. The
  /// ordering is applied client-side for the same reason.
  Stream<List<Suggestion>> _watchWhere(String field, Object? value, int limit) {
    if (!isAvailable) {
      return const Stream<List<Suggestion>>.empty();
    }
    return _ref
        .where(field, isEqualTo: value)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final items =
          snap.docs.map((d) => Suggestion.fromMap(d.id, d.data())).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  @override
  Stream<List<Suggestion>> watchMine() async* {
    if (!isAvailable) {
      yield const <Suggestion>[];
      return;
    }
    final tag = await SuggestionDeviceTag.get();
    if (tag.isEmpty) {
      yield const <Suggestion>[];
      return;
    }
    yield* _watchWhere('deviceTag', tag, 50);
  }

  @override
  Stream<List<Suggestion>> watchPublic() => _watchWhere('isPublic', true, 100);

  @override
  Future<void> reply(String id, String text) async {
    if (!isAvailable) return;
    final trimmed = text.trim();
    await _ref.doc(id).update({
      'reply': trimmed,
      'repliedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setPublic(String id, bool isPublic) async {
    if (!isAvailable) return;
    await _ref.doc(id).update({'isPublic': isPublic});
  }

  @override
  Future<void> delete(String id) async {
    if (!isAvailable) return;
    await _ref.doc(id).delete();
  }
}
