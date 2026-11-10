// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(settingsRepository)
final settingsRepositoryProvider = SettingsRepositoryProvider._();

final class SettingsRepositoryProvider extends $FunctionalProvider<
        AsyncValue<SettingsRepository>,
        SettingsRepository,
        FutureOr<SettingsRepository>>
    with
        $FutureModifier<SettingsRepository>,
        $FutureProvider<SettingsRepository> {
  SettingsRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'settingsRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$settingsRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<SettingsRepository> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<SettingsRepository> create(Ref ref) {
    return settingsRepository(ref);
  }
}

String _$settingsRepositoryHash() =>
    r'9470ec8d1f8962af43afa992955792143a601ea7';

@ProviderFor(Settings)
final settingsProvider = SettingsProvider._();

final class SettingsProvider
    extends $AsyncNotifierProvider<Settings, AppSettings> {
  SettingsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'settingsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$settingsHash();

  @$internal
  @override
  Settings create() => Settings();
}

String _$settingsHash() => r'5aaf58ca8e3fa901ba05ee20fe9ced3f702d2dc4';

abstract class _$Settings extends $AsyncNotifier<AppSettings> {
  FutureOr<AppSettings> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AppSettings>, AppSettings>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<AppSettings>, AppSettings>,
        AsyncValue<AppSettings>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
