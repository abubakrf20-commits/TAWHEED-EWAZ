// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evaluation_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Evaluation)
final evaluationProvider = EvaluationProvider._();

final class EvaluationProvider
    extends $AsyncNotifierProvider<Evaluation, EvaluationState> {
  EvaluationProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'evaluationProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$evaluationHash();

  @$internal
  @override
  Evaluation create() => Evaluation();
}

String _$evaluationHash() => r'6b38c186357c2f369704cf62ab63e350c14c70cc';

abstract class _$Evaluation extends $AsyncNotifier<EvaluationState> {
  FutureOr<EvaluationState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<EvaluationState>, EvaluationState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<EvaluationState>, EvaluationState>,
        AsyncValue<EvaluationState>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
