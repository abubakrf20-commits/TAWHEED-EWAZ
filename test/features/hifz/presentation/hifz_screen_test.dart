import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_review_model.dart';
import 'package:tawheeed/features/hifz/domain/hifz_helpers.dart';
import 'package:tawheeed/features/hifz/presentation/providers/hifz_provider.dart';
import 'package:tawheeed/features/hifz/presentation/screens/hifz_screen.dart';

final _now = DateTime.now();

const _lessonRange = (sFrom: 2, aFrom: 1, sTo: 2, aTo: 6);
const _sabaqRange = (sFrom: 18, aFrom: 1, sTo: 18, aTo: 1);
const _murajaahRange = (sFrom: 36, aFrom: 1, sTo: 36, aTo: 1);

String _label(({int sFrom, int aFrom, int sTo, int aTo}) r) =>
    rangeLabel(r.sFrom, r.aFrom, r.sTo, r.aTo);

/// [d] with the time-of-day dropped, so a week count is a calendar count.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The Saturday that starts [d]'s week, at local midnight.
DateTime _saturdayOf(DateTime d) =>
    _dateOnly(d).subtract(Duration(days: (d.weekday - DateTime.saturday) % 7));

/// Whole days from [a] to [b], counted on the calendar rather than the clock:
/// building the pair in UTC keeps a daylight-saving shift out of the
/// difference, and `Duration.inDays` on exact whole days never truncates.
int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
        b.year, b.month, b.day)
    .difference(DateTime.utc(a.year, a.month, a.day))
    .inDays;

/// The first Jalali month boundary at or after [d], midnight.
DateTime _nextJalaliBoundary(DateTime d) {
  var j = Jalali.fromDateTime(d);
  j = j.month == 12 ? Jalali(j.year + 1) : Jalali(j.year, j.month + 1);
  return j.toDateTime();
}

/// The «هفتهٔ قبل» tap count from the screen's starting week (its Saturday at
/// [now]) to a week that STRADDLES a Jalali month boundary — the week whose
/// Saturday precedes the boundary, so the boundary falls on day 2..7 of it
/// and the label takes its longest intra-year form.
/// Negative → «هفتهٔ بعد» taps instead.
int _stepsToCrossingWeek(DateTime now) {
  var probe = now;
  for (var attempt = 0; attempt < 4; attempt++) {
    final boundary = _nextJalaliBoundary(probe);
    final dayOf = _daysBetween(_saturdayOf(boundary), boundary);
    if (dayOf > 0) {
      final weeks = _daysBetween(_saturdayOf(boundary), _saturdayOf(now));
      assert(weeks % 7 == 0);
      return weeks ~/ 7;
    }
    probe = boundary.add(const Duration(days: 20));
  }
  fail('no month-crossing week reachable');
}

