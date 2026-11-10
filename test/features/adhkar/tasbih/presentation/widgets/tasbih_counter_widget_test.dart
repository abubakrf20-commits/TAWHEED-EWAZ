import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/widgets/tasbih_counter_widget.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/azkar_settings_provider.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_provider.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_stats_provider.dart';
import 'package:tawheeed/features/home/services/widget_sync.dart';
import 'package:tawheeed/features/home/services/widget_sync_provider.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import '../../../../../core/database/mock_daos.dart';

/// The counter reads TWO stores, not one: its own DAO, and the daily-status
/// DAO behind the stat pills (`tasbihStatsProvider`) and behind every flushed
/// tap's daily totals. Overriding only `tasbihDaoProvider` leaves the second
/// one opening the real drift `AppDatabase` — one extra database instance per
/// case, plus a read on the tap path — so both overrides always travel
/// together.
List<Override> _daoOverrides(
  MockTasbihDao dao, [
  List<Override> extra = const [],
]) =>
    [
      tasbihDaoProvider.overrideWithValue(dao),
      dailyStatusDaoProvider.overrideWithValue(MockDailyStatusDao()),
      ...extra,
    ];

/// Spy/doubles for WidgetSync — records calls without touching the platform
/// bridge (which would throw MissingPluginException in tests).
class _SpyWidgetSync extends WidgetSync {
  final List<
      ({
        String dhikr,
        int count,
        int target,
        bool isActive,
        int? zikrIndex
      })> calls = [];

  @override
  Future<void> updateTasbihWidget({
    required String dhikr,
    required int count,
    required int target,
    required bool isActive,
    int? zikrIndex,
    String? zikrId,
  }) async {
    calls.add((
      dhikr: dhikr,
      count: count,
      target: target,
      isActive: isActive,
      zikrIndex: zikrIndex
    ));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The counter runs the daily-reset decision on every load, and its default
  /// is ON (`azkar_autoReset ?? true`) with "never stamped" (`lastDate == null`)
  /// counting as overdue. A file whose prefs cache is empty therefore zeroed
  /// the seeded counts — the overshoot case below only ever passed because an
  /// earlier case had written the date marker, i.e. the suite depended on test
  /// ORDER. Pinning the switch off is the root fix: every case states the
  /// counts it seeds, whatever ran before it.
  setUp(() =>
      SharedPreferences.setMockInitialValues(const {'azkar_autoReset': false}));
  testWidgets('TasbihCounterWidget renders empty state', (tester) async {
    final mockDao = MockTasbihDao();
    await tester.pumpWidget(
      ProviderScope(
        overrides: _daoOverrides(mockDao),
        child: const MaterialApp(
            home: Scaffold(
                body: SizedBox(height: 700, child: TasbihCounterWidget()))),
      ),
    );
    await tester.pump();
    expect(find.byType(TasbihCounterWidget), findsOneWidget);
  });

  testWidgets('TasbihCounterWidget renders with tasbih data', (tester) async {
    final mockDao = MockTasbihDao();
    await mockDao.upsertTasbih(TasbihTableData(
      id: '1',
      dhikrText: 'Test Dhikr',
      count: 5,
      target: 33,
      totalLifetimeCount: 0,
      createdAt: DateTime.now(),
      isDefault: false,
      isEnabled: true,
    ));
    await tester.pumpWidget(
      ProviderScope(
        overrides: _daoOverrides(mockDao),
        child: const MaterialApp(
            home: Scaffold(
                body: SizedBox(height: 700, child: TasbihCounterWidget()))),
      ),
    );
    await tester.pump();
    expect(find.byType(TasbihCounterWidget), findsOneWidget);
  });

  testWidgets('TasbihCounterWidget shows completed rounds badge next to circle',
      (tester) async {
    final binding = tester.binding;
    await binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => binding.setSurfaceSize(null));

    final mockDao = MockTasbihDao();
    await mockDao.upsertTasbih(TasbihTableData(
      id: '1',
      dhikrText: 'Rounds',
      count: 2,
      target: 100,
      totalLifetimeCount:
          66, // 2 completed rounds of 33 — badge was intentionally removed in a6a3842
      createdAt: DateTime.now(),
      isDefault: false,
      isEnabled: true,
    ));
    await tester.pumpWidget(
      ProviderScope(
        overrides: _daoOverrides(mockDao),
        child: const MaterialApp(
            home: Scaffold(
                body: SizedBox(height: 750, child: TasbihCounterWidget()))),
      ),
    );
    await tester.pump();
    // Badge was removed in feat(tasbih): حذف نشانه دور — should not be shown
    expect(find.byIcon(Icons.repeat), findsNothing);
    expect(find.textContaining('دور'), findsNothing);
  });

