// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dorar_hadith_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(dorarClient)
final dorarClientProvider = DorarClientProvider._();

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

final class DorarClientProvider extends $FunctionalProvider<
        AsyncValue<DorarClient>, DorarClient, FutureOr<DorarClient>>
    with $FutureModifier<DorarClient>, $FutureProvider<DorarClient> {
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
  DorarClientProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dorarClientProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dorarClientHash();

  @$internal
  @override
  $FutureProviderElement<DorarClient> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DorarClient> create(Ref ref) {
    return dorarClient(ref);
  }
}

String _$dorarClientHash() => r'bd3af519e242e9e5e800d844ba4b02a57456230d';

@ProviderFor(dorarRemoteDataSource)
final dorarRemoteDataSourceProvider = DorarRemoteDataSourceProvider._();

final class DorarRemoteDataSourceProvider extends $FunctionalProvider<
        AsyncValue<DorarHadithRemoteDataSource>,
        DorarHadithRemoteDataSource,
        FutureOr<DorarHadithRemoteDataSource>>
    with
        $FutureModifier<DorarHadithRemoteDataSource>,
        $FutureProvider<DorarHadithRemoteDataSource> {
  DorarRemoteDataSourceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dorarRemoteDataSourceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dorarRemoteDataSourceHash();

  @$internal
  @override
  $FutureProviderElement<DorarHadithRemoteDataSource> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DorarHadithRemoteDataSource> create(Ref ref) {
    return dorarRemoteDataSource(ref);
  }
}

String _$dorarRemoteDataSourceHash() =>
    r'54f3aa79533a6231c64d19501f8ee6b936a34874';

/// مخزن درر هم مادام‌العمر است چون جستجو آن را با `read(...future)`
/// (بدون listener پایدار) می‌خواند؛ با autoDispose این زنجیره وسط
/// `build` (درست بعد از `await`) دور می‌شد و استفادهٔ بعدی از `ref`
/// خطای «Ref after it has been disposed» می‌داد.
///
/// ترتیب خواندن‌ها هم مهم است: هر دو وابستگی پیش از نخستین `await`
/// خوانده می‌شوند تا پس از آن هیچ استفاده‌ای از `ref` نماند.

@ProviderFor(dorarHadithRepository)
final dorarHadithRepositoryProvider = DorarHadithRepositoryProvider._();

/// مخزن درر هم مادام‌العمر است چون جستجو آن را با `read(...future)`
/// (بدون listener پایدار) می‌خواند؛ با autoDispose این زنجیره وسط
/// `build` (درست بعد از `await`) دور می‌شد و استفادهٔ بعدی از `ref`
/// خطای «Ref after it has been disposed» می‌داد.
///
/// ترتیب خواندن‌ها هم مهم است: هر دو وابستگی پیش از نخستین `await`
/// خوانده می‌شوند تا پس از آن هیچ استفاده‌ای از `ref` نماند.

final class DorarHadithRepositoryProvider extends $FunctionalProvider<
        AsyncValue<DorarHadithRepository>,
        DorarHadithRepository,
        FutureOr<DorarHadithRepository>>
    with
        $FutureModifier<DorarHadithRepository>,
        $FutureProvider<DorarHadithRepository> {
  /// مخزن درر هم مادام‌العمر است چون جستجو آن را با `read(...future)`
  /// (بدون listener پایدار) می‌خواند؛ با autoDispose این زنجیره وسط
  /// `build` (درست بعد از `await`) دور می‌شد و استفادهٔ بعدی از `ref`
  /// خطای «Ref after it has been disposed» می‌داد.
  ///
  /// ترتیب خواندن‌ها هم مهم است: هر دو وابستگی پیش از نخستین `await`
  /// خوانده می‌شوند تا پس از آن هیچ استفاده‌ای از `ref` نماند.
  DorarHadithRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dorarHadithRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dorarHadithRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<DorarHadithRepository> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DorarHadithRepository> create(Ref ref) {
    return dorarHadithRepository(ref);
  }
}

String _$dorarHadithRepositoryHash() =>
    r'1585aa25ed8c46d1323b0a5a9dbcf2ffb42b5f74';

