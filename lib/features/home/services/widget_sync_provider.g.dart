// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'widget_sync_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(widgetSync)
final widgetSyncProvider = WidgetSyncProvider._();

final class WidgetSyncProvider
    extends $FunctionalProvider<WidgetSync, WidgetSync, WidgetSync>
    with $Provider<WidgetSync> {
  WidgetSyncProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'widgetSyncProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$widgetSyncHash();

  @$internal
  @override
  $ProviderElement<WidgetSync> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WidgetSync create(Ref ref) {
    return widgetSync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WidgetSync value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WidgetSync>(value),
    );
  }
}

String _$widgetSyncHash() => r'387ca0b0196bade41308ce870946ad315cb61753';
