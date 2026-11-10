import 'package:tawheeed/features/dorar_hadith/domain/entities/dorar_hadith_entity.dart';
import 'package:tawheeed/features/dorar_hadith/domain/repositories/dorar_hadith_repository.dart';

/// گرفتن حدیث مشابه و بدیلِ صحیح برای یک حدیث.
class GetHadithAlternativesUseCase {
  final DorarHadithRepository repository;

  const GetHadithAlternativesUseCase(this.repository);

  Future<DorarHadithDetail> call(String hadithId) {
    if (hadithId.trim().isEmpty) {
      throw const DorarHadithFailure('شناسه حدیث معتبر نیست');
    }
    return repository.getHadithDetails(hadithId);
  }
}
