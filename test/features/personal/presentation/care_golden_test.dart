import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/care_engine/care_templates.dart';
import 'package:tawheeed/features/personal/data/care_repository.dart';
import 'package:tawheeed/features/personal/presentation/providers/care_providers.dart';
import 'package:tawheeed/features/personal/presentation/screens/car_screen.dart';
import 'package:tawheeed/features/personal/presentation/screens/home_care_screen.dart';
import 'package:tawheeed/features/personal/services/care_reminder_scheduler.dart';
import '../support/fake_care_template_overrides.dart';

/// Layout/palette baselines for «خودرو» and «خانه».
///
/// «Now» is pinned to 12 October 2026, so the progress bars, the remaining
/// texts and the season banner are the same on every run. Like the More, Home
/// and Calendar sets these render tofu glyphs — no font is loaded in the test
/// binding — so they guard layout and colour drift, never shaping.
class _FakeRepo implements CareRepository {
  _FakeRepo(this.snapshot);

  final CareSnapshot snapshot;

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

final _now = DateTime(2026, 10, 12);

CareSnapshot _car() => CareSnapshot(
      assets: [
        CareAsset(
          id: 'a1',
          kind: CareAssetKind.car,
          name: 'پژو ۲۰۶',
          meta: const {
            'make': 'پژو',
            'model': '206',
            'color': 'سفید',
            'plate': '۱۲ ب ۳۴۵',
          },
          createdAt: DateTime(2025, 4),
        ),
      ],
      tasks: [
        CareTask(
          id: 't1',
          assetId: 'a1',
          title: 'روغن موتور',
          categoryKey: 'general',
          iconKey: 'oil',
          scheduleType: CareScheduleType.both,
          intervalDays: 180,
          intervalKm: 5000,
          lastDoneDate: DateTime(2026, 4, 10),
          lastDoneKm: 37000,
          createdAt: DateTime(2025, 4),
        ),
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
    );

CareSnapshot _home() => CareSnapshot(
      assets: [
        CareAsset(
          id: 'h1',
          kind: CareAssetKind.home,
          name: 'خانه',
          meta: const {'nickname': 'آپارتمان'},
          createdAt: DateTime(2025, 4),
        ),
      ],
      tasks: [
        CareTask(
          id: 's1',
          assetId: 'h1',
          title: 'سرویس پکیج',
          categoryKey: 'general',
          iconKey: 'boiler',
          scheduleType: CareScheduleType.time,
          intervalDays: 365,
          lastDoneDate: DateTime(2025, 12),
          createdAt: DateTime(2025, 4),
        ),
        CareTask(
          id: 's2',
          assetId: 'h1',
          title: 'فیلتر تصفیهٔ آب',
          categoryKey: 'general',
          iconKey: 'filter',
          scheduleType: CareScheduleType.time,
          intervalDays: 180,
          lastDoneDate: DateTime(2026, 2),
          createdAt: DateTime(2025, 4),
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  required Widget home,
  required CareSnapshot snapshot,
  required ThemeKind kind,
  Size size = const Size(360, 1300),
}) async {
  AppTheme.applyTheme(
      kind: kind, phase: kind == ThemeKind.night ? TimePhase.night : TimePhase.day);
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        careRepositoryProvider.overrideWithValue(_FakeRepo(snapshot)),
        careRemindersProvider.overrideWithValue(_NoopReminders()),
        careTemplateOverridesProvider
            .overrideWithValue(FakeCareTemplateOverrides()),
        // Resolve the bundle deterministically, so the baseline really does
        // contain the season banner instead of racing the file read.
        careTemplatesProvider.overrideWith((ref) async => CareTemplates.parse(
            File('assets/data/care_templates.json').readAsStringSync())),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Directionality(textDirection: TextDirection.rtl, child: home),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('car page, day', (tester) async {
    await _pump(
      tester,
      home: CarScreen(nowOverride: _now),
      snapshot: _car(),
      kind: ThemeKind.day,
    );
    await expectLater(
      find.byType(CarScreen),
      matchesGoldenFile('goldens/car_page_day.png'),
    );
  });

  testWidgets('car page, night', (tester) async {
    await _pump(
      tester,
      home: CarScreen(nowOverride: _now),
      snapshot: _car(),
      kind: ThemeKind.night,
    );
    await expectLater(
      find.byType(CarScreen),
      matchesGoldenFile('goldens/car_page_night.png'),
    );
  });

  testWidgets('car page, empty', (tester) async {
    await _pump(
      tester,
      home: CarScreen(nowOverride: _now),
      snapshot: const CareSnapshot(),
      kind: ThemeKind.day,
      size: const Size(360, 520),
    );
    await expectLater(
      find.byType(CarScreen),
      matchesGoldenFile('goldens/car_empty_day.png'),
    );
  });

  testWidgets('home page, day', (tester) async {
    await _pump(
      tester,
      home: HomeCareScreen(nowOverride: _now),
      snapshot: _home(),
      kind: ThemeKind.day,
    );
    await expectLater(
      find.byType(HomeCareScreen),
      matchesGoldenFile('goldens/home_page_day.png'),
    );
  });

  testWidgets('home page, night', (tester) async {
    await _pump(
      tester,
      home: HomeCareScreen(nowOverride: _now),
      snapshot: _home(),
      kind: ThemeKind.night,
    );
    await expectLater(
      find.byType(HomeCareScreen),
      matchesGoldenFile('goldens/home_page_night.png'),
    );
  });

  testWidgets('home page, empty', (tester) async {
    await _pump(
      tester,
      home: HomeCareScreen(nowOverride: _now),
      snapshot: const CareSnapshot(),
      kind: ThemeKind.day,
      size: const Size(360, 520),
    );
    await expectLater(
      find.byType(HomeCareScreen),
      matchesGoldenFile('goldens/home_empty_day.png'),
    );
  });
}
