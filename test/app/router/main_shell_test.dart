import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/app/router/home_bottom_nav.dart';
import 'package:tawheeed/app/router/main_shell.dart';
import 'package:tawheeed/app/state/pending_prayer.dart';
import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/core/services/clock_ticker.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/screens/more_screen.dart';
import 'package:tawheeed/features/home/presentation/screens/home_tab.dart';
import '../../core/database/mock_daos.dart';

/// The redesign's hero attaches the shared ClockTicker; a real one would
/// leave a recurring second-boundary timer pending at teardown (the
/// UncontrolledProviderScope container disposes after the framework's
/// pending-timer assertion). The idle variant never schedules.
final _idleTicker = clockTickerProvider.overrideWith((ref) {
  final ticker = ClockTicker.idle();
  ref.onDispose(ticker.dispose);
  return ticker;
});

/// What Android reports while the IME is up: the keyboard covers the system
/// navigation bar, so its inset drops out of [MediaQuery.padding] too.
EdgeInsets _paddingFor(double inset) =>
    EdgeInsets.only(top: 24, bottom: inset >= 24 ? 0 : 24);

void main() {
  testWidgets('MainShell renders without error', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockRepo = MockSettingsRepository();
    mockRepo.setMockSettings(const AppSettings());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
          _idleTicker,
        ],
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.pump();
    expect(find.byType(MainShell), findsOneWidget);
    // Dispose MainShell and let all pending timers fire
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('cold-start prayer tap reaches pendingPrayer (Phase-1)',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'notification_payload': 'prayer_fajr',
    });
    final mockRepo = MockSettingsRepository();
    mockRepo.setMockSettings(const AppSettings());

    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
        _idleTicker,
      ],
    );
    // HomeTab consumes + clears pendingPrayer the instant it fires (its own
    // contract), so record every write from a listener attached BEFORE the
    // first frame instead of reading the value after the fact.
    final seenPrayerWrites = <String?>[];
    container.read(pendingPrayerProvider).addListener(() {
      seenPrayerWrites.add(container.read(pendingPrayerProvider).value);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainShell()),
      ),
    );
    // Frame 1 registers the static tap handlers in initState; the
    // post-frame BootCoordinator.run() then consumes the stashed payload —
    // handlers must already be live (the Phase-1 bug consumed it from main()
    // before registration and dropped the prayer tap).
    await tester.pump();
    await tester.pump();

    expect(seenPrayerWrites, contains('fajr'),
        reason: 'cold-start tap must dispatch to a registered handler');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('notification_payload'), isNull,
        reason: 'payload must be consumed by the boot path');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
    // The container owns the evaluation provider's midnight timer, and the
    // framework's pending-timer check runs BEFORE `addTearDown` — so it has to
    // go inside the body or the test fails on a timer the app is right to hold.
    container.dispose();
  });

  // The keyboard covers the pill bar anyway, and a tab page that resizes for
  // the IME would be squeezed by the bar's height on top of that — leaving a
  // dead page-background band above the keyboard (the «بیشتر» search report).
  testWidgets('the bottom bar steps out while the keyboard is up',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockRepo = MockSettingsRepository();
    mockRepo.setMockSettings(const AppSettings());

    Future<void> pumpShell(double inset) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
          _idleTicker,
        ],
        child: MaterialApp(
          home: Builder(builder: (ctx) {
            final mq = MediaQuery.of(ctx);
            return MediaQuery(
              data: mq.copyWith(
                viewInsets: EdgeInsets.only(bottom: inset),
                viewPadding: const EdgeInsets.only(bottom: 24),
                padding: _paddingFor(inset),
              ),
              child: const MainShell(),
            );
          }),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await pumpShell(0);
    expect(find.byType(HomeBottomNav), findsOneWidget);

    await pumpShell(300);
    expect(find.byType(HomeBottomNav), findsNothing);

    await pumpShell(0);
    expect(find.byType(HomeBottomNav), findsOneWidget,
        reason: 'closing the keyboard brings the bar back');
  });

  testWidgets('a tab page ends exactly at the top of the keyboard',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final mockRepo = MockSettingsRepository();
    mockRepo.setMockSettings(const AppSettings());

    final container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
      _idleTicker,
    ]);
    // The More tab is the one the report is about: a scrolling page with a
    // search field.
    container.read(shellTabIndexProvider.notifier).setIndex(5);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(builder: (ctx) {
          final mq = MediaQuery.of(ctx);
          return MediaQuery(
            data: mq.copyWith(
              viewInsets: const EdgeInsets.only(bottom: 300),
              viewPadding: const EdgeInsets.only(bottom: 24),
              padding: _paddingFor(300),
            ),
            child: const MainShell(),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();

    final list = find.descendant(
        of: find.byType(MoreScreen), matching: find.byType(ListView));
    expect(list, findsOneWidget);
    expect(tester.getRect(list).bottom, 780 - 300,
        reason: 'no bar-height band of page background above the keyboard');
    // See the other container tests: dispose before the pending-timer check.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
    container.dispose();
  });

  // Performance contract (weak phones): a shell rebuild must not re-create the
  // tabs. `IndexedStack` keeps their elements alive, but handing it a fresh
  // widget on every rebuild made `Element.update` rebuild every visited tab —
  // so switching tabs (or, before the split, animating the keyboard) re-ran
  // More's 30 tiles and the calendar grid for nothing.
  testWidgets('a tab switch keeps the other tabs\' widget instances',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockRepo = MockSettingsRepository();
    mockRepo.setMockSettings(const AppSettings());

    final container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
      _idleTicker,
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MainShell()),
    ));
    await tester.pump();

    final homeBefore =
        tester.widget<HomeTab>(find.byType(HomeTab, skipOffstage: false));

    container.read(shellTabIndexProvider.notifier).setIndex(5);
    await tester.pump();

    final homeAfter =
        tester.widget<HomeTab>(find.byType(HomeTab, skipOffstage: false));
    expect(identical(homeBefore, homeAfter), isTrue,
        reason: 'the visited Home tab must keep its widget instance; a new '
            'instance makes IndexedStack rebuild it on every tab switch');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
    // The container owns the evaluation provider's midnight timer, and the
    // framework's pending-timer check runs BEFORE `addTearDown` — so it has to
    // go inside the body or the test fails on a timer the app is right to hold.
    container.dispose();
  });

  testWidgets('the keyboard inset never rebuilds a tab', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockRepo = MockSettingsRepository();
    mockRepo.setMockSettings(const AppSettings());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
        _idleTicker,
      ],
      child: const MaterialApp(home: MainShell()),
    ));
    await tester.pump();

    final before =
        tester.widget<HomeTab>(find.byType(HomeTab, skipOffstage: false));

    // Android animates this inset on every frame of the IME transition.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final after =
        tester.widget<HomeTab>(find.byType(HomeTab, skipOffstage: false));
    expect(identical(before, after), isTrue,
        reason: 'viewInsets changes every keyboard frame; the shell must not '
            'hand the tabs a new widget for it');
    expect(find.byType(HomeBottomNav), findsNothing,
        reason: 'the bar still steps out while the keyboard is up');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  });

  // The "each section has its own light" signature: the shell's ambient field
  // takes the tab's SectionHue, so moving between tabs changes the room rather
  // than repainting the same navy. Both the map and the wiring are pinned —
  // a new tab that forgets its hue would fall back to `more` silently.
  test('every shell tab maps to its own section hue', () {
    expect(MainShellState.sectionHue(0), SectionHues.home);
    expect(MainShellState.sectionHue(1), SectionHues.quran);
    expect(MainShellState.sectionHue(2), SectionHues.tasbih);
    expect(MainShellState.sectionHue(3), SectionHues.calendar);
    expect(MainShellState.sectionHue(4), SectionHues.evaluation);
    expect(MainShellState.sectionHue(5), SectionHues.more);
    final hues = <Color>{for (var i = 0; i < 6; i++) MainShellState.sectionHue(i)};
    expect(hues.length, 6, reason: 'six tabs must read as six rooms');
  });

  testWidgets('the ambient background follows the active tab', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockRepo = MockSettingsRepository();
    mockRepo.setMockSettings(const AppSettings());

    final container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
      _idleTicker,
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MainShell()),
    ));
    await tester.pump();

    AmbientBackground ambient() => tester.widget<AmbientBackground>(
        find.byType(AmbientBackground).first);

    expect(ambient().accent, SectionHues.home);

    container.read(shellTabIndexProvider.notifier).setIndex(3);
    await tester.pump();
    expect(ambient().accent, SectionHues.calendar);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
    // The container owns the evaluation provider's midnight timer, and the
    // framework's pending-timer check runs BEFORE `addTearDown` — so it has to
    // go inside the body or the test fails on a timer the app is right to hold.
    container.dispose();
  });
}
