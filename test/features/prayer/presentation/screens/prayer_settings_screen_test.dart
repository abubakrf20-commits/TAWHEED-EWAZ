import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/features/prayer/presentation/screens/prayer_settings_screen.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';

import '../../../../core/database/mock_daos.dart';
import '../../../settings/presentation/fake_notification_infra.dart';

/// The prayer & adhan page after the Design-A redesign: eight sections, one
/// titled «اذان و اقامه هر نماز» and carrying a single per-prayer card (azan
/// switch + voice chip + adhan shift + adhan→iqamah interval per prayer)
/// instead of three separate five-row lists read side by side.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sectionTitles = <String>[
    'صوت اذان',
    'روش محاسباتی',
    'موقعیت مکانی',
    'اذان و اقامه هر نماز',
    'اعلان نماز',
    'جابجایی کلی',
    'وقت نماز جمعه',
    'بی‌صدا قبل از اقامه',
  ];

  const prayers = ['فجر', 'ظهر', 'عصر', 'مغرب', 'عشاء'];

  late MockSettingsRepository repo;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    double width = 412,
    // The rewritten page is taller than 2000px and the body is a lazy
    // ListView: anything below the fold is never built, so the last
    // sections (e.g. «بی‌صدا قبل از اقامه») cannot be found. Pump tall —
    // the same idiom as settings_screen_test — so every section exists.
    double height = 6000,
    double textScale = 1.0,
    Map<String, Object> prefs = const {},
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The per-prayer card reads its voice overrides from SharedPreferences
    // in initState; the card tests and the screen tests share this pump.
    SharedPreferences.setMockInitialValues(prefs);

    repo = MockSettingsRepository()..setMockSettings(settings);
    final container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => repo),
      dailyNotificationSchedulerProvider
          .overrideWithValue(FakeDailyNotificationScheduler()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const PrayerSettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return container;
  }

  Finder finderBlock(String name) => find.byKey(ValueKey('adhan-block-$name'));

  /// The azan switch lives in the block header, next to the duotone tile.
  Finder prayerSwitch(String name) => find.descendant(
        of: finderBlock(name),
        matching: find.byType(SettingsSwitch),
      );

  /// Per-prayer adhan-time shift stepper («جابجایی اذان»).
  Finder azanStepper(String prayer) => find.byWidgetPredicate(
      (w) => w is SettingsStepper && w.semanticLabel == 'جابجایی اذان $prayer');

  /// Per-prayer adhan→iqamah interval stepper («تا اقامه» uses the same
  /// semantic label the home counters print).
  Finder iqamahStepper(String prayer) => find.byWidgetPredicate(
      (w) => w is SettingsStepper && w.semanticLabel == 'فاصله اقامه $prayer');

  /// A real file inside a directory literally named `custom_azans`: the row's
  /// usability check demands both, so a bare temp path would only ever render
  /// the «در دسترس نیست» copy and the filename case could not be exercised.
  String makeAzanFile(String name) {
    final root = Directory.systemTemp.createTempSync('azan_row_test');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final dir = Directory(
        '${root.path}${Platform.pathSeparator}custom_azans')
      ..createSync(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}$name')
      ..writeAsBytesSync(const [0, 1, 2, 3]);
    return file.path;
  }

  testWidgets('renders the eight designed sections in order', (tester) async {
    await pump(tester);

    for (final title in sectionTitles) {
      expect(find.widgetWithText(SectionHeader, title), findsOneWidget,
          reason: 'missing «$title»');
    }

    // Section order is the reading order: the adhan card sits between the
    // location section and the prayer-notification section.
    final ys = sectionTitles
        .map((t) => tester.getTopLeft(find.widgetWithText(SectionHeader, t)).dy)
        .toList(growable: false);
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i], greaterThan(ys[i - 1]), reason: '«${sectionTitles[i]}»');
    }
  });

  testWidgets('an angle drag writes the store once with the last value',
      (tester) async {
    await pump(
      tester,
      settings: const AppSettings(
          calculationMethod: CalculationMethodOption.custom),
    );
    final before = repo.getMockSettings().customFajrAngle;

    final row = find.ancestor(
      of: find.text('زاویه فجر'),
      matching: find.byType(SettingsSliderRow),
    );
    final slider = find.descendant(of: row, matching: find.byType(Slider));
    final rect = tester.getRect(slider);

    // Several onChanged ticks; the trailing writer must persist exactly one
    // write carrying the released value — not one Drift write per tick.
    final gesture =
        await tester.startGesture(Offset(rect.left + 8, rect.center.dy));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(24, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    expect(repo.updateCount, 1);
    expect(repo.getMockSettings().customFajrAngle, isNot(before));
  });

  testWidgets('the per-prayer card carries all five prayers', (tester) async {
    await pump(tester);

    for (final name in prayers) {
      expect(prayerSwitch(name), findsOneWidget, reason: 'missing «$name»');
    }
    // Every prayer row is open: five azan steppers, five iqamah steppers and
    // five voice chips with no expander anywhere.
    for (final name in prayers) {
      expect(azanStepper(name), findsOneWidget, reason: 'azan «$name»');
      expect(iqamahStepper(name), findsOneWidget, reason: 'iqamah «$name»');
    }
    expect(find.byType(PopupMenuButton<String>), findsNWidgets(prayers.length));
    expect(find.byTooltip('تنظیم دقیق'), findsNothing);
  });

  testWidgets('a prayer switch flips only that prayer', (tester) async {
    await pump(
      tester,
    );

    expect(tester.widget<SettingsSwitch>(prayerSwitch('فجر')).value, isFalse);
    await tester.tap(prayerSwitch('فجر'));
    await tester.pumpAndSettle();
    // The notifier debounces its notification reschedule by 350 ms; let the
    // timer fire so the test does not end with a pending timer.
    await tester.pump(const Duration(milliseconds: 500));

    final saved = await repo.getSettings();
    expect(saved.azanEnabledForFajr, isTrue);
    expect(saved.azanEnabledForDhuhr, isFalse);
    expect(saved.azanEnabledForAsr, isFalse);
    expect(saved.azanEnabledForMaghrib, isFalse);
    expect(saved.azanEnabledForIsha, isFalse);
  });

  testWidgets('the fajr azan stepper writes the fajr offset only',
      (tester) async {
    await pump(tester);

    // The strip is open: no expander tap needed.
    await tester.tap(
      find.descendant(
          of: azanStepper('فجر'), matching: find.byIcon(Icons.add_rounded)),
    );
    await tester.pumpAndSettle();
    // The notifier debounces its notification reschedule by 350 ms; let the
    // timer fire so the test does not end with a pending timer.
    await tester.pump(const Duration(milliseconds: 500));

    final saved = await repo.getSettings();
    expect(saved.fajrOffset, 1);
    expect(saved.dhuhrOffset, 0);
  });

  testWidgets('the dhuhr iqamah stepper writes the dhuhr iqamah offset',
      (tester) async {
    await pump(tester);

    await tester.tap(
      find.descendant(
          of: iqamahStepper('ظهر'), matching: find.byIcon(Icons.add_rounded)),
    );
    await tester.pumpAndSettle();
    // The notifier debounces its notification reschedule by 350 ms; let the
    // timer fire so the test does not end with a pending timer.
    await tester.pump(const Duration(milliseconds: 500));

    final saved = await repo.getSettings();
    expect(saved.iqamahOffsetDhuhr, 26);
    expect(saved.iqamahOffsetFajr, 30);
  });

  testWidgets('a prayer voice chip sets only that prayer’s own override',
      (tester) async {
    // fajr's playback is ON so its voice chip is enabled; the others are
    // off by default — their chips render muted.
    await pump(
      tester,
      settings: const AppSettings(azanSound: 'kamel', azanEnabledForFajr: true),
    );

    // FIVE chips render the effective voice; fajr now shows its own… well,
    // initially it still INHERITS the shared voice (no override anywhere),
    // so all five print کامل.
    expect(find.text('کامل'), findsNWidgets(prayers.length));

    // The fajr chip's popup writes fajr's own override…
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تکبیر').last);
    await tester.pumpAndSettle();
    // The store change still reschedules the alarms (350 ms debounce).
    await tester.pump(const Duration(milliseconds: 500));

    // …the SHARED «صوت اذان» row is untouched: the global voice remains
    // kamel and only fajr carries an override key.
    final saved = await repo.getSettings();
    expect(saved.azanSound, 'kamel');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('azan_sound_fajr'), 'takbir');
    expect(prefs.containsKey('azan_sound_dhuhr'), isFalse);
  });

  testWidgets('an adhan-left-off prayer keeps its voice chip disabled',
      (tester) async {
    await pump(tester, settings: const AppSettings(azanSound: 'kamel'));

    // OFF dims ONLY the voice chip; the counters keep working (see the
    // longer card suite). Here: the disabled chip never opens a popup.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('تکبیر'), findsNothing);
  });

  testWidgets('the sunrise stepper writes the sunrise offset', (tester) async {
    await pump(tester);

    final stepper = find.byWidgetPredicate(
        (w) => w is SettingsStepper && w.semanticLabel == 'جابجایی طلوع آفتاب');
    expect(stepper, findsOneWidget);

    await tester.tap(
      find.descendant(of: stepper, matching: find.byIcon(Icons.add_rounded)),
    );
    await tester.pumpAndSettle();
    // The write now also reschedules the alarms (350 ms debounce) — pump past
    // it so no timer outlives the test.
    await tester.pump(const Duration(milliseconds: 500));

    final saved = await repo.getSettings();
    expect(saved.sunriseOffset, 1);
    expect(saved.globalPrayerOffset, 0);
  });

  testWidgets('clearing the latitude field refuses instead of writing 0',
      (tester) async {
    await pump(
      tester,
      // Manual tiles render only with auto-location off.
      settings: const AppSettings(
          useLocation: false,
          manualLat: 35.7,
          manualLng: 51.4,
          hasLocation: true),
    );

    final latField = find.byType(TextField).at(0);
    await tester.enterText(latField, '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final saved = await repo.getSettings();
    expect(saved.manualLat, 35.7);
    expect(saved.manualLng, 51.4);
  });

  testWidgets('persian digits in the latitude field parse correctly',
      (tester) async {
    await pump(
      tester,
      // Manual tiles render only with auto-location off.
      settings: const AppSettings(
          useLocation: false,
          manualLat: 35.7,
          manualLng: 51.4,
          hasLocation: true),
    );

    final latField = find.byType(TextField).at(0);
    await tester.enterText(latField, '۳۵٫۵');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final saved = await repo.getSettings();
    expect(saved.manualLat, closeTo(35.5, 0.0001));
  });

  group('the picked adhan file', () {
    Finder removeButton() => find.byIcon(Icons.delete_outline_rounded);

    testWidgets('prints the filename and offers a remove control',
        (tester) async {
      final path = makeAzanFile('khosh-azan.mp3');
      await pump(
        tester,
        settings: AppSettings(azanSound: 'custom', customAzanPath: path),
      );

      expect(find.text('انتخاب فایل اذان'), findsOneWidget);
      expect(find.text('khosh-azan.mp3'), findsOneWidget);
      expect(removeButton(), findsOneWidget);
    });

    testWidgets('offers no remove control without a recorded path',
        (tester) async {
      await pump(tester, settings: const AppSettings(azanSound: 'custom'));

      expect(find.textContaining('فایلی انتخاب نشده'), findsOneWidget);
      expect(removeButton(), findsNothing);
    });

    testWidgets('a stale recorded path is still clearable', (tester) async {
      final path = makeAzanFile('gone.mp3');
      File(path).deleteSync();

      await pump(
        tester,
        settings: AppSettings(azanSound: 'custom', customAzanPath: path),
      );

      expect(find.textContaining('در دسترس نیست'), findsOneWidget);
      expect(removeButton(), findsOneWidget);
    });

    testWidgets('cancelling the dialog keeps the file and every setting',
        (tester) async {
      final path = makeAzanFile('keep.mp3');
      final container = await pump(
        tester,
        settings: AppSettings(azanSound: 'custom', customAzanPath: path),
        prefs: const {'azan_sound_fajr': 'custom'},
      );

      await tester.tap(removeButton());
      await tester.pumpAndSettle();
      expect(find.text('حذف فایل اذان'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'انصراف'));
      await tester.pumpAndSettle();

      final saved = await repo.getSettings();
      expect(saved.customAzanPath, path);
      expect(saved.azanSound, 'custom');
      expect(File(path).existsSync(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('azan_sound_fajr'), 'custom');
      expect(container.read(settingsProvider).value?.customAzanPath, path);
      expect(find.text('keep.mp3'), findsOneWidget);
      expect(removeButton(), findsOneWidget);
    });

    testWidgets('confirming removes the file, the path and the «شخصی» overrides',
        (tester) async {
      final path = makeAzanFile('khosh-azan.mp3');
      final container = await pump(
        tester,
        settings: AppSettings(azanSound: 'custom', customAzanPath: path),
        prefs: const {
          'azan_sound_fajr': 'custom',
          'azan_sound_isha': 'custom',
          // Somebody else's voice: not a dangling path to the removed file.
          'azan_sound_asr': 'takbir',
        },
      );

      await tester.tap(removeButton());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'حذف'));
      await tester.pumpAndSettle();

      final saved = await repo.getSettings();
      expect(saved.customAzanPath, isNull);
      // The re-pick row is gated on the shared voice; clearing it would strand
      // the reader with no door back to «انتخاب فایل اذان».
      expect(saved.azanSound, 'custom');
      expect(File(path).existsSync(), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('azan_sound_fajr'), isNull);
      expect(prefs.getString('azan_sound_isha'), isNull);
      expect(prefs.getString('azan_sound_asr'), 'takbir');

      expect(container.read(settingsProvider).value?.customAzanPath, isNull);
      expect(find.text('فایل اذان حذف شد'), findsOneWidget);
      expect(find.textContaining('فایلی انتخاب نشده'), findsOneWidget);
      expect(removeButton(), findsNothing);

      // The notifier debounces its notification reschedule by 350 ms and the
      // snackbar dismisses itself; let both timers fire before the teardown.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('a long filename does not overflow a narrow phone',
        (tester) async {
      final path =
          makeAzanFile('azan-mahalli-bandar-abbas-1403-full-version.mp3');

      await pump(
        tester,
        width: 320,
        textScale: 1.3,
        settings: AppSettings(azanSound: 'custom', customAzanPath: path),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('azan-mahalli-bandar-abbas-1403-full-version.mp3'),
          findsOneWidget);
    });
  });

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('lays out at ${width.toInt()}dp x$scale with no overflow',
          (tester) async {
        await pump(tester, width: width, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
