// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ramadan_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ramadan)
final ramadanProvider = RamadanProvider._();

final class RamadanProvider
    extends $FunctionalProvider<RamadanState, RamadanState, RamadanState>
    with $Provider<RamadanState> {
  RamadanProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'ramadanProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$ramadanHash();

  @$internal
  @override
  $ProviderElement<RamadanState> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RamadanState create(Ref ref) {
    return ramadan(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RamadanState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RamadanState>(value),
    );
  }
}

String _$ramadanHash() => r'7bf4accfbb330e099cffb4b790854d26759a0282';

@ProviderFor(isRamadan)
final isRamadanProvider = IsRamadanProvider._();

final class IsRamadanProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  IsRamadanProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'isRamadanProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$isRamadanHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isRamadan(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isRamadanHash() => r'7c4a1e1e101b0b54706727b32ba94a5a875cb491';
