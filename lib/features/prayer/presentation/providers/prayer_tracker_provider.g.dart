// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prayer_tracker_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PrayerTracker)
final prayerTrackerProvider = PrayerTrackerProvider._();

final class PrayerTrackerProvider
    extends $AsyncNotifierProvider<PrayerTracker, PrayerTrackerState> {
  PrayerTrackerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'prayerTrackerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$prayerTrackerHash();

  @$internal
  @override
  PrayerTracker create() => PrayerTracker();
}

String _$prayerTrackerHash() => r'0d284db1a1584f959b1bd6b0db4ecc7ae55b807e';

abstract class _$PrayerTracker extends $AsyncNotifier<PrayerTrackerState> {
  FutureOr<PrayerTrackerState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<PrayerTrackerState>, PrayerTrackerState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<PrayerTrackerState>, PrayerTrackerState>,
        AsyncValue<PrayerTrackerState>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
