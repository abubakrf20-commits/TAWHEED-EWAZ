import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/home/presentation/widgets/home_tokens.dart';
import 'package:tawheeed/features/home/presentation/widgets/period_hayz_banner.dart';
import 'package:tawheeed/features/home/presentation/widgets/prayer_times_card.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_tracker_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_provider.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/shared/models/day_time.dart';

class _MockPrayerTracker extends PrayerTracker {
  final Map<FardhPrayer, PrayerStatus> _statuses;
  _MockPrayerTracker([this._statuses = const {}]);

  @override
  Future<PrayerTrackerState> build() async =>
      PrayerTrackerState(fardStatuses: _statuses);

  @override
  PrayerStatus getStatus(FardhPrayer prayer) =>
      _statuses[prayer] ?? PrayerStatus.pending;
}

class _MockPeriod extends Period {
  final PeriodState data;
  _MockPeriod(this.data);

  @override
  Future<PeriodState> build() async => data;
}

class _MockSettings extends Settings {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

class _MockPrayerTimes extends PrayerTimes {
  final pi.PrayerTimes? _data;

  _MockPrayerTimes.data(this._data);

  @override
  Future<pi.PrayerTimes?> build() async => _data;
}

/// Counts `reload()` calls so the loading retry is proven to re-run the
/// provider instead of being decoration.
class _CountingPrayerTimes extends PrayerTimes {
  _CountingPrayerTimes(this._data);
  static int reloads = 0;
  final pi.PrayerTimes? _data;

  @override
  Future<pi.PrayerTimes?> build() async => _data;

  @override
  Future<void> reload({bool forceRefresh = false}) async {
    reloads++;
  }
}

/// #151: fails once, then succeeds — proves the retry button really re-runs
/// the provider instead of being decoration.
class _FlakyPrayerTimes extends PrayerTimes {
  static int calls = 0;

  @override
  Future<pi.PrayerTimes?> build() async {
    calls++;
    if (calls == 1) throw StateError('boom-reason');
    return _mockPrayerTimes(DateTime(2026, 10, 3, 9));
  }
}

pi.PrayerTimes _mockPrayerTimes(DateTime date) => pi.PrayerTimes(
      date: date,
      fajr: const pi.PrayerInfo(
          name: 'fajr', arabicName: 'فجر', time: DayTime(hour: 4, minute: 30)),
      shorouq: const pi.PrayerInfo(
          name: 'shorouq',
          arabicName: 'طلوع',
          time: DayTime(hour: 6, minute: 0)),
      duhr: const pi.PrayerInfo(
          name: 'duhr', arabicName: 'ظهر', time: DayTime(hour: 13, minute: 0)),
      asr: const pi.PrayerInfo(
          name: 'asr', arabicName: 'عصر', time: DayTime(hour: 16, minute: 30)),
      maghrib: const pi.PrayerInfo(
          name: 'maghrib',
          arabicName: 'مغرب',
          time: DayTime(hour: 19, minute: 30)),
      isha: const pi.PrayerInfo(
          name: 'isha', arabicName: 'عشاء', time: DayTime(hour: 21, minute: 0)),
    );

PeriodState _periodCovering(DateTime day) => PeriodState(records: [
      PeriodRecordTableData(
        id: 1,
        startDate: day.subtract(const Duration(days: 2)),
        periodLength: 7,
        createdAt: day.subtract(const Duration(days: 2)),
        recordType: 'hayz',
      ),
    ]);

Future<void> _pumpCard(
  WidgetTester tester, {
  required DateTime at,
  Map<FardhPrayer, PrayerStatus> statuses = const {},
  PeriodState? period,
  bool use12 = false,
  bool dark = false,
  ValueNotifier<String>? notice,
  PrayerTimes Function()? times,
}) async {
  ThemeData? theme;
  if (dark) {
    // Statics first, ThemeData getter second: AppTheme.dark reads the
    // palette statics applyTheme just set (argument order lesson from
    // settings_golden_test.dart).
    AppTheme.applyTheme(kind: ThemeKind.night, phase: TimePhase.night);
    addTearDown(() =>
        AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day));
    theme = AppTheme.dark;
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prayerTrackerProvider.overrideWith(() => _MockPrayerTracker(statuses)),
        settingsProvider.overrideWith(_MockSettings.new),
        prayerTimesProvider.overrideWith(
            times ?? () => _MockPrayerTimes.data(_mockPrayerTimes(at))),
        periodProvider
            .overrideWith(() => _MockPeriod(period ?? const PeriodState())),
        use12HourProvider.overrideWithValue(use12),
        if (notice != null)
          prayerLocationNoticeProvider.overrideWithValue(notice),
      ],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PrayerTimesCard(nowOverride: at),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('six single-line rows: names + times, no secondary text',
      (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 9));
    for (final name in [
      'اذان صبح',
      'طلوع آفتاب',
      'اذان ظهر',
      'اذان عصر',
      'اذان مغرب',
      'اذان عشاء'
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    for (final time in ['04:30', '06:00', '13:00', '16:30', '19:30', '21:00']) {
      expect(find.text(time), findsOneWidget, reason: time);
    }
    // Bug #9: the rows carry NO secondary line at all — no iqamah time,
    // no «تا پایان وقت», no window progress.
    expect(find.textContaining('اقامه'), findsNothing);
    expect(find.textContaining('تا پایان وقت'), findsNothing);
  });

