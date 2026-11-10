import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/services/clock_ticker.dart';
import 'package:tawheeed/features/adhkar/adhkar.dart';
import 'package:tawheeed/features/adhkar/duas/data/hesn_db_service.dart';
import 'package:tawheeed/features/books/presentation/providers/reading_stats_provider.dart';
import 'package:tawheeed/features/home/presentation/widgets/actions_timeline_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/prayer_times_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/rawatib_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/reminders_card.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/features/khatm/presentation/providers/khatm_provider.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/prayer/domain/rawatib_model.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_tracker_provider.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/shared/models/day_time.dart';

/// Home's minute tick must repaint only what the minute actually changed.
///
/// The four cards read the shared minute ticker through [QuantizedRebuild]:
/// a tick that does not cross a derivation boundary must leave the card's
/// widgets untouched (identity-preserved), and a tick that crosses one must
/// repaint exactly the surfaces the derivation feeds.
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

class _MockPeriod extends Period {
  final PeriodState _data;
  _MockPeriod(this._data);

  @override
  Future<PeriodState> build() async => _data;
}

class _MockAzkar extends Azkar {
  @override
  Future<List<ZikrItem>> build() async => [];
}

class _MockKhatm extends Khatm {
  @override
  Future<KhatmModel?> build() async => null;
}

class _MockTracker extends PrayerTracker {
  final Map<FardhPrayer, PrayerStatus> _fardh;
  final Map<SunnahPrayer, bool> _sunnah;
  _MockTracker({
    Map<FardhPrayer, PrayerStatus> fardh = const {},
    Map<SunnahPrayer, bool> sunnah = const {},
  })  : _fardh = fardh,
        _sunnah = sunnah;

  @override
  Future<PrayerTrackerState> build() async => PrayerTrackerState(
        fardStatuses: _fardh,
        sunnahStatuses: _sunnah,
      );

  @override
  PrayerStatus getStatus(FardhPrayer prayer) =>
      _fardh[prayer] ?? PrayerStatus.pending;
}