Future<void> _pumpScreen(WidgetTester tester, ProviderContainer container) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HifzScreen()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('filters حفظ/سبق/مراجعه by the selected day', (tester) async {
    final notifier = container.read(hifzProvider.notifier);
    await notifier.addHafiz(name: 'محمد');
    final hafizId = container.read(hifzProvider).hafizs.first.id;

    // Today: a lesson + a sabaq. One week ago: a muraja'ah.
    await notifier.addLesson(
      hafizId: hafizId,
      date: _now,
      surahFrom: _lessonRange.sFrom,
      ayahFrom: _lessonRange.aFrom,
      surahTo: _lessonRange.sTo,
      ayahTo: _lessonRange.aTo,
      pages: 2,
    );
    await notifier.addReview(
      hafizId: hafizId,
      date: _now,
      type: ReviewType.sabaq,
      surahFrom: _sabaqRange.sFrom,
      ayahFrom: _sabaqRange.aFrom,
      surahTo: _sabaqRange.sTo,
      ayahTo: _sabaqRange.aTo,
      pages: 1,
      quality: ReviewQuality.excellent,
    );
    await notifier.addReview(
      hafizId: hafizId,
      date: _now.subtract(const Duration(days: 7)),
      type: ReviewType.murajaah,
      surahFrom: _murajaahRange.sFrom,
      ayahFrom: _murajaahRange.aFrom,
      surahTo: _murajaahRange.sTo,
      ayahTo: _murajaahRange.aTo,
      pages: 1,
      quality: ReviewQuality.medium,
    );

    await _pumpScreen(tester, container);
    await tester.pumpAndSettle();

    // Today's records are listed…
    expect(find.text(_label(_lessonRange)), findsOneWidget);
    expect(find.text(_label(_sabaqRange)), findsOneWidget);
    // …while the muraja'ah from another day is hidden with an empty state.
    expect(find.text(_label(_murajaahRange)), findsNothing);
    expect(
      find.textContaining('مراجعهای در این روز ثبت نشده'),
      findsOneWidget,
    );
  });

  testWidgets('navigates to a previous week and shows that day\'s records',
      (tester) async {
    final notifier = container.read(hifzProvider.notifier);
    await notifier.addHafiz(name: 'محمد', sabaqWindowDays: 30);
    final hafizId = container.read(hifzProvider).hafizs.first.id;

    final lastWeek = _now.subtract(const Duration(days: 7));
    await notifier.addLesson(
      hafizId: hafizId,
      date: lastWeek,
      surahFrom: _lessonRange.sFrom,
      ayahFrom: _lessonRange.aFrom,
      surahTo: _lessonRange.sTo,
      ayahTo: _lessonRange.aTo,
      pages: 2,
    );
    await notifier.addReview(
      hafizId: hafizId,
      date: _now,
      type: ReviewType.sabaq,
      surahFrom: _sabaqRange.sFrom,
      ayahFrom: _sabaqRange.aFrom,
      surahTo: _sabaqRange.sTo,
      ayahTo: _sabaqRange.aTo,
      pages: 1,
      quality: ReviewQuality.excellent,
    );

    await _pumpScreen(tester, container);
    await tester.pumpAndSettle();

    // Today's sabaq is visible, last week's lesson is not.
    expect(find.text(_label(_sabaqRange)), findsOneWidget);
    expect(find.text(_label(_lessonRange)), findsNothing);

    // Go back one week, then select the day with the lesson.
    await tester.tap(find.byTooltip('هفتهٔ قبل'));
    await tester.pumpAndSettle();

    final jLastWeek = Jalali.fromDateTime(lastWeek);
    await tester.tap(find
        .ancestor(
          of: find.text(en(jLastWeek.day)),
          matching: find.byType(GestureDetector),
        )
        .first);
    await tester.pumpAndSettle();

    expect(find.text(_label(_lessonRange)), findsOneWidget);
    expect(find.text(_label(_sabaqRange)), findsNothing);
    // The sabaq section is empty for a day with no سَبَق. Depending on
    // whether the lesson still falls inside the suggestion window, the
    // empty state is either the day-empty text or the onboarding hint.
    expect(
      find.byWidgetPredicate((w) =>
          w is Text &&
          w.data != null &&
          (w.data!.contains('سبقی در این روز') ||
              w.data!.contains('سپس سبق از محفوظات'))),
      findsOneWidget,
    );
  });

  testWidgets('calendar button opens the Shamsi date picker dialog',
      (tester) async {
    final notifier = container.read(hifzProvider.notifier);
    await notifier.addHafiz(name: 'محمد');

    await _pumpScreen(tester, container);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('انتخاب از تقویم'));
    await tester.pumpAndSettle();

    expect(find.text('امروز'), findsOneWidget);
    expect(find.text('تأیید'), findsOneWidget);

    // Cancel closes the dialog without changing the selection.
    await tester.tap(find.text('لغو'));
    await tester.pumpAndSettle();
    expect(find.text('امروز'), findsNothing);
  });

  testWidgets(
      'the week label fits 320 dp at scale 1.3 on a month-crossing week',
      (tester) async {
    // Real Persian metrics: the binding font draws glyphs ~1.7x wider than
    // Vazirmatn (see system_nav_inset_test.dart's loadVazirmatn note), so the
    // un-limited label overflowed there in tofu that fits on a real phone —
    // and squeezed on real 320dp phones at scale 1.3.
    final loader = FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
    await loader.load();
    AppTheme.fontFamily = 'Vazirmatn';
    addTearDown(() => AppTheme.fontFamily = AppTheme.defaultFontFamily);

    await container.read(hifzProvider.notifier).addHafiz(name: 'محمد');

    final steps = _stepsToCrossingWeek(_now);
    final back = steps > 0;

    tester.view.physicalSize = const Size(320, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            theme: ThemeData(fontFamily: AppTheme.fontFamily),
            home: const HifzScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (var i = 0; i < steps.abs(); i++) {
      await tester
          .tap(find.byTooltip(back ? 'هفتهٔ قبل' : 'هفتهٔ بعد'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    // The label is a Row-level Flexible + FittedBox(scaleDown): it always
    // fits — the old bare Text threw a ~9.8 px overflow on this week.
    expect(tester.takeException(), isNull);
    // And the recipe itself is what guarantees ANY future label fits, so pin
    // it structurally: a FittedBox lives between the two week arrows (the
    // Row-level Flexible wraps it — a Flexible nested inside the label's own
    // Text could never bound it).
    final rightArrow = tester.getRect(find.byTooltip('هفتهٔ قبل')).center.dx;
    final leftArrow = tester.getRect(find.byTooltip('هفتهٔ بعد')).center.dx;
    expect(rightArrow, greaterThan(leftArrow), reason: 'RTL row');
    var labelInRow = false;
    for (final w in tester.widgetList<FittedBox>(find.byType(FittedBox))) {
      final r = tester.getRect(find.byWidget(w));
      if (r.center.dx > leftArrow && r.center.dx < rightArrow) {
        labelInRow = true;
      }
    }
    expect(labelInRow, isTrue,
        reason: 'the week label must render inside a FittedBox');
  });
}
