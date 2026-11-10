import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/prayer/presentation/widgets/prayer_widget_preview.dart'
    as pw;
import 'package:tawheeed/features/adhkar/tasbih/presentation/widgets/tasbih_widget_preview.dart';
import 'package:tawheeed/features/home/services/widget_sync.dart';
import 'package:tawheeed/features/home/domain/entities/widget_snapshot.dart';
import 'package:tawheeed/features/home/services/widget_sync_provider.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_provider.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart'
    as tasbih_domain;
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/shared/services/widget_sync_service.dart';
import 'package:tawheeed/features/prayer/services/prayer_time_service.dart';
import 'package:tawheeed/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/screens/widget_settings_screen.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/shared/models/day_time.dart';
import 'package:tawheeed/core/design_system/components/setting_row.dart';
import 'package:tawheeed/core/design_system/components/settings_components.dart';

/// Recording fake of [WidgetSync]: the screen only touches the theme
/// accessors, so the data paths are never called here. The fake FAILS the
/// test if any method channel is touched through the base class.
class RecordingWidgetSync extends WidgetSync {
  int setThemeCalls = 0;
  String? lastPaletteId;
  int? lastOpacityStep;
  final List<String> lastWidgets = [];

  Map<String, Object?> stored;

  /// When false the write is dropped on the floor — the platform channel
  /// failed. The screen must not report success in that case.
  final bool persists;

  RecordingWidgetSync({this.stored = const {}, this.persists = true});

  @override
  Future<Map<String, dynamic>> getWidgetTheme() async => stored;

  @override
  Future<void> setWidgetTheme(
      {required String paletteId,
      required int opacityStep,
      required String widget}) async {
    setThemeCalls++;
    lastPaletteId = paletteId;
    lastOpacityStep = opacityStep;
    lastWidgets.add(widget);
    if (persists) {
      stored = {
        ...stored,
        widget: {'paletteId': paletteId, 'opacityStep': opacityStep},
      };
    }
  }
}

/// Spy on the sync ENGINE: the screen DELEGATES the snapshot rebuild to
/// [WidgetSyncService.syncWidgetsNow] instead of building its own inline
/// snapshot. The spy records the call without running the whole pipeline —
/// the engine's internals are covered by their own suites.
class SpySyncService extends WidgetSyncService {
  int syncNowCalls = 0;

  @override
  Future<void> syncWidgetsNow(WidgetRef ref) async {
    syncNowCalls++;
  }
}

class _LiveTasbih extends Tasbih {
  @override
  Future<List<tasbih_domain.TasbihModel>> build() async => const [];
}

