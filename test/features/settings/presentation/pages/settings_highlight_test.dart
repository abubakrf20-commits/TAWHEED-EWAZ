/// Deep-link behaviour of the settings search.
///
/// Tapping a search result pushes the destination page with
/// `extra: {kSettingsHighlightExtra: rowKey}`; the page must scroll that row
/// into view and flash its section (see `SettingsHighlight`).
///
/// The viewports here are deliberately SHORT: the target row has to start
/// below the fold, otherwise the test would pass without any scrolling at all.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/design_system/components/components.dart'
    show SectionHeader;
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart'
    as tasbih_domain;
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_provider.dart';
import 'package:tawheeed/features/home/services/widget_sync.dart';
import 'package:tawheeed/features/home/services/widget_sync_provider.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/features/khatm/presentation/providers/khatm_provider.dart';
import 'package:tawheeed/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/presentation/screens/prayer_settings_screen.dart';
import 'package:tawheeed/features/prayer/services/prayer_time_service.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/pages/settings_screen.dart'
    show FontDisplayPage;
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/screens/about_screen.dart';
import 'package:tawheeed/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:tawheeed/features/settings/presentation/screens/widget_settings_screen.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_flash.dart';
import 'package:tawheeed/shared/services/widget_sync_service.dart';

import '../../../../core/database/mock_daos.dart';
import '../fake_notification_infra.dart';

class _LiveSettings extends Settings {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

class _LiveTasbih extends Tasbih {
  @override
  Future<List<tasbih_domain.TasbihModel>> build() async => const [];
}

class _LiveKhatm extends Khatm {
  @override
  Future<KhatmModel?> build() async => null;
}

/// One-shot recording fake of [WidgetSync]: the widgets page only touches the
/// theme accessors (the sync engine is stubbed separately).
class _StubWidgetSync extends WidgetSync {
  @override
  Future<Map<String, dynamic>> getWidgetTheme() async => const {};

