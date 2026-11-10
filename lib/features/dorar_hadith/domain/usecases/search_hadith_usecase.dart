import 'package:tawheeed/features/dorar_hadith/domain/entities/dorar_hadith_entity.dart';
import 'package:tawheeed/features/dorar_hadith/domain/repositories/dorar_hadith_repository.dart';

/// جستجوی حدیث با اعتبارسنجی ورودی کاربر.
class SearchHadithUseCase {
  final DorarHadithRepository repository;

  const SearchHadithUseCase(this.repository);

  Future<DorarHadithResultsPage> call({
    required String query,
    int page = 1,
    DorarHadithFilter filter = DorarHadithFilter.all,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw const DorarHadithFailure('متن جستجو نمی‌تواند خالی باشد');
    }
    if (trimmed.runes.length < 3) {
      throw const DorarHadithFailure('حداقل 3 حرف بنویسید');
    }
    return repository.search(query: trimmed, page: page, filter: filter);
  }
}
