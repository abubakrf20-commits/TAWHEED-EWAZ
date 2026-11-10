import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/core/services/clock_ticker.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';
import 'package:tawheeed/features/search/services/more_content_search.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/screens/more_screen.dart';

import '../../../../core/database/mock_daos.dart';

/// Visual baselines for the redesigned «بیشتر» page (spec §MORE, goldens).
/// Four states — full page, search with results, empty search, and the deep
/// content block — under each of the four pinned ThemeKinds, plus the width
/// matrix (320/360) and a 1.3 text scale. Everything is frozen: the strip reads
/// a fixed schedule at a fixed instant, so the countdown never drifts between
/// runs, and the content block answers from text written here, not from the
/// bundled guides. Recorded on the host with `flutter test --update-goldens`;
/// they guard layout and palette drift, not on-device font shaping.
final _kinds = <ThemeKind>[
  ThemeKind.dawn,
  ThemeKind.day,
  ThemeKind.sunset,
  ThemeKind.night,
];

/// Noon-ish fixed day: at 12:00 the next adhan is ظهر at 12:10.
DayTimes _day(int dayOffset) {
  final d = DateTime(2026, 10, 9).add(Duration(days: dayOffset));
  return DayTimes(
    fajr: DateTime(d.year, d.month, d.day, 6),
    sunrise: DateTime(d.year, d.month, d.day, 7, 30),
    dhuhr: DateTime(d.year, d.month, d.day, 12, 10),
    asr: DateTime(d.year, d.month, d.day, 15, 40),
    maghrib: DateTime(d.year, d.month, d.day, 18, 20),
    isha: DateTime(d.year, d.month, d.day, 19, 40),
  );
}

/// A clock frozen at 12:00:40 on 2026-10-09 (the seconds keep the countdown
/// visibly non-round: 00:09:20 to the adhan).
({ClockTicker ticker, PrayerClock clock}) _frozenClock() {
  final ticker = ClockTicker.idle()
    ..second.value = DateTime(2026, 10, 9, 12, 0, 40);
  final clock = PrayerClock(
    ticker,
    schedule:
        PrayerSchedule(yesterday: _day(-1), today: _day(0), tomorrow: _day(1)),
  );
  return (ticker: ticker, clock: clock);
}

ProviderScope _wrap(Widget child, {ClockTicker? ticker, PrayerClock? clock}) {
  SharedPreferences.setMockInitialValues({});
  final mockRepo = MockSettingsRepository();
  mockRepo.setMockSettings(const AppSettings());
  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
      if (ticker == null)
        clockTickerProvider.overrideWith((ref) => ClockTicker.idle())
      else
        clockTickerProvider.overrideWith((ref) => ticker),
      if (clock != null) prayerClockProvider.overrideWith((ref) => clock),
    ],
    child: child,
  );
}

Widget _app({
  double textScale = 1,
  List<MoreContentSource> sources = const [],
}) {
  // AppTheme.scaledFontSize reads the user's factor off bodyMedium — the same
  // knob the overflow-matrix tests turn.
  final base = AppTheme.light.textTheme;
  final theme = textScale == 1
      ? AppTheme.light
      : AppTheme.light.copyWith(
          textTheme: base.copyWith(
            bodyMedium: base.bodyMedium
                ?.copyWith(fontSize: base.bodyMedium!.fontSize! * textScale),
          ),
        );
  return MaterialApp(
    theme: theme,
    // Production paints the shell's «بیشتر orange» field behind this tab
    // (main_shell.dart's `sectionHue` + `AmbientBackground`). The page itself
    // is transparent now, so the harness must carry that field or the
    // baselines would record the bare window.
    home: AmbientBackground(
      accent: SectionHues.more,
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: MoreScreen(contentSources: sources)),
    ),
  );
}

Future<void> _open(WidgetTester tester,
    {required Size size,
    required bool live,
    double textScale = 1,
    List<MoreContentSource> sources = const []}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final strip = live ? _frozenClock() : null;
  if (strip != null) {
    addTearDown(strip.clock.dispose);
    addTearDown(strip.ticker.dispose);
  }
  await tester.pumpWidget(_wrap(_app(textScale: textScale, sources: sources),
      ticker: strip?.ticker, clock: strip?.clock));
  await tester.pumpAndSettle();
}