pi.PrayerTimes _mockPrayerTimes() {
  final now = DateTime(2026, 10, 3);
  return pi.PrayerTimes(
    date: now,
    fajr: const pi.PrayerInfo(
        name: 'fajr', arabicName: 'فجر', time: DayTime(hour: 4, minute: 30)),
    shorouq: const pi.PrayerInfo(
        name: 'shorouq', arabicName: 'طلوع', time: DayTime(hour: 6, minute: 0)),
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
}

ClockTicker _tickerAt(DateTime at) {
  final ticker = ClockTicker.idle();
  ticker.second.value = at;
  ticker.minute.value = at;
  addTearDown(ticker.dispose);
  return ticker;
}

Future<void> _tick(WidgetTester tester, ClockTicker ticker, DateTime t) async {
  ticker.second.value = t;
  ticker.minute.value = t;
  await tester.pump();
}

// -- prayer times card -------------------------------------------------------

Future<void> _pumpPrayerCard(
  WidgetTester tester,
  ClockTicker ticker, {
  DateTime? pinned,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockTickerProvider.overrideWithValue(ticker),
        prayerTrackerProvider.overrideWith(_MockTracker.new),
        settingsProvider.overrideWith(_MockSettings.new),
        prayerTimesProvider
            .overrideWith(() => _MockPrayerTimes.data(_mockPrayerTimes())),
        periodProvider.overrideWith(() => _MockPeriod(const PeriodState())),
        use12HourProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PrayerTimesCard(nowOverride: pinned),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

// -- rawatib card ------------------------------------------------------------

Future<void> _pumpRawatibCard(
  WidgetTester tester,
  ClockTicker ticker,
) async {
  await tester.pumpWidget(
    // UniqueKey: a second pumpWidget in one test must remount the scope.
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        clockTickerProvider.overrideWithValue(ticker),
        prayerTrackerProvider.overrideWith(_MockTracker.new),
        settingsProvider.overrideWith(_MockSettings.new),
        prayerTimesProvider
            .overrideWith(() => _MockPrayerTimes.data(_mockPrayerTimes())),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: RawatibCard(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

// -- actions timeline card ---------------------------------------------------

Future<void> _pumpTimelineCard(
  WidgetTester tester,
  ClockTicker ticker,
) async {
  // A 2400-wide surface keeps all ten horizontal nodes built (10 * 84 px of
  // node extent fits the viewport), so the identity probes never race a lazy
  // ListView disposal, and both auto-centerings clamp to offset 0.
  await tester.binding.setSurfaceSize(const Size(2400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        clockTickerProvider.overrideWithValue(ticker),
        settingsProvider.overrideWith(_MockSettings.new),
        prayerTimesProvider
            .overrideWith(() => _MockPrayerTimes.data(_mockPrayerTimes())),
        use12HourProvider.overrideWithValue(false),
        azkarProvider.overrideWith(_MockAzkar.new),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: ActionsTimelineCard(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

// -- reminders card ----------------------------------------------------------

Directory _tempDir() {
  final dir = Directory.systemTemp.createTempSync('minute_scope_test');
  addTearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });
  return dir;
}

Future<void> _pumpRemindersCard(
  WidgetTester tester,
  ClockTicker ticker,
) async {
  final tmp = _tempDir();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => tmp.path,
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'), null));
  await tester.runAsync(() => HesnDbService().init());

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        clockTickerProvider.overrideWithValue(ticker),
        settingsProvider.overrideWith(_MockSettings.new),
        prayerTimesProvider
            .overrideWith(() => _MockPrayerTimes.data(_mockPrayerTimes())),
        hijriOffsetProvider.overrideWith((ref) => 0),
        readingStatsProvider.overrideWith((ref) async => const <String, int>{}),
        khatmProvider.overrideWith(_MockKhatm.new),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: RemindersCard(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('prayer times card minute scope', () {
    testWidgets('a quiet minute repaints nothing', (WidgetTester tester) async {
      final ticker = _tickerAt(DateTime(2026, 10, 3, 13, 30));
      await _pumpPrayerCard(tester, ticker);
      final before =
          tester.widget(find.byKey(const ValueKey('prayer-row-dhuhr')));
      expect(find.text('اکنون'), findsOneWidget);

      await _tick(tester, ticker, DateTime(2026, 10, 3, 13, 31));

      final after =
          tester.widget(find.byKey(const ValueKey('prayer-row-dhuhr')));
      expect(identical(before, after), isTrue,
          reason: '13:30 -> 13:31 crosses no row boundary; the dhuhr row '
              'must not repaint');
      expect(find.text('اکنون'), findsOneWidget);
    });

    testWidgets('a row boundary repaints the rows',
        (WidgetTester tester) async {
      final ticker = _tickerAt(DateTime(2026, 10, 3, 13, 30));
      await _pumpPrayerCard(tester, ticker);
      final before =
          tester.widget(find.byKey(const ValueKey('prayer-row-dhuhr')));

      await _tick(tester, ticker, DateTime(2026, 10, 3, 16, 40));

      final after =
          tester.widget(find.byKey(const ValueKey('prayer-row-dhuhr')));
      expect(identical(before, after), isFalse,
          reason: 'the dhuhr row must repaint when its window closes and '
              'asr opens');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('prayer-row-asr')),
          matching: find.text('اکنون'),
        ),
        findsOneWidget,
      );
      expect(find.text('اکنون'), findsOneWidget);
    });

    testWidgets('a pinned now never repaints on ticker ticks',
        (WidgetTester tester) async {
      final ticker = _tickerAt(DateTime(2026, 10, 3, 13, 30));
      final pinned = DateTime(2026, 10, 3, 13, 30);
      await _pumpPrayerCard(tester, ticker, pinned: pinned);
      final before =
          tester.widget(find.byKey(const ValueKey('prayer-row-dhuhr')));

      await _tick(tester, ticker, DateTime(2026, 10, 3, 13, 31));

      final after =
          tester.widget(find.byKey(const ValueKey('prayer-row-dhuhr')));
      expect(identical(before, after), isTrue,
          reason: 'keyOf uses nowOverride; the pinned card must not repaint '
              'when the ticker moves');
      expect(find.text('اکنون'), findsOneWidget);
    });
  });

  group('rawatib card minute scope', () {
    testWidgets('a quiet minute repaints nothing', (WidgetTester tester) async {
      final ticker = _tickerAt(DateTime(2026, 10, 3, 13, 30));
      await _pumpRawatibCard(tester, ticker);
      final before =
          tester.widget(find.byKey(const ValueKey('rawatib_fajrRawatib')));

      await _tick(tester, ticker, DateTime(2026, 10, 3, 13, 31));

      final after =
          tester.widget(find.byKey(const ValueKey('rawatib_fajrRawatib')));
      expect(identical(before, after), isTrue,
          reason: '13:30 -> 13:31 crosses no sunnah span boundary');
    });

    testWidgets('a span boundary repaints the boxes',
        (WidgetTester tester) async {
      final ticker = _tickerAt(DateTime(2026, 10, 3, 13, 30));
      await _pumpRawatibCard(tester, ticker);
      final before =
          tester.widget(find.byKey(const ValueKey('rawatib_maghribRawatib')));
      expect(
          ((before as dynamic).state as RawatibState), RawatibState.upcoming);

      await _tick(tester, ticker, DateTime(2026, 10, 3, 20));

      final after =
          tester.widget(find.byKey(const ValueKey('rawatib_maghribRawatib')));
      expect(identical(before, after), isFalse,
          reason: 'maghrib rawatib goes upcoming -> suggested at its window');
      expect(
          ((after as dynamic).state as RawatibState), RawatibState.suggested);
      expect(find.textContaining('پیشنهاد این وقت'), findsOneWidget);
    });
  });

  group('actions timeline card minute scope', () {
    testWidgets('a quiet minute repaints nothing', (WidgetTester tester) async {
      final ticker = _tickerAt(DateTime(2026, 10, 3, 14, 30));
      await _pumpTimelineCard(tester, ticker);
      final before =
          tester.widget(find.byKey(const ValueKey('timeline_node_3')));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('timeline_node_3')),
          matching: find.text('اکنون'),
        ),
        findsOneWidget,
      );

      await _tick(tester, ticker, DateTime(2026, 10, 3, 14, 31));

      final after =
          tester.widget(find.byKey(const ValueKey('timeline_node_3')));
      expect(identical(before, after), isTrue,
          reason: '14:30 -> 14:31 keeps current = 3 and postPrayerNow; the '
              'node must not repaint');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('timeline_node_3')),
          matching: find.text('اکنون'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a step change repaints the nodes',
        (WidgetTester tester) async {
      final ticker = _tickerAt(DateTime(2026, 10, 3, 14, 30));
      await _pumpTimelineCard(tester, ticker);
      final before =
          tester.widget(find.byKey(const ValueKey('timeline_node_3')));

      await _tick(tester, ticker, DateTime(2026, 10, 3, 20));
      // The flip re-centers the rail in a post-frame callback, then the
      // ListView relays out; two pumps settle both.
      await tester.pump();
      await tester.pump();

      final after =
          tester.widget(find.byKey(const ValueKey('timeline_node_3')));
      expect(identical(before, after), isFalse,
          reason: 'the current step moved 3 -> 5; the nodes must repaint');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('timeline_node_5')),
          matching: find.text('اکنون'),
        ),
        findsOneWidget,
      );
      expect(find.text('اکنون'), findsOneWidget,
          reason: 'the «اکنون» pill is showTag-gated; the ride-along node 9 '
              'never shows it');
    });
  });

  group('reminders card minute scope', () {
    testWidgets('a quiet minute repaints nothing', (WidgetTester tester) async {
      final ticker = _tickerAt(DateTime(2026, 10, 3, 14, 30));
      await _pumpRemindersCard(tester, ticker);
      final before =
          tester.widget(find.byKey(const ValueKey('reminder_circle_quran')));

      await _tick(tester, ticker, DateTime(2026, 10, 3, 14, 31));

      final after =
          tester.widget(find.byKey(const ValueKey('reminder_circle_quran')));
      expect(identical(before, after), isTrue,
          reason: '14:30 -> 14:31 keeps the same visible reminder set');
    });

    testWidgets('an entering reminder repaints the card',
        (WidgetTester tester) async {
      final ticker = _tickerAt(DateTime(2026, 10, 3, 14, 30));
      await _pumpRemindersCard(tester, ticker);
      expect(find.text('قیام (نماز شب)'), findsNothing);
      final before =
          tester.widget(find.byKey(const ValueKey('reminder_circle_quran')));

      await _tick(tester, ticker, DateTime(2026, 10, 3, 20));

      final after =
          tester.widget(find.byKey(const ValueKey('reminder_circle_quran')));
      expect(identical(before, after), isFalse,
          reason: 'the qiyam reminder enters the visible set at 20:00');
      expect(find.text('قیام (نماز شب)'), findsOneWidget);
    });
  });
}
