import 'package:tawheeed/features/suggestions/domain/entities/suggestion.dart';

/// مخزن پیشنهادها؛ پیاده‌سازی Firestore در لایهٔ data با همین قرارداد.
///
/// این رابط به تست‌ها اجازه می‌دهد بدون نیاز به Firebase یک مخزن جعلی
/// تزریق کنند.
abstract interface class SuggestionsRepository {
  /// آیا Firebase در این اجرا راه‌اندازی شده؟ اگر خیر، ارسال و پنل مدیر
  /// باید غیرفعال نشان داده شوند و [watchAll] جریان خالی برگرداند.
  bool get isAvailable;

  /// ارسال یک پیشنهاد/انتقاد جدید. [name] اختیاری است.
  Future<void> submit({
    required String text,
    SuggestionCategory category = SuggestionCategory.suggestion,
    String? name,
  });

  /// جریان لحظه‌ای همهٔ پیشنهادها (جدیدترین اول).
  Stream<List<Suggestion>> watchAll();

  /// جریان پیشنهادهای همین دستگاه تا فرستنده پاسخ مدیر را ببیند.
  Stream<List<Suggestion>> watchMine();

  /// جریان پیشنهادهایی که مدیر عمومی منتشر کرده است.
  Stream<List<Suggestion>> watchPublic();

  /// ثبت/ویرایش پاسخ مدیر برای یک پیشنهاد.
  Future<void> reply(String id, String text);

  /// انتشار یا لغو انتشار عمومی یک پیشنهاد.
  Future<void> setPublic(String id, bool isPublic);

  /// حذف یک پیشنهاد (تنها توسط مدیر).
  Future<void> delete(String id);
}
