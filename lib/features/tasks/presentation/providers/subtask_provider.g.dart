// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtask_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Checklist («زیرکارها») of one task, ordered by position.

@ProviderFor(SubtaskList)
final subtaskListProvider = SubtaskListFamily._();

/// Checklist («زیرکارها») of one task, ordered by position.
final class SubtaskListProvider
    extends $NotifierProvider<SubtaskList, List<Subtask>> {
  /// Checklist («زیرکارها») of one task, ordered by position.
  SubtaskListProvider._(
      {required SubtaskListFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'subtaskListProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$subtaskListHash();

  @override
  String toString() {
    return r'subtaskListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SubtaskList create() => SubtaskList();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Subtask> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Subtask>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SubtaskListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subtaskListHash() => r'3e8086ec1ac57de761e24c7d43753a12d5c8ad5a';

/// Checklist («زیرکارها») of one task, ordered by position.

final class SubtaskListFamily extends $Family
    with
        $ClassFamilyOverride<SubtaskList, List<Subtask>, List<Subtask>,
            List<Subtask>, String> {
  SubtaskListFamily._()
      : super(
          retry: null,
          name: r'subtaskListProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Checklist («زیرکارها») of one task, ordered by position.

  SubtaskListProvider call(
    String taskId,
  ) =>
      SubtaskListProvider._(argument: taskId, from: this);

  @override
  String toString() => r'subtaskListProvider';
}

/// Checklist («زیرکارها») of one task, ordered by position.

abstract class _$SubtaskList extends $Notifier<List<Subtask>> {
  late final _$args = ref.$arg as String;
  String get taskId => _$args;

  List<Subtask> build(
    String taskId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<Subtask>, List<Subtask>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<List<Subtask>, List<Subtask>>,
        List<Subtask>,
        Object?,
        Object?>;
    return element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}
