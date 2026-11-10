import 'dart:async';

import 'package:dorar_hadith/dorar_hadith.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tawheeed/features/dorar_hadith/data/daos/dorar_favorite_dao.dart';
import 'package:tawheeed/features/dorar_hadith/data/datasources/browser_user_agent_client.dart';
import 'package:tawheeed/features/dorar_hadith/data/datasources/dorar_remote_datasource.dart';
import 'package:tawheeed/features/dorar_hadith/data/repositories/dorar_hadith_repository_impl.dart';
import 'package:tawheeed/features/dorar_hadith/domain/entities/dorar_hadith_entity.dart';
import 'package:tawheeed/features/dorar_hadith/domain/repositories/dorar_hadith_repository.dart';
import 'package:tawheeed/features/dorar_hadith/domain/usecases/get_hadith_alternatives_usecase.dart';
import 'package:tawheeed/features/dorar_hadith/domain/usecases/search_hadith_usecase.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

part 'dorar_hadith_provider.g.dart';

/// کلاینت درر برای کل عمر برنامه یکی است و عمداً autoDispose نیست.
///
/// دو دلیل فنی که autoDispose را ناامن می‌کرد:
///
/// ۱) `DorarClient` در سازنده‌اش `CacheDatabase()` می‌سازد و
///    `CacheDatabase()` همان لحظه connection factory را *captures* می‌کند.
///    پس هر کلاینتی که پیش از کامل‌شدن `configureDorarCache()` بسازد، به
///    مسیر پیش‌فرض پکیج گره می‌خورد؛ یعنی `Directory.current/cache.db`،
///    که روی Android قابل نوشتن نیست و هر جست‌وجو را با خطای عمومی
///    «مشکلی در ارتباط با پایگاه احادیث» می‌شکند.
/// ۲) `dispose` در پکیج `async` است ولی `ref.onDispose` فقط `void`
///    می‌پذیرد، پس بستن کش fire-and-forget می‌شد و ممکن بود درخواستِ
///    در حال پرواز را وسط کار روی همان فایل ببندد.
///
/// یک نمونهٔ مادام‌العمر هر دو مشکل را حذف می‌کند: مسیر کش پیش از ساخت
/// کلاینت تضمین شده است و کانکشن تا پایان برنامه باز می‌ماند.
@Riverpod(keepAlive: true)
Future<DorarClient> dorarClient(Ref ref) async {
  // ترتیب حیاتی است: مسیر کش باید پیش از ساخته‌شدن DorarClient تثبیت شود.
  await configureDorarCache();
  // درر به UA بدون مرورگر ۴۰۳ می‌دهد؛ کلاینت لایه‌دار UA موبایل می‌فرستد.
  return DorarClient(
    httpClient: DorarHttpClient(client: BrowserUserAgentClient()),
  );
}

@riverpod
Future<DorarHadithRemoteDataSource> dorarRemoteDataSource(
  Ref ref,
) async {
  final client = await ref.watch(dorarClientProvider.future);
  return DorarRemoteDataSource(client);
}

/// مخزن درر هم مادام‌العمر است چون جستجو آن را با `read(...future)`
/// (بدون listener پایدار) می‌خواند؛ با autoDispose این زنجیره وسط
/// `build` (درست بعد از `await`) دور می‌شد و استفادهٔ بعدی از `ref`
/// خطای «Ref after it has been disposed» می‌داد.
///
/// ترتیب خواندن‌ها هم مهم است: هر دو وابستگی پیش از نخستین `await`
/// خوانده می‌شوند تا پس از آن هیچ استفاده‌ای از `ref` نماند.
@Riverpod(keepAlive: true)
Future<DorarHadithRepository> dorarHadithRepository(Ref ref) async {
  final favorites = ref.watch(dorarFavoriteDaoProvider);
  final dataSource = await ref.watch(dorarRemoteDataSourceProvider.future);
  return DorarHadithRepositoryImpl(
    dataSource: dataSource,
    favorites: favorites,
  );
}

@riverpod
Future<SearchHadithUseCase> searchHadithUseCase(Ref ref) async {
  final repository = await ref.watch(dorarHadithRepositoryProvider.future);
  return SearchHadithUseCase(repository);
}

