import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/adhkar/presentation/providers/azkar_provider.dart';
import 'package:tawheeed/features/adhkar/data/azkar_data.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_stats_provider.dart';
import 'package:tawheeed/features/home/presentation/widgets/daily_summary_card.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_tracker_provider.dart';

class _MockPrayerTracker extends PrayerTracker {
  final Map<FardhPrayer, PrayerStatus> _fard;
  final Map<SunnahPrayer, bool> _sunnah;
  final bool _duha;
  _MockPrayerTracker({
    Map<FardhPrayer, PrayerStatus> fard = const {},
    Map<SunnahPrayer, bool> sunnah = const {},
    bool duha = false,
  })  : _fard = fard,
        _sunnah = sunnah,
        _duha = duha;

  @override
  Future<PrayerTrackerState> build() async => PrayerTrackerState(
        fardStatuses: _fard,
        sunnahStatuses: _sunnah,
        duhaStatus: _duha,
      );
}

class _MockAzkar extends Azkar {
  @override
  Future<List<ZikrItem>> build() async => [];
}

/// Resolves after the first frame, exactly like the real provider meeting a
/// cold [AzkarData] parse. The card asks for stats while this is pending.
class _SlowAzkar extends Azkar {
  final List<ZikrItem> items;
  _SlowAzkar(this.items);

  @override
  Future<List<ZikrItem>> build() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    AzkarData.setTestData(items);
    return items;
  }
}

const _sampleAzkar = [
  ZikrItem(
    id: 'z1',
    title: 'تسبیح',
    arabicText: 'سُبْحَانَ اللَّهِ',
    translation: 'Glory be to Allah',
    source: 'quran',
    period: PrayerPeriod.morningAzkar,
    count: 0,
    repeatCount: 33,
  ),
  ZikrItem(
    id: 'z2',
    title: 'حمد',
    arabicText: 'الْحَمْدُ لِلَّهِ',
    translation: 'Praise be to Allah',
    source: 'quran',
    period: PrayerPeriod.morningAzkar,
    count: 0,
    repeatCount: 33,
  ),
  ZikrItem(
    id: 'z3',
    title: 'تکبیر',
    arabicText: 'اللَّهُ أَكْبَرُ',
    translation: 'Allah is the Greatest',
    source: 'quran',
    period: PrayerPeriod.eveningAzkar,
    count: 0,
    repeatCount: 34,
  ),
];

Future<void> _pumpCard(
  WidgetTester tester, {
  Map<FardhPrayer, PrayerStatus> fard = const {},
  Map<SunnahPrayer, bool> sunnah = const {},
  bool duha = false,
  TasbihStatsData tasbih = TasbihStatsData.empty,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        prayerTrackerProvider.overrideWith(
            () => _MockPrayerTracker(fard: fard, sunnah: sunnah, duha: duha)),
        azkarProvider.overrideWith(_MockAzkar.new),
        tasbihStatsProvider.overrideWith((ref) async => tasbih),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: DailySummaryCard())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(AzkarData.resetTestData);

  testWidgets('renders the four rings with counts at zero', (tester) async {
    await _pumpCard(tester);
    expect(find.text('خلاصه امروز'), findsOneWidget);
    expect(find.text('نماز'), findsOneWidget);
    expect(find.text('رواتب'), findsOneWidget);
    expect(find.text('اذکار'), findsOneWidget);
    expect(find.text('تسبیح'), findsOneWidget);
    // 0/5, 0/7, 0/<adhkar total> and 0/0 — all four counters rendered.
    final counters = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .where((s) => RegExp(r'0/\d+').hasMatch(s))
        .length;
    expect(counters, 4);
  });

  testWidgets('qada counts as performed for the prayer ring', (tester) async {
    await _pumpCard(tester, fard: {
      FardhPrayer.fajr: PrayerStatus.done,
      FardhPrayer.dhuhr: PrayerStatus.qada,
    });
    expect(find.textContaining('2/5'), findsOneWidget);
  });

  testWidgets('the rawatib ring counts duha with the sunnahs', (tester) async {
    await _pumpCard(tester,
        sunnah: {SunnahPrayer.fajrRawatib: true}, duha: true);
    expect(find.textContaining('2/7'), findsOneWidget);
  });

  testWidgets('the tasbih ring reads today against the summed targets',
      (tester) async {
    await _pumpCard(
      tester,
      tasbih: const TasbihStatsData(
          weekTotal: 250, todayTotal: 34, sumTargets: 100),
    );
    expect(find.textContaining('34/100'), findsOneWidget);
    // The days chip («N روز پیاپی») is gone from the card for good.
    expect(find.textContaining('روز پیاپی'), findsNothing);
  });

  testWidgets('the adhkar ring leaves 0/0 once the data finishes loading',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          prayerTrackerProvider.overrideWith(_MockPrayerTracker.new),
          azkarProvider.overrideWith(() => _SlowAzkar(_sampleAzkar)),
          tasbihStatsProvider.overrideWith((ref) async => TasbihStatsData.empty),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: DailySummaryCard())),
        ),
      ),
    );

    // First frame: the provider is still loading, so the card paints 0/0.
    expect(find.textContaining('0/3'), findsNothing);

    // The load completes and the card must rebuild off the full provider —
    // watching only the version counter (an int that stays 0) would leave the
    // ring at 0/0 for the whole session.
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(find.textContaining('0/3'), findsOneWidget);
  });
}
