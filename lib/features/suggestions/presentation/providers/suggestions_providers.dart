import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/suggestions/data/repositories/firestore_suggestions_repository.dart';
import 'package:tawheeed/features/suggestions/domain/entities/suggestion.dart';
import 'package:tawheeed/features/suggestions/domain/repositories/suggestions_repository.dart';
import 'package:tawheeed/shared/services/admin_gate.dart';

/// مخزن پیشنهادها؛ در تست‌ها با یک نمونهٔ جعلی override می‌شود.
final suggestionsRepositoryProvider = Provider<SuggestionsRepository>(
  (ref) => FirestoreSuggestionsRepository(),
);

/// دروازهٔ ورود مدیر؛ در تست‌ها با نمونهٔ جعلی override می‌شود.
final adminGateProvider = Provider<AdminGate>((ref) => FirebaseAdminGate());

/// جریان زندهٔ همهٔ پیشنهادها (جدیدترین اول) — مصرف در پنل مدیریت.
///
/// Firebase core is lazy since the startup-lag fix (it starts unawaited in
/// `main()`, well before any screen opens); the repository's `isAvailable`
/// gate covers the residual race exactly like a failed init always has.
final suggestionsStreamProvider = StreamProvider<List<Suggestion>>((ref) {
  return ref.watch(suggestionsRepositoryProvider).watchAll();
});

/// پیشنهادهای همین دستگاه، تا فرستنده پاسخ مدیر را ببیند.
final mySuggestionsStreamProvider = StreamProvider<List<Suggestion>>((ref) {
  return ref.watch(suggestionsRepositoryProvider).watchMine();
});

/// پیشنهادهای عمومی منتشرشده توسط مدیر.
final publicSuggestionsStreamProvider = StreamProvider<List<Suggestion>>((ref) {
  return ref.watch(suggestionsRepositoryProvider).watchPublic();
});
