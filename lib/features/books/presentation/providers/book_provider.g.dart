// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Book)
final bookProvider = BookProvider._();

final class BookProvider extends $AsyncNotifierProvider<Book, List<BookModel>> {
  BookProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'bookProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$bookHash();

  @$internal
  @override
  Book create() => Book();
}

String _$bookHash() => r'd8e3804e87d34ddf62490b0b5d1e19d79840bc63';

abstract class _$Book extends $AsyncNotifier<List<BookModel>> {
  FutureOr<List<BookModel>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<BookModel>>, List<BookModel>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<BookModel>>, List<BookModel>>,
        AsyncValue<List<BookModel>>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
