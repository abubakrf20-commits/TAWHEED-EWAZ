// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_plan_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReadingPlan)
final readingPlanProvider = ReadingPlanProvider._();

final class ReadingPlanProvider
    extends $AsyncNotifierProvider<ReadingPlan, ReadingPlanState> {
  ReadingPlanProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'readingPlanProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$readingPlanHash();

  @$internal
  @override
  ReadingPlan create() => ReadingPlan();
}

String _$readingPlanHash() => r'5bb5ca7415b54c9f6310c7f9953dc065e87f188c';

abstract class _$ReadingPlan extends $AsyncNotifier<ReadingPlanState> {
  FutureOr<ReadingPlanState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ReadingPlanState>, ReadingPlanState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<ReadingPlanState>, ReadingPlanState>,
        AsyncValue<ReadingPlanState>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
