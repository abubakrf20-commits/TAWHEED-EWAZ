import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal_info/services/pin_lock_service.dart';

/// Whether the «اطلاعات من» PIN gate has been passed during this app session.
/// The gate itself lives in [PinLockService]; this only remembers that the
/// user unlocked, so sub-routes deep-linked or pushed after a successful
/// unlock are not gated twice.
class VaultSessionNotifier extends Notifier<bool> with WidgetsBindingObserver {
  @override
  bool build() {
    // Leaving the app must cost the user something: while the vault was open
    // only a screen `dispose()` could re-lock it, so backgrounding (or the
    // recents switcher) left every field decrypted and on screen. `inactive`
    // is deliberately not a trigger — an incoming call must not lock a form
    // the user is halfway through.
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      lock();
    }
  }

  void unlock() => state = true;

  void lock() {
    if (state) state = false;
  }
}

final vaultSessionProvider =
    NotifierProvider<VaultSessionNotifier, bool>(VaultSessionNotifier.new);

/// Whether a vault PIN exists. Overridable in tests to avoid Keystore I/O.
final vaultPinSetProvider =
    FutureProvider<bool>((ref) => PinLockService.isPinSet());

/// Wraps a personal-vault sub-route so it cannot be opened while the vault is
/// locked. With no PIN ever set (or a vault error reading as absent) the child
/// passes through; once the session is unlocked it passes through too.
class VaultGuard extends ConsumerWidget {
  const VaultGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinSet = ref.watch(vaultPinSetProvider);
    switch (pinSet) {
      case AsyncData(:final value):
        if (!value) return child;
        return ref.watch(vaultSessionProvider) ? child : const _VaultLocked();
      default:
        // Loading or unreadable storage: stay on the safe side and don't
        // render vault data yet.
        return const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        );
    }
  }
}

class _VaultLocked extends StatelessWidget {
  const _VaultLocked();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = TopicHues.personalInfo;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'صندوق قفل است',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'بازگشت',
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.lock_outline, size: 36, color: accent),
                ),
                const SizedBox(height: 18),
                Text(
                  'برای دیدن این بخش، اول رمز صندوق را وارد کنید',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 15),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.go(RouteNames.personalInfo),
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  icon: const Icon(Icons.lock_open_outlined, size: 18),
                  label: const Text('ورود رمز'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
