import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/care_engine/care_templates.dart';
import 'package:tawheeed/features/personal/data/care_repository.dart';
import 'package:tawheeed/features/personal/presentation/providers/care_providers.dart';
import 'package:tawheeed/features/personal/presentation/screens/car_screen.dart';
import 'package:tawheeed/features/personal/presentation/screens/home_care_screen.dart';
import 'package:tawheeed/features/personal/services/care_reminder_scheduler.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import '../support/fake_care_template_overrides.dart';

class _FakeRepo implements CareRepository {
  _FakeRepo(this.snapshot);

  CareSnapshot snapshot;

  @override
  Future<CareSnapshot> load() async => snapshot;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _NoopReminders implements CareReminders {
  @override
  Future<void> sync(CareSnapshot snapshot, {dynamic settings}) async {}

  @override
  Future<void> notifyThresholdCrossed({
    required String title,
    required String body,
    required String payload,
  }) async {}
}

CareTask _task({
  String id = 't1',
  String title = 'روغن موتور',
  DateTime? lastDone,
  int intervalDays = 180,
  int intervalKm = 5000,
  int? lastDoneKm = 41500,
}) =>
    CareTask(
      id: id,
      assetId: 'a1',
      title: title,
      categoryKey: 'general',
      iconKey: 'oil',
      scheduleType: CareScheduleType.both,
      intervalDays: intervalDays,
      intervalKm: intervalKm,
      lastDoneDate: lastDone ?? DateTime.now().subtract(const Duration(days: 160)),
      lastDoneKm: lastDoneKm,
      createdAt: DateTime(2025, 4),
    );

CareSnapshot _snapshot({CareAssetKind kind = CareAssetKind.car, bool empty = false}) {
  if (empty) return const CareSnapshot();
  final asset = CareAsset(
    id: 'a1',
    kind: kind,
    name: kind == CareAssetKind.car ? 'پژو ۲۰۶' : 'خانه',
    meta: const {'make': 'پژو', 'model': '206', 'color': 'سفید'},
    createdAt: DateTime(2025, 4),
  );
  return CareSnapshot(
    assets: [asset],
    tasks: [_task(title: kind == CareAssetKind.car ? 'روغن موتور' : 'سرویس پکیج')],
    readings: [
      OdometerReading(
          id: 'o1', assetId: 'a1', date: DateTime.now(), km: 41800),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required double width,
  required double textScale,
  required CareSnapshot snapshot,
  CareTemplates? templates,
}) async {
  const height = 900.0;
  tester.view.physicalSize = const Size(360, 900) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        careRepositoryProvider.overrideWithValue(_FakeRepo(snapshot)),
        careRemindersProvider.overrideWithValue(_NoopReminders()),
        careTemplateOverridesProvider
            .overrideWithValue(FakeCareTemplateOverrides()),
        // The bundle read is real I/O; overrides keep the banner tests
        // deterministic instead of racing pumpAndSettle.
        if (templates != null)
          careTemplatesProvider.overrideWith((ref) async => templates),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CareTemplates _templates() => CareTemplates.parse(
      File('assets/data/care_templates.json').readAsStringSync());

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('car page renders at ${width.toInt()}dp / scale $scale',
          (tester) async {
        await _pump(
          tester,
          const CarScreen(),
          width: width,
          textScale: scale,
          snapshot: _snapshot(),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('خودرو'), findsWidgets);
        expect(find.text('روغن موتور'), findsWidgets);
      });

      testWidgets('home page renders at ${width.toInt()}dp / scale $scale',
          (tester) async {
        await _pump(
          tester,
          const HomeCareScreen(),
          width: width,
          textScale: scale,
          snapshot: _snapshot(kind: CareAssetKind.home),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('خانه'), findsWidgets);
      });
    }
  }

