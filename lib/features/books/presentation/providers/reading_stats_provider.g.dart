// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_stats_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(readingStats)
final readingStatsProvider = ReadingStatsProvider._();

final class ReadingStatsProvider extends $FunctionalProvider<
        AsyncValue<Map<String, int>>,
        Map<String, int>,
        FutureOr<Map<String, int>>>
    with $FutureModifier<Map<String, int>>, $FutureProvider<Map<String, int>> {
  ReadingStatsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'readingStatsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$readingStatsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, int>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, int>> create(Ref ref) {
    return readingStats(ref);
  }
}

String _$readingStatsHash() => r'4949bdfa2eff1d60f2f42d6bf0b2d4b905c95c71';

@ProviderFor(readingTotal)
final readingTotalProvider = ReadingTotalProvider._();

final class ReadingTotalProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  ReadingTotalProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'readingTotalProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$readingTotalHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return readingTotal(ref);
  }
}

String _$readingTotalHash() => r'5f0a579567cb7b0f3aee72d0cc15678c80ce4d62';

@ProviderFor(readingStreak)
final readingStreakProvider = ReadingStreakProvider._();

final class ReadingStreakProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  ReadingStreakProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'readingStreakProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$readingStreakHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return readingStreak(ref);
  }
}

String _$readingStreakHash() => r'da77b4d091650ff8d6656e1f9e40590a79f431a2';
