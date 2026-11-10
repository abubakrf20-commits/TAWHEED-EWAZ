import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/features/home/presentation/screens/home_tab.dart';
import 'package:tawheeed/features/quran/presentation/screens/quran_tab.dart';
import 'package:tawheeed/features/adhkar/presentation/screens/azkar_tasbih_tab.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/azkar_provider.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_provider.dart';
import 'package:tawheeed/features/tools/calendar/presentation/screens/calendar_screen.dart';
import 'package:tawheeed/features/worship/presentation/screens/evaluation_tab.dart';

import 'package:tawheeed/features/settings/presentation/screens/more_screen.dart';
import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/services/widget_sync_service.dart';
import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/app/router/home_bottom_nav.dart';
import 'package:tawheeed/app/state/boot_coordinator.dart';
import 'package:tawheeed/features/prayer/prayer.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => MainShellState();
}

class MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  static MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();

  late final BootCoordinator _bootCoordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootCoordinator = BootCoordinator(
      ref: ref,
      widgetSyncService: ref.read(widgetSyncServiceProvider),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _bootCoordinator.run();
      if (!mounted) return;
      // A cold-start notification tap owns the first interaction — do not
      // preempt its destination with the GPS-enable dialog (P1-7 polish).
      if (!NotificationService.consumedColdStartTap) {
        await _bootCoordinator.showGpsPromptIfNeeded(context);
      }
      if (!mounted) return;
      await _bootCoordinator.runDelayedResync();
    });

    NotificationService.onPrayerTapped = _bootCoordinator.onPrayerTapped;
    NotificationService.onPostPrayerAzkarTapped =
        _bootCoordinator.onPostPrayerAzkarTapped;
    NotificationService.onKhatmTapped = _bootCoordinator.onKhatmTapped;
    NotificationService.onQuranTapped = _bootCoordinator.onQuranTapped;
    NotificationService.onCareTapped = _bootCoordinator.onCareTapped;
    NotificationService.onFamilyTapped = _bootCoordinator.onFamilyTapped;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bootCoordinator.dispose();
    NotificationService.onPrayerTapped = null;
    NotificationService.onPostPrayerAzkarTapped = null;
    NotificationService.onKhatmTapped = null;
    NotificationService.onQuranTapped = null;
    NotificationService.onCareTapped = null;
    NotificationService.onFamilyTapped = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bootCoordinator.onResume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      // Background upkeep goes quiet: no 15-minute maintenance tick and no
      // 30-minute widget sync while the user cannot see them. onResume()
      // restarts both and runs their catch-up once.
      _bootCoordinator.onPause();
    }
  }

  /// Tabs visited at least once — built lazily so weak phones don't pay the
  /// cost of constructing (and keeping alive) all six tabs at startup.
  /// Once visited, a tab stays alive to preserve its state.
  final Set<int> _visitedTabs = {0};

  /// One widget instance per tab, kept for the life of the shell.
  ///
  /// `IndexedStack` already keeps a visited tab's ELEMENT alive, but the shell
  /// used to hand it a freshly built widget on every rebuild, which made
  /// `Element.update` rebuild every visited tab. A rebuild happens on each tab
  /// switch (and, before [_ShellScaffold], on every frame of the keyboard
  /// animation), so all six tabs — More's 30 tiles, the calendar grid, the
  /// quran tab — re-ran their `build` for a change that concerns one of them.
  /// Reusing the same instance is what lets Flutter skip the untouched
  /// subtrees; it costs nothing extra in memory, because the element tree was
  /// already retained.
  late final Widget _homeTab =
      HomeTab(onNavigateToAzkarTimeline: _goToAzkarCounters);
  static const Widget _quranTab = QuranTab();
  static const Widget _calendarTab = CalendarScreen();
  static const Widget _evaluationTab = EvaluationTab();
  static const Widget _moreTab = MoreScreen();

  /// The azkar tab is the only one whose constructor takes a sub-tab, so it is
  /// cached per value. Keyed only by the sub-tab: an explicit nav tap resets
  /// the sub-tab (fresh تسبیح view), but re-tapping تسبیح while already on the
  /// تسبیح sub-tab no longer destroys the whole subtree — the counter keeps
  /// its selected dhikr and warm sound pool.
  int _cachedAzkarSubTab = -1;
  Widget? _cachedAzkarTab;

  Widget _tabFor(int index, int azkarSubTab) {
    switch (index) {
      case 0:
        return _homeTab;
      case 1:
        return _quranTab;
      case 2:
        if (_cachedAzkarTab == null || _cachedAzkarSubTab != azkarSubTab) {
          _cachedAzkarSubTab = azkarSubTab;
          _cachedAzkarTab = AzkarTasbihTab(
              key: ValueKey('azkar_$azkarSubTab'), initialSubTab: azkarSubTab);
        }
        return _cachedAzkarTab!;
      case 3:
        return _calendarTab;
      case 4:
        return _evaluationTab;
      default:
        return _moreTab;
    }
  }

  void _goToAzkarCounters() {
    ref.read(shellTabIndexProvider.notifier).setIndex(2);
    ref.read(shellSubTabProvider.notifier).setIndex(1);
  }

  /// The shell's six rooms: each tab's ambient field takes its own
  /// [SectionHues] colour, so moving between tabs changes the light instead of
  /// repainting the same navy. The hues are the same identity table the tiles,
  /// pills and charts already read.
  static Color sectionHue(int index) => switch (index) {
        0 => SectionHues.home,
        1 => SectionHues.quran,
        2 => SectionHues.tasbih,
        3 => SectionHues.calendar,
        4 => SectionHues.evaluation,
        _ => SectionHues.more,
      };

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(shellTabIndexProvider);
    final azkarSubTab = ref.watch(shellSubTabProvider);

    // Idempotent — makes sure the currently selected tab exists in the lazy set.
    _visitedTabs.add(currentIndex);

    ref.listen(prayerTimesProvider, (prev, next) {
      if (next is AsyncData && next.value != null) {
        _bootCoordinator.widgetSyncService.scheduleSync(ref);
      }
    });

    // Counting in the app must reach the home-screen tasbih widget promptly
    // (the widget keeps its own counters; the snapshot merge never lets a
    // stale app value overwrite a higher native count).
    ref.listen(tasbihProvider, (prev, next) {
      if (next is AsyncData && next.value != null) {
        _bootCoordinator.widgetSyncService.scheduleSync(ref);
      }
    });

    // Completing a daily dhikr in the app must update the «اذکار روزانه» line
    // of the home-screen widget immediately (same debounce as the tasbih).
    // The lightweight version counter fires on every completion toggle and on
    // the calendar-day rollover (yesterday's progress resets).
    ref.listen(azkarVersionProvider, (prev, next) {
      if (next != prev) {
        _bootCoordinator.widgetSyncService.scheduleSync(ref);
      }
    });

    // Built once per shell rebuild. [_ShellScaffold] rebuilds on every frame of
    // the keyboard animation and whenever the mushaf toggles immersion, but it
    // receives this instance as-is, so none of those frames can reach a tab.
    final body = IndexedStack(
      index: currentIndex,
      children: [
        for (var i = 0; i < 6; i++)
          if (_visitedTabs.contains(i))
            // TickerMode pauses animations of hidden tabs
            // (e.g. hero colon blink, tasbih pulse) to save battery.
            TickerMode(
              enabled: i == currentIndex,
              child: _tabFor(i, azkarSubTab),
            )
          else
            const SizedBox.shrink(),
      ],
    );

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(shellTabIndexProvider.notifier).setIndex(0);
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AmbientBackground(
          accent: sectionHue(currentIndex),
          // User request 2026-11-09: drop the soft light halos behind the
          // Calendar (3) / Evaluation (4) / More (5) tabs — they read as a
          // stray glow around those boxes.
          includeGlow:
              currentIndex != 3 && currentIndex != 4 && currentIndex != 5,
          child: _ShellScaffold(body: body, currentIndex: currentIndex),
        ),
      ),
    );
  }
}