@ProviderFor(searchHadithUseCase)
final searchHadithUseCaseProvider = SearchHadithUseCaseProvider._();

final class SearchHadithUseCaseProvider extends $FunctionalProvider<
        AsyncValue<SearchHadithUseCase>,
        SearchHadithUseCase,
        FutureOr<SearchHadithUseCase>>
    with
        $FutureModifier<SearchHadithUseCase>,
        $FutureProvider<SearchHadithUseCase> {
  SearchHadithUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'searchHadithUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$searchHadithUseCaseHash();

  @$internal
  @override
  $FutureProviderElement<SearchHadithUseCase> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<SearchHadithUseCase> create(Ref ref) {
    return searchHadithUseCase(ref);
  }
}

String _$searchHadithUseCaseHash() =>
    r'af1c183258f7bf2ddb950509d137fac25c83e3cf';

@ProviderFor(getHadithAlternativesUseCase)
final getHadithAlternativesUseCaseProvider =
    GetHadithAlternativesUseCaseProvider._();

final class GetHadithAlternativesUseCaseProvider extends $FunctionalProvider<
        AsyncValue<GetHadithAlternativesUseCase>,
        GetHadithAlternativesUseCase,
        FutureOr<GetHadithAlternativesUseCase>>
    with
        $FutureModifier<GetHadithAlternativesUseCase>,
        $FutureProvider<GetHadithAlternativesUseCase> {
  GetHadithAlternativesUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'getHadithAlternativesUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$getHadithAlternativesUseCaseHash();

  @$internal
  @override
  $FutureProviderElement<GetHadithAlternativesUseCase> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<GetHadithAlternativesUseCase> create(Ref ref) {
    return getHadithAlternativesUseCase(ref);
  }
}

String _$getHadithAlternativesUseCaseHash() =>
    r'fe4d470ad19dc8b8935acc4780e09b7ab7d51477';

/// فیلتر درجه صحت انتخابی در نوار جستجو.

@ProviderFor(DorarSearchFilter)
final dorarSearchFilterProvider = DorarSearchFilterProvider._();

/// فیلتر درجه صحت انتخابی در نوار جستجو.
final class DorarSearchFilterProvider
    extends $NotifierProvider<DorarSearchFilter, DorarHadithFilter> {
  /// فیلتر درجه صحت انتخابی در نوار جستجو.
  DorarSearchFilterProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dorarSearchFilterProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dorarSearchFilterHash();

  @$internal
  @override
  DorarSearchFilter create() => DorarSearchFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DorarHadithFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DorarHadithFilter>(value),
    );
  }
}

String _$dorarSearchFilterHash() => r'711ea568acbd2f99b151113d7ef7cac39f5d324c';

/// فیلتر درجه صحت انتخابی در نوار جستجو.

