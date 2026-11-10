import 'package:dorar_hadith/dorar_hadith.dart';
import 'package:tawheeed/features/dorar_hadith/data/daos/dorar_favorite_dao.dart';
import 'package:tawheeed/features/dorar_hadith/data/datasources/dorar_remote_datasource.dart';
import 'package:tawheeed/features/dorar_hadith/domain/entities/dorar_hadith_entity.dart';
import 'package:tawheeed/features/dorar_hadith/domain/repositories/dorar_hadith_repository.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

class DorarHadithRepositoryImpl implements DorarHadithRepository {
  final DorarHadithRemoteDataSource dataSource;
  final DorarFavoriteDao favorites;

  DorarHadithRepositoryImpl({
    required this.dataSource,
    required this.favorites,
  });

  /// همهٔ خطاهای سرویس (حتی غیردوراری مثل خرابی کش) به پیام فارسی تبدیل
  /// می‌شود؛ متن اصلی در لاگر می‌ماند تا خطای دستگاه از دور قابل تشخیص باشد.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DorarHadithFailure {
      rethrow;
    } on DorarException catch (e) {
      AppLogger.warning('DorarHadith', '${e.runtimeType}: ${e.message}');
      throw DorarHadithFailure(_userMessage(e));
    } catch (e, st) {
      AppLogger.error('DorarHadith', e, st);
      throw const DorarHadithFailure(
          'مشکلی در ارتباط با پایگاه احادیث پیش آمد. دوباره تلاش کنید.');
    }
  }

  @override
  Future<DorarHadithResultsPage> search({
    required String query,
    int page = 1,
    DorarHadithFilter filter = DorarHadithFilter.all,
  }) =>
      _guard(() async {
        final model = await dataSource.search(
          query: query,
          page: page,
          filter: filter,
        );
        return model.toDomain();
      });

  @override
  Future<DorarHadithDetail> getHadithDetails(String id) => _guard(() async {
        final hadith = await dataSource.getById(id);
        final similar = await dataSource.getSimilarHadiths(id);
        final alternative = await dataSource.getAuthenticAlternative(id);
        return DorarHadithDetail(
          hadith: hadith.toEntity(),
          similar: similar.map((m) => m.toEntity()).toList(),
          authenticAlternative: alternative?.toEntity(),
        );
      });

  @override
  Future<String?> getExplanation(String hadithText) =>
      _guard(() => dataSource.getExplanation(hadithText));

  @override
  Future<void> saveFavorite(DorarHadithEntity hadith) =>
      favorites.upsertFavorite(hadith);

  @override
  Future<void> removeFavorite(String id) => favorites.deleteFavorite(id);

  @override
  Future<Set<String>> favoriteIds() async {
    final rows = await favorites.getFavorites();
    return rows.map((r) => r.id).toSet();
  }

  /// پیام‌های خطای پکیج (عربی/انگلیسی) به پیام قابل‌فهم فارسی تبدیل می‌شود؛
  /// rate-limit و خطای سرور برای کاربر فرق دارند.
  static String _userMessage(DorarException e) {
    // «HTTP 403: …» یعنی درخواست به سرور رسیده ولی پاسخ وضعیت داده —
    // پیام «اینترنت را وصل کنید» اینجا گمراه‌کننده است.
    if (e is DorarNetworkException && e.message.startsWith('HTTP ')) {
      return 'سرور پایگاه احادیث به این درخواست پاسخ نداد. '
          'کمی بعد دوباره تلاش کنید.';
    }
    if (e is DorarNetworkException || e is DorarTimeoutException) {
      return 'برای جستجوی احادیث باید به اینترنت متصل باشید.';
    }
    if (e is DorarRateLimitException) {
      return 'چند لحظه صبر کنید و دوباره جستجو کنید.';
    }
    if (e is DorarValidationException) {
      return 'عبارت جستجو معتبر نیست.';
    }
    return 'خطا در جستجوی احادیث. دوباره تلاش کنید.';
  }
}
