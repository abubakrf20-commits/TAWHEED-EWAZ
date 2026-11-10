import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/adhkar/duas/data/hesn_db_service.dart';
import 'package:tawheeed/features/books/presentation/providers/reading_stats_provider.dart';
import 'package:tawheeed/features/home/presentation/widgets/reminders_card.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/features/khatm/presentation/providers/khatm_provider.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/shared/models/day_time.dart';
import 'package:tawheeed/shared/utils/date_key.dart';

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

class _MockKhatm extends Khatm {
  @override
  Future<KhatmModel?> build() async => null;
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

/// Reads the header's n/total count chip through its digit-slash shape,
/// stripping the LTR-isolate wrappers NumberFormat.ltrIsolated adds.
String _chipText(WidgetTester tester) => tester
    .widget<Text>(find.textContaining(RegExp(r'[0-9]/[0-9]')))
    .data!
    .replaceAll('\u2066', '')
    .replaceAll('\u2069', '');

Finder _circleFinders() => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('reminder_circle_'),
    );

Future<void> _pumpCard(
  WidgetTester tester, {
  required DateTime at,
  Map<String, int> readingStats = const {},
}) async {
  // The widget loads the daily dua from HesnDbService, which copies the
  // bundled asset into the documents directory via path_provider. Under the
  // widget-test binding a missing platform handler HANGS (instead of
  // throwing MissingPluginException like the plain-test binding), so point
  // path_provider at a real temp dir — the asset copy then succeeds and
  // init finishes normally (same recipe as quick_reminders_test.dart).
  final tmp = Directory.systemTemp.createTempSync('reminders_card_test');
  addTearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {
      // best-effort cleanup; the temp dir may already be gone
    }
  });
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => tmp.path,
  );
  // init() short-circuits once ready, so pre-warming the singleton outside
  // fake async leaves only synchronous sqlite work inside the widget.
  await tester.runAsync(() => HesnDbService().init());

  await tester.pumpWidget(
    // UniqueKey: a second pumpWidget in one test must remount the scope.
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        settingsProvider.overrideWith(_MockSettings.new),
        prayerTimesProvider
            .overrideWith(() => _MockPrayerTimes.data(_mockPrayerTimes())),
        hijriOffsetProvider.overrideWith((ref) => 0),
        readingStatsProvider.overrideWith((ref) async => readingStats),
        khatmProvider.overrideWith(_MockKhatm.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(child: RemindersCard(nowOverride: at)),
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

  testWidgets('always-present rows, header chip, no arrow', (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 9));
    expect(find.text('یادآوری‌های امروز'), findsOneWidget);
    expect(find.text('تلاوت قرآن'), findsOneWidget);
    expect(find.text('ختم قرآن'), findsOneWidget);
    expect(find.text('دعای روز'), findsOneWidget);
    expect(find.textContaining('0 از 1 صفحه'), findsOneWidget);
    // Bug #6: the circle is the only affordance — no navigation arrow.
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byKey(const ValueKey('reminder_circle_quran')), findsOneWidget);
    expect(_chipText(tester), startsWith('0/'));
  });

  testWidgets('duha shows in its window (sunrise+20min → dhuhr)',
      (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 9));
    expect(find.text('نماز ضحی'), findsOneWidget);
    expect(find.text('نماز 2 رکعتی در وسط روز مستحب است'), findsOneWidget);
  });

  testWidgets('no duha and no post-prayer adhkar after their windows',
      (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 14, 30));
    expect(find.text('نماز ضحی'), findsNothing);
    expect(find.text('اذکار بعد از نماز'), findsNothing);
  });

  testWidgets('qiyam at night', (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 21, 45));
    expect(find.text('قیام (نماز شب)'), findsOneWidget);
  });

  testWidgets('no qiyam by day', (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 12));
    expect(find.text('قیام (نماز شب)'), findsNothing);
  });

  testWidgets('Monday fast row', (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 5, 9)); // Monday
    expect(find.text('روزه امروز'), findsOneWidget);
    expect(find.text('روزه دوشنبه مستحب است'), findsOneWidget);
  });

  testWidgets('tomorrow-fast row on Sunday evening', (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 4, 20)); // Sunday
    expect(find.text('روزه فردا'), findsOneWidget);
    expect(find.text('فردا دوشنبه است — روزه مستحب است'), findsOneWidget);
  });

  testWidgets('post-prayer adhkar in the dhuhr iqamah slot', (tester) async {
    // dhuhr 13:00 + iqamah 25 + 10 = slot 13:35, window 13:30 → 14:05.
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 13, 45));
    expect(find.text('اذکار بعد از نماز'), findsOneWidget);
    expect(find.text('اذکار ماثور بعد از ظهر را بخوانید'), findsOneWidget);
  });

  testWidgets('circle toggle marks the row done and bumps the chip',
      (tester) async {
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 9));
    expect(_chipText(tester), startsWith('0/'));
    await tester.tap(find.byKey(const ValueKey('reminder_circle_quran')));
    await tester.pumpAndSettle();
    final title = tester.widget<Text>(find.text('تلاوت قرآن'));
    expect(title.style?.decoration, TextDecoration.lineThrough);
    expect(_chipText(tester), startsWith('1/'));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    // Untoggle restores the hollow circle and the pending state.
    await tester.tap(find.byKey(const ValueKey('reminder_circle_quran')));
    await tester.pumpAndSettle();
    expect(_chipText(tester), startsWith('0/'));
    final restored = tester.widget<Text>(find.text('تلاوت قرآن'));
    expect(restored.style?.decoration, isNull);
  });

  testWidgets('toggling every visible row shows the all-done footer',
      (tester) async {
    // 14:30 keeps the conditional set small: no duha (ends 13:00), no
    // post-prayer (window ends 14:05), no qiyam (starts 20:00).
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 14, 30));
    final circleKeys = tester
        .widgetList(_circleFinders())
        .map((w) => (w.key! as ValueKey<String>).value)
        .toList();
    expect(circleKeys, isNotEmpty);
    for (final k in circleKeys) {
      await tester.tap(find.byKey(ValueKey<String>(k)));
      await tester.pumpAndSettle();
    }
    expect(find.text('آفرین! همه\u200cی یادآوری‌های امروز انجام شد'),
        findsOneWidget);
    expect(find.byIcon(Icons.celebration), findsOneWidget);
    expect(_chipText(tester), startsWith('${circleKeys.length}/'));
  });

  testWidgets('quran progress folds into the subtitle', (tester) async {
    await _pumpCard(
      tester,
      at: DateTime(2026, 10, 3, 9),
      readingStats: {'2026-10-03': 2},
    );
    expect(find.textContaining('2 از 1 صفحه'), findsOneWidget);
  });

  testWidgets('saved done-ids restore as completed rows', (tester) async {
    // The widget's init reads the pref under the REAL current date (the
    // date-roll timer also keys on it), not nowOverride.
    SharedPreferences.setMockInitialValues({
      'flutter.home_reminders_${dateKeyOf(DateTime.now())}': ['quran'],
    });
    await _pumpCard(tester, at: DateTime(2026, 10, 3, 9));
    final title = tester.widget<Text>(find.text('تلاوت قرآن'));
    expect(title.style?.decoration, TextDecoration.lineThrough);
    expect(_chipText(tester), startsWith('1/'));
  });
}