/// The Scaffold, and nothing else, follows the IME and the immersive mushaf.
///
/// [MediaQuery.viewInsetsOf] changes on EVERY frame of the keyboard animation;
/// reading it in [MainShellState.build] used to rebuild all six tabs per frame
/// of every keyboard open/close, on a phone that can least afford it. Here the
/// dependency is confined to this widget, and [body] arrives as an already
/// built (and cached) widget, so the tabs are never rebuilt for an inset.
class _ShellScaffold extends ConsumerWidget {
  const _ShellScaffold({required this.body, required this.currentIndex});

  final Widget body;
  final int currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The immersive mushaf reader hides the bottom navigation so the page
    // fills the whole screen (tap the page to bring it back).
    final quranImmersive = ref.watch(quranImmersiveProvider);
    // The keyboard already covers the bar, and a tab page that resizes for it
    // would otherwise be squeezed twice: its own bottom lands one bar-height
    // above the keyboard and shows a dead page-background band there (the
    // cream box over the «بیشتر» search keyboard). Hidden, the page ends
    // exactly at the keyboard's top edge.
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // کیبورد بدون تغییر سایز کل صفحه باز شود تا تب‌های باز
      // (IndexedStack) هنگام تایپ دوباره چیده نشوند و لگ نگیرند.
      resizeToAvoidBottomInset: false,
      // The mushaf tab (index 1) is full-bleed: the status-bar strip
      // must belong to the page itself, not the ambient background.
      // The reader insets its own chrome by the real safe-area inset.
      body: SafeArea(
        top: currentIndex != 1,
        bottom: false,
        child: Stack(children: [body]),
      ),
      bottomNavigationBar: quranImmersive || keyboardUp
          ? null
          : HomeBottomNav(
              currentIndex: currentIndex,
              onTap: (index) {
                FocusManager.instance.primaryFocus?.unfocus();
                ref.read(shellTabIndexProvider.notifier).setIndex(index);
                // An explicit tap on تسبیح always lands on the تسبیح sub-tab;
                // when it is already there this is a no-op (the persisted int
                // provider does not notify on an unchanged value), so nothing
                // rebuilds.
                if (index == 2) {
                  ref.read(shellSubTabProvider.notifier).setIndex(0);
                }
              },
            ),
    );
  }
}
