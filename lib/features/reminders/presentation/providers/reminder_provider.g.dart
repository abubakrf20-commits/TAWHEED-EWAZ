// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Reminder)
final reminderProvider = ReminderProvider._();

final class ReminderProvider
    extends $AsyncNotifierProvider<Reminder, List<ReminderModel>> {
  ReminderProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'reminderProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$reminderHash();

  @$internal
  @override
  Reminder create() => Reminder();
}

String _$reminderHash() => r'c7100a7a56c6e56b624e968da955250132bb90a8';

abstract class _$Reminder extends $AsyncNotifier<List<ReminderModel>> {
  FutureOr<List<ReminderModel>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<ReminderModel>>, List<ReminderModel>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<ReminderModel>>, List<ReminderModel>>,
        AsyncValue<List<ReminderModel>>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
