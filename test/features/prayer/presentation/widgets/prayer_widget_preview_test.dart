import 'dart:async';

import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_tracker_provider.dart';
import 'package:tawheeed/features/prayer/presentation/widgets/prayer_widget_preview.dart';
import 'package:tawheeed/features/prayer/services/prayer_time_service.dart';

const _accent = Color(0xFFC9A94E);
const _missedDark = Color(0xFFFF8A80);

/// The staged service answers every getter itself; the repository is never
/// reached, so a throwing stub is enough.
class _UnusedRepo implements PrayerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('PrayerRepository is not used by _StagedTimes');
}

/// Times relative to the wall clock, chosen so every window's state is
/// deterministic at any hour:
///   fajr 6 h ago   → its window (ended at sunrise) is closed,
///   dhuhr 4 h ago  → closed at asr,
///   asr 10 min ago → OPEN, its iqamah (now + 15 min) still ahead,
///   maghrib/isha   → later today, open.
class _StagedTimes extends PrayerTimeService {
  final Map<String, DateTime> _at;

  _StagedTimes.relative(DateTime now)
      : _at = {
          'fajr': now.subtract(const Duration(hours: 6)),
          'sunrise': now.subtract(const Duration(hours: 5)),
          'dhuhr': now.subtract(const Duration(hours: 4)),
          'asr': now.subtract(const Duration(minutes: 10)),
          'maghrib': now.add(const Duration(hours: 2)),
          'isha': now.add(const Duration(hours: 3)),
        },
        super(_UnusedRepo());

  @override
  DateTime? get fajr => _at['fajr'];
  @override
  DateTime? get sunrise => _at['sunrise'];
  @override
  DateTime? get dhuhr => _at['dhuhr'];
  @override
  DateTime? get asr => _at['asr'];
  @override
  DateTime? get maghrib => _at['maghrib'];
  @override
  DateTime? get isha => _at['isha'];

  /// adhan's `PrayerTimes` only has its own factory constructors, so arbitrary
  /// times cannot be injected. Null makes the preview's «next» selection fall
  /// back to fajr (index 0) — the deterministic next box these tests pin.
  @override
  adhan.PrayerTimes? get prayerTimes => null;

  @override
  String get cityName => 'تهران';

  @override
  Map<String, String> get allTimes => const {
        'فجر': '04:30',
        'ظهر': '12:30',
        'عصر': '16:00',
        'مغرب': '19:00',
        'عشاء': '20:30',
      };
}

class _MockTracker extends PrayerTracker {
  final Map<FardhPrayer, PrayerStatus> _statuses;

  _MockTracker([this._statuses = const {}]);

  @override
  Future<PrayerTrackerState> build() async =>
      PrayerTrackerState(fardStatuses: _statuses);
}

class _MockPeriod extends Period {
  final PeriodState _state;

  _MockPeriod(this._state);

  @override
  Future<PeriodState> build() async => _state;
}

/// A period that never resolves: `periodKnown` stays false, which must never
/// make the preview paint a red missed mark.
class _PendingPeriod extends Period {
  @override
  Future<PeriodState> build() => Completer<PeriodState>().future;
}

