import 'package:tawheeed/features/dorar_hadith/domain/entities/dorar_hadith_entity.dart';

/// خطای قابل‌نمایش برای کاربر — پیامش فارسی و بدون پیشوند Exception است.
class DorarHadithFailure implements Exception {
  final String message;

  const DorarHadithFailure(this.message);

  @override
  String toString() => message;
}

/// قرارداد جستجوی احادیث درر — لایه Domain.
abstract class DorarHadithRepository {
  /// جستجوی متن حدیث با فیلتر درجه صحت و Pagination.
  Future<DorarHadithResultsPage> search({
    required String query,
    int page = 1,
    DorarHadithFilter filter = DorarHadithFilter.all,
  });

  /// جزئیات یک حدیث به‌همراه احادیث مشابه و بدیل صحیح.
  Future<DorarHadithDetail> getHadithDetails(String id);

  /// شرح الحديث برای متن داده‌شده؛ null یعنی شرحی یافت نشد.
  Future<String?> getExplanation(String hadithText);

  Future<void> saveFavorite(DorarHadithEntity hadith);

  Future<void> removeFavorite(String id);

  /// شناسه‌های احادیث ذخیره‌شده در المفضلة.
  Future<Set<String>> favoriteIds();
}
