// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prayer_time_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(prayerTimeService)
final prayerTimeServiceProvider = PrayerTimeServiceProvider._();

final class PrayerTimeServiceProvider extends $FunctionalProvider<
    PrayerTimeService,
    PrayerTimeService,
    PrayerTimeService> with $Provider<PrayerTimeService> {
  PrayerTimeServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'prayerTimeServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$prayerTimeServiceHash();

  @$internal
  @override
  $ProviderElement<PrayerTimeService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PrayerTimeService create(Ref ref) {
    return prayerTimeService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrayerTimeService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrayerTimeService>(value),
    );
  }
}

String _$prayerTimeServiceHash() => r'c631f222ebadfd4d071da223a94d624b5306afe5';

@ProviderFor(PrayerTimes)
final prayerTimesProvider = PrayerTimesProvider._();

final class PrayerTimesProvider
    extends $AsyncNotifierProvider<PrayerTimes, pi.PrayerTimes?> {
  PrayerTimesProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'prayerTimesProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$prayerTimesHash();

  @$internal
  @override
  PrayerTimes create() => PrayerTimes();
}

String _$prayerTimesHash() => r'01184f340dab6c5a2fb5661109646cdd05735ff7';

abstract class _$PrayerTimes extends $AsyncNotifier<pi.PrayerTimes?> {
  FutureOr<pi.PrayerTimes?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<pi.PrayerTimes?>, pi.PrayerTimes?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<pi.PrayerTimes?>, pi.PrayerTimes?>,
        AsyncValue<pi.PrayerTimes?>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