/// A section's own text, written by the test so the content block's pixels are
/// fixed rather than whatever the bundled guides happen to say.
class _GoldenSource extends MoreContentSource {
  _GoldenSource(super.itemId, this.owned);

  final List<ContentPiece> owned;

  @override
  Future<List<ContentPiece>> pieces(WidgetRef? ref) async => owned;
}

final _goldenSources = <MoreContentSource>[
  _GoldenSource('purification', const [
    ContentPiece('بطلان وضو', 'خواب عمیق و چرت زدن وضو را باطل می‌کند'),
    ContentPiece('آداب غسل', 'چرت پیش از غسل بی‌اعتبار است'),
  ]),
  _GoldenSource('fasting', const [
    ContentPiece('روزه', 'کسی که چرت بزند روزه‌اش صحیح است'),
  ]),
];

void main() {
  for (final kind in _kinds) {
    final name = kind.name;

    testWidgets('More full page golden — $name', (tester) async {
      AppTheme.applyTheme(kind: kind, phase: TimePhase.day);
      // Sized to the page's measured content height (the `golden_page_fit`
      // convention: extent + kToolbarHeight), so every group — including
      // «تنظیمات و بیشتر» — is inside the captured surface.
      await _open(tester, size: const Size(412, 2293), live: true);
      await expectLater(
          find.byType(MoreScreen), matchesGoldenFile('goldens/more_$name.png'));
    });

    testWidgets('More search golden — $name', (tester) async {
      AppTheme.applyTheme(kind: kind, phase: TimePhase.day);
      await _open(tester, size: const Size(412, 455), live: true);
      // A partial Persian word: matching groups keep their header + count.
      await tester.enterText(find.byType(TextField), 'نما');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MoreScreen),
          matchesGoldenFile('goldens/more_search_$name.png'));
    });

    testWidgets('More empty-search golden — $name', (tester) async {
      AppTheme.applyTheme(kind: kind, phase: TimePhase.day);
      await _open(tester, size: const Size(412, 292), live: true);
      await tester.enterText(find.byType(TextField), 'زززز');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MoreScreen),
          matchesGoldenFile('goldens/more_empty_$name.png'));
    });

    /// The deep layer alone: a word no tile carries, so only «در متن بخش‌ها»
    /// answers. The rows group under the section that owns each piece.
    testWidgets('More content-search golden — $name', (tester) async {
      AppTheme.applyTheme(kind: kind, phase: TimePhase.day);
      await _open(tester,
          size: const Size(412, 480), live: true, sources: _goldenSources);
      await tester.enterText(find.byType(TextField), 'چرت');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MoreScreen),
          matchesGoldenFile('goldens/more_content_$name.png'));
    });
  }

  /// Both layers at once: «وضو» is a tile's own word and a guide's prose, so
  /// the tiles keep their section header and the content block reads below.
  testWidgets('More tiles-plus-content golden — day', (tester) async {
    AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
    await _open(tester,
        size: const Size(412, 516), live: true, sources: _goldenSources);
    await tester.enterText(find.byType(TextField), 'وضو');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MoreScreen),
        matchesGoldenFile('goldens/more_content_day_both.png'));
  });

  // Width matrix: the tiles are size-derived from the screen, so 320 (where
  // the four-column grid sits on the 52dp floor) and 360 (57.4dp, the phone
  // the design was measured on) get their own pinned day-theme baselines.
  testWidgets('More full page golden — day, 320dp', (tester) async {
    AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
    await _open(tester, size: const Size(320, 2095), live: true);
    await expectLater(
        find.byType(MoreScreen), matchesGoldenFile('goldens/more_day_320.png'));
  });

  testWidgets('More full page golden — day, 360dp', (tester) async {
    AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
    await _open(tester, size: const Size(360, 2166), live: true);
    await expectLater(
        find.byType(MoreScreen), matchesGoldenFile('goldens/more_day_360.png'));
  });

  testWidgets('More full page golden — day, 360dp, text scale 1.3',
      (tester) async {
    AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
    await _open(tester,
        size: const Size(360, 2391), live: true, textScale: 1.3);
    await expectLater(find.byType(MoreScreen),
        matchesGoldenFile('goldens/more_day_360_scale13.png'));
  });
}
