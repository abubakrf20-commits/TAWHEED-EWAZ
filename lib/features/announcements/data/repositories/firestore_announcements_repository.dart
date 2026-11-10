import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tawheeed/features/announcements/domain/entities/announcement.dart';
import 'package:tawheeed/features/announcements/domain/repositories/announcements_repository.dart';

/// پیام‌های اطلاع‌رسانی مدیر روی Firestore.
///
/// اگر Firebase راه‌اندازی نشده باشد [isAvailable] false است و متدهای نوشتن
/// [AnnouncementsWriteError] پرتاب می‌کنند — عمداً `return` خاموش نه، چون آن
/// کاربر پیام موفقیت می‌دید در حالی که هیچ سندی نوشته نشده بود.
class FirestoreAnnouncementsRepository implements AnnouncementsRepository {
  FirestoreAnnouncementsRepository();

  static const collectionName = 'announcements';

  /// مسیرِ صندوقِ خروجی اعلان پوش — مورد استفادهٔ داشبورد وب؛ نوشتنِ
  /// [publish] دیگر به آن وابسته نیست و پیام را مستقیم در [collectionName]
  /// می‌نویسد تا روی همهٔ پلن‌ها (از جمله Spark بدون Cloud Functions) کار کند.
  static const outboxCollection = 'admin/outbox';

  /// حداکثر طول عنوان/متن — هم‌تراز با `isValidAnnouncement()` در
  /// `firestore.rules`. اگر اینها از قوانین بزرگ‌تر شوند، نوشتن رد می‌شود و
  /// کاربر فقط یک «انتشار ناموفق بود» بی‌معنا می‌بیند؛ پس سمت کلاینت هم
  /// محدود می‌شود تا خطا پیش از رفت‌وبرگشت شبکه گرفته شود.
  static const maxTitleLength = kAnnouncementMaxTitleLength;
  static const maxBodyLength = kAnnouncementMaxBodyLength;

  CollectionReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection(collectionName);

  @override
  bool get isAvailable => Firebase.apps.isNotEmpty;

  @override
  Stream<List<Announcement>> watchAll() {
    if (!isAvailable) {
      return const Stream<List<Announcement>>.empty();
    }
    return _ref
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
      final items =
          snap.docs.map((d) => Announcement.fromMap(d.id, d.data())).toList();
      // سنجاق‌شده‌ها بالا، سپس جدیدترین.
      items.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return items;
    });
  }

  @override
  Future<AnnounceResult> publish({
    required String title,
    required String body,
  }) async {
    _requireAvailable();
    final (t, b) = _validated(title, body);

    final now = FieldValue.serverTimestamp();
    final DocumentReference<Map<String, dynamic>> ref;
    try {
      ref = await _ref.add({
        'title': t,
        'body': b,
        'createdAt': now,
        'isPinned': false,
      });
    } on FirebaseException catch (e) {
      throw _translate(e);
    }

    // انتشار «مستقیم از اپ»: فقط کالکشن `announcements` نوشته می‌شود؛ هیچ
    // وابستگی به Cloud Function یا صندوق خروجی نیست (که روی پلن Spark
    // مستقر نیست). اگر بعداً توابع فعال شوند، داشبورد وب می‌تواند صندوقِ
    // خروجی را جدا پر کند.
    return AnnounceResult(
      id: ref.id,
      pushQueued: false,
    );
  }

  @override
  Future<void> setPinned(String id, bool isPinned) async {
    _requireAvailable();
    try {
      await _ref.doc(id).update({'isPinned': isPinned});
    } on FirebaseException catch (e) {
      throw _translate(e);
    }
  }

  @override
  Future<void> update({
    required String id,
    required String title,
    required String body,
  }) async {
    _requireAvailable();
    final (t, b) = _validated(title, body);
    try {
      await _ref.doc(id).update({'title': t, 'body': b});
    } on FirebaseException catch (e) {
      throw _translate(e);
    }
  }

  @override
  Future<void> delete(String id) async {
    _requireAvailable();
    try {
      await _ref.doc(id).delete();
    } on FirebaseException catch (e) {
      throw _translate(e);
    }
  }

  /// به‌جای بازگشت خاموش، صریحاً خطا می‌دهیم.
  void _requireAvailable() {
    if (!isAvailable) {
      throw const AnnouncementsWriteError(AnnouncementsFailure.unavailable);
    }
  }

  /// اعتبارسنجی مشترک عنوان/متن (پیش از انتشار یا ویرایش).
  ///
  /// جلوگیری از نوشتنی که قوانین رد می‌کنند: طول بر حسب کاراکتر است و
  /// `maxLength` دیالوگ هم همین را می‌شمارد، پس این دو هم‌ترازند.
  (String, String) _validated(String title, String body) {
    final t = title.trim();
    final b = body.trim();
    if (t.isEmpty || b.isEmpty) {
      throw const AnnouncementsWriteError(
        AnnouncementsFailure.unknown,
        cause: 'empty title or body',
      );
    }
    if (t.length > maxTitleLength || b.length > maxBodyLength) {
      throw const AnnouncementsWriteError(
        AnnouncementsFailure.unknown,
        cause: 'announcement exceeds the Firestore length limit',
      );
    }
    return (t, b);
  }

  /// ترجمهٔ خطای Firestore به دلیل قابل‌نمایش.
  ///
  /// `permission-denied` را جدا می‌کنیم چون رایج‌ترین علت است و پیامش باید
  /// راهنمای عملی بدهد، نه «دوباره تلاش کنید».
  AnnouncementsWriteError _translate(FirebaseException e) {
    final reason = switch (e.code) {
      'permission-denied' ||
      'unauthenticated' =>
        AnnouncementsFailure.permissionDenied,
      'unavailable' ||
      'deadline-exceeded' ||
      'network-request-failed' =>
        AnnouncementsFailure.network,
      'failed-precondition' ||
      'unimplemented' =>
        AnnouncementsFailure.unavailable,
      _ => AnnouncementsFailure.unknown,
    };
    return AnnouncementsWriteError(reason, cause: '${e.code}: ${e.message}');
  }
}