@riverpod
Future<GetHadithAlternativesUseCase> getHadithAlternativesUseCase(
  Ref ref,
) async {
  final repository = await ref.watch(dorarHadithRepositoryProvider.future);
  return GetHadithAlternativesUseCase(repository);
}

/// فیلتر درجه صحت انتخابی در نوار جستجو.
@riverpod
class DorarSearchFilter extends _$DorarSearchFilter {
  @override
  DorarHadithFilter build() => DorarHadithFilter.all;

  void select(DorarHadithFilter filter) => state = filter;
}

/// نتایج جستجوی احادیث با Pagination.
///
/// سه محافظ هم‌زمانی:
/// ۱) دیبانس ۵۰۰ms روی تایپ (`search`) تا هر کلید یک درخواست نسازد؛
///    ارسال فرم و «تلاش دوباره» از `searchNow` بدون تأخیر می‌روند.
/// ۲) شمارندهٔ نسل (`_generation`) به‌جای CancelToken — چون پروژه از http
///    استفاده می‌کند نه Dio. با هر جستجوی تازه یک نسل بالا می‌رود و پاسخ
///    نسل قدیمی (دیررس یا لغوشده) کاملاً نادیده می‌ماند و UI خطا نمی‌دهد.
/// ۳) همهٔ `ref`‌خوانی‌ها پیش از نخستین `await` انجام می‌شود و بعد از هر
///    گپ async، `ref.mounted` بررسی می‌شود.
@riverpod
class DorarHadithSearch extends _$DorarHadithSearch {
  static const Duration debounceDelay = Duration(milliseconds: 500);

  String _query = '';
  int _page = 1;
  bool _hasNextPage = false;
  bool _loadingMore = false;
  Timer? _debounce;
  int _generation = 0;

  String get currentQuery => _query;
  bool get hasNextPage => _hasNextPage;
  bool get loadingMore => _loadingMore;

  @override
  Future<List<DorarHadithEntity>> build() {
    // لغو کارهای معلق هنگام dispose: تایمر دیبانس کنسل و نسل فعلی باطل
    // می‌شود تا پاسخ در حال پرواز دیگر به state دست نزند.
    ref.onDispose(() {
      _debounce?.cancel();
      _debounce = null;
      _generation++;
    });
    // تغییر فیلتر باید همان جستجوی جاری را با فیلتر تازه تکرار کند؛ با
    // listen (نه watch) چون watch خودِ build را اجرا و نتایج را پاک می‌کرد.
    ref.listen(dorarSearchFilterProvider, (_, __) {
      if (_query.isNotEmpty) {
        _runSearch(_query);
      }
    });
    return Future.value(const <DorarHadithEntity>[]);
  }

  /// مسیر تایپ: با دیبانس؛ پرس‌وجوی خالی یا فقط‌فاصله نادیده گرفته می‌شود.
  void search(String query) {
    _debounce?.cancel();
    _debounce = null;
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _debounce = Timer(debounceDelay, () {
      _debounce = null;
      _runSearch(trimmed);
    });
  }

  /// مسیر اکشن صریح (دکمهٔ جستجو / تلاش دوباره): بدون دیبانس.
  void searchNow(String query) {
    _debounce?.cancel();
    _debounce = null;
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _runSearch(trimmed);
  }

  Future<void> _runSearch(String query) async {
    // repo و filter پیش از هر await خوانده می‌شوند تا پس از آن ref لمس نشود.
    final repository = ref.read(dorarHadithRepositoryProvider.future);
    final filter = ref.read(dorarSearchFilterProvider);
    final generation = ++_generation;
    state = const AsyncLoading();
    try {
      final repo = await repository;
      final page = await SearchHadithUseCase(repo)(query: query, filter: filter);
      // پاسخ دیررسِ نسل قدیمی (لغوشده) نه state را عوض می‌کند نه خطا می‌دهد.
      if (!ref.mounted || generation != _generation) return;
      _query = query;
      _page = 1;
      _hasNextPage = page.hasNextPage;
      state = AsyncData(page.items);
    } catch (e, st) {
      // خطای نسل جاری به‌صورت AsyncError به UI می‌رسد (AppEmptyState با
      // «تلاش دوباره»)؛ نسل قدیمیِ لغوشده فقط بی‌صدا دور ریخته می‌شود.
      // لاگ جدا لازم نیست چون لایهٔ مخزن پیش‌تر خطای اصلی را ثبت می‌کند.
      if (!ref.mounted || generation != _generation) return;
      state = AsyncError(e, st);
    }
  }

