import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/dorar_hadith/domain/entities/dorar_hadith_entity.dart';
import 'package:tawheeed/features/dorar_hadith/domain/repositories/dorar_hadith_repository.dart';
import 'package:tawheeed/features/dorar_hadith/domain/usecases/search_hadith_usecase.dart';

class _RecordingFakeRepository implements DorarHadithRepository {
  final List<({String query, int page, DorarHadithFilter filter})> calls = [];

  @override
  Future<DorarHadithResultsPage> search({
    required String query,
    int page = 1,
    DorarHadithFilter filter = DorarHadithFilter.all,
  }) async {
    calls.add((query: query, page: page, filter: filter));
    return const DorarHadithResultsPage(
      items: [
        DorarHadithEntity(id: '1', hadithText: 'حدیث نمونه'),
      ],
      hasNextPage: true,
      totalResults: 10,
    );
  }

  @override
  Future<DorarHadithDetail> getHadithDetails(String id) async =>
      throw UnimplementedError();

  @override
  Future<String?> getExplanation(String hadithText) async => null;

  @override
  Future<void> saveFavorite(DorarHadithEntity hadith) async {}

  @override
  Future<void> removeFavorite(String id) async {}

  @override
  Future<Set<String>> favoriteIds() async => {};
}

void main() {
  group('SearchHadithUseCase', () {
    test('query را trim کرده و به repository می‌فرستد', () async {
      final repo = _RecordingFakeRepository();
      final useCase = SearchHadithUseCase(repo);

      await useCase(
          query: '  الصلاة  ', page: 2, filter: DorarHadithFilter.sahih);

      expect(repo.calls, hasLength(1));
      expect(repo.calls.first.query, 'الصلاة');
      expect(repo.calls.first.page, 2);
      expect(repo.calls.first.filter, DorarHadithFilter.sahih);
    });

    test('query خالی → DorarHadithFailure و تماس با repository', () async {
      final repo = _RecordingFakeRepository();
      final useCase = SearchHadithUseCase(repo);

      expect(
        () => useCase(query: '   '),
        throwsA(isA<DorarHadithFailure>()
            .having((f) => f.message, 'message', contains('خالی'))),
      );
      expect(repo.calls, isEmpty);
    });

    test('query کوتاه‌تر از 3 حرف رد می‌شود', () async {
      final repo = _RecordingFakeRepository();
      final useCase = SearchHadithUseCase(repo);

      expect(
        () => useCase(query: 'اب'),
        throwsA(isA<DorarHadithFailure>()),
      );
      expect(repo.calls, isEmpty);
    });

    test('نتایج با pagination از repository عبور می‌کند', () async {
      final repo = _RecordingFakeRepository();
      final useCase = SearchHadithUseCase(repo);

      final results = await useCase(query: 'النار');

      expect(results.items, hasLength(1));
      expect(results.hasNextPage, isTrue);
      expect(results.totalResults, 10);
    });
  });
}
