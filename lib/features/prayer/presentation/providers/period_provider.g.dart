// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'period_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Period)
final periodProvider = PeriodProvider._();

final class PeriodProvider extends $AsyncNotifierProvider<Period, PeriodState> {
  PeriodProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'periodProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$periodHash();

  @$internal
  @override
  Period create() => Period();
}

String _$periodHash() => r'09f57dbb4bc5aaa6acfc128c2dbe121e7bff8194';

abstract class _$Period extends $AsyncNotifier<PeriodState> {
  FutureOr<PeriodState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PeriodState>, PeriodState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<PeriodState>, PeriodState>,
        AsyncValue<PeriodState>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
