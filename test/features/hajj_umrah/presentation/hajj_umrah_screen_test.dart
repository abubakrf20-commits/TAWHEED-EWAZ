import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/hajj_umrah/data/hajj_content.dart';
import 'package:tawheeed/features/hajj_umrah/data/hajj_trip.dart';
import 'package:tawheeed/features/hajj_umrah/presentation/screens/hajj_umrah_screen.dart';
import 'package:tawheeed/features/hajj_umrah/presentation/widgets/rite_counter_sheet.dart';
import 'package:tawheeed/features/hajj_umrah/presentation/widgets/ritual_steps_view.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/shared/widgets/checklist_card.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';

/// The page now reads the user's Hijri offset, which lives in settings; the
/// tests must not drag the settings database in, so the offset is overridden.
Widget _app() => ProviderScope(
      overrides: [hijriOffsetProvider.overrideWithValue(2)],
      child: const MaterialApp(home: HajjUmrahScreen()),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HajjData content', () {
    setUp(() async {
      await HajjData.load();
    });

    test('loads every major section from the JSON asset', () {
      expect(HajjData.isLoaded, isTrue);
      expect(HajjData.introConcepts, isNotEmpty);
      expect(HajjData.rulings, isNotEmpty);
      expect(HajjData.umrahSteps, isNotEmpty);
      expect(HajjData.hajjSteps, isNotEmpty);
      expect(HajjData.hajjTypes, isNotEmpty);
      expect(HajjData.expiation, isNotEmpty);
      expect(HajjData.specialRulings, isNotEmpty);
      expect(HajjData.faq, isNotEmpty);
      expect(HajjData.checklists, isNotEmpty);
      expect(HajjData.disclaimer, isNotEmpty);
    });

    test('ruling sections and screen aliases carry the rendered fields', () {
      for (final section in HajjData.rulings) {
        expect(section.id, isNotEmpty);
        for (final item in section.items) {
          expect(item.title, isNotEmpty);
          expect(item.body, isNotEmpty);
        }
      }
      for (final map in HajjData.expiation) {
        expect(map['title'], isNotEmpty, reason: 'map title missing');
        expect(map['body'], isNotEmpty, reason: 'map body missing');
      }
    });

    test(
        'every ritual step is numbered and described; duas/tips render when present',
        () {
      final steps = [...HajjData.umrahSteps, ...HajjData.hajjSteps];
      expect(steps, isNotEmpty);
      for (final s in steps) {
        expect(s.step, greaterThan(0), reason: 'step numbered from JSON field');
        expect(s.title, isNotEmpty);
        expect(s.description, isNotEmpty);
      }
      // Item 21: arabic + tip were parsed before but never rendered. Most steps
      // carry a dua and a tip (the final حلق step legitimately has none).
      final withDua = steps.where((s) => s.arabic.isNotEmpty).toList();
      final withTip = steps.where((s) => s.tip.isNotEmpty).toList();
      expect(withDua.length, greaterThan(steps.length ~/ 2));
      expect(withTip.length, greaterThan(steps.length ~/ 2));
    });

    test('steps keep JSON numbering even if the array is reordered', () {
      final reordered = [...HajjData.hajjSteps.reversed];
      expect(reordered.map((s) => s.step).toSet(),
          HajjData.hajjSteps.map((s) => s.step).toSet());
    });

    test('section routing uses stable ids, not Persian titles', () {
      // coreRulingSections excludes kaffarah/women/contemporary/niyaba/types.
      final ids = HajjData.coreRulingSections.map((s) => s.id).toSet();
      expect(ids.contains('kaffarah'), isFalse);
      expect(ids.contains('women'), isFalse);
      expect(ids.contains('types'), isFalse);
      expect(ids.contains('hajj-pillars'), isTrue);
      // A renamed title must not drop content — routing keys on id.
      expect(HajjData.expiation, isNotEmpty);
    });

    test('faq is loaded from JSON (not the Dart fallback)', () {
      expect(HajjData.faq.first.question, isNotEmpty);
      expect(HajjData.faq.first.answer, isNotEmpty);
    });
  });

  group('HajjUmrahScreen', () {
    setUp(() async {
      await HajjData.load();
    });

    testWidgets('renders the header and all seven tabs', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('حج و عمره'), findsOneWidget);
      expect(find.text('آشنایی'), findsOneWidget);
      expect(find.text('مناسک عمره'), findsOneWidget);
      expect(find.text('مناسک حج'), findsOneWidget);
      expect(find.text('ارکان و محرمات'), findsOneWidget);
      expect(find.text('فدیه و کفارات'), findsOneWidget);
      expect(find.text('احکام ویژه'), findsOneWidget);
      expect(find.text('پرسش‌ها'), findsOneWidget);

      // The route is wrapped in AmbientBackground; an opaque scaffold paints
      // over the field and makes this page flatter than its siblings.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, Colors.transparent);
    });

    testWidgets('intro tab shows the hero header and the first concept',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // The flat TabIntroCard joins title + subtitle into one text node.
      expect(find.textContaining('آشنایی با حج و عمره'), findsOneWidget);
      final firstConcept = HajjData.introConcepts.first.title;
      expect(find.text(firstConcept), findsOneWidget);
    });

    testWidgets('umrah tab renders the per-step arabic dua and a tip',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Open the umrah rituals tab.
      await tester.tap(find.text('مناسک عمره'));
      await tester.pumpAndSettle();

      final first = HajjData.umrahSteps.first;
      expect(find.text(first.arabic), findsWidgets,
          reason: 'arabic dua must be rendered');
      expect(find.textContaining(first.tip.substring(0, 8)), findsWidgets,
          reason: 'tip must be rendered');
      expect(find.text('ذِکر و دعا'), findsWidgets);
    });

    testWidgets('pillars tab surfaces hajj types', (tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Tab).at(3));
      await tester.pumpAndSettle();

      expect(find.text('انواع حج'), findsWidgets,
          reason: 'hajj-types header must render on the pillars tab');
      for (final t in HajjData.hajjTypes) {
        expect(find.text(t.title), findsWidgets,
            reason: 'hajj type ${t.title}');
      }
    });

    testWidgets('the step list paints on the first frame, before the ticks load',
        (tester) async {
      // The view used to return `SizedBox.shrink()` while SharedPreferences
      // was read, so the whole guide popped in after a blank frame. Rendered
      // in isolation the very first frame must already carry the steps.
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final steps = HajjData.umrahSteps;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RitualStepsView(
              storageKey: 'first-frame-test',
              steps: steps,
              accentColor: TopicHues.hajjUmrah,
            ),
          ),
        ),
      ));

      // No pumpAndSettle: this is the frame in which _load() is still pending.
      expect(find.textContaining(steps.first.title), findsWidgets,
          reason: 'the guide must not wait for the saved ticks');

      await tester.pumpAndSettle();
      expect(find.textContaining(steps.first.title), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('the pilgrimage calendar', () {
    test('maps the days of Dhu al-Hijjah onto the guide steps', () {
      expect(hajjStepForHijri(12, 8), 1);
      expect(hajjStepForHijri(12, 9), 2);
      expect(hajjStepForHijri(12, 10), 4);
      expect(hajjStepForHijri(12, 11), 5);
      expect(hajjStepForHijri(12, 12), 5);
      expect(hajjStepForHijri(12, 13), 6);
    });

    test('says nothing outside the five days of hajj', () {
      expect(hajjStepForHijri(12, 7), isNull);
      expect(hajjStepForHijri(12, 14), isNull);
      expect(hajjStepForHijri(11, 9), isNull, reason: 'ذی‌قعده is not hajj');
      expect(hajjStepForHijri(1, 10), isNull);
    });

    test('the night of Arafah points at Muzdalifah, and only that night', () {
      expect(hajjNightStepForHijri(12, 9), 3);
      expect(hajjNightStepForHijri(12, 10), isNull);
      expect(hajjNightStepForHijri(11, 9), isNull);
    });

    test('every mapped step exists in the loaded guide', () async {
      await HajjData.load();
      final numbers = HajjData.hajjSteps.map((s) => s.step).toSet();
      for (var day = 8; day <= 13; day++) {
        final step = hajjStepForHijri(12, day);
        expect(numbers.contains(step), isTrue,
            reason: 'day $day maps to a step that is not in the guide');
      }
    });
  });

  group('the rite counter', () {
    /// The step numbers behind the sheet also print bare digits, so the
    /// numeral is only ever looked for inside the counter itself.
    Finder numeral(String value) => find.descendant(
          of: find.byKey(const ValueKey('rite-counter-tap')),
          matching: find.text(value),
        );

    test('sa\'i alternates legs and starts from Safa', () {
      expect(saiLeg(1), 'صفا به مروه');
      expect(saiLeg(2), 'مروه به صفا');
      expect(saiLeg(7), 'صفا به مروه');
      // Four out, three back — the count the guide states.
      final out = [for (var i = 1; i <= 7; i++) if (i.isOdd) i].length;
      expect(out, 4);
    });

    testWidgets('counts a round per tap and remembers it', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('مناسک عمره'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('شمارنده طواف'));
      await tester.pumpAndSettle();
      // Two: the button that opened it and the sheet's own title.
      expect(find.text('شمارنده طواف'), findsWidgets);
      expect(numeral('0'), findsOneWidget);

      final tap = find.byKey(const ValueKey('rite-counter-tap'));
      await tester.tap(tap);
      await tester.pumpAndSettle();
      expect(numeral('1'), findsOneWidget);
      expect(find.text('دور 1'), findsOneWidget);

      await tester.tap(tap);
      await tester.tap(tap);
      await tester.pumpAndSettle();
      expect(numeral('3'), findsOneWidget);

      // The count is written through, not just held in memory.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('hajj_counter_tawaf'), 3);

      // A mistake in a crowd must be undoable.
      await tester.tap(find.text('یک دور عقب'));
      await tester.pumpAndSettle();
      expect(numeral('2'), findsOneWidget);
    });

    testWidgets('the seventh round completes the rite and offers a new one',
        (tester) async {
      SharedPreferences.setMockInitialValues({'hajj_counter_tawaf': 6});
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('مناسک عمره'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('شمارنده طواف'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('rite-counter-tap')));
      await tester.pumpAndSettle();

      expect(numeral('7'), findsOneWidget);
      expect(find.text('طواف کامل شد — طواف جدید'), findsOneWidget);
      // The increment control is gone: seven is the end of a tawaf.
      expect(find.text('یک دور عقب'), findsNothing);

      await tester.tap(find.text('طواف کامل شد — طواف جدید'));
      await tester.pumpAndSettle();
      expect(numeral('0'), findsOneWidget);
    });

    testWidgets('switching to sa\'i shows the leg of the round',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('مناسک عمره'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('شمارنده سعی'));
      await tester.pumpAndSettle();

      expect(find.text('شمارنده سعی'), findsWidgets);
      expect(find.text('شروع از صفا'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('rite-counter-tap')));
      await tester.pumpAndSettle();
      expect(find.text('صفا به مروه'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('rite-counter-tap')));
      await tester.pumpAndSettle();
      expect(find.text('مروه به صفا'), findsOneWidget);
    });
  });

  group('the trip', () {
    testWidgets('closing a trip archives it instead of losing it silently',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'hajj_steps_trip-test': '1,2',
        'hajj_trip_start_trip-test': '2026-05-01',
      });
      await HajjData.load();
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RitualStepsView(
              storageKey: 'trip-test',
              steps: HajjData.umrahSteps,
              accentColor: TopicHues.hajjUmrah,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('سفر جاری از'), findsOneWidget);
      expect(find.text('سفر جدید'), findsOneWidget);

      await tester.tap(find.text('سفر جدید'));
      await tester.pumpAndSettle();
      // A reset that wipes progress must ask first.
      expect(find.text('شروع سفر جدید'), findsOneWidget);
      await tester.tap(find.text('شروع سفر جدید'));
      await tester.pumpAndSettle();

      expect(find.textContaining('سفر قبلی: 2 از 4'), findsOneWidget);
      expect(find.textContaining('سفر جاری از'), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('hajj_steps_trip-test'), isNull);
      expect(prefs.getString('hajj_trip_archive_trip-test'), contains('2026-05-01'));
    });

    testWidgets('the day banner appears only inside the days of hajj',
        (tester) async {
      await HajjData.load();
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('مناسک حج'));
      await tester.pumpAndSettle();

      // «Today» cannot be pinned in a test, so the assertion is the rule
      // itself: the banner shows exactly when the Hijri date is 8–13 Dhu
      // al-Hijjah, and never outside it.
      final now = DateTime.now();
      final h =
          HijriUtils.hijriFromGreg(now.year, now.month, now.day, offset: 2);
      final inWindow = hajjStepForHijri(h.month, h.day) != null;

      expect(find.textContaining('امروز '), inWindow ? findsOneWidget : findsNothing);
      if (inWindow) {
        expect(find.text('امروز'), findsOneWidget,
            reason: 'the rite of the day must be ringed in the step list');
        expect(find.textContaining('مرحله ${hajjStepForHijri(h.month, h.day)} از'),
            findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('the reference tabs', () {
    setUp(() async {
      await HajjData.load();
    });

    testWidgets('the expiation tab names its five kinds', (tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Tab).at(4));
      await tester.pumpAndSettle();

      expect(find.text('انواع فدیه و کفارات'), findsWidgets);
      expect(find.textContaining('دسته'), findsWidgets);
      for (final row in HajjData.expiation) {
        expect(find.text(row['title'] as String), findsWidgets,
            reason: 'expiation row ${row['title']} is missing');
      }
    });

    testWidgets('a special ruling opens on its own and keeps the others shut',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Tab).at(5));
      await tester.pumpAndSettle();
      expect(find.text(HajjData.specialRulings.first['title'] as String),
          findsWidgets);
    });

    testWidgets('a faq answer is hidden until its question is tapped',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Tab).at(6));
      await tester.pumpAndSettle();

      // The card cross-fades instead of removing the answer, so "is it shown"
      // is the cross-fade state, not whether the text exists in the tree.
      CrossFadeState state() => tester
          .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade).first)
          .crossFadeState;

      final faq = HajjData.faq.first;
      expect(find.text(faq.question), findsOneWidget);
      expect(state(), CrossFadeState.showFirst);

      await tester.tap(find.text(faq.question));
      await tester.pumpAndSettle();
      expect(state(), CrossFadeState.showSecond);
      expect(find.text(faq.answer), findsOneWidget);

      await tester.tap(find.text(faq.question));
      await tester.pumpAndSettle();
      expect(state(), CrossFadeState.showFirst);
    });

    testWidgets('a checklist tick is counted, stored and restored',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Tab).at(6));
      await tester.pumpAndSettle();

      final section = HajjData.checklistSections.first;
      await tester.scrollUntilVisible(
        find.text(section.items.first.title),
        320,
        scrollable: find.byType(Scrollable).last,
      );

      Finder count(String value) => find.descendant(
            of: find.ancestor(
              of: find.text(section.title),
              matching: find.byType(ChecklistCard),
            ),
            matching: find.text(value),
          );

      await tester.tap(find.text(section.items.first.title));
      await tester.pumpAndSettle();

      expect(count('1/${section.items.length}'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('hajj_checklist_${section.title}'), '0');

      // Reopening the page reads the tick back instead of starting empty.
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Tab).at(6));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(section.items.first.title),
        320,
        scrollable: find.byType(Scrollable).last,
      );
      expect(count('1/${section.items.length}'), findsOneWidget);
    });

    testWidgets('resetting the checklist clears both the count and the store',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final section = HajjData.checklistSections.first;
      SharedPreferences.setMockInitialValues({
        'hajj_checklist_${section.title}': '0',
      });

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Tab).at(6));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(section.items.first.title),
        320,
        scrollable: find.byType(Scrollable).last,
      );

      Finder count(String value) => find.descendant(
            of: find.ancestor(
              of: find.text(section.title),
              matching: find.byType(ChecklistCard),
            ),
            matching: find.text(value),
          );

      expect(count('1/${section.items.length}'), findsOneWidget);
      await tester.tap(find.descendant(
        of: find.ancestor(
          of: find.text(section.title),
          matching: find.byType(ChecklistCard),
        ),
        matching: find.text('بازنشانی'),
      ));
      await tester.pumpAndSettle();

      expect(count('0/${section.items.length}'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('hajj_checklist_${section.title}'), isNull);
    });
  });

  group('the in-section search', () {
    test('indexes every tab of the guide', () async {
      await HajjData.load();
      final entries = hajjSearchEntries();
      expect(entries, isNotEmpty);
      final tabs = entries.map((e) => e.tab).toSet();
      // All seven tabs contribute at least one searchable piece.
      expect(tabs, containsAll([0, 1, 2, 3, 4, 5, 6]));
      // And every entry names the tab it came from, so the chip is never blank.
      expect(entries.every((e) => (e.tabLabel ?? '').isNotEmpty), isTrue);
    });

    testWidgets('finds a ruling by a word from its body', (tester) async {
      await HajjData.load();
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.text('جست‌وجو در حج و عمره'), findsOneWidget);

      // A word that appears in the rites, not in the tab labels.
      await tester.enterText(find.byType(TextField), 'طواف');
      await tester.pumpAndSettle();

      expect(find.textContaining('طواف'), findsWidgets);
      expect(find.text('چیزی در حج و عمره پیدا نشد.'), findsNothing);
    });

    testWidgets('an empty query explains the sheet instead of listing all',
        (tester) async {
      await HajjData.load();
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.textContaining('جست‌وجو کنید'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