  testWidgets('the suggested intervals are editable in the app', (tester) async {
    await _pump(
      tester,
      const HomeCareScreen(),
      width: 360,
      textScale: 1.0,
      snapshot: _snapshot(kind: CareAssetKind.home),
      templates: _templates(),
    );
    await tester.tap(find.text('تنظیم پیش‌فرض‌ها').first);
    await tester.pumpAndSettle();
    expect(find.text('تنظیم پیشنهادی؛ هر عدد را می‌توانید در همین برنامه عوض کنید.', findRichText: true), findsNothing);
    // The sheet lists both asset kinds and the shipped suggestions.
    expect(find.text('خانه'), findsWidgets);
    expect(find.text('خودرو'), findsWidgets);
    expect(find.byType(ListTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('the season pack banner is honest', () {
    testWidgets('a fresh home is told how much of the pack is left',
        (tester) async {
      await _pump(
        tester,
        const HomeCareScreen(),
        width: 360,
        textScale: 1.0,
        snapshot: _snapshot(kind: CareAssetKind.home),
        templates: _templates(),
      );
      expect(tester.takeException(), isNull);
      // Today sits inside one of the two shipped windows, so the pack is
      // offered with its own state rather than a hardcoded month guess.
      expect(find.text('آماده‌سازی زمستان'), findsOneWidget);
      // One fraction formatter decides both the numbers and their isolation.
      expect(find.text(NumberFormat.fraction(0, 4)), findsOneWidget);
      expect(find.text('افزودن 4 مورد'), findsOneWidget);
    });

    testWidgets('a fully scheduled pack has no add button', (tester) async {
      final base = _snapshot(kind: CareAssetKind.home);
      final seasonal = [
        for (final key in const [
          'boiler_service',
          'chimney_cleaning',
          'fire_extinguisher',
          'detector_battery',
        ])
          CareTask(
            id: key,
            assetId: 'a1',
            title: key,
            templateKey: key,
            categoryKey: 'seasonal',
            iconKey: '',
            scheduleType: CareScheduleType.time,
            intervalDays: 365,
            createdAt: DateTime(2025, 4),
          ),
      ];
      await _pump(
        tester,
        const HomeCareScreen(),
        width: 360,
        textScale: 1.0,
        snapshot: CareSnapshot(
          assets: base.assets,
          tasks: [...base.tasks, ...seasonal],
          readings: base.readings,
        ),
        templates: _templates(),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('هر 4 مورد ثبت شده'), findsOneWidget);
      expect(find.text('افزودن 4 مورد'), findsNothing);
      expect(find.textContaining('فصل بعد'), findsNothing);
    });
  });

  testWidgets('the car page offers a first-run entry point', (tester) async {
    await _pump(
      tester,
      const CarScreen(),
      width: 360,
      textScale: 1.0,
      snapshot: _snapshot(empty: true),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('هنوز خودرویی ثبت نشده'), findsOneWidget);
    expect(find.text('افزودن خودرو'), findsOneWidget);
  });

  testWidgets('the home page offers a first-run entry point', (tester) async {
    await _pump(
      tester,
      const HomeCareScreen(),
      width: 360,
      textScale: 1.0,
      snapshot: _snapshot(empty: true),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('هنوز خانه‌ای ثبت نشده'), findsOneWidget);
    expect(find.text('افزودن خانه'), findsOneWidget);
  });

  testWidgets('both pages expose history and settings actions', (tester) async {
    await _pump(
      tester,
      const CarScreen(),
      width: 360,
      textScale: 1.0,
      snapshot: _snapshot(),
    );
    expect(find.byTooltip('تاریخچه'), findsOneWidget);
    expect(find.byTooltip('تنظیمات'), findsOneWidget);
    expect(find.byTooltip('بازگشت'), findsOneWidget);
  });

  testWidgets('a car with history and fuel still fits 320dp at scale 1.3',
      (tester) async {
    await _pump(
      tester,
      const CarScreen(),
      width: 320,
      textScale: 1.3,
      snapshot: CareSnapshot(
        assets: [
          CareAsset(
            id: 'a1',
            kind: CareAssetKind.car,
            name: 'پژو ۲۰۶',
            meta: const {'make': 'پژو', 'model': '206', 'color': 'سفید'},
            createdAt: DateTime(2025, 4),
          ),
        ],
        tasks: [
          _task(),
          CareTask(
            id: 't2',
            assetId: 'a1',
            title: 'لنت ترمز جلو',
            categoryKey: 'general',
            iconKey: 'brake',
            scheduleType: CareScheduleType.distance,
            intervalKm: 30000,
            lastDoneKm: 20000,
            createdAt: DateTime(2025, 4),
          ),
        ],
        readings: [
          OdometerReading(
              id: 'o1', assetId: 'a1', date: DateTime(2026, 9), km: 41000),
          OdometerReading(
              id: 'o2', assetId: 'a1', date: DateTime(2026, 10, 10), km: 41800),
        ],
        records: [
          CareRecord(
            id: 'r1',
            assetId: 'a1',
            taskId: 't1',
            title: 'روغن موتور',
            date: DateTime(2026, 4, 10),
            odometerKm: 37000,
            cost: 1850000,
          ),
        ],
        fuelLogs: [
          FuelLog(
            id: 'f1',
            assetId: 'a1',
            date: DateTime(2026, 9),
            liters: 40,
            odometerKm: 41000,
            totalCost: 1400000,
          ),
          FuelLog(
            id: 'f2',
            assetId: 'a1',
            date: DateTime(2026, 10, 10),
            liters: 38,
            odometerKm: 41800,
            totalCost: 1330000,
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    // The page is a lazy ListView: at 320dp / scale 1.3 the records section is
    // below the fold, so it has to be scrolled into range before it exists.
    await tester.scrollUntilVisible(
      find.text('آخرین ثبت‌ها'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('آخرین ثبت‌ها'), findsOneWidget);
  });
}
