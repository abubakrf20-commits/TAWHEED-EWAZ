import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/home/presentation/widgets/dashed_border_painter.dart';
import 'package:tawheeed/features/home/presentation/widgets/home_tokens.dart';
import 'package:tawheeed/features/home/presentation/widgets/rawatib_card.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/prayer/domain/rawatib_model.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_tracker_provider.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/shared/models/day_time.dart';

class _MockPrayerTracker extends PrayerTracker {
  final Map<SunnahPrayer, bool> _sunnah;
  final bool _duha;
  _MockPrayerTracker({
    Map<SunnahPrayer, bool> sunnah = const {},
    bool duha = false,
  })  : _sunnah = sunnah,
        _duha = duha;

  @override
  Future<PrayerTrackerState> build() async => PrayerTrackerState(
        sunnahStatuses: _sunnah,
        duhaStatus: _duha,
      );
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

/// Reads a box's derived state through its stable key.
RawatibState _boxState(WidgetTester tester, SunnahPrayer id) =>
    (tester.widget(find.byKey(ValueKey('rawatib_${id.name}'))) as dynamic).state
        as RawatibState;

Future<void> _pumpCard(
  WidgetTester tester, {
  required DateTime at,
  Map<SunnahPrayer, bool> sunnah = const {},
  bool duha = false,
  bool dark = false,
}) async {
  ThemeData? theme;
  if (dark) {
    // Statics first, ThemeData getter second (the settings_golden order
    // lesson): AppTheme.dark reads what applyTheme just set.
    AppTheme.applyTheme(kind: ThemeKind.night, phase: TimePhase.night);
    addTearDown(() =>
        AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day));
    theme = AppTheme.dark;
  }
  await tester.pumpWidget(
    // UniqueKey: a second pumpWidget in one test must remount the scope —
    // updating ProviderScope in place keeps the old container (and the old
    // mock) alive.
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        prayerTrackerProvider
            .overrideWith(() => _MockPrayerTracker(sunnah: sunnah, duha: duha)),
        settingsProvider.overrideWith(_MockSettings.new),
        prayerTimesProvider
            .overrideWith(() => _MockPrayerTimes.data(_mockPrayerTimes())),
      ],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: RawatibCard(nowOverride: at),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('three lines of two rawatibs each, chronological (RTL)',
      (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 13, 30));
    final details = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .where((s) => s.contains('رکعت'))
        .toList();
    // Row-major tree order: in RTL the RIGHT cell of each line comes first, so
    // the flat list alternates right, left, right… rather than reading the day
    // in one sweep.
    expect(details, [
      '2 رکعت · قبل', // راتب فجر — line 1, right
      '2 رکعت · بعد', // راتب مغرب — line 1, left
      '4 رکعت · قبل', // راتب ظهر قبل — line 2, right
      '2 رکعت · بعد', // راتب عشاء — line 2, left
      '2 رکعت · بعد', // راتب ظهر بعد — line 3, right
      '3 رکعت · بعد از عشاء', // وتر — line 3, left
    ]);

    Offset box(SunnahPrayer id) =>
        tester.getCenter(find.byKey(ValueKey('rawatib_${id.name}')));

    final fajr = box(SunnahPrayer.fajrRawatib);
    final dhuhrBefore = box(SunnahPrayer.dhuhrRawatibBefore);
    final dhuhrAfter = box(SunnahPrayer.dhuhrRawatibAfter);
    final maghrib = box(SunnahPrayer.maghribRawatib);
    final isha = box(SunnahPrayer.ishaRawatib);
    final witr = box(SunnahPrayer.witr);

