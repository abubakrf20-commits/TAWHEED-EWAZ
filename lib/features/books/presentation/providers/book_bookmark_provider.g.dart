// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_bookmark_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// IDs of every book that has at least one bookmark anywhere — was a
/// private FutureProvider living inside ketabkhaneh_screen.dart.

@ProviderFor(allBookmarkedIds)
final allBookmarkedIdsProvider = AllBookmarkedIdsProvider._();

/// IDs of every book that has at least one bookmark anywhere — was a
/// private FutureProvider living inside ketabkhaneh_screen.dart.

final class AllBookmarkedIdsProvider extends $FunctionalProvider<
        AsyncValue<Set<String>>, Set<String>, FutureOr<Set<String>>>
    with $FutureModifier<Set<String>>, $FutureProvider<Set<String>> {
  /// IDs of every book that has at least one bookmark anywhere — was a
  /// private FutureProvider living inside ketabkhaneh_screen.dart.
  AllBookmarkedIdsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'allBookmarkedIdsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$allBookmarkedIdsHash();

  @$internal
  @override
  $FutureProviderElement<Set<String>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Set<String>> create(Ref ref) {
    return allBookmarkedIds(ref);
  }
}

String _$allBookmarkedIdsHash() => r'40f9bca7e4e899876168bc7de0c2589d3b6e6055';

@ProviderFor(BookBookmark)
final bookBookmarkProvider = BookBookmarkFamily._();

final class BookBookmarkProvider
    extends $AsyncNotifierProvider<BookBookmark, List<BookBookmarkData>> {
  BookBookmarkProvider._(
      {required BookBookmarkFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'bookBookmarkProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$bookBookmarkHash();

  @override
  String toString() {
    return r'bookBookmarkProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BookBookmark create() => BookBookmark();

  @override
  bool operator ==(Object other) {
    return other is BookBookmarkProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookBookmarkHash() => r'366266af7aa1e304e2d9d362e7d28ff5bf714565';

final class BookBookmarkFamily extends $Family
    with
        $ClassFamilyOverride<BookBookmark, AsyncValue<List<BookBookmarkData>>,
            List<BookBookmarkData>, FutureOr<List<BookBookmarkData>>, String> {
  BookBookmarkFamily._()
      : super(
          retry: null,
          name: r'bookBookmarkProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  BookBookmarkProvider call(
    String bookId,
  ) =>
      BookBookmarkProvider._(argument: bookId, from: this);

  @override
  String toString() => r'bookBookmarkProvider';
}

abstract class _$BookBookmark extends $AsyncNotifier<List<BookBookmarkData>> {
  late final _$args = ref.$arg as String;
  String get bookId => _$args;

  FutureOr<List<BookBookmarkData>> build(
    String bookId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref
        as $Ref<AsyncValue<List<BookBookmarkData>>, List<BookBookmarkData>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<BookBookmarkData>>, List<BookBookmarkData>>,
        AsyncValue<List<BookBookmarkData>>,
        Object?,
        Object?>;
    return element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}
