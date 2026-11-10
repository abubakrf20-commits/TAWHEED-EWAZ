// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'duas_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Duas)
final duasProvider = DuasProvider._();

final class DuasProvider extends $NotifierProvider<Duas, DuasState> {
  DuasProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'duasProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$duasHash();

  @$internal
  @override
  Duas create() => Duas();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DuasState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DuasState>(value),
    );
  }
}

String _$duasHash() => r'912d35a9e2161b37d1b1823ce36ef1d3df8cbefa';

abstract class _$Duas extends $Notifier<DuasState> {
  DuasState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DuasState, DuasState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<DuasState, DuasState>, DuasState, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}