  /// صفحه بعدی را به نتایج موجود می‌چسباند. خطای اینجا فهرست نمایش‌داده‌شده
  /// را از بین نمی‌برد؛ دکمه «بیشتر» می‌ماند تا کاربر دوباره بزند.
  Future<void> loadMore() async {
    if (_query.isEmpty || !_hasNextPage || _loadingMore || state.isLoading) {
      return;
    }
    final repository = ref.read(dorarHadithRepositoryProvider.future);
    final filter = ref.read(dorarSearchFilterProvider);
    final generation = _generation;
    _loadingMore = true;
    state = AsyncData(List.of(state.value ?? const <DorarHadithEntity>[]));
    DorarHadithResultsPage? page;
    try {
      final repo = await repository;
      page = await SearchHadithUseCase(repo)(
        query: _query,
        page: _page + 1,
        filter: filter,
      );
    } catch (e, st) {
      // شکست «بیشتر» عمداً به UI نمی‌رسد (فهرست جاری و دکمهٔ تلاش دوباره
      // سر جایشان می‌مانند) ولی برای تشخیص خطا لاگ می‌شود.
      AppLogger.error('DorarHadith', e, st);
    }
    _loadingMore = false;
    if (!ref.mounted || generation != _generation) return;
    if (page == null) {
      state = AsyncData(List.of(state.value ?? const <DorarHadithEntity>[]));
      return;
    }
    _page += 1;
    _hasNextPage = page.hasNextPage;
    state = AsyncData([...(state.value ?? const []), ...page.items]);
  }
}

/// جزئیات یک حدیث با مشابهات و بدیل صحیح.
@riverpod
Future<DorarHadithDetail> dorarHadithDetails(
  Ref ref,
  String hadithId,
) async {
  final useCase = await ref.watch(getHadithAlternativesUseCaseProvider.future);
  return useCase(hadithId);
}

/// شرح الحديث؛ null یعنی شرحی یافت نشد.
@riverpod
Future<String?> dorarHadithExplanation(
  Ref ref,
  String hadithText,
) async {
  final repository = await ref.watch(dorarHadithRepositoryProvider.future);
  return repository.getExplanation(hadithText);
}

/// مجموعه شناسه‌های احادیث ذخیره‌شده در المفضلة.
@riverpod
class DorarHadithFavorites extends _$DorarHadithFavorites {
  @override
  Future<Set<String>> build() async {
    final repository = await ref.watch(dorarHadithRepositoryProvider.future);
    return repository.favoriteIds();
  }

  bool contains(String id) => (state.value ?? const <String>{}).contains(id);

  Future<void> toggle(DorarHadithEntity hadith) async {
    final repo = await ref.read(dorarHadithRepositoryProvider.future);
    final current = state.value ?? const <String>{};
    final removing = current.contains(hadith.id);
    // به‌روزرسانی خوش‌بینانه: آیکن قلب بی درنگ عوض شود و نوشتن در Drift
    // پس‌زمینه‌ای ادامه یابد؛ خطای ذخیره فهرست قبلی را برمی‌گرداند.
    if (removing) {
      state = AsyncData({...current}..remove(hadith.id));
    } else {
      state = AsyncData({...current, hadith.id});
    }
    try {
      if (removing) {
        await repo.removeFavorite(hadith.id);
      } else {
        await repo.saveFavorite(hadith);
      }
    } catch (e, st) {
      // The optimistic heart reverts silently — without this line the write
      // failure would leave no trace at all.
      AppLogger.error('dorar_favorites', e, st);
      state = AsyncData(current);
    }
  }
}