class _LiveSettings extends Settings {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

/// Prayer times collapsed onto one instant: every phase boundary is 12:00,
/// so «خودکار» resolves deterministically (before 12:00 → night via
/// minutes < fajr, after → night via minutes >= isha) without depending on
/// the real wall clock.
class _FlatPrayerTimes extends PrayerTimes {
  @override
  Future<pi.PrayerTimes?> build() async => _flatTimes();
}

pi.PrayerTimes _flatTimes() => pi.PrayerTimes(
      date: DateTime(2026, 10, 12),
      fajr: const pi.PrayerInfo(
          name: 'fajr', arabicName: 'فجر', time: DayTime(hour: 12, minute: 0)),
      shorouq: const pi.PrayerInfo(
          name: 'shorouq',
          arabicName: 'طلوع',
          time: DayTime(hour: 12, minute: 0)),
      duhr: const pi.PrayerInfo(
          name: 'duhr', arabicName: 'ظهر', time: DayTime(hour: 12, minute: 0)),
      asr: const pi.PrayerInfo(
          name: 'asr', arabicName: 'عصر', time: DayTime(hour: 12, minute: 0)),
      maghrib: const pi.PrayerInfo(
          name: 'maghrib',
          arabicName: 'مغرب',
          time: DayTime(hour: 12, minute: 0)),
      isha: const pi.PrayerInfo(
          name: 'isha',
          arabicName: 'عشاء',
          time: DayTime(hour: 12, minute: 0)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingWidgetSync ws;
  late SpySyncService spy;

  Future<void> pumpScreen(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    Map<String, Object?> storedTheme = const {},
    bool persists = true,
    GoRouter? router,
  }) async {
    // Very tall viewport: the options ListView builds lazily, so rows below
    // the fold do not EXIST in the widget tree. The 8000px trick materialises
    // every row so finders reach the footer actions directly.
    tester.view.physicalSize = const Size(900, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    ws = RecordingWidgetSync(stored: storedTheme, persists: persists);
    spy = SpySyncService();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        widgetSyncProvider.overrideWithValue(ws),
        widgetSyncServiceProvider.overrideWithValue(spy),
        settingsProvider.overrideWith(_LiveSettings.new),
        tasbihProvider.overrideWith(_LiveTasbih.new),
        prayerTimesProvider.overrideWith(_FlatPrayerTimes.new),
        // Real service over the app's FakePrayerRepository — the widget
        // preview reads times through this service; no location/network is
        // touched.
        prayerTimeServiceProvider.overrideWith(
            (ref) => PrayerTimeService(ref.read(prayerRepositoryProvider))),
      ],
      child: router != null
          ? MaterialApp.router(routerConfig: router)
          : const MaterialApp(home: WidgetSettingsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the header, tabs and the palette + opacity cards',
      (tester) async {
    await pumpScreen(tester, prefs: {
      'widget_bg_color': '#004F9E',
      'widget_opacity': 0.85,
    });
    expect(find.text('ویجت‌ها'), findsOneWidget);
    expect(find.text('اوقات نماز'), findsOneWidget);
    expect(find.text('تسبیح'), findsOneWidget);
    expect(find.text('پالت رنگ — اوقات نماز'), findsOneWidget);
    expect(find.text('شفافیت پس‌زمینه — اوقات نماز'), findsOneWidget);
    // Every preset ships its Persian name as the chip label.
    expect(find.text('خودکار'), findsOneWidget);
    expect(find.text('قهوه‌ای طلایی'), findsOneWidget);
    expect(find.text('شب آبی'), findsOneWidget);
    expect(find.text('روشن کرم'), findsOneWidget);
    // The four opacity steps are the fixed percentages from the JSON.
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('55%'), findsOneWidget);
    expect(find.text('همگام‌سازی دستی'), findsOneWidget);
    // The add row is per layout now: the prayer tab pins the horizontal and
    // the vertical widget as two independent widgets.
    expect(find.text('افزودن ویجت افقی اوقات نماز'), findsOneWidget);
    expect(find.text('افزودن ویجت عمودی اوقات نماز'), findsOneWidget);
    expect(find.text('نحوه اضافه کردن ویجت'), findsOneWidget);
    expect(find.byType(pw.PrayerWidgetPreview), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mirrors the legacy migration when nothing is stored natively',
      (tester) async {
    // #004F9E / 0.85 must open on شب آبی @ step 1. Prove it through the
    // save path: the carried STEP is what the recorded call must keep.
    await pumpScreen(tester, prefs: {
      'widget_bg_color': '#004F9E',
      'widget_opacity': 0.85,
    });
    await tester.tap(find.text('زمردی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(ws.setThemeCalls, 1);
    expect(ws.lastPaletteId, 'emerald');
    expect(ws.lastOpacityStep, 1);
    // The active tab (prayer) is the widget the call targets.
    expect(ws.lastWidgets, ['prayer']);
  });

  testWidgets('save keeps the stored step when only the palette changes',
      (tester) async {
    await pumpScreen(tester,
        storedTheme: {'paletteId': 'emerald', 'opacityStep': 2});
    await tester.tap(find.text('شب آبی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(ws.setThemeCalls, 1);
    expect(ws.lastPaletteId, 'night_blue');
    expect(ws.lastOpacityStep, 2);
    expect(ws.lastWidgets, ['prayer']);
    // A style save also refreshes the data snapshot through the engine.
    expect(spy.syncNowCalls, 1);
    expect(find.text('استایل ویجت ذخیره شد'), findsOneWidget);
  });

  testWidgets('ذخیره stays inert until the selection actually changes',
      (tester) async {
    await pumpScreen(tester,
        storedTheme: {'paletteId': 'emerald', 'opacityStep': 2});
    // Nothing changed yet: tapping the disabled action must be a no-op.
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(ws.setThemeCalls, 0);
    expect(spy.syncNowCalls, 0);
    // Now a real change enables the save.
    await tester.tap(find.text('شب آبی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(ws.setThemeCalls, 1);
  });

  /// The bridge logs and returns when the platform channel fails, so a
  /// completed call is not proof the widget changed. Reporting «ذخیره شد»
  /// over a widget that still paints the old palette is the one lie this
  /// page must not tell — and the selection must stay unsaved so the user
  /// can retry without re-picking.
  testWidgets('a dropped native write is reported, not dressed as success',
      (tester) async {
    await pumpScreen(tester,
        storedTheme: {'paletteId': 'emerald', 'opacityStep': 2},
        persists: false);
    await tester.tap(find.text('شب آبی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    expect(ws.setThemeCalls, 1);
    expect(find.text('استایل ویجت ذخیره شد'), findsNothing);
    expect(find.textContaining('ذخیره نشد'), findsOneWidget);
    // Nothing reached the engine, because nothing was actually saved.
    expect(spy.syncNowCalls, 0);
    // Still dirty: the save action is enabled, so one more tap can retry.
    final save = tester.widget<TextButton>(find.widgetWithText(TextButton, 'ذخیره'));
    expect(save.onPressed, isNotNull);
  });

  testWidgets('tasbih tab switches to the tasbih-widget preview',
      (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('تسبیح'));
    await tester.pumpAndSettle();
    expect(find.byType(pw.PrayerWidgetPreview), findsNothing);
    expect(find.byType(TasbihWidgetPreview), findsOneWidget);
  });

  testWidgets('خودکار is stored as the selection itself, not a preset',
      (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('خودکار'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(ws.setThemeCalls, 1);
    expect(ws.lastPaletteId, 'auto');
    expect(ws.lastWidgets, ['prayer']);
  });

  testWidgets('each tab edits its own widget and saves only the changed ones',
      (tester) async {
    // Both widgets start on the shared emerald/2 selection (the pre-split
    // ladder). A different palette per tab is exactly two targeted calls.
    await pumpScreen(tester,
        storedTheme: {'paletteId': 'emerald', 'opacityStep': 2});
    await tester.tap(find.text('شب آبی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسبیح'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('روشن کرم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(ws.setThemeCalls, 2);
    expect(ws.lastWidgets, ['prayer', 'tasbih']);
    // The last recorded call is the tasbih one: cream_light carrying the
    // inherited step.
    expect(ws.lastPaletteId, 'cream_light');
    expect(ws.lastOpacityStep, 2);
    // One snapshot rebuild covers both saves.
    expect(spy.syncNowCalls, 1);
  });

  testWidgets('stored per-widget maps drive independent selections',
      (tester) async {
    // Native already persisted a split: prayer = night_blue/1, tasbih =
    // brown_gold/3. The shared keys are the old pre-split selection and must
    // be ignored for display once a per-widget map exists.
    await pumpScreen(tester, storedTheme: {
      'paletteId': 'emerald',
      'opacityStep': 2,
      'prayer': {'paletteId': 'night_blue', 'opacityStep': 1},
      'tasbih': {'paletteId': 'brown_gold', 'opacityStep': 3},
    });
    final preview = tester.widget<pw.PrayerWidgetPreview>(
        find.byType(pw.PrayerWidgetPreview));
    // night_blue's bg in assets/widget_palettes.json. The old 0xFF004F9E was
    // the pre-palette-JSON literal and had drifted.
    expect(preview.bgColor, const Color(0xFF14306E));
    // Nothing changed on either tab: the save stays disabled.
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(ws.setThemeCalls, 0);
    // The tasbih tab opens on its own stored selection; editing and saving
    // targets only that widget.
    await tester.tap(find.text('تسبیح'));
    await tester.pumpAndSettle();
    expect(find.byType(TasbihWidgetPreview), findsOneWidget);
    await tester.tap(find.text('روشن کرم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(ws.setThemeCalls, 1);
    expect(ws.lastWidgets, ['tasbih']);
    expect(ws.lastPaletteId, 'cream_light');
    expect(ws.lastOpacityStep, 3);
  });

  testWidgets('the preview wears the selected palette, accent and ink included',
      (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('روشن کرم'));
    await tester.pumpAndSettle();
    final preview = tester.widget<pw.PrayerWidgetPreview>(
        find.byType(pw.PrayerWidgetPreview));
    // cream_light as shipped in assets/widget_palettes.json. These three were
    // the pre-JSON literals; the palette was retuned and the expectations
    // were never re-run (flutter test was unrunnable in the sandbox).
    expect(preview.bgColor, const Color(0xFFFFF8E8));
    expect(preview.accentColor, const Color(0xFF9A5F0F));
    expect(preview.textColor, const Color(0xFF3B2418));
    expect(preview.light, isTrue);
  });

  testWidgets('preset palettes stay readable at every step — no warning',
      (tester) async {
    await pumpScreen(tester);
    expect(find.textContaining('خوانایی متن'), findsNothing);
    // Walk the opacity steps: the preset floors are pinned by
    // widget_palettes_test.dart, so the screen must never flag one.
    for (final step in ['85%', '70%', '55%']) {
      await tester.tap(find.text(step));
      await tester.pumpAndSettle();
      expect(find.textContaining('خوانایی متن'), findsNothing,
          reason: 'step $step');
    }
  });

  testWidgets('popping with unsaved changes asks before discarding',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(const {});
    ws = RecordingWidgetSync();
    spy = SpySyncService();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        widgetSyncProvider.overrideWithValue(ws),
        widgetSyncServiceProvider.overrideWithValue(spy),
        settingsProvider.overrideWith(_LiveSettings.new),
        tasbihProvider.overrideWith(_LiveTasbih.new),
        prayerTimesProvider.overrideWith(_FlatPrayerTimes.new),
        prayerTimeServiceProvider.overrideWith(
            (ref) => PrayerTimeService(ref.read(prayerRepositoryProvider))),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            key: const ValueKey('root'),
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const WidgetSettingsScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // A real edit arms the guard.
    await tester.tap(find.text('شب آبی'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButtonIcon));
    await tester.pumpAndSettle();
    expect(find.text('تغییرات ذخیره نشده'), findsOneWidget);

    await tester.tap(find.text('ماندن'));
    await tester.pumpAndSettle();
    expect(find.text('تغییرات ذخیره نشده'), findsNothing);
    expect(find.text('ویجت‌ها'), findsOneWidget);

    // Leaving without saving pops back to the root after the confirm.
    await tester.tap(find.byType(BackButtonIcon));
    await tester.pumpAndSettle();
    await tester.tap(find.text('خروج بدون ذخیره'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('root')), findsOneWidget);
  });

  // ── The per-widget options (2026-11) ─────────────────────────────────────
  //
  // The user's report: «گزینه‌های جدید که در صفحه ویجت اضافه شدن قابل تغییر
  // نیستند و قفل هستند». These three tests pin the fix: a tap MOVES the thumb,
  // writes the exact key the native widget reads, reaches the preview above,
  // and leaves the control usable for the next tap.

  testWidgets('the layout option switches the preview to the five-row card',
      (tester) async {
    await pumpScreen(tester);
    pw.PrayerWidgetPreview preview() => tester
        .widget<pw.PrayerWidgetPreview>(find.byType(pw.PrayerWidgetPreview));

    // Default: the shipped five-box card, and its 320×220 medium cell.
    expect(preview().layout, WidgetSnapshot.prayerLayoutHorizontal);
    expect(tester.getSize(find.byType(pw.PrayerWidgetPreview)).height,
        lessThan(240));

    await tester.tap(find.text('عمودی'));
    await tester.pumpAndSettle();

    expect(preview().layout, WidgetSnapshot.prayerLayoutVertical);
    // The five-row card needs the height its rows are priced for, so the
    // preview box grows with the layout instead of squashing the rows.
    expect(tester.getSize(find.byType(pw.PrayerWidgetPreview)).height,
        greaterThan(240));
    // ...and the choice is written where the native renderer reads it.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('widget_prayer_layout'), 'vertical');
    expect(spy.syncNowCalls, 1);
  });

  testWidgets('the progress switch moves, writes the native key and is not locked',
      (tester) async {
    await pumpScreen(tester);
    pw.PrayerWidgetPreview preview() => tester
        .widget<pw.PrayerWidgetPreview>(find.byType(pw.PrayerWidgetPreview));

    Finder switchOf(String title) => find.descendant(
          of: find.ancestor(
              of: find.text(title), matching: find.byType(SettingRow)),
          matching: find.byType(SettingsSwitch),
        );

    final sw = switchOf('نمایش نوار پیشرفت');
    expect(tester.widget<SettingsSwitch>(sw).value, isTrue);
    expect(tester.widget<SettingsSwitch>(sw).onChanged, isNotNull);

    await tester.tap(sw);
    await tester.pumpAndSettle();

    // The thumb moved (the old card wrote the pref and left the thumb put)...
    expect(tester.widget<SettingsSwitch>(sw).value, isFalse);
    // ...the preview followed it...
    expect(preview().showProgress, isFalse);
    // ...the pref is the one the native card reads...
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('widget_show_progress'), isFalse);
    // ...and the control is NOT left disabled: the old `_busy` flag was never
    // cleared, which locked every switch for the rest of the session.
    expect(tester.widget<SettingsSwitch>(sw).onChanged, isNotNull);

    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(tester.widget<SettingsSwitch>(sw).value, isTrue);
    expect(prefs.getBool('widget_show_progress'), isTrue);
  });

  testWidgets('the Gregorian and Persian-digit options reach the preview',
      (tester) async {
    await pumpScreen(tester);
    pw.PrayerWidgetPreview preview() => tester
        .widget<pw.PrayerWidgetPreview>(find.byType(pw.PrayerWidgetPreview));

    Finder switchOf(String title) => find.descendant(
          of: find.ancestor(
              of: find.text(title), matching: find.byType(SettingRow)),
          matching: find.byType(SettingsSwitch),
        );

    expect(preview().showGregorian, isTrue);
    expect(preview().faDigits, isFalse);

    await tester.tap(switchOf('نمایش تاریخ میلادی'));
    await tester.pumpAndSettle();
    await tester.tap(switchOf('ارقام فارسی ساعت ویجت'));
    await tester.pumpAndSettle();

    expect(preview().showGregorian, isFalse);
    expect(preview().faDigits, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('widget_show_gregorian'), isFalse);
    expect(prefs.getBool('widget_fa_digits'), isTrue);
    expect(spy.syncNowCalls, 2);
  });

  // The page is a page-based (GoRouter) route in the app, so this harness is
  // page-based too: with a plain MaterialPageRoute the pop is imperative and
  // the bug cannot appear. Here `Navigator.pop` goes through the delegate's
  // `onPopPage`, which is exactly where the old code lost the user.
  testWidgets('confirming «خروج بدون ذخیره» really leaves the page',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('صفحه اصلی')),
          ),
        ),
        GoRoute(
          path: '/widgets',
          builder: (context, state) => const WidgetSettingsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await pumpScreen(tester, router: router);
    expect(find.text('صفحه اصلی'), findsOneWidget);

    router.push('/widgets');
    await tester.pumpAndSettle();
    expect(find.text('ویجت‌ها'), findsOneWidget);

    // An unsaved palette change is what arms the guard.
    await tester.tap(find.text('زمردی'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButtonIcon));
    await tester.pumpAndSettle();
    expect(find.text('تغییرات ذخیره نشده'), findsOneWidget);

    await tester.tap(find.text('خروج بدون ذخیره'));
    await tester.pumpAndSettle();

    // The page is GONE — the bug left it on screen forever.
    expect(find.text('ویجت‌ها'), findsNothing);
    expect(find.text('صفحه اصلی'), findsOneWidget);
  });

  testWidgets('«ماندن» keeps the page and keeps the edit', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('صفحه اصلی')),
          ),
        ),
        GoRoute(
          path: '/widgets',
          builder: (context, state) => const WidgetSettingsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await pumpScreen(tester, router: router);
    router.push('/widgets');
    await tester.pumpAndSettle();

    await tester.tap(find.text('زمردی'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButtonIcon));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ماندن'));
    await tester.pumpAndSettle();

    expect(find.text('ویجت‌ها'), findsOneWidget);
    expect(find.text('صفحه اصلی'), findsNothing);
  });
}
