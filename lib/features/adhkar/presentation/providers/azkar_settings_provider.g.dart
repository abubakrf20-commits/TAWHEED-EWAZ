// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'azkar_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AzkarSettings)
final azkarSettingsProvider = AzkarSettingsProvider._();

final class AzkarSettingsProvider
    extends $NotifierProvider<AzkarSettings, AzkarSettingsData> {
  AzkarSettingsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'azkarSettingsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$azkarSettingsHash();

  @$internal
  @override
  AzkarSettings create() => AzkarSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AzkarSettingsData value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AzkarSettingsData>(value),
    );
  }
}

String _$azkarSettingsHash() => r'1f10d29f1968a2e338e7a9652a9c7828f04a294d';

abstract class _$AzkarSettings extends $Notifier<AzkarSettingsData> {
  AzkarSettingsData build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AzkarSettingsData, AzkarSettingsData>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AzkarSettingsData, AzkarSettingsData>,
        AzkarSettingsData,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
