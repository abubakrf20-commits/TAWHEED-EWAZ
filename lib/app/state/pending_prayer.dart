import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Transient prayer-highlight request from a notification tap.
///
/// Written by `BootCoordinator.onPrayerTapped`, consumed + cleared by HomeTab.
/// (A constructor-passed value was lost whenever Home was already built,
/// because the IndexedStack tab is not rebuilt on re-select.)
///
/// Lives in its own file (rather than `shell_nav.dart`) so shell-navigation
/// refactors can't silently drop it.
final pendingPrayerProvider =
    Provider<ValueNotifier<String?>>((ref) => ValueNotifier(null));