  testWidgets('quick mode shows speed selector and applies the chosen speed',
      (tester) async {
    final binding = tester.binding;
    await binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => binding.setSurfaceSize(null));

    final mockDao = MockTasbihDao();
    await mockDao.upsertTasbih(TasbihTableData(
      id: '1',
      dhikrText: 'Test',
      count: 0,
      target: 100,
      totalLifetimeCount: 0,
      createdAt: DateTime.now(),
      isDefault: false,
      isEnabled: true,
    ));
    final container = ProviderContainer(overrides: _daoOverrides(mockDao));
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: Scaffold(
                body: SizedBox(height: 750, child: TasbihCounterWidget()))),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Speed selector hidden while quick mode is off.
    expect(find.text('آرام'), findsNothing);

    // Enable quick mode → the three speed options appear.
    await tester.tap(find.text('تسبیح سریع'));
    await tester.pumpAndSettle();
    expect(find.text('آرام'), findsOneWidget);
    expect(find.text('عادی'), findsOneWidget);
    expect(find.text('سریع'), findsOneWidget);

    // Select 'سریع' → the setting persists.
    await tester.tap(find.text('سریع'));
    await tester.pumpAndSettle();
    expect(
        container.read(azkarSettingsProvider).quickSpeed, QuickCountSpeed.fast);

