// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasbih_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Tasbih)
final tasbihProvider = TasbihProvider._();

final class TasbihProvider
    extends $AsyncNotifierProvider<Tasbih, List<domain.TasbihModel>> {
  TasbihProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'tasbihProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$tasbihHash();

  @$internal
  @override
  Tasbih create() => Tasbih();
}

String _$tasbihHash() => r'5350e51b04f781a48cc3136d4a03705e5a74c7bb';

abstract class _$Tasbih extends $AsyncNotifier<List<domain.TasbihModel>> {
  FutureOr<List<domain.TasbihModel>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref
        as $Ref<AsyncValue<List<domain.TasbihModel>>, List<domain.TasbihModel>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<domain.TasbihModel>>,
            List<domain.TasbihModel>>,
        AsyncValue<List<domain.TasbihModel>>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