abstract class _$DorarSearchFilter extends $Notifier<DorarHadithFilter> {
  DorarHadithFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DorarHadithFilter, DorarHadithFilter>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<DorarHadithFilter, DorarHadithFilter>,
        DorarHadithFilter,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
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

@ProviderFor(DorarHadithSearch)
final dorarHadithSearchProvider = DorarHadithSearchProvider._();

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
final class DorarHadithSearchProvider
    extends $AsyncNotifierProvider<DorarHadithSearch, List<DorarHadithEntity>> {
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
  DorarHadithSearchProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dorarHadithSearchProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dorarHadithSearchHash();

  @$internal
  @override
  DorarHadithSearch create() => DorarHadithSearch();
}

String _$dorarHadithSearchHash() => r'79c8f1a191c389f2f48c42e7524d18e16a48fddb';

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

abstract class _$DorarHadithSearch
    extends $AsyncNotifier<List<DorarHadithEntity>> {
  FutureOr<List<DorarHadithEntity>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref
        as $Ref<AsyncValue<List<DorarHadithEntity>>, List<DorarHadithEntity>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<DorarHadithEntity>>,
            List<DorarHadithEntity>>,
        AsyncValue<List<DorarHadithEntity>>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}

/// جزئیات یک حدیث با مشابهات و بدیل صحیح.

@ProviderFor(dorarHadithDetails)
final dorarHadithDetailsProvider = DorarHadithDetailsFamily._();

/// جزئیات یک حدیث با مشابهات و بدیل صحیح.

final class DorarHadithDetailsProvider extends $FunctionalProvider<
        AsyncValue<DorarHadithDetail>,
        DorarHadithDetail,
        FutureOr<DorarHadithDetail>>
    with
        $FutureModifier<DorarHadithDetail>,
        $FutureProvider<DorarHadithDetail> {
  /// جزئیات یک حدیث با مشابهات و بدیل صحیح.
  DorarHadithDetailsProvider._(
      {required DorarHadithDetailsFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'dorarHadithDetailsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dorarHadithDetailsHash();

  @override
  String toString() {
    return r'dorarHadithDetailsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<DorarHadithDetail> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DorarHadithDetail> create(Ref ref) {
    final argument = this.argument as String;
    return dorarHadithDetails(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DorarHadithDetailsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dorarHadithDetailsHash() =>
    r'742b81c81bc909d6759fe042c419042d9c659c65';

/// جزئیات یک حدیث با مشابهات و بدیل صحیح.

final class DorarHadithDetailsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<DorarHadithDetail>, String> {
  DorarHadithDetailsFamily._()
      : super(
          retry: null,
          name: r'dorarHadithDetailsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// جزئیات یک حدیث با مشابهات و بدیل صحیح.

  DorarHadithDetailsProvider call(
    String hadithId,
  ) =>
      DorarHadithDetailsProvider._(argument: hadithId, from: this);

  @override
  String toString() => r'dorarHadithDetailsProvider';
}

/// شرح الحديث؛ null یعنی شرحی یافت نشد.

@ProviderFor(dorarHadithExplanation)
final dorarHadithExplanationProvider = DorarHadithExplanationFamily._();

/// شرح الحديث؛ null یعنی شرحی یافت نشد.

final class DorarHadithExplanationProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// شرح الحديث؛ null یعنی شرحی یافت نشد.
  DorarHadithExplanationProvider._(
      {required DorarHadithExplanationFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'dorarHadithExplanationProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dorarHadithExplanationHash();

  @override
  String toString() {
    return r'dorarHadithExplanationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return dorarHadithExplanation(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DorarHadithExplanationProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dorarHadithExplanationHash() =>
    r'80bd266dba48210bca79b971c9bc5f1fe5cbd9df';

/// شرح الحديث؛ null یعنی شرحی یافت نشد.

final class DorarHadithExplanationFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  DorarHadithExplanationFamily._()
      : super(
          retry: null,
          name: r'dorarHadithExplanationProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// شرح الحديث؛ null یعنی شرحی یافت نشد.

  DorarHadithExplanationProvider call(
    String hadithText,
  ) =>
      DorarHadithExplanationProvider._(argument: hadithText, from: this);

  @override
  String toString() => r'dorarHadithExplanationProvider';
}

/// مجموعه شناسه‌های احادیث ذخیره‌شده در المفضلة.

@ProviderFor(DorarHadithFavorites)
final dorarHadithFavoritesProvider = DorarHadithFavoritesProvider._();

/// مجموعه شناسه‌های احادیث ذخیره‌شده در المفضلة.
final class DorarHadithFavoritesProvider
    extends $AsyncNotifierProvider<DorarHadithFavorites, Set<String>> {
  /// مجموعه شناسه‌های احادیث ذخیره‌شده در المفضلة.
  DorarHadithFavoritesProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dorarHadithFavoritesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dorarHadithFavoritesHash();

  @$internal
  @override
  DorarHadithFavorites create() => DorarHadithFavorites();
}

String _$dorarHadithFavoritesHash() =>
    r'7fe62e6f338589e3ad28731089a961294dfea7d1';

/// مجموعه شناسه‌های احادیث ذخیره‌شده در المفضلة.

abstract class _$DorarHadithFavorites extends $AsyncNotifier<Set<String>> {
  FutureOr<Set<String>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Set<String>>, Set<String>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<Set<String>>, Set<String>>,
        AsyncValue<Set<String>>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
