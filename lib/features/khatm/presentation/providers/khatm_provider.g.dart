// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'khatm_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Khatm)
final khatmProvider = KhatmProvider._();

final class KhatmProvider extends $AsyncNotifierProvider<Khatm, KhatmModel?> {
  KhatmProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'khatmProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$khatmHash();

  @$internal
  @override
  Khatm create() => Khatm();
}

String _$khatmHash() => r'e1a4601628890335695badeb8d80219979203192';

abstract class _$Khatm extends $AsyncNotifier<KhatmModel?> {
  FutureOr<KhatmModel?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<KhatmModel?>, KhatmModel?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<KhatmModel?>, KhatmModel?>,
        AsyncValue<KhatmModel?>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
