import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/services/clock_ticker.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/home/presentation/widgets/hero_card.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/shared/models/day_time.dart';

class _MockSettings extends Settings {
  final AppSettings settings;
  _MockSettings([this.settings = const AppSettings()]);

  @override
  Future<AppSettings> build() async => settings;
}

class _MockPrayerTimes extends PrayerTimes {
  final pi.PrayerTimes data;
  _MockPrayerTimes(this.data);

  @override
  Future<pi.PrayerTimes?> build() async => data;
}

class _NoPrayerTimes extends PrayerTimes {
  @override
  Future<pi.PrayerTimes?> build() async => null;
}

/// A read that has already failed, as opposed to one still running.
class _FailingPrayerTimes extends PrayerTimes {
  @override
  Future<pi.PrayerTimes?> build() async =>
      throw StateError('no location fix');
}

pi.PrayerTimes _mockPrayerTimes() {
  final now = DateTime.now();
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

Widget _host({
  AppSettings settings = const AppSettings(),
  ClockTicker? ticker,
  bool tickerModeEnabled = true,
  double? textScale,
  bool failPrayerTimes = false,
}) =>
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(() => _MockSettings(settings)),
        prayerTimesProvider.overrideWith(() => failPrayerTimes
            ? _FailingPrayerTimes()
            : _MockPrayerTimes(_mockPrayerTimes())),
        if (ticker != null) clockTickerProvider.overrideWithValue(ticker),
      ],
      child: MaterialApp(
        theme: ThemeData(
          extensions: <ThemeExtension<dynamic>>[],
        ),
        builder: textScale == null
            ? null
            : (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
        home: Scaffold(
          body: SingleChildScrollView(
            // The shell wraps every tab in TickerMode(enabled: isVisible);
            // this group reproduces exactly that for the hidden case.
            child: TickerMode(
              enabled: tickerModeEnabled,
              child: const HeroCard(),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('HeroCard renders clock, weekday and triple-calendar chips',
      (tester) async {
    // Default settings: 12-hour clock + iqamah offsets → «تا اقامه».
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(HeroCard), findsOneWidget);
    // Clock tiles render digits (padded hour/minute).
    expect(findTextRegExp(RegExp(r'^\d{1,2}$')), findsWidgets);
    // Weekday outline chip — one of the seven names.
    expect(
      findTextRegExp(
          RegExp('دوشنبه|سه‌شنبه|چهارشنبه|پنجشنبه|جمعه|شنبه|یکشنبه')),
      findsOneWidget,
    );
    // 12-hour meridiem mini tile (default settings) — one of the two.
    final q = find.text('ق.ظ').evaluate().isNotEmpty;
    final b = find.text('ب.ظ').evaluate().isNotEmpty;
    expect(q || b, isTrue);
  });

  testWidgets('a failed prayer-times read says so, not «در حال محاسبه»',
      (tester) async {
    // The hero and the prayer card read the same provider. When it failed,
    // the hero used to keep promising «در حال محاسبهٔ اوقات شرعی…» for as long
    // as the app stayed open, while the card 200dp below said «در دسترس
    // نیست» — one screen, two answers, and the wrong one on top.
    await tester.pumpWidget(_host(failPrayerTimes: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('اوقات شرعی محاسبه نشد'), findsOneWidget);
    expect(find.textContaining('در حال محاسبهٔ اوقات شرعی'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'countdown names the adhan even with iqamah offsets; iqamah is a pill',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Bug #8 contract: the arc number counts to the NEXT ADHAN named by the
    // label — never to iqamah — and iqamah shows as its own milestone pill.
    expect(find.textContaining('تا اذان'), findsOneWidget);
    expect(find.textContaining('تا اقامه'), findsNothing);
    expect(find.textContaining('اقامه'), findsOneWidget);
  });

  testWidgets('arc shows an analog dial instead of digit blocks',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // «تا اذان صبح» stays, but the stacked HH:MM digit blocks with their
    // unit captions are gone — a painted dial carries the hands instead,
    // so no unit words remain as text anywhere in the arc.
    expect(find.textContaining('تا اذان'), findsOneWidget);
    expect(find.textContaining('(ساعت:دقیقه)'), findsNothing);
    expect(find.textContaining('(دقیقه:ثانیه)'), findsNothing);
    expect(find.text('دقیقه'), findsNothing);
    expect(find.text('ساعت'), findsNothing);
    expect(find.text('ثانیه'), findsNothing);
  });

  testWidgets('the countdown lines ride the hero scale and keep their gap',
      (tester) async {
    // 2026-10-14: both lines joined the hero's group multiplier. 2026-11: the
    // same reader asked the hero back DOWN («باکس ساعت کوتاه‌تر و جمع‌وجورتر»),
    // so the group rides 1.08. 2026-11-07: the brief asked both lines bigger
    // and cleaner again — caption 14 → 16 at w600, value 26 → 30 at w700, gap
    // 4 → 5 — still riding the group multiplier.
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    const captionKey = ValueKey('hero-countdown-caption');
    const valueKey = ValueKey('hero-countdown-value');
    final context = tester.element(find.byKey(valueKey));

    expect(
      tester.widget<Text>(find.byKey(captionKey)).style?.fontSize,
      AppTheme.scaledFontSize(context, 16 * 1.08),
    );
    expect(
      tester.widget<Text>(find.byKey(valueKey)).style?.fontSize,
      AppTheme.scaledFontSize(context, 30 * 1.08),
    );

    final caption = tester.getRect(find.byKey(captionKey));
    final value = tester.getRect(find.byKey(valueKey));
    expect(value.top - caption.bottom, closeTo(5, 1));
  });

  testWidgets('HeroCard honors the 24-hour setting', (tester) async {
    await tester.pumpWidget(
      _host(settings: const AppSettings(use12Hour: false)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ق.ظ'), findsNothing);
    expect(find.text('ب.ظ'), findsNothing);
    // Padded 24-hour hour tile.
    expect(findTextRegExp(RegExp(r'^\d{2}$')), findsWidgets);
  });

  testWidgets('the arc shows a visible loading state instead of blank space',
      (tester) async {
    // The reported «قوس و باقی‌مانده کاملاً مخفی است» was a blank placeholder:
    // while the location pipeline runs the hero must say it is calculating,
    // in the arc's own footprint, so nothing jumps when the times land.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_MockSettings.new),
          prayerTimesProvider.overrideWith(_NoPrayerTimes.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: HeroCard()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('در حال محاسبهٔ اوقات شرعی…'), findsOneWidget);
    expect(find.byIcon(Icons.nights_stay_outlined), findsOneWidget);
  });

  testWidgets('HeroCard lite mode still renders all content', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_MockSettings.new),
          prayerTimesProvider
              .overrideWith(() => _MockPrayerTimes(_mockPrayerTimes())),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: HeroCard(lite: true)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HeroCard), findsOneWidget);
    expect(find.textContaining('اقامه'), findsOneWidget);
  });

  /// The hidden-tab battery contract (audit item 5) and, beside it, the
  /// accuracy promise that must never be traded for it: a tab that is not the
  /// selected one must cost nothing per second, and must still show the LIVE
  /// time the moment it is selected again — never the value it last rendered.
  ///
  /// Both directions are exercised. If someone later "simplifies"
  /// `_PerMinute`/`_SecondsRing` into always-on `ValueListenableBuilder`s, the
  /// listener assertion fails; if they cache the last rendered time instead of
  /// reading the notifier while inactive, the accuracy assertion fails.
  group('HeroCard while the home tab is NOT the selected tab', () {
  /// `ChangeNotifier.hasListeners` is protected, so it is only reachable from
  /// a subclass — and that is the honest way to observe "did anything in the
  /// hero subscribe to the ticker?" without timing tricks.
  bool secondIsListened(ClockTicker t) => _ListenerProbe.listens(t.second);
  bool minuteIsListened(ClockTicker t) => _ListenerProbe.listens(t.minute);

  ClockTicker frozenTickerAt(int hour, int minute, int second) {
    final ticker = ClockTicker.idle();
    final at = DateTime(2026, 10, 9, hour, minute, second);
    ticker.second.value = at;
    ticker.minute.value = at;
    addTearDown(ticker.dispose);
    return ticker;
  }

  testWidgets('subscribes to NO per-second layer while hidden', (tester) async {
    final ticker = frozenTickerAt(12, 0, 40);
    await tester.pumpWidget(_host(ticker: ticker, tickerModeEnabled: false));
    await tester.pump();

    // The shared ticker keeps firing app-wide (that is not what we assert);
    // what must be true is that nothing in this subtree listens to it.
    expect(secondIsListened(ticker), isFalse,
        reason: 'the seconds ring must not subscribe while the tab is hidden');
    expect(minuteIsListened(ticker), isFalse,
        reason: 'neither may the minute layer — the tab is not visible');
  });

  testWidgets('the visible tab DOES subscribe (the saving is real, not '
      'a deaf clock)', (tester) async {
    final ticker = frozenTickerAt(12, 0, 40);
    // Default tickerModeEnabled is true — the visible case.
    await tester.pumpWidget(_host(ticker: ticker));
    await tester.pump();
    expect(secondIsListened(ticker), isTrue,
        reason: 'the ring has to tick while the tab is visible');
  });

  testWidgets('shows the LIVE time when selected again — never the stale '
      'rendered one', (tester) async {
    final ticker = frozenTickerAt(12, 0, 40);
    await tester.pumpWidget(_host(ticker: ticker, tickerModeEnabled: false));
    await tester.pump();

    // While hidden the shared ticker keeps advancing (as the real one does).
    final later = DateTime(2026, 10, 9, 12, 3, 7);
    ticker.minute.value = later;
    ticker.second.value = later;
    await tester.pump();

    // Selecting the tab flips TickerMode; the very next frame must read the
    // notifier's CURRENT value — 12:03 — not the 12:00 it last rendered.
    await tester.pumpWidget(_host(ticker: ticker));
    await tester.pump();
    expect(find.text('03'), findsOneWidget,
        reason: 'the minute tile must show the live minute, not a stale 00');
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('a hidden tab already renders the live time on its first hidden '
      'frame', (tester) async {
    final ticker = frozenTickerAt(9, 5, 0);
    await tester.pumpWidget(_host(ticker: ticker, tickerModeEnabled: false));
    await tester.pump();
    // 12-hour default: 9:05 stays 9:05.
    expect(find.text('9'), findsOneWidget);
    expect(find.text('05'), findsOneWidget);
  });
  });

  group('the three calendar chips are one size', () {
    /// The user's report: «سایز بوکس تقویم‌ها یک سایز باشند — الان هجری کوتاه‌تر
    /// از بقیه است و زیبا نیست». Each chip therefore gets an equal `Expanded`
    /// cell and fills it; measuring the three rects is the only way to prove
    /// they are equal, because the strings themselves differ in length.
    Finder chip(String which) => find.byKey(ValueKey('date-chip-$which'));

    testWidgets('shamsi, hijri and gregorian boxes match', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final shamsi = tester.getRect(chip('shamsi'));
      final hijri = tester.getRect(chip('hijri'));
      final greg = tester.getRect(chip('gregorian'));
      expect(hijri.width, closeTo(shamsi.width, 0.5));
      expect(greg.width, closeTo(shamsi.width, 0.5));
      expect(hijri.height, closeTo(shamsi.height, 0.5));
      expect(greg.height, closeTo(shamsi.height, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('320dp x 1.3 keeps them equal and inside the page',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_host(textScale: 1.3));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final shamsi = tester.getRect(chip('shamsi'));
      final hijri = tester.getRect(chip('hijri'));
      final greg = tester.getRect(chip('gregorian'));
      expect(hijri.width, closeTo(shamsi.width, 0.5));
      expect(greg.width, closeTo(shamsi.width, 0.5));
      // The FittedBox in each cell scales the glyphs down instead of letting
      // the row outrun a narrow phone.
      expect(greg.right, lessThanOrEqualTo(320));
      expect(shamsi.left, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);
    });
  });
}

/// Finder helper — flutter_test has no built-in text-regex finder.
Finder findTextRegExp(RegExp pattern) => find.byWidgetPredicate(
      (w) => w is Text && pattern.hasMatch(w.data ?? ''),
    );

/// Probes whether anything listens to one of the ticker's notifiers.
///
/// `ChangeNotifier.hasListeners` is protected, and Dart only lets it be read
/// inside a subclass of the declaring class — so the probe IS that subclass.
/// Dart's protected model does not require the instance to be `this`, so a
/// static helper can read it on the ticker we were handed.
class _ListenerProbe extends ChangeNotifier {
  static bool listens(ValueNotifier<DateTime> notifier) =>
      notifier.hasListeners;
}