    // The RIGHT column of each line is the greater dx (RTL) and reads the day
    // top to bottom — راتب فجر، ظهر قبل، ظهر بعد.
    expect(fajr.dx, greaterThan(maghrib.dx));
    expect(dhuhrBefore.dx, greaterThan(isha.dx));
    expect(dhuhrAfter.dx, greaterThan(witr.dx));
    expect(fajr.dy, lessThan(dhuhrBefore.dy));
    expect(dhuhrBefore.dy, lessThan(dhuhrAfter.dy));
    // …and the LEFT column runs the evening, also top to bottom.
    expect(maghrib.dy, lessThan(isha.dy));
    expect(isha.dy, lessThan(witr.dy));
  });

  testWidgets('the open window suggests its rawatib, header names it',
      (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 13, 30));
    expect(find.text('پیشنهاد این وقت: راتبه ظهر'), findsOneWidget);
    expect(_boxState(tester, SunnahPrayer.dhuhrRawatibBefore),
        RawatibState.suggested);
    expect(_boxState(tester, SunnahPrayer.dhuhrRawatibAfter),
        RawatibState.suggested);
    // The fajr window is long closed; its rawatib is not suggested.
    expect(_boxState(tester, SunnahPrayer.fajrRawatib), RawatibState.past);
  });

  testWidgets('tapping a box toggles the tracker', (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 13, 30));
    await tester.tap(find.text('راتبه فجر'));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.text('رواتب (سنن مؤکده)')),
    );
    expect(
      container
          .read(prayerTrackerProvider)
          .value
          ?.sunnahStatuses[SunnahPrayer.fajrRawatib],
      isTrue,
    );
  });

  testWidgets('ended windows show past unchecked boxes with the dashed style',
      (tester) async {
    // 20:00 → fajr + both dhuhr rawatibs ended unchecked; maghrib is open.
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 20));
    expect(_boxState(tester, SunnahPrayer.fajrRawatib), RawatibState.past);
    expect(
        _boxState(tester, SunnahPrayer.dhuhrRawatibBefore), RawatibState.past);
    expect(
        _boxState(tester, SunnahPrayer.dhuhrRawatibAfter), RawatibState.past);
    expect(
        _boxState(tester, SunnahPrayer.maghribRawatib), RawatibState.suggested);
    expect(_boxState(tester, SunnahPrayer.ishaRawatib), RawatibState.upcoming);
    // The past box wears the dashed border painter (it wraps the box's
    // inner Container — a descendant of the keyed widget).
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('rawatib_fajrRawatib')),
        matching: find.byWidgetPredicate((w) =>
            w is CustomPaint && w.foregroundPainter is DashedRRectPainter),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the past dashed border under DARK is the faint white',
      (tester) async {
    // The 2026-10-17 dark-theme report: the tan dashed hairline vanished
    // on the dark card; dark wears the faint-box white instead.
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 20), dark: true);
    final painter = tester
        .widget<CustomPaint>(find.descendant(
      of: find.byKey(const ValueKey('rawatib_fajrRawatib')),
      matching: find.byWidgetPredicate((w) =>
          w is CustomPaint && w.foregroundPainter is DashedRRectPainter),
    ))
        .foregroundPainter! as DashedRRectPainter;
    expect(painter.color, HomeColors.faintBorder(true, alpha: 0.85));
  });

  testWidgets('a logged rawatib is done — never past, never dashed',
      (tester) async {
    await _pumpCard(
      tester,
      at: DateTime(2026, 10, 3, 20),
      sunnah: {SunnahPrayer.fajrRawatib: true},
    );
    expect(_boxState(tester, SunnahPrayer.fajrRawatib), RawatibState.done);
    expect(
        _boxState(tester, SunnahPrayer.dhuhrRawatibBefore), RawatibState.past);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('rawatib_fajrRawatib')),
        matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.foregroundPainter != null),
      ),
      findsNothing,
    );
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('n/6 counts only the six boxes; the old footer is gone',
      (tester) async {
    await _pumpCard(
      tester,
      at: DateTime(2026, 10, 3, 13, 30),
      sunnah: {SunnahPrayer.fajrRawatib: true},
      // Duha lives on the prayer card now — it must NOT reach the counter.
      duha: true,
    );
    expect(find.textContaining('1/6'), findsOneWidget);
    expect(find.textContaining('/7'), findsNothing);
    expect(find.textContaining('مورد دیگر'), findsNothing);
  });
}
