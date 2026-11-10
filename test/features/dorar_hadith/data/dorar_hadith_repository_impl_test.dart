import 'package:dorar_hadith/dorar_hadith.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/dorar_hadith/data/daos/dorar_favorite_dao.dart';
import 'package:tawheeed/features/dorar_hadith/data/datasources/dorar_remote_datasource.dart';
import 'package:tawheeed/features/dorar_hadith/data/models/dorar_hadith_model.dart';
import 'package:tawheeed/features/dorar_hadith/data/repositories/dorar_hadith_repository_impl.dart';
import 'package:tawheeed/features/dorar_hadith/domain/entities/dorar_hadith_entity.dart';
import 'package:tawheeed/features/dorar_hadith/domain/repositories/dorar_hadith_repository.dart';

const _sampleModel = DorarHadithModel(
  hadithText: 'إنما الأعمال بالنيات',
  narrator: 'عمر بن الخطاب',
  mohdith: 'البخاري',
  book: 'صحيح البخاري',
  numberOrPage: '1',
  degree: 'صحيح',
  hadithId: '42',
);

class _FakeDataSource implements DorarHadithRemoteDataSource {
  DorarSearchPageModel nextPage = const DorarSearchPageModel.empty();
  Object? searchError;
  String? explanationToReturn = 'شرح نمونه';
  DorarHadithModel? alternative;
  List<DorarHadithModel> similar = const [];

  final List<DorarHadithFilter> appliedFilters = [];

  @override
  Future<DorarSearchPageModel> search({
    required String query,
    required int page,
    required DorarHadithFilter filter,
  }) async {
    appliedFilters.add(filter);
    final error = searchError;
    if (error != null) throw error;
    return nextPage;
  }

  @override
  Future<DorarHadithModel> getById(String hadithId) async => _sampleModel;

  @override
  Future<List<DorarHadithModel>> getSimilarHadiths(String hadithId) async =>
      similar;

  @override
  Future<DorarHadithModel?> getAuthenticAlternative(String hadithId) async =>
      alternative;

  @override
  Future<String?> getExplanation(String hadithText) async =>
      explanationToReturn;
}

void main() {
  late _FakeDataSource dataSource;
  late AppDatabase db;
  late DorarHadithRepositoryImpl repository;

  setUp(() {
    dataSource = _FakeDataSource();
    db = AppDatabase.withConnection(NativeDatabase.memory());
    repository = DorarHadithRepositoryImpl(
      dataSource: dataSource,
      favorites: DorarFavoriteDao(db),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('DorarHadithRepositoryImpl.search', () {
    test('مدل‌ها را به entity لایه domain نگاشت می‌کند', () async {
      dataSource.nextPage = const DorarSearchPageModel(
        items: [_sampleModel],
        hasNextPage: true,
        totalResults: 31,
      );

      final results = await repository.search(query: 'النية');

      expect(results.items, hasLength(1));
      final hadith = results.items.first;
      expect(hadith.id, '42');
      expect(hadith.canViewDetails, isTrue);
      expect(hadith.hadithText, contains('بالنيات'));
      expect(hadith.narrator, 'عمر بن الخطاب');
      expect(hadith.degree, 'صحيح');
      expect(results.hasNextPage, isTrue);
      expect(results.totalResults, 31);
    });

    test('خطای شبکه به پیام فارسیِ DorarHadithFailure تبدیل می‌شود', () async {
      dataSource.searchError =
          const DorarNetworkException('connection refused');

      await expectLater(
        repository.search(query: 'الصلاة'),
        throwsA(isA<DorarHadithFailure>()
            .having((f) => f.message, 'message', contains('اینترنت'))),
      );
    });

    test('پاسخ وضعیت سرور (HTTP 403) پیام «اینترنت» گمراه‌کننده نمی‌گیرد',
        () async {
      dataSource.searchError =
          const DorarNetworkException('HTTP 403: Forbidden');

      await expectLater(
        repository.search(query: 'الصلاة'),
        throwsA(isA<DorarHadithFailure>()
            .having((f) => f.message, 'message', contains('سرور'))
            .having((f) => f.message, 'message', isNot(contains('اینترنت')))),
      );
    });

    test('خطای غیردوراری (مثل خرابی کش) هم به پیام فارسی نگاشت می‌شود',
        () async {
      dataSource.searchError = StateError('cache db closed');

      await expectLater(
        repository.search(query: 'الصلاة'),
        throwsA(isA<DorarHadithFailure>()
            .having((f) => f.message, 'message', contains('تلاش کنید'))),
      );
    });

    test('فیلترهای درجه صحت به datasource می‌رسند', () async {
      await repository.search(
        query: 'الصلاة',
        filter: DorarHadithFilter.weak,
      );
      expect(dataSource.appliedFilters.single, DorarHadithFilter.weak);
    });
  });

  group('DorarHadithRepositoryImpl.getHadithDetails', () {
    test('حدیث + مشابه + بدیل صحیح را در یک detail جمع می‌کند', () async {
      dataSource.similar = const [_sampleModel];
      dataSource.alternative = _sampleModel;

      final detail = await repository.getHadithDetails('42');

      expect(detail.hadith.id, '42');
      expect(detail.similar, hasLength(1));
      expect(detail.authenticAlternative, isNotNull);
    });

    test('مشابه/بدیل نبود → null و فهرست خالی', () async {
      final detail = await repository.getHadithDetails('42');

      expect(detail.similar, isEmpty);
      expect(detail.authenticAlternative, isNull);
    });
  });

  test('getExplanation بدون شرح → null', () async {
    dataSource.explanationToReturn = null;
    expect(await repository.getExplanation('نص'), isNull);
  });

  group('المفضلة (Drift)', () {
    test('ذخیره، خواندن و حذف در پایگاه داده واقعی', () async {
      await repository.saveFavorite(_sampleModel.toEntity());
      expect(await repository.favoriteIds(), {'42'});

      // ذخیره دوبارهٔ یک حدیث نباید خطا بدهد یا رکورد تکراری بسازد.
      await repository.saveFavorite(_sampleModel.toEntity());
      expect(await repository.favoriteIds(), {'42'});

      await repository.removeFavorite('42');
      expect(await repository.favoriteIds(), isEmpty);
    });

    test('حدیثِ بدون hadithId شناسهٔ پایدار از متن+منبع می‌گیرد', () async {
      const light = DorarHadithModel(
        hadithText: 'حدیث سبک',
        narrator: '',
        mohdith: 'مسلم',
        book: 'صحيح مسلم',
        numberOrPage: '123',
        degree: 'صحيح',
      );
      final entity = light.toEntity();

      expect(entity.canViewDetails, isFalse);
      expect(entity.id, isNotEmpty);
      // پایدار در برابر دو بار نگاشت یک مدل:
      expect(light.toEntity().id, entity.id);

      await repository.saveFavorite(entity);
      final ids = await repository.favoriteIds();
      expect(ids, {entity.id});
      expect(ids.first.length, 40); // sha1 hex
    });
  });
}
