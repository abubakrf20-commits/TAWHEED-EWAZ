// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_settings_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether Islamic-occasion reminders are enabled (defaults to true).

@ProviderFor(islamicEventsEnabled)
final islamicEventsEnabledProvider = IslamicEventsEnabledProvider._();

/// Whether Islamic-occasion reminders are enabled (defaults to true).

final class IslamicEventsEnabledProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether Islamic-occasion reminders are enabled (defaults to true).
  IslamicEventsEnabledProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'islamicEventsEnabledProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$islamicEventsEnabledHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return islamicEventsEnabled(ref);
  }
}

String _$islamicEventsEnabledHash() =>
    r'0533f3a6fa948fe37a196238236e2bb514625c22';

/// Coordinator [AsyncNotifier] that bridges [AppSettings] and the notification
/// scheduling infrastructure.
///
/// It keeps [NotificationService] (a low-level singleton wrapping
/// `flutter_local_notifications`) and [DailyNotificationScheduler] in sync with
/// the user's settings. Persistence still flows through the canonical
/// [Settings] notifier so there is a single source of truth for [AppSettings].

@ProviderFor(NotificationSettings)
final notificationSettingsProvider = NotificationSettingsProvider._();

/// Coordinator [AsyncNotifier] that bridges [AppSettings] and the notification
/// scheduling infrastructure.
///
/// It keeps [NotificationService] (a low-level singleton wrapping
/// `flutter_local_notifications`) and [DailyNotificationScheduler] in sync with
/// the user's settings. Persistence still flows through the canonical
/// [Settings] notifier so there is a single source of truth for [AppSettings].
final class NotificationSettingsProvider
    extends $AsyncNotifierProvider<NotificationSettings, AppSettings> {
  /// Coordinator [AsyncNotifier] that bridges [AppSettings] and the notification
  /// scheduling infrastructure.
  ///
  /// It keeps [NotificationService] (a low-level singleton wrapping
  /// `flutter_local_notifications`) and [DailyNotificationScheduler] in sync with
  /// the user's settings. Persistence still flows through the canonical
  /// [Settings] notifier so there is a single source of truth for [AppSettings].
  NotificationSettingsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'notificationSettingsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$notificationSettingsHash();

  @$internal
  @override
  NotificationSettings create() => NotificationSettings();
}

String _$notificationSettingsHash() =>
    r'8f96feadb3da9c1d7cb92a30acc32a07b92deb1b';

/// Coordinator [AsyncNotifier] that bridges [AppSettings] and the notification
/// scheduling infrastructure.
///
/// It keeps [NotificationService] (a low-level singleton wrapping
/// `flutter_local_notifications`) and [DailyNotificationScheduler] in sync with
/// the user's settings. Persistence still flows through the canonical
/// [Settings] notifier so there is a single source of truth for [AppSettings].

abstract class _$NotificationSettings extends $AsyncNotifier<AppSettings> {
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
