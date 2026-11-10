// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'azkar_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Azkar)
final azkarProvider = AzkarProvider._();

final class AzkarProvider
    extends $AsyncNotifierProvider<Azkar, List<ZikrItem>> {
  AzkarProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'azkarProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$azkarHash();

  @$internal
  @override
  Azkar create() => Azkar();
}

String _$azkarHash() => r'6fabb6736f367bda459848a1384c8587553c7c7a';

abstract class _$Azkar extends $AsyncNotifier<List<ZikrItem>> {
  FutureOr<List<ZikrItem>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<ZikrItem>>, List<ZikrItem>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<ZikrItem>>, List<ZikrItem>>,
        AsyncValue<List<ZikrItem>>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}

/// Lightweight version counter that bumps every time an azkar completion
/// toggles. Consumers can watch this instead of the full async [azkarProvider]
/// to avoid async lifecycle issues in tests and reduce rebuild scope.

@ProviderFor(azkarVersion)
final azkarVersionProvider = AzkarVersionProvider._();

/// Lightweight version counter that bumps every time an azkar completion
/// toggles. Consumers can watch this instead of the full async [azkarProvider]
/// to avoid async lifecycle issues in tests and reduce rebuild scope.

final class AzkarVersionProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Lightweight version counter that bumps every time an azkar completion
  /// toggles. Consumers can watch this instead of the full async [azkarProvider]
  /// to avoid async lifecycle issues in tests and reduce rebuild scope.
  AzkarVersionProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'azkarVersionProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$azkarVersionHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return azkarVersion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$azkarVersionHash() => r'fcaf724215302b45e0e1f8614ce5238ee9597609';

@ProviderFor(GeneralAzkar)
final generalAzkarProvider = GeneralAzkarProvider._();

final class GeneralAzkarProvider
    extends $AsyncNotifierProvider<GeneralAzkar, List<GeneralZikr>> {
  GeneralAzkarProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'generalAzkarProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$generalAzkarHash();

  @$internal
  @override
  GeneralAzkar create() => GeneralAzkar();
}

String _$generalAzkarHash() => r'2a75455cd84548dc4cbb7cf65c3e409b9e34d38b';

abstract class _$GeneralAzkar extends $AsyncNotifier<List<GeneralZikr>> {
  FutureOr<List<GeneralZikr>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<GeneralZikr>>, List<GeneralZikr>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<GeneralZikr>>, List<GeneralZikr>>,
        AsyncValue<List<GeneralZikr>>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
