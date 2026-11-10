// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shell_nav.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Canonical shell navigation state.
///
/// Provider-based shell navigation: any widget (including legacy tabs) can
/// switch the active shell tab imperatively via
/// `ProviderScope.containerOf(context).read(shellTabIndexProvider.notifier)`
/// without coupling to the shell widget tree.
///
/// `MainShellState.of(context)` (app_router/main_shell.dart) is NOT replaced by
/// this — it remains the InheritedWidget read/write path for widgets that live
/// inside the shell subtree.

@ProviderFor(ShellTabIndex)
final shellTabIndexProvider = ShellTabIndexProvider._();

/// Canonical shell navigation state.
///
/// Provider-based shell navigation: any widget (including legacy tabs) can
/// switch the active shell tab imperatively via
/// `ProviderScope.containerOf(context).read(shellTabIndexProvider.notifier)`
/// without coupling to the shell widget tree.
///
/// `MainShellState.of(context)` (app_router/main_shell.dart) is NOT replaced by
/// this — it remains the InheritedWidget read/write path for widgets that live
/// inside the shell subtree.
final class ShellTabIndexProvider
    extends $NotifierProvider<ShellTabIndex, int> {
  /// Canonical shell navigation state.
  ///
  /// Provider-based shell navigation: any widget (including legacy tabs) can
  /// switch the active shell tab imperatively via
  /// `ProviderScope.containerOf(context).read(shellTabIndexProvider.notifier)`
  /// without coupling to the shell widget tree.
  ///
  /// `MainShellState.of(context)` (app_router/main_shell.dart) is NOT replaced by
  /// this — it remains the InheritedWidget read/write path for widgets that live
  /// inside the shell subtree.
  ShellTabIndexProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'shellTabIndexProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$shellTabIndexHash();

  @$internal
  @override
  ShellTabIndex create() => ShellTabIndex();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$shellTabIndexHash() => r'f6d5128b49ddb06851531c8a239d2fa58c8eaa9e';

/// Canonical shell navigation state.
///
/// Provider-based shell navigation: any widget (including legacy tabs) can
/// switch the active shell tab imperatively via
/// `ProviderScope.containerOf(context).read(shellTabIndexProvider.notifier)`
/// without coupling to the shell widget tree.
///
/// `MainShellState.of(context)` (app_router/main_shell.dart) is NOT replaced by
/// this — it remains the InheritedWidget read/write path for widgets that live
/// inside the shell subtree.

abstract class _$ShellTabIndex extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element = ref.element
        as $ClassProviderElement<AnyNotifier<int, int>, int, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(ShellSubTab)
final shellSubTabProvider = ShellSubTabProvider._();

final class ShellSubTabProvider extends $NotifierProvider<ShellSubTab, int> {
  ShellSubTabProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'shellSubTabProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$shellSubTabHash();

  @$internal
  @override
  ShellSubTab create() => ShellSubTab();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$shellSubTabHash() => r'3ff45ccc0abc01fb746f1cf8ec1572232eb8e89e';

abstract class _$ShellSubTab extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element = ref.element
        as $ClassProviderElement<AnyNotifier<int, int>, int, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}