Future<void> _pumpPreview(
  WidgetTester tester, {
  Map<FardhPrayer, PrayerStatus> statuses = const {},
  PeriodState period = const PeriodState(),
  bool periodPending = false,
  bool light = false,
  double width = 320,
  double height = 220,
}) async {
  final times = _StagedTimes.relative(DateTime.now());
  await tester.pumpWidget(ProviderScope(
    overrides: [
      prayerTrackerProvider.overrideWith(() => _MockTracker(statuses)),
      periodProvider.overrideWith(
          () => periodPending ? _PendingPeriod() : _MockPeriod(period)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            // The widget is only ever read in Persian, and the native layout's
            // root declares `layoutDirection="rtl"`, so the preview is pumped
            // that way too — the countdown row's caption/value order depends
            // on it.
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: PrayerWidgetPreview(
                timeService: times,
                light: light,
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rows show ✓ for a logged prayer and — for a closed unlogged one',
      (tester) async {
    await _pumpPreview(tester, statuses: {
      FardhPrayer.fajr: PrayerStatus.done,
      FardhPrayer.dhuhr: PrayerStatus.missed,
      // asr's window is still open, so its logged state is honoured as-is.
      FardhPrayer.asr: PrayerStatus.done,
    });

    // Gold belongs to the next prayer alone now, and next outranks logged: this
    // fixture resolves «next» to fajr (it stages no PrayerTimes), so fajr keeps
    // the accent even though it is marked done.
    final nextAndDone = tester.widget<Text>(find.text('صبح'));
    expect(nextAndDone.style?.color, _accent);
    // The done mark is a check ICON beside the name — exactly what the native
    // card draws (`bindCapsule`) — not a ✓ glued onto the label. fajr and asr
    // are both logged.
    expect(find.byIcon(Icons.check), findsNWidgets(2));
    // A logged prayer that is NOT next has to give the accent up and dim.
    final done = tester.widget<Text>(find.text('عصر'));
    expect(done.style?.color, Colors.white.withValues(alpha: 0.50));
    final missed = tester.widget<Text>(find.text('— ظهر'));
    expect(missed.style?.color, _missedDark);
    // maghrib is still ahead: no mark, and the strongest body ink — one step
    // under full strength, so the next prayer still leads the row.
    final open = tester.widget<Text>(find.text('مغرب'));
    expect(open.style?.color, Colors.white.withValues(alpha: 0.70));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exactly one next-prayer box, filled and outlined in the accent',
      (tester) async {
    await _pumpPreview(tester);

    final nextBoxes = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration! as BoxDecoration).color ==
                _accent.withValues(alpha: 0.30))
        .toList();
    expect(nextBoxes, hasLength(1));
    final decoration = nextBoxes.single.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.top.color, _accent.withValues(alpha: 0.55));
    expect(border.top.width, 1);
  });

  testWidgets('a light palette gets the softer accent fill', (tester) async {
    await _pumpPreview(tester, light: true);

    bool paints(Color color) =>
        tester.widgetList<Container>(find.byType(Container)).any((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration! as BoxDecoration).color == color);
    expect(paints(_accent.withValues(alpha: 0.20)), isTrue);
    expect(paints(_accent.withValues(alpha: 0.30)), isFalse);
  });

  testWidgets('the countdown is ONE line — caption then value, both accent',
      (tester) async {
    await _pumpPreview(tester);

    final caption = find.text('تا اقامه نماز عصر');
    final value = find.textContaining('دقیقه');
    expect(caption, findsOneWidget);
    expect(value, findsOneWidget);

    final captionText = tester.widget<Text>(caption);
    final valueText = tester.widget<Text>(value);
    // The caption frames the number rather than shouting alongside it: same
    // accent hue, one step down, and no bold.
    expect(captionText.style?.color, _accent.withValues(alpha: 0.85));
    expect(captionText.style?.fontWeight, isNot(FontWeight.w700));
    expect(valueText.style?.color, _accent);
    expect(captionText.style!.fontSize!, lessThan(valueText.style!.fontSize!));

    final captionRect = tester.getRect(caption);
    final valueRect = tester.getRect(value);
    // One line: the boxes share a centre band, so neither sits above the other.
    expect(captionRect.bottom, greaterThan(valueRect.top));
    expect(captionRect.center.dy, closeTo(valueRect.center.dy, 2));
    // The page reads RTL, so the caption owns the rightmost slot and the
    // remaining time follows to its left — mirroring the native row.
    expect(captionRect.center.dx, greaterThan(valueRect.center.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no clock or row time carries a ق.ظ/ب.ظ marker', (tester) async {
    await _pumpPreview(tester);

    // The five boxes sit side by side, and the marker costs about half of one;
    // the prayer names above each time already carry the period. The native
    // render agrees (`convertTo12h` and the `h:mm` clock).
    expect(find.text('4:30'), findsOneWidget);
    expect(find.text('12:30'), findsOneWidget);
    expect(find.text('4:00'), findsOneWidget);
    expect(find.textContaining(RegExp('[قب]\\.ظ')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a taller cell grows the clock and the prayer rows',
      (tester) async {
    double biggestClock() {
      var size = 0.0;
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final fontSize = text.style?.fontSize ?? 0;
        if (fontSize > size) size = fontSize;
      }
      return size;
    }

    await _pumpPreview(tester, height: 150);
    final shortClock = biggestClock();
    final shortTime = tester.widget<Text>(find.text('4:30')).style!.fontSize!;

    await _pumpPreview(tester);
    final tallClock = biggestClock();
    final tallTime = tester.widget<Text>(find.text('4:30')).style!.fontSize!;

    expect(tallClock, greaterThan(shortClock));
    expect(tallTime, greaterThan(shortTime));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Gregorian reading waits for a ≥300 dp placement',
      (tester) async {
    final now = DateTime.now();
    final greg =
        '${now.day} ${DateConstants.gregorianMonths[now.month - 1]} ${now.year}';

    await _pumpPreview(tester);
    expect(find.text(greg), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpPreview(tester, width: 280, height: 340);
    expect(find.text(greg), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hayz day suppresses missed marks but keeps the done one',
      (tester) async {
    final now = DateTime.now();
    await _pumpPreview(
      tester,
      statuses: {
        FardhPrayer.fajr: PrayerStatus.done,
        FardhPrayer.dhuhr: PrayerStatus.missed,
      },
      period: PeriodState(records: [
        PeriodRecordTableData(
          id: 1,
          startDate: now.subtract(const Duration(days: 2)),
          periodLength: 7,
          createdAt: now.subtract(const Duration(days: 2)),
          recordType: 'hayz',
        ),
      ]),
    );

    expect(find.text('— ظهر'), findsNothing);
    expect(find.text('ظهر'), findsOneWidget);
    expect(find.text('صبح'), findsOneWidget);
    // The logged prayer keeps its check even while the period suppresses the
    // missed marks on the others.
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('an unknown period never paints a missed mark', (tester) async {
    await _pumpPreview(
      tester,
      statuses: {FardhPrayer.dhuhr: PrayerStatus.missed},
      periodPending: true,
    );

    expect(find.text('— ظهر'), findsNothing);
    expect(find.text('ظهر'), findsOneWidget);
  });
}