  testWidgets('header: period chip in the sunrise→dhuhr stretch + n/5',
      (tester) async {
    // Bug #7: the stretch shows the period NAME, never a fake «اکنون».
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 9));
    expect(find.text('اشراق و صبح'), findsOneWidget);
    expect(find.text('اکنون'), findsNothing);
    // LTR-isolated digits — match by substring.
    expect(find.textContaining('0/5'), findsOneWidget);
  });

  testWidgets('dhuhr window: «اکنون» on dhuhr only', (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 13, 30));
    expect(find.text('اکنون'), findsOneWidget);
    expect(find.text('ظهر'), findsOneWidget);
  });

  testWidgets('every prayer row is a faint box; the open one is solid gold',
      (tester) async {
    // 2026-10-14 user request: «هر نماز در بوکسی کمرنگ که وقتی وقتش شد
    // پررنگ‌تر بشود». dhuhr's window (13:00→16:30) is open at 13:30.
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 13, 30));
    BoxDecoration decoOf(String id) =>
        tester.widget<Container>(find.byKey(ValueKey('prayer-row-$id')))
            .decoration! as BoxDecoration;

    // The open window keeps the solid-gold gradient box.
    final open = decoOf('dhuhr');
    expect(open.gradient, isNotNull, reason: 'the open window is پررنگ');
    expect(open.border, isNotNull);

    // Every other row wears the faint box: a flat fill, never a gradient.
    for (final id in ['fajr', 'sunrise', 'asr', 'maghrib', 'isha']) {
      final d = decoOf(id);
      expect(d.gradient, isNull, reason: id);
      expect(d.color, isNotNull, reason: id);
      expect(d.borderRadius, BorderRadius.circular(14), reason: id);
    }
  });

  testWidgets('open window under LIGHT paints the approved creams', (tester) async {
    // The pinned golden instant has no NOW row, so the gradient's light
    // hexes are pinned here, not by home_prayer_day.png.
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 13, 30));
    final deco = tester.widget<Container>(
            find.byKey(const ValueKey('prayer-row-dhuhr')))
        .decoration! as BoxDecoration;
    final gradient = deco.gradient! as LinearGradient;
    expect(gradient.colors[0], HomeColors.nowRowStart(false));
    expect(gradient.colors[1], HomeColors.nowRowEnd(false));
    expect(gradient.colors[0].toARGB32(), 0xFFFFF6DA);
    expect(gradient.colors[1].toARGB32(), 0xFFFFFBF0);
  });

  testWidgets('open window under DARK wears the gold wash, not the creams',
      (tester) async {
    // The 2026-10-17 report: the open prayer window «با رنگ کرمی رنگی
    // شده» in the dark theme. Dark paints the gold wash instead.
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 13, 30), dark: true);
    final deco = tester.widget<Container>(
            find.byKey(const ValueKey('prayer-row-dhuhr')))
        .decoration! as BoxDecoration;
    final gradient = deco.gradient! as LinearGradient;
    expect(gradient.colors[0], HomeColors.nowRowStart(true));
    expect(gradient.colors[1], HomeColors.nowRowEnd(true));
    expect(gradient.colors[0].toARGB32(), isNot(0xFFFFF6DA));

    // The time ink flips to the hero gold; the «اکنون» badge is present.
    final timeStyle = tester
        .widget<Text>(find.text('13:00'))
        .style!;
    expect(timeStyle.color, HomeColors.nowRowTime(true));
    expect(find.text('اکنون'), findsOneWidget);
  });

  testWidgets('sunrise is never «اکنون» even when highlighted', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerTrackerProvider.overrideWith(_MockPrayerTracker.new),
          settingsProvider.overrideWith(_MockSettings.new),
          prayerTimesProvider.overrideWith(() => _MockPrayerTimes.data(
              _mockPrayerTimes(DateTime(2026, 10, 3, 6, 30)))),
          periodProvider.overrideWith(() => _MockPeriod(const PeriodState())),
          use12HourProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrayerTimesCard(
                nowOverride: DateTime(2026, 10, 3, 6, 30),
                highlightKey: 'sunrise',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('اکنون'), findsNothing);
    // The notification-tap highlight still draws the open-window visual —
    // hard to assert a gradient in a widget test, so pin the row's presence.
    expect(find.text('طلوع آفتاب'), findsOneWidget);
  });

  testWidgets('row tap toggles the tracker (persistence path)', (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 13, 30));
    await tester.tap(find.text('اذان ظهر'));
    await tester.pump();
    // Done wins over the open window, so «اکنون» is gone after the tap —
    // anchor the container lookup on the header instead.
    final container = ProviderScope.containerOf(
      tester.element(find.text('اوقات شرعی')),
    );
    expect(
      container
          .read(prayerTrackerProvider)
          .value
          ?.fardStatuses[FardhPrayer.dhuhr],
      PrayerStatus.done,
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget,
        reason: 'the toggled dhuhr row keeps its green check');
    expect(find.byIcon(Icons.remove_rounded), findsOneWidget,
        reason: 'the closed unlogged fajr window wears the red dash, not a tick');
  });

  testWidgets('logged rows show the green check; qada counts too',
      (tester) async {
    await _pumpCard(
      tester,
      at: DateTime(2026, 10, 3, 20),
      statuses: {
        FardhPrayer.fajr: PrayerStatus.done,
        FardhPrayer.dhuhr: PrayerStatus.qada,
      },
    );
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2),
        reason: 'fajr done + dhuhr qada are logged with the green check');
    expect(find.byIcon(Icons.remove_rounded), findsOneWidget,
        reason: 'the closed unlogged asr window wears the red dash, not a tick');
    expect(find.textContaining('2/5'), findsOneWidget);
  });

  testWidgets('closed unlogged windows show the past-due mark, hayz none',
      (tester) async {
    // Windows close at the next adhan: fajr→06:00, dhuhr→16:30,
    // asr→19:30, maghrib→21:00 (still open at 20:00 — it is the «اکنون»
    // row), isha→midnight.
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 20));
    expect(
        find.byTooltip('از وقت گذشته — برای ثبت لمس کنید'), findsNWidgets(3));
    expect(find.byIcon(Icons.remove_rounded), findsNWidgets(3),
        reason: 'every closed unlogged window wears the red dash');
    expect(find.byIcon(Icons.check_rounded), findsNothing,
        reason: 'a missed prayer is never shown as a done-tick');
    expect(find.text('اکنون'), findsOneWidget);
  });

  testWidgets('a hayz day suppresses every past-due mark', (tester) async {
    await _pumpCard(
      tester,
      at: DateTime(2026, 10, 3, 20),
      period: _periodCovering(DateTime(2026, 10, 3)),
    );
    expect(find.byTooltip('از وقت گذشته — برای ثبت لمس کنید'), findsNothing);
    expect(find.byIcon(Icons.remove_rounded), findsNothing,
        reason: 'prayer is not obligatory on a period day, so no row is missed');
    // The note itself is no longer the card's business — Home renders it as its
    // own block under «دسترسی سریع» (2026-10-23 user request). What must stay
    // inside the card is only the suppression above.
    expect(find.byType(PeriodHayzBanner), findsNothing);
    expect(find.textContaining('«فوت» شمرده نمی‌شود'), findsNothing);
  });

  testWidgets('12-hour setting formats the row times', (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 13, 30), use12: true);
    // Dhuhr 13:00 → 1:00 ب.ظ.
    expect(find.text('1:00 ب.ظ'), findsOneWidget);
    expect(find.text('13:00'), findsNothing);
  });

  testWidgets('loading state renders the skeleton card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerTrackerProvider.overrideWith(_MockPrayerTracker.new),
          settingsProvider.overrideWith(_MockSettings.new),
          prayerTimesProvider.overrideWith(() => _MockPrayerTimes.data(null)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PrayerTimesCard()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('اوقات شرعی'), findsOneWidget);
    // The skeleton says what it is waiting for instead of being six bare
    // boxes; the retry only appears once the wait stops being normal.
    expect(find.text('در حال محاسبهٔ اوقات شرعی…'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsNothing);
    expect(find.text('اذان صبح'), findsNothing);
  });

  testWidgets('a slow load reveals the retry after 12 s and it reloads',
      (tester) async {
    _CountingPrayerTimes.reloads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerTrackerProvider.overrideWith(_MockPrayerTracker.new),
          settingsProvider.overrideWith(_MockSettings.new),
          prayerTimesProvider
              .overrideWith(() => _CountingPrayerTimes(null)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PrayerTimesCard()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('تلاش دوباره'), findsNothing);

    // Past the platform checks and both GPS attempts the wait is no longer
    // normal — the card offers the way out instead of pretending to finish.
    await tester.pump(const Duration(seconds: 12));
    expect(find.text('محاسبهٔ اوقات شرعی طول کشید.'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsOneWidget);

    await tester.tap(find.text('تلاش دوباره'));
    await tester.pump();
    expect(_CountingPrayerTimes.reloads, 1,
        reason: 'the retry must actually re-run the provider');
  });

  testWidgets('a location failure is surfaced with a retry that reloads',
      (tester) async {
    _CountingPrayerTimes.reloads = 0;
    final notice = ValueNotifier<String>('موقعیت در دسترس نیست');
    addTearDown(notice.dispose);
    await _pumpCard(
      tester,
      at: DateTime(2026, 10, 3, 9),
      notice: notice,
      times: () =>
          _CountingPrayerTimes(_mockPrayerTimes(DateTime(2026, 10, 3, 9))),
    );

    // The card still shows the fallback times, but says they are not fresh.
    expect(find.text('اذان صبح'), findsOneWidget);
    expect(
        find.text(
            'موقعیت مکانی به‌روز نشد؛ اوقات نمایش‌داده‌شده ممکن است دقیق نباشد.'),
        findsOneWidget);

    await tester.tap(find.text('تلاش دوباره'));
    await tester.pump();
    expect(_CountingPrayerTimes.reloads, 1);

    // The row disappears the moment the notice clears.
    notice.value = '';
    await tester.pump();
    expect(find.textContaining('موقعیت مکانی به‌روز نشد'), findsNothing);
  });

  testWidgets('error state: friendly message + a retry that reloads',
      (tester) async {
    _FlakyPrayerTimes.calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerTrackerProvider.overrideWith(_MockPrayerTracker.new),
          settingsProvider.overrideWith(_MockSettings.new),
          prayerTimesProvider.overrideWith(_FlakyPrayerTimes.new),
          periodProvider.overrideWith(() => _MockPeriod(const PeriodState())),
          use12HourProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PrayerTimesCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // #151: the raw exception never reaches the reader.
    expect(find.textContaining('boom-reason'), findsNothing);
    expect(find.text('اوقات شرعی در دسترس نیست'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsOneWidget);

    await tester.tap(find.text('تلاش دوباره'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_FlakyPrayerTimes.calls, greaterThanOrEqualTo(2));
    expect(find.text('اذان صبح'), findsOneWidget);
    expect(find.text('اوقات شرعی در دسترس نیست'), findsNothing);
  });
}