  @override
  Future<void> setWidgetTheme({
    required String paletteId,
    required int opacityStep,
    required String widget,
  }) async {}
}

/// The widgets page delegates to the sync engine; the engine's own pipeline is
/// covered elsewhere, so a no-op stand-in is enough here.
class _StubSyncService extends WidgetSyncService {
  @override
  Future<void> syncWidgetsNow(WidgetRef ref) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSettingsRepository repo;
  late FakeNotificationService fakeNotif;
  late FakeDailyNotificationScheduler fakeScheduler;
  late FakePrayerTimeService fakePrayer;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = MockSettingsRepository()..setMockSettings(const AppSettings());
    fakeNotif = FakeNotificationService();
    fakeScheduler = FakeDailyNotificationScheduler();
    fakePrayer = FakePrayerTimeService();
  });

  /// The minimum a settings sub-page needs: the entity repository plus the
  /// inert scheduler. The prayer page renders the REAL prayer service (its
  /// Friday card reads `dhuhr`), so the prayer fake is not installed here.
  Widget baseScope(Widget child) => ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWith((ref) async => repo),
          dailyNotificationSchedulerProvider.overrideWithValue(fakeScheduler),
        ],
        child: child,
      );

  /// The notification page additionally reads the notification service and the
  /// prayer times.
  Widget notificationScope(Widget child) => ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWith((ref) async => repo),
          notificationServiceProvider.overrideWithValue(fakeNotif),
          dailyNotificationSchedulerProvider.overrideWithValue(fakeScheduler),
          prayerTimeServiceProvider.overrideWith((ref) => fakePrayer),
        ],
        child: child,
      );

  /// Everything the widget-settings page additionally touches (its live
  /// previews read the sync engine and the tasbih/khatm feeds).
  Widget widgetScope(Widget child) => ProviderScope(
        overrides: [
          widgetSyncProvider.overrideWithValue(_StubWidgetSync()),
          widgetSyncServiceProvider.overrideWithValue(_StubSyncService()),
          settingsProvider.overrideWith(_LiveSettings.new),
          tasbihProvider.overrideWith(_LiveTasbih.new),
          khatmProvider.overrideWith(_LiveKhatm.new),
          prayerTimeServiceProvider.overrideWith(
              (ref) => PrayerTimeService(ref.read(prayerRepositoryProvider))),
        ],
        child: child,
      );

  double viewportHeight(WidgetTester tester) =>
      tester.view.physicalSize.height / tester.view.devicePixelRatio;

  void useViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Builds a router that starts on an empty page, then lands on [page] with
  /// the search extra — exactly what tapping a search result does.
  Future<void> landWithHighlight(
    WidgetTester tester, {
    required Widget page,
    required String rowKey,
    required Widget Function(Widget child) scope,
    required Size viewport,
    bool disableAnimations = false,
  }) async {
    useViewport(tester, viewport);
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, __) => const SizedBox.shrink()),
        GoRoute(path: '/page', builder: (_, __) => page),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      scope(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/page', extra: {kSettingsHighlightExtra: rowKey});
    await tester.pumpAndSettle();
  }

  /// The flash key of the section owning [rowKey], or null when the section is
  /// absent (a below-the-fold row the lazy list never built) or not flashing.
  String? flashKeyOf(WidgetTester tester, String rowKey) {
    for (final section in tester
        .widgetList<SettingsFlashSection>(find.byType(SettingsFlashSection))) {
      if (section.rowKey == rowKey) return section.flashKey;
    }
    return null;
  }

  /// The row must end up fully inside the viewport.
  void expectInViewport(WidgetTester tester, Finder finder) {
    final rect = tester.getRect(finder);
    final height = viewportHeight(tester);
    expect(rect.top, greaterThanOrEqualTo(-0.5),
        reason: 'the row is still above the viewport');
    expect(rect.bottom, lessThanOrEqualTo(height + 0.5),
        reason: 'the row is still below the viewport');
  }

  testWidgets('prayer page scrolls to «بی‌صدا قبل از اقامه» and flashes it',
      (tester) async {
    const viewport = Size(412, 820);
    const target = 'بی‌صدا قبل از اقامه';
    await landWithHighlight(
      tester,
      page: const PrayerSettingsScreen(),
      rowKey: 'silent',
      scope: baseScope,
      viewport: viewport,
    );

    final header = find.widgetWithText(SectionHeader, target);
    expectInViewport(tester, header);
    // The flash is set while the highlight is live...
    expect(flashKeyOf(tester, 'silent'), 'silent');
    // ...and clears itself after 900ms (also drains the mixin's timer).
    await tester.pump(const Duration(milliseconds: 1000));
    expect(flashKeyOf(tester, 'silent'), isNull);
  });

  testWidgets('a per-prayer row is anchored inside the adhan card',
      (tester) async {
    await landWithHighlight(
      tester,
      page: const PrayerSettingsScreen(),
      rowKey: 'prayer.isha',
      scope: baseScope,
      viewport: const Size(412, 820),
    );

    // «عشاء» is the fifth block of the adhan card — it exists exactly once in
    // the visible tree, i.e. the scroll landed on the right block.
    expectInViewport(tester, find.text('عشاء'));
    expect(flashKeyOf(tester, 'prayer.isha'), 'prayer.isha');
    await tester.pump(const Duration(milliseconds: 1000));
  });

  testWidgets('notifications page scrolls to «سایر»', (tester) async {
    await landWithHighlight(
      tester,
      page: const NotificationSettingsScreen(),
      rowKey: 'misc',
      scope: notificationScope,
      viewport: const Size(412, 820),
    );

    final header = find.widgetWithText(SectionHeader, 'سایر');
    expectInViewport(tester, header);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('widgets page scrolls to the opacity card', (tester) async {
    await landWithHighlight(
      tester,
      page: const WidgetSettingsScreen(),
      rowKey: 'sliders',
      scope: widgetScope,
      viewport: const Size(412, 820),
    );

    expectInViewport(tester, find.text('شفافیت پس‌زمینه — اوقات نماز'));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('about page scrolls to «ارتباط با ما»', (tester) async {
    await landWithHighlight(
      tester,
      page: const AboutScreen(),
      rowKey: 'support',
      scope: baseScope,
      viewport: const Size(412, 600),
    );

    final header = find.widgetWithText(SectionHeader, 'ارتباط با ما');
    expectInViewport(tester, header);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('font page scrolls to the display toggles', (tester) async {
    await landWithHighlight(
      tester,
      page: const FontDisplayPage(),
      rowKey: 'toggles',
      scope: baseScope,
      viewport: const Size(412, 240),
    );

    expectInViewport(tester, find.text('ساعت 12 ساعته'));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('font page scrolls to «روش عرضه ماه»', (tester) async {
    // The month row moved off the main page into this card, so the search
    // highlight has to walk the lazy list down to it like any other row.
    // 380 dp is the tightest viewport that can land it: the page is ONE card
    // of ~708 dp, so at 240 dp its scroll range (278 px for a 184 px
    // viewport) can never bring a row that deep to the top.
    await landWithHighlight(
      tester,
      page: const FontDisplayPage(),
      rowKey: 'monthDisplay',
      scope: baseScope,
      viewport: const Size(412, 380),
    );

    expectInViewport(tester, find.text('روش عرضه ماه'));
    // The landing must contain the control itself, not only its title.
    expectInViewport(tester, find.text('افغانی'));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('without the extra the page does not scroll on its own',
      (tester) async {
    const viewport = Size(412, 820);
    useViewport(tester, viewport);
    await tester.pumpWidget(
      baseScope(const MaterialApp(home: PrayerSettingsScreen())),
    );
    await tester.pumpAndSettle();

    // Nothing moved: the page still sits at the top of the list, and no
    // section is flashing. (The last section is below the fold and is not even
    // built by the lazy list — which is exactly why the extra is needed.)
    final position =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.pixels, 0);
    expect(flashKeyOf(tester, 'silent'), isNull);
  });

  testWidgets('reduce-motion scrolls but never flashes', (tester) async {
    await landWithHighlight(
      tester,
      page: const PrayerSettingsScreen(),
      rowKey: 'silent',
      scope: baseScope,
      viewport: const Size(412, 820),
      disableAnimations: true,
    );

    expectInViewport(tester, find.widgetWithText(SectionHeader, 'بی‌صدا قبل از اقامه'));
    expect(flashKeyOf(tester, 'silent'), isNull);
  });
}