    // Hold the counter: at fast speed (516ms) a long hold yields multiple
    // counts; at the default normal speed it would be far fewer.
    final before = container.read(tasbihProvider).value!.first.currentCount;
    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(TasbihCounterWidget)));
    // 500ms long-press threshold + ~2.7s of fast ticking (>= 3 counts at 516ms).
    await tester.pump(const Duration(milliseconds: 3200));
    await gesture.up();
    await tester.pump();
    final after = container.read(tasbihProvider).value!.first.currentCount;
    expect(after - before, greaterThanOrEqualTo(3));
    await tester.pumpAndSettle();
  });

  testWidgets('long dhikr title wraps to two lines with no «بیشتر» toggle',
      (tester) async {
    final binding = tester.binding;
    await binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => binding.setSurfaceSize(null));

    const longDhikr =
        'لا حول ولا قوة الا بالله العلی العظیم و اتوب الیه عدد خلقه و رضا نفسه';
    final mockDao = MockTasbihDao();
    await mockDao.upsertTasbih(TasbihTableData(
      id: '1',
      dhikrText: longDhikr,
      count: 0,
      target: 100,
      totalLifetimeCount: 0,
      createdAt: DateTime.now(),
      isDefault: false,
      isEnabled: true,
    ));
    await tester.pumpWidget(
      ProviderScope(
        overrides: _daoOverrides(mockDao),
        child: const MaterialApp(
            home: Scaffold(
                body: SizedBox(height: 750, child: TasbihCounterWidget()))),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // A plain two-line, centered title — the «بیشتر»/«بستن» expander is gone
    // for good (user decision, 2026-10-16). Anchor on the dial's key: the same
    // dhikr text also appears in the picker chip, so `find.text` matches two.
    final titleFinder = find.byKey(const ValueKey('1'));
    final title = tester.widget<Text>(titleFinder);
    expect(title.maxLines, 2);
    expect(title.textAlign, TextAlign.center);
    expect(find.text('بیشتر'), findsNothing);
    expect(find.text('بستن'), findsNothing);

    // Two lines are really laid out (not a one-line cut).
    final paragraph = tester.renderObject<RenderParagraph>(titleFinder);
    final lineTops = paragraph
        .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: longDhikr.length))
        .map((box) => box.top)
        .toSet();
    expect(lineTops, hasLength(2),
        reason: 'the long dhikr must render on exactly two lines');
  });

  testWidgets(
      'TasbihCounterWidget shows +X فراتر از هدف and ادامه button past target',
      (tester) async {
    final binding = tester.binding;
    await binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => binding.setSurfaceSize(null));

    final mockDao = MockTasbihDao();
    await mockDao.upsertTasbih(TasbihTableData(
      id: '1',
      dhikrText: 'Overshoot',
      count: 105,
      target: 100,
      totalLifetimeCount: 0,
      createdAt: DateTime.now(),
      isDefault: false,
      isEnabled: true,
    ));
    await tester.pumpWidget(
      ProviderScope(
        overrides: _daoOverrides(mockDao),
        child: const MaterialApp(
            home: Scaffold(
                body: SizedBox(height: 750, child: TasbihCounterWidget()))),
      ),
    );
    await tester.pump();

    // Past the target: the overshoot badge and the ادامه button appear
    // (and the plain «تکمیل شده» badge does not).
    expect(find.textContaining('فراتر از هدف'), findsOneWidget);
    expect(find.textContaining('+5'), findsOneWidget);
    expect(find.text('ادامه'), findsOneWidget);
    expect(find.text('تکمیل شده'), findsNothing);

    // Pressing ادامه dismisses the overshoot visuals and counting continues
    // in the normal (non-completion) state.
    await tester.tap(find.text('ادامه'));
    await tester.pumpAndSettle();
    expect(find.textContaining('فراتر از هدف'), findsNothing);
    expect(find.text('ادامه'), findsNothing);
    expect(find.text('تکمیل شده'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('شمارش → ویجت خانه نیز با همان تعداد هماهنگ می‌شود',
      (tester) async {
    final binding = tester.binding;
    await binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => binding.setSurfaceSize(null));

    final mockDao = MockTasbihDao();
    await mockDao.upsertTasbih(TasbihTableData(
      id: '1',
      dhikrText: 'هماهنگ',
      count: 0,
      target: 33,
      totalLifetimeCount: 0,
      createdAt: DateTime.now(),
      isDefault: false,
      isEnabled: true,
    ));
    final spy = _SpyWidgetSync();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _daoOverrides(mockDao, [
          widgetSyncProvider.overrideWithValue(spy),
        ]),
        child: const MaterialApp(
            home: Scaffold(
                body: SizedBox(height: 750, child: TasbihCounterWidget()))),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // یک ضربه: شمارش +۱ و ویجت باید با count=1 صدا زده شود.
    await tester.tap(find.byType(TasbihCounterWidget));
    // فلاش ۱۸۰ms
    await tester.pump(const Duration(milliseconds: 250));
    expect(spy.calls, isNotEmpty);
    final last = spy.calls.last;
    expect(last.count, 1);
    expect(last.dhikr, 'هماهنگ');
    expect(last.isActive, isTrue);
    // هنوز باید ادامه بدهد: شماره با هر ضربه همگام می‌ماند.

    // چند ضربهٔ دیگر — ویجت باید همراهش به‌روز شود.
    await tester.tap(find.byType(TasbihCounterWidget));
    await tester.pump(const Duration(milliseconds: 250));
    expect(spy.calls.last.count, 2);
    await tester.pumpAndSettle();
  });

  testWidgets('TasbihCounterWidget shows completed badge when target reached',
      (tester) async {
    final binding = tester.binding;
    await binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => binding.setSurfaceSize(null));

    final mockDao = MockTasbihDao();
    await mockDao.upsertTasbih(TasbihTableData(
      id: '1',
      dhikrText: 'Completed',
      count: 33,
      target: 33,
      totalLifetimeCount: 0,
      createdAt: DateTime.now(),
      isDefault: false,
      isEnabled: true,
    ));
    await tester.pumpWidget(
      ProviderScope(
        overrides: _daoOverrides(mockDao),
        child: const MaterialApp(
            home: Scaffold(
                body: SizedBox(height: 750, child: TasbihCounterWidget()))),
      ),
    );
    await tester.pump();
    expect(find.byType(TasbihCounterWidget), findsOneWidget);
  });

  /// The counter wears the tasbih section's own colour (its amber), and the two
  /// stat pills wear the «تسبیح سریع» recipe in their own hues. These pin the
  /// two halves of the visual change; the ring's beads/arc are a `CustomPainter`
  /// with no widget seam and are guarded by `tasbih_ring_style_test.dart`.
  group('the counter and the stat pills wear the section design', () {
    /// Pumps one tasbih with [count]/[target] and returns nothing: every
    /// assertion below reads the rendered tree.
    Future<void> pumpCounter(
      WidgetTester tester, {
      int count = 5,
      int target = 33,
    }) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockDao = MockTasbihDao();
      await mockDao.upsertTasbih(TasbihTableData(
        id: '1',
        dhikrText: 'Test',
        count: count,
        target: target,
        totalLifetimeCount: 0,
        createdAt: DateTime.now(),
        isDefault: false,
        isEnabled: true,
      ));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _daoOverrides(mockDao),
          child: const MaterialApp(
              home: Scaffold(
                  body: SizedBox(height: 750, child: TasbihCounterWidget()))),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    /// The decoration of the nearest `Container` above [label] — i.e. its pill.
    BoxDecoration pillOf(WidgetTester tester, String label) {
      BoxDecoration? found;
      tester.element(find.text(label)).visitAncestorElements((ancestor) {
        final widget = ancestor.widget;
        if (widget is Container && widget.decoration is BoxDecoration) {
          found = widget.decoration as BoxDecoration;
          return false;
        }
        return true;
      });
      expect(found, isNotNull,
          reason: '«$label» should sit inside a decorated pill');
      return found!;
    }

    testWidgets('the count reads the tasbih amber, not the pale hero gold',
        (tester) async {
      await pumpCounter(tester);

      final count = tester.widget<Text>(find.text('5'));
      expect(count.style?.fontSize, 56);
      // The derivation the app uses everywhere for hue-tinted ink on a light
      // page: the hue deepened 30% (`dsContentColor`).
      expect(count.style?.color, mix(SectionHues.tasbih, Colors.black, 0.30));
      expect(count.style?.color, isNot(AppPalette.heroGold),
          reason: 'the hero gold is exactly what this replaced');
    });

    testWidgets('both stat pills wear the quick-tasbih recipe, own hue each',
        (tester) async {
      await pumpCounter(tester);

      final day = pillOf(tester, 'هدف روزانه');
      expect(day.borderRadius, BorderRadius.circular(20),
          reason: 'fully rounded, like the «تسبیح سریع» pill');
      expect(day.color, AppPalette.emerald.withValues(alpha: 0.12));
      expect((day.border as Border).top.color,
          AppPalette.emerald.withValues(alpha: 0.40));

      final week = pillOf(tester, 'این هفته');
      expect(week.borderRadius, BorderRadius.circular(20));
      expect(week.color, SectionHues.calendar.withValues(alpha: 0.12),
          reason: 'the week box must not repeat the pill\'s amber');
      expect((week.border as Border).top.color,
          SectionHues.calendar.withValues(alpha: 0.40));
    });
  });

  // ── Guards for the 2026-10-23 tasbih pass ────────────────────────────────
  group('the counting surface announces ONE button', () {
    testWidgets(
        'the card carries count, hint and tap — its painted text stays silent',
        (tester) async {
      // The handle is released INSIDE the body: `_endOfTestVerifications` runs
      // at the end of the body, before tearDowns, so `addTearDown(dispose)`
      // still leaves it active at that check. `dispose` is not idempotent, so
      // the two must not both run.
      final handle = tester.ensureSemantics();
      try {
        await _pumpTasbih(tester);

        final card = tester.widget<Semantics>(find.descendant(
            of: find.byType(TasbihCounterWidget),
            matching: find.byWidgetPredicate((w) =>
                w is Semantics &&
                w.properties.label == 'Test' &&
                w.properties.button == true)));
        expect(card.properties.value, '5 از 33');
        expect(card.properties.hint, 'برای افزودن یک ذکر ضربه بزنید');
        expect(card.properties.onTap, isNotNull);

        // The number and the title are the very words this node already
        // announces, so they must not reach the tree too — otherwise a reader
        // hears «Test · Test · 5 از 33» off one tap target.
        expect(
            find.ancestor(
                of: find.text('5'),
                matching: find.byType(ExcludeSemantics)),
            findsOneWidget);
        expect(
            find.ancestor(
                of: find.byKey(const ValueKey('1')),
                matching: find.byType(ExcludeSemantics)),
            findsOneWidget);

        // Exactly one button on the page: the five action tiles and the
        // quick-mode pill answer a tap but are not buttons, so a reader can
        // still step between them.
        final buttons = _allSemantics(tester)
            .where((d) => d.flagsCollection.isButton)
            .toList();
        expect(buttons, hasLength(1));
        expect(buttons.single.hasAction(ui.SemanticsAction.tap), isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
        'past the target the pill merges into the card and «ادامه» keeps its own tap',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        // `warmup: null` — the overshoot pill renders on the frame the data
        // lands, the same reason the overshoot case above pumps once.
        await _pumpTasbih(tester, count: 105, target: 100, warmup: null);

        final buttons = _allSemantics(tester)
            .where((d) => d.flagsCollection.isButton)
            .toList();
        expect(buttons, hasLength(1));
        expect(buttons.single.label, contains('فراتر از هدف'));
        expect(buttons.single.value, '105 از 100');

        // «ادامه» is deliberately NOT excluded: it is the only way a reader can
        // dismiss the overshoot pill. It sits inside the excluded column, so
        // `getSemantics(find.text(...))` cannot see it — only a root walk can.
        final cont = _allSemantics(tester)
            .where((d) => d.label == 'ادامه')
            .toList();
        expect(cont, hasLength(1));
        expect(cont.single.hasAction(ui.SemanticsAction.tap), isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('the five action tiles each answer exactly one tap',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await _pumpTasbih(tester);

        for (final label in const [
          'قبلی',
          'ریست',
          'افزودن',
          'تغییر هدف',
          'بعدی'
        ]) {
          final nodes =
              _allSemantics(tester).where((d) => d.label == label).toList();
          expect(nodes, hasLength(1),
              reason: '«$label» must be one announced control, not two');
          expect(nodes.single.hasAction(ui.SemanticsAction.tap), isTrue);
          expect(nodes.single.flagsCollection.isButton, isFalse,
              reason: 'only the counting surface is a button');
        }
      } finally {
        handle.dispose();
      }
    });
  });

  group('an unknown stat is never a zero', () {
    testWidgets('a failed stats read prints «—» and says why', (tester) async {
      await _pumpTasbih(tester, overrides: [
        tasbihStatsProvider
            .overrideWith((ref) async => throw StateError('dao down')),
      ]);

      expect(
          find.descendant(
              of: find.byType(TasbihCounterWidget), matching: find.text('—')),
          findsNWidgets(2));

      for (final label in const ['هدف روزانه', 'این هفته']) {
        final texts = _pillTexts(tester, label);
        expect(texts, contains(label));
        expect(texts, contains('—'));
        expect(texts.any((t) => RegExp(r'[0-9۰-۹]').hasMatch(t)), isFalse,
            reason: '«$label» must not print a number it does not have');
      }

      final notes = find.descendant(
          of: find.byType(TasbihCounterWidget),
          matching: find.byWidgetPredicate((w) =>
              w is Semantics &&
              w.properties.label == 'آمار تسبیح بارگیری نشد'));
      expect(notes, findsNWidgets(2));
      for (final note in tester.widgetList<Semantics>(notes)) {
        expect(note.excludeSemantics, isTrue,
            reason: 'the pill paints «—»; the sentence belongs to the node, '
                'and must not merge into a neighbour');
      }
    });

    testWidgets('a stats read still in flight also prints «—»', (tester) async {
      await _pumpTasbih(tester, overrides: [
        // A future that never completes: the pill must not guess.
        tasbihStatsProvider.overrideWith(
            (ref) => Completer<TasbihStatsData>().future),
      ]);

      expect(
          find.descendant(
              of: find.byType(TasbihCounterWidget), matching: find.text('—')),
          findsNWidgets(2));
      expect(
          find.byWidgetPredicate((w) =>
              w is Semantics &&
              w.properties.label == 'آمار تسبیح هنوز بارگیری نشده است'),
          findsNWidgets(2));
    });

    testWidgets('a loaded read still prints the numbers', (tester) async {
      await _pumpTasbih(tester, overrides: [
        tasbihStatsProvider.overrideWith(
            (ref) async => const TasbihStatsData(
                weekTotal: 41, todayTotal: 12, sumTargets: 99)),
      ]);

      expect(_pillTexts(tester, 'هدف روزانه'), contains('12 از 99'));
      expect(_pillTexts(tester, 'این هفته'), contains('41'));
      expect(
          find.descendant(
              of: find.byType(TasbihCounterWidget), matching: find.text('—')),
          findsNothing);
    });
  });

  group('the action row has a floor, not a fixed box', () {
    testWidgets('all five tiles floor at 52 and can still grow', (tester) async {
      await _pumpTasbih(tester);
      final floors = find.descendant(
          of: find.byType(TasbihCounterWidget),
          matching: find.byWidgetPredicate(_isFloorContainer));
      expect(floors, findsNWidgets(5));

      for (final label in const ['قبلی', 'ریست', 'افزودن', 'تغییر هدف', 'بعدی']) {
        final floor = find.descendant(
            of: find.byType(TasbihCounterWidget),
            matching: find.ancestor(
                of: find.text(label),
                matching: find.byWidgetPredicate(_isFloorContainer)));
        expect(floor, findsOneWidget, reason: '«$label» must sit in a tile');
        // A fixed `height` is what used to cut a scaled label; only a floor
        // may be declared here, so the ceiling must stay unbounded.
        expect(
            tester.widget<Container>(floor).constraints!.maxHeight,
            double.infinity,
            reason: '«$label» must stretch for its own text');
        expect(tester.getRect(floor).height, greaterThanOrEqualTo(52));
      }
    });

    testWidgets('320 dp × 1.3 writes every action label in full',
        (tester) async {
      await _pumpTasbih(tester,
          surface: const Size(320, 800),
          fontFamily: 'Vazirmatn',
          textScale: 1.3);
      expect(tester.takeException(), isNull);

      for (final label in const ['قبلی', 'ریست', 'افزودن', 'تغییر هدف', 'بعدی']) {
        final text = find.descendant(
            of: find.byType(TasbihCounterWidget), matching: find.text(label));
        final floor = find.descendant(
            of: find.byType(TasbihCounterWidget),
            matching: find.ancestor(
                of: find.text(label),
                matching: find.byWidgetPredicate(_isFloorContainer)));
        final textRect = tester.getRect(text);
        final floorRect = tester.getRect(floor);
        expect(textRect.top, greaterThanOrEqualTo(floorRect.top - 0.5),
            reason: '«$label» must not cross its tile top');
        expect(textRect.bottom, lessThanOrEqualTo(floorRect.bottom + 0.5),
            reason: '«$label» must not cross its tile bottom');
        expect(tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
            isFalse,
            reason: '«$label» must be readable at text scale 1.3');
      }
    });
  });

  group('page dots are one excluded Wrap', () {
    testWidgets('20 dhikrs draw 20 dots, all on screen, none announced',
        (tester) async {
      await _pumpTasbih(tester, surface: const Size(320, 800), extraDhikrs: 19);
      expect(tester.takeException(), isNull);

      final dots = find.byWidgetPredicate(_isDot);
      expect(dots, findsNWidgets(20));
      // A `Row` was the old shape and it clipped the tail dots off the card;
      // a `Wrap` lays them out on as many runs as the width needs.
      // Anchor on ONE dot: `find.ancestor` of all 20 matches the same `Wrap`
      // 20 times, so the un-anchored form can never be a single result.
      final wrap =
          find.ancestor(of: dots.first, matching: find.byType(Wrap));
      expect(wrap, findsOneWidget);
      expect(find.ancestor(of: wrap, matching: find.byType(ExcludeSemantics)),
          findsOneWidget,
          reason: 'the dots are decoration — 20 announced nodes is noise');

      expect(
          tester
              .widgetList<Container>(dots)
              .where((c) => _isDotOfWidth(c, 20)),
          hasLength(1),
          reason: 'exactly the active dhikr is the long dot');

      final page = tester.getRect(find.byType(TasbihCounterWidget));
      for (var i = 0; i < 20; i++) {
        final rect = tester.getRect(dots.at(i));
        expect(rect.left, greaterThanOrEqualTo(page.left - 0.5));
        expect(rect.right, lessThanOrEqualTo(page.right + 0.5));
        expect(rect.top, greaterThanOrEqualTo(page.top - 0.5));
        expect(rect.bottom, lessThanOrEqualTo(page.bottom + 0.5));
      }
    });
  });

  group('a queued burst is never lost or resurrected', () {
    testWidgets('tearing the tab down mid-burst still lands the tap',
        (tester) async {
      final mockDao = MockTasbihDao();
      await mockDao.upsertTasbih(TasbihTableData(
        id: '1',
        dhikrText: 'Test',
        count: 0,
        target: 33,
        totalLifetimeCount: 0,
        createdAt: DateTime.now(),
        isDefault: false,
        isEnabled: true,
      ));
      final spy = _SpyWidgetSync();
      final container = ProviderContainer(overrides: _daoOverrides(mockDao, [
        widgetSyncProvider.overrideWithValue(spy),
      ]));
      addTearDown(container.dispose);
      // The notifier's own A-2 gate returns early when `ref` is unmounted, and
      // `tasbihProvider` is autoDispose — a live subscription is what keeps the
      // state alive long enough for the deactivate flush to write into it.
      final sub = container.listen(tasbihProvider, (_, __) {});
      addTearDown(sub.close);

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: Scaffold(
                body: SizedBox(height: 750, child: TasbihCounterWidget()))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byType(TasbihCounterWidget));
      await tester.pump();
      // Gone BEFORE the 180 ms flush timer fires — `deactivate` must flush.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(await mockDao.getTasbih('1'), isNotNull);
      expect((await mockDao.getTasbih('1'))!.count, 1,
          reason: 'the tap queued before the tab died must still be counted');
      expect(container.read(tasbihProvider).value!.first.currentCount, 1);
    });

    testWidgets('a reset confirmed inside the burst window stays reset',
        (tester) async {
      final mockDao = await _pumpTasbih(tester);
      await tester.tap(find.byType(TasbihCounterWidget));
      await tester.pump();

      await tester.tap(find.descendant(
          of: find.byType(TasbihCounterWidget), matching: find.text('ریست')));
      await tester.pump();
      // Confirmed while the tap is still sitting in the queue (< 180 ms).
      await tester.tap(find.widgetWithText(TextButton, 'ریست'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final row = await mockDao.getTasbih('1');
      expect(row, isNotNull);
      expect(row!.count, 0,
          reason: 'the flush must land BEFORE the zeroing, or the reset '
              'comes back as the burst count — the shipped defect');
      // The lifetime tally is a history, not the day's count: it keeps the tap.
      expect(row.totalLifetimeCount, 1);
    });
  });
}

/// The `Container` an action tile grows inside: a `minHeight` floor and no
/// fixed height. This exact equality is the contract — a `height:` reintroduced
/// beside the floor would clip a scaled label again.
bool _isFloorContainer(Widget w) =>
    w is Container && w.constraints == const BoxConstraints(minHeight: 52);

/// A page dot: 8 dp tall, short (idle) or long (active).
bool _isDot(Widget w) => _isDotOfWidth(w, 8) || _isDotOfWidth(w, 20);

/// `Container` has no `width`/`height` getters — it keeps them in
/// `constraints` (`BoxConstraints.tightFor`) — and `tightFor` is a factory,
/// not a const constructor, so the comparison cannot be `const`.
bool _isDotOfWidth(Widget w, double width) =>
    w is Container &&
    w.constraints == BoxConstraints.tightFor(width: width, height: 8);

/// Seeds one dhikr (plus [extraDhikrs] more) and pumps the counter.
///
/// Every guard below needs the same tree with different numbers, and two knobs
/// exist because two cases genuinely differ: the overshoot pill renders on the
/// frame the data lands (the extra 100 ms pump swallowed it — hence
/// `warmup: null`), and a fit matrix must render with the real Persian face,
/// which needs a non-const `MaterialApp`.
Future<MockTasbihDao> _pumpTasbih(
  WidgetTester tester, {
  String dhikr = 'Test',
  int count = 5,
  int target = 33,
  int extraDhikrs = 0,
  Size surface = const Size(400, 800),
  String? fontFamily,
  double? textScale,
  Duration? warmup = const Duration(milliseconds: 100),
  List<Override> overrides = const [],
}) async {
  if (fontFamily != null) {
    final loader = FontLoader(fontFamily)
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
    await loader.load();
    AppTheme.fontFamily = fontFamily;
    addTearDown(() => AppTheme.fontFamily = AppTheme.defaultFontFamily);
  }

  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final mockDao = MockTasbihDao();
  Future<void> seed(String id, String text, {int? t}) =>
      mockDao.upsertTasbih(TasbihTableData(
        id: id,
        dhikrText: text,
        count: count,
        target: t ?? target,
        totalLifetimeCount: 0,
        createdAt: DateTime.now(),
        isDefault: false,
        isEnabled: true,
      ));
  await seed('1', dhikr);
  for (var i = 0; i < extraDhikrs; i++) {
    await seed('${i + 2}', 'ذکر $i');
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: _daoOverrides(mockDao, overrides),
      child: MaterialApp(
        theme: fontFamily == null ? null : ThemeData(fontFamily: fontFamily),
        builder: textScale == null
            ? null
            : (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
        home: const Scaffold(
            body: SizedBox(height: 750, child: TasbihCounterWidget())),
      ),
    ),
  );
  await tester.pump();
  if (warmup != null) await tester.pump(warmup);
  return mockDao;
}

/// Every [SemanticsData] in the tree, walked from the root.
///
/// `tester.getSemantics(finder)` climbs ancestors only while the node it finds
/// is merged into its parent, so a node that lives under `ExcludeSemantics`
/// answers with something that is not itself — the root walk is the only way
/// to prove such a node exists and carries its own actions.
List<SemanticsData> _allSemantics(WidgetTester tester) {
  // The view's own owner, not the binding's deprecated `pipelineOwner`: the
  // latter is the same object today, and this is the accessor that survives.
  final owner = tester.binding.renderViews.first.owner?.semanticsOwner;
  expect(owner, isNotNull, reason: 'call tester.ensureSemantics() first');
  final out = <SemanticsData>[];
  void visit(SemanticsNode node) {
    out.add(node.getSemanticsData());
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(owner!.rootSemanticsNode!);
  return out;
}

/// The texts painted inside the stat pill whose label is [label].
///
/// Scoped per pill because the stats provider is only overridden in the cases
/// that need it, and a page-wide `find.text('0')` would match the counter
/// itself.
List<String> _pillTexts(WidgetTester tester, String label) {
  Element? pillElement;
  tester.element(find.text(label)).visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    if (w is Container && w.decoration is BoxDecoration) {
      pillElement = ancestor;
      return false;
    }
    return true;
  });
  expect(pillElement, isNotNull, reason: '«$label» sits inside its own pill');

  final out = <String>[];
  void visit(Element e) {
    final w = e.widget;
    // Only `Text` is counted: its own `RichText` child paints the same string
    // and would double every entry.
    if (w is Text) {
      out.add(w.data ?? w.textSpan?.toPlainText() ?? '');
    }
    e.visitChildren(visit);
  }

  visit(pillElement!);
  return out;
}
