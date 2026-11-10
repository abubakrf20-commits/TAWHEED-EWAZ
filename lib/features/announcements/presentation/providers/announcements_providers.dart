import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/announcements/data/repositories/firestore_announcements_repository.dart';
import 'package:tawheeed/features/announcements/domain/entities/announcement.dart';
import 'package:tawheeed/features/announcements/domain/repositories/announcements_repository.dart';
import 'package:tawheeed/shared/services/admin_gate.dart';

/// مخزن پیام‌های اطلاع‌رسانی؛ در تست‌ها با یک نمونهٔ جعلی override می‌شود.
final announcementsRepositoryProvider = Provider<AnnouncementsRepository>(
  (ref) => FirestoreAnnouncementsRepository(),
);

/// دروازهٔ ورود مدیر (مشترک با پنل پیشنهادها)؛ در تست‌ها override می‌شود.
final announcementsAdminGateProvider = Provider<AdminGate>(
  (ref) => FirebaseAdminGate(),
);

/// جریان زندهٔ پیام‌های منتشرشده.
///
/// Lazy-Firebase note: core init starts unawaited in `main()` (startup-lag
/// fix); the repository's `isAvailable` gate covers the residual race exactly
/// like a failed init always has.
final announcementsStreamProvider = StreamProvider<List<Announcement>>((ref) {
  return ref.watch(announcementsRepositoryProvider).watchAll();
});
