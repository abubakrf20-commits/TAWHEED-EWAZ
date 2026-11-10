import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/core/database/app_database.dart' show NoteTableData;
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/services/clock_ticker.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/adhkar/duas/domain/entities/dua_model.dart';
import 'package:tawheeed/features/adhkar/duas/presentation/screens/dua_detail_screen.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';
import 'package:tawheeed/features/search/presentation/screens/content_hit_reader_screen.dart';
import 'package:tawheeed/features/search/services/more_content_search.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/more/more_duotone.dart';
import 'package:tawheeed/features/settings/presentation/more/more_registry.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/screens/more_screen.dart';
import 'package:tawheeed/shared/widgets/in_app_browser_screen.dart';

import '../../../../core/database/mock_daos.dart';

/// The redesign's hero strip attaches the shared ClockTicker; a real one
/// would leave a recurring second-boundary timer pending at teardown. The
/// idle variant never schedules.
final _idleTicker = clockTickerProvider.overrideWith((ref) {
  final ticker = ClockTicker.idle();
  ref.onDispose(ticker.dispose);
  return ticker;
});

ProviderScope _wrap(
  Widget child, {
  ClockTicker? ticker,
  PrayerClock? clock,
}) {
  SharedPreferences.setMockInitialValues({});
  final mockRepo = MockSettingsRepository();
  mockRepo.setMockSettings(const AppSettings());
  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
      if (ticker == null)
        _idleTicker
      else
        clockTickerProvider.overrideWith((ref) => ticker),
      if (clock != null) prayerClockProvider.overrideWith((ref) => clock),
    ],
    child: child,
  );
}

/// The page hides the countdown until a prayer clock exists, so the strip
/// tests hand one over: a fixed noon schedule, or the same schedule read at
/// the current time.
({ClockTicker ticker, PrayerClock clock}) _stripClock({
  DateTime? now,
  Map<PrayerId, int> iqamahOffsets = const {},
}) {
  final ticker = ClockTicker.idle();
  if (now != null) ticker.second.value = now;
  final clock = PrayerClock(ticker, schedule: _scheduleAroundNoon());
  if (iqamahOffsets.isNotEmpty) clock.updateIqamahOffsets(iqamahOffsets);
  return (ticker: ticker, clock: clock);
}

/// [AppTheme.scaledFontSize] reads the user's font scale off
/// `textTheme.bodyMedium`, so that is the knob a scale test has to turn.
/// (`textTheme.apply()` is not usable here: AppTheme leaves several styles
/// with a null fontSize, which the factor assertion rejects.)
ThemeData _theme(double scale) {
  final base = AppTheme.light.textTheme;
  return AppTheme.light.copyWith(
    textTheme: base.copyWith(
      bodyMedium: base.bodyMedium
          ?.copyWith(fontSize: (base.bodyMedium!.fontSize!) * scale),
    ),
  );
}

/// A router whose every destination prints a marker, so a tap can be judged
/// by what the user actually sees on the next screen.
GoRouter _router({List<MoreContentSource>? sources}) {
  final seen = <String>{};
  final routes = <RouteBase>[
    GoRoute(
        path: '/more',
        builder: (_, __) => MoreScreen(contentSources: sources)),
    GoRoute(
      path: RouteNames.inAppBrowser,
      builder: (_, s) =>
          Marker('MARK:web:${(s.extra as InAppBrowserArgs).url}'),
    ),
    GoRoute(
      path: RouteNames.audioLibrary,
      builder: (_, s) => Marker('MARK:audio:${s.uri.queryParameters['cat']}'),
    ),
    // The two per-item destinations a content hit can deep-link to.
    GoRoute(
      path: RouteNames.noteEditor,
      builder: (_, s) => Marker('MARK:note:${(s.extra as NoteTableData).title}'),
    ),
    GoRoute(
      path: '/hadeeth-enc/:id',
      builder: (_, s) {
        // A deep-search hit hands the matched literal over as `?q=`, so the
        // marker has to show it or the highlight contract goes unpinned.
        final q = s.uri.queryParameters['q'];
        return Marker(
            'MARK:hadeeth-enc:${s.pathParameters['id']}${q == null ? '' : '?q=$q'}');
      },
    ),
    for (final item in kMoreItems)
      if ((item.kind == MoreKind.route || item.kind == MoreKind.lockedRoute) &&
          seen.add(item.destination))
        GoRoute(
          path: item.destination,
          builder: (_, __) => Marker('MARK:${item.destination}'),
        ),
  ];
  return GoRouter(initialLocation: '/more', routes: routes);
}

class Marker extends StatelessWidget {
  const Marker(this.tag, {super.key});
  final String tag;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(tag)));
}

/// A content source a widget test owns, so the deep layer answers with text
/// the test wrote rather than with whatever the assets happen to contain.
class _FakeSource extends MoreContentSource {
  _FakeSource(super.itemId, this.owned);

  final List<ContentPiece> owned;
  int calls = 0;

  @override
  Future<List<ContentPiece>> pieces(WidgetRef? ref) {
    calls++;
    return Future.value(owned);
  }
}

/// A source that is still fetching its section's text — the state the page
/// must show as «searching» instead of «nothing found».
class _PendingSource extends MoreContentSource {
  _PendingSource(super.itemId);

  final Completer<List<ContentPiece>> done = Completer();

  @override
  Future<List<ContentPiece>> pieces(WidgetRef? ref) => done.future;
}

/// A section whose text cannot be read at all (no local database, a corrupt
/// asset): the engine isolates it, the page must not notice.
class _ThrowingSource extends MoreContentSource {
  _ThrowingSource(super.itemId);

  @override
  Future<List<ContentPiece>> pieces(WidgetRef? ref) async =>
      throw StateError('no content on this device');
}

NoteTableData _note(String title) {
  final now = DateTime(2026, 10, 11);
  return NoteTableData(
    id: 'n-1',
    title: title,
    content: 'متن یادداشت',
    createdAt: now,
    updatedAt: now,
    tags: '',
    folder: '',
    isDone: false,
    colorIndex: 0,
    isPinned: false,
    audioPath: '',
    audioDurationMs: 0,
  );
}

/// A day whose times bracket noon: at 12:00 the next adhan is ظهر 12:10 and
/// its iqamah, with a 20-minute offset, 12:30.
DayTimes _day(int offset) {
  final d = DateTime(2026, 10, 9).add(Duration(days: offset));
  return DayTimes(
    fajr: DateTime(d.year, d.month, d.day, 6),
    sunrise: DateTime(d.year, d.month, d.day, 7, 30),
    dhuhr: DateTime(d.year, d.month, d.day, 12, 10),
    asr: DateTime(d.year, d.month, d.day, 15, 40),
    maghrib: DateTime(d.year, d.month, d.day, 18, 20),
    isha: DateTime(d.year, d.month, d.day, 19, 40),
  );
}

PrayerSchedule _scheduleAroundNoon() => PrayerSchedule(
      yesterday: _day(-1),
      today: _day(0),
      tomorrow: _day(1),
    );

void main() {
  testWidgets('MoreScreen builds without crashing', (tester) async {
    await tester.pumpWidget(_wrap(const MaterialApp(home: MoreScreen())));
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('بیشتر'), findsOneWidget);
  });

  // Runs before the navigation sweep: tapping the locked tile once unlocks it
  // for the rest of the session, and the sweep then has to tolerate either.
  testWidgets('تثبیت یقین is locked and asks for the password', (tester) async {
    // The tile grids are tall; keep every tile inside the
    // hit-testable viewport.
    await tester.binding.setSurfaceSize(const Size(900, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = _router();
    await tester.pumpWidget(_wrap(MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();

    // The tile shows a lock mark instead of opening directly.
    await tester.tap(find.text('تثبیت یقین'));
    await tester.pumpAndSettle();

    expect(find.text('بخش قفل‌شده'), findsOneWidget);
    expect(find.text('انصراف'), findsOneWidget);

    // Scoped to the dialog: the screen itself has a search field now.
    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    // Wrong password shows the error.
    await tester.enterText(dialogField, '0000');
    await tester.tap(find.text('ورود'));
    await tester.pumpAndSettle();
    expect(find.textContaining('رمز اشتباه'), findsOneWidget);

    // Correct password unlocks and closes the dialog.
    await tester.enterText(dialogField, yaqeenLockCode);
    await tester.tap(find.text('ورود'));
    await tester.pumpAndSettle();
    expect(find.text('بخش قفل‌شده'), findsNothing);
  });

  group('layout', () {
    // Captured across the two scales of the same width, so the test proves it
    // actually rendered bigger rather than silently ignoring the scale.
    final labelSizes = <String, double>{};

    for (final width in const [320.0, 360.0, 412.0]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets(
            'RTL, ${width.toInt()}dp, text scale $scale: every group lays out',
            (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 5000));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(_wrap(MaterialApp(
            theme: _theme(scale),
            home: const Directionality(
                textDirection: TextDirection.rtl, child: MoreScreen()),
          )));
          await tester.pumpAndSettle();

          // Every group and the utility list are on screen at once, so an
          // overflow anywhere in the page fails this pump.
          for (final group in MoreGroup.values) {
            expect(find.text(group.title), findsOneWidget,
                reason: '${group.title} header missing');
          }
          expect(find.text('نماز'), findsOneWidget);
          expect(find.text('هوش مصنوعی شرعی قاف'), findsOneWidget,
              reason: 'the longest title must not overflow its tile');

          final label = tester.widget<Text>(find.text('نماز')).style!.fontSize!;
          labelSizes['${width.toInt()}@$scale'] = label;
        });
      }
    }

    test('the 1.3 pass really rendered larger labels', () {
      for (final width in const [320, 360, 412]) {
        expect(labelSizes['$width@1.3'], greaterThan(labelSizes['$width@1.0']!),
            reason: 'text scale had no effect at ${width}dp');
      }
    });
  });

  group('search', () {
    /// The title layer, with the content layer silenced by default so a test
    /// of tile matching cannot be moved by what the guides happen to contain.
    Future<void> open(WidgetTester tester,
        {List<MoreContentSource> sources = const []}) async {
      await tester.binding.setSurfaceSize(const Size(412, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(MaterialApp(
        theme: _theme(1),
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: MoreScreen(contentSources: sources)),
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('keywords match, and only after the 150ms debounce',
        (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'rowzeh');

      // Inside the debounce window the page is still unfiltered…
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('میراث'), findsOneWidget);
      // …and one filtered rebuild later only روزه is left.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('روزه'), findsOneWidget);
      expect(find.text('میراث'), findsNothing);
      expect(find.text(MoreGroup.worship.title), findsOneWidget);
      expect(find.text(MoreGroup.tools.title), findsNothing);
    });

    testWidgets('an empty query shows every group; a miss shows the card',
        (tester) async {
      await open(tester);
      expect(find.text('تنظیمات'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'زززز');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('موردی پیدا نشد'), findsOneWidget);
      for (final group in MoreGroup.values) {
        expect(find.text(group.title), findsNothing);
      }

      // The clear button restores the full page.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('موردی پیدا نشد'), findsNothing);
      expect(find.text(MoreGroup.hadith.title), findsOneWidget);
    });

    testWidgets('the settings entry is searchable and stays a row',
        (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'پیکربندی');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('تنظیمات'), findsOneWidget);
      expect(find.text(MoreGroup.worship.title), findsNothing);
      // A SettingRow subtitle, not a tile label.
      expect(find.text('شخصی‌سازی و پیکربندی برنامه'), findsOneWidget);
    });
  });

  /// «چرت» is not in any tile title, subtitle or keyword — only in a guide's
  /// prose, which is exactly what the deep layer exists to find.
  group('content search', () {
    const guideBody = 'اگر چرت بزنانید وضو باطل می‌شود';

    List<MoreContentSource> guideLayer() => [
          _FakeSource('purification', const [
            ContentPiece('بطلان وضو', guideBody),
          ]),
        ];

    Future<void> open(WidgetTester tester,
        {List<MoreContentSource>? sources}) async {
      await tester.binding.setSurfaceSize(const Size(412, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(MaterialApp(
        theme: _theme(1),
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: MoreScreen(contentSources: sources)),
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('a word that only lives inside a section still reaches it',
        (tester) async {
      await open(tester, sources: guideLayer());
      await tester.enterText(find.byType(TextField), 'چرت');
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('در متن بخش‌ها'), findsOneWidget);
      // The heading the match sits under, its own section as the caption, and
      // the sentence itself — short enough to need no window.
      expect(find.text('بطلان وضو'), findsOneWidget);
      expect(find.text(moreItemById('purification')!.title), findsOneWidget,
          reason: 'the row names the section it was found inside');
      // The snippet is painted (Text.rich), so the row carries the sentence
      // with the searched word shaded rather than a plain Text.
      expect(find.textContaining(guideBody, findRichText: true), findsOneWidget);
      // No tile matched, so the group headers are gone.
      expect(find.text(MoreGroup.worship.title), findsNothing);
      expect(find.text('موردی پیدا نشد'), findsNothing);
    });

    testWidgets('both layers answer at once, tiles first', (tester) async {
      await open(tester, sources: guideLayer());
      await tester.enterText(find.byType(TextField), 'وضو');
      await tester.pump(const Duration(milliseconds: 200));

      // «وضو» is the طهارت tile's own word, and the guide prose repeats it.
      expect(find.text(MoreGroup.worship.title), findsOneWidget);
      expect(find.text('در متن بخش‌ها'), findsOneWidget);
      expect(
          tester.getTopLeft(find.text('در متن بخش‌ها')).dy,
          greaterThan(tester.getTopLeft(find.text(MoreGroup.worship.title)).dy),
          reason: 'the content block reads below the tiles');
    });

    testWidgets('below two characters no section is asked at all',
        (tester) async {
      final source = _FakeSource('purification', const []);
      await open(tester, sources: [source]);

      await tester.enterText(find.byType(TextField), 'چ');
      await tester.pump(const Duration(milliseconds: 200));
      expect(source.calls, 0, reason: 'one character is not a search');
      expect(find.text('در متن بخش‌ها'), findsNothing);
    });

    testWidgets('a section that is still answering shows a spinner',
        (tester) async {
      final pending = _PendingSource('purification');
      await open(tester, sources: [pending]);

      await tester.enterText(find.byType(TextField), 'چرت');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('موردی پیدا نشد'), findsNothing,
          reason: 'still searching is not nothing found');

      pending.done.complete(const [
        ContentPiece('بطلان وضو', guideBody),
      ]);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining(guideBody, findRichText: true), findsOneWidget);
    });

    testWidgets('clearing the field drops the content rows', (tester) async {
      await open(tester, sources: guideLayer());
      await tester.enterText(find.byType(TextField), 'چرت');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('در متن بخش‌ها'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('در متن بخش‌ها'), findsNothing);
      expect(find.textContaining(guideBody, findRichText: true), findsNothing);
      expect(find.text(MoreGroup.worship.title), findsOneWidget);
    });

    testWidgets('a broken source cannot take the page down with it',
        (tester) async {
      await open(tester, sources: [_ThrowingSource('purification')]);
      await tester.enterText(find.byType(TextField), 'چرت');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('در متن بخش‌ها'), findsNothing);
      expect(find.text('موردی پیدا نشد'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('content results route', () {
    Future<void> openRouter(WidgetTester tester,
        List<MoreContentSource> sources) async {
      await tester.binding.setSurfaceSize(const Size(900, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
          _wrap(MaterialApp.router(routerConfig: _router(sources: sources))));
      await tester.pumpAndSettle();
    }

    testWidgets('a guide hit opens the matched block, word painted',
        (tester) async {
      await openRouter(tester, [
        _FakeSource('purification', const [
          ContentPiece('بطلان وضو', 'اگر چرت بزنانید وضو باطل می‌شود'),
        ]),
      ]);
      await tester.enterText(find.byType(TextField), 'چرت');
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('بطلان وضو'));
      await tester.pumpAndSettle();

      // A section with no per-item route lands on the exact block that holds
      // the match, carrying the literal the engine projected onto the text.
      final reader = tester.widget<ContentHitReaderScreen>(
          find.byType(ContentHitReaderScreen));
      expect(reader.hit.highlightQuery, 'چرت');
      expect(reader.hit.body, contains('چرت بزنانید'));

      // …and the owning section stays one tap away.
      final owner = moreItemById('purification')!;
      await tester.tap(find.text('رفتن به بخش «${owner.title}»'));
      await tester.pumpAndSettle();
      expect(find.text('MARK:${owner.destination}'), findsOneWidget);
    });

    testWidgets('a note hit opens that note', (tester) async {
      await openRouter(tester, [
        _FakeSource('worship-notes', [
          ContentPiece('یادداشت نماز', 'چرت در نماز',
              entity: _note('یادداشت نماز')),
        ]),
      ]);
      await tester.enterText(find.byType(TextField), 'چرت');
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('یادداشت نماز'));
      await tester.pumpAndSettle();
      expect(find.text('MARK:note:یادداشت نماز'), findsOneWidget);
    });

    testWidgets('an encyclopedia hadith hit opens it by id', (tester) async {
      await openRouter(tester, [
        _FakeSource('hadeeth-enc', const [
          ContentPiece('حدیث 34', 'چرت نگرفته از مسجد نماز ندارد', entity: 34),
        ]),
      ]);
      await tester.enterText(find.byType(TextField), 'چرت');
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('حدیث 34'));
      await tester.pumpAndSettle();
      // The literal rides along as `?q=` so the card can shade the word.
      expect(find.text('MARK:hadeeth-enc:34?q=چرت'), findsOneWidget);
    });

    testWidgets('a dua hit opens that dua’s reader', (tester) async {
      const dua = DuaModel(
        id: 'c1s2',
        title: 'دعای صبح',
        arabicText: 'اللہ اعلم',
        translation: 'خداوند داناتر است',
        source: 'حصن مسلم',
      );
      await openRouter(tester, [
        _FakeSource('duas', const [
          ContentPiece('دعای صبح', 'چرت ذکر نکند', entity: dua),
        ]),
      ]);
      await tester.enterText(find.byType(TextField), 'چرت');
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('دعای صبح'));
      await tester.pumpAndSettle();
      expect(find.byType(DuaDetailScreen), findsOneWidget);
      expect(find.text('خداوند داناتر است'), findsOneWidget);
    });
  });

  testWidgets('the utility rows are direct rows on the page', (tester) async {
    // User decision: these must not hide behind the settings screen.
    await tester.binding.setSurfaceSize(const Size(412, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(MaterialApp(
      theme: _theme(1),
      home: const Directionality(
          textDirection: TextDirection.rtl, child: MoreScreen()),
    )));
    await tester.pumpAndSettle();

    // The app group is a row list inside one card: five 40dp mini tiles and
    // the captions, not tiles.
    expect(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.constraints ==
                const BoxConstraints.tightFor(width: 40, height: 40)),
        findsNWidgets(5),
        reason: 'the app group rows carry the mini squircle');
    expect(
        find.ancestor(of: find.text('تنظیمات'), matching: find.byType(AppCard)),
        findsOneWidget,
        reason: 'the rows live in the utility card');
    for (final caption in [
      'حساب ابری، پشتیبان و بازیابی اطلاعات',
      'اطلاعیه‌ها و پیام‌های رسمی برنامه',
      'پیشنهاد، انتقاد یا گزارش خطا',
      'نسخه و اطلاعات برنامه',
    ]) {
      expect(find.text(caption), findsOneWidget, reason: '$caption missing');
    }
  });

  group('style-2 metrics', () {
    Finder tilesOf(double s) => find.byWidgetPredicate((w) =>
        w is Container &&
        w.constraints == BoxConstraints.tightFor(width: s, height: s));

    /// Grid width = screen − 2×page padding (10) − 2×card padding (6)
    /// − the card's two 0.5px hairlines, which Container lays the child
    /// inside of. Divided by the four columns the user asked for.
    double expectedS(double width) => moreTileSize((width - 20 - 12 - 1) / 4);

    Future<void> pump(WidgetTester tester, double width) async {
      await tester.binding.setSurfaceSize(Size(width, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(MaterialApp(
        theme: _theme(1),
        home: const Directionality(
            textDirection: TextDirection.rtl, child: MoreScreen()),
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('every grid tile is a square inside the 52–72 clamp',
        (tester) async {
      for (final width in const [320.0, 360.0, 412.0, 600.0]) {
        await pump(tester, width);
        final s = expectedS(width);
        expect(s, inInclusiveRange(52, 72), reason: 'width $width');
        // 53 registry items minus the 5 app-group rows — and every tile,
        // including the personal tools, is laid out.
        expect(tilesOf(s), findsNWidgets(48),
            reason: '${width}dp must lay out the whole grid');
      }
    });

    testWidgets('four tiles share a row and the neighbor gap stays in range',
        (tester) async {
      for (final width in const [320.0, 360.0, 412.0]) {
        await pump(tester, width);
        final s = expectedS(width);
        final worship = find.descendant(
            of: find.byType(AppCard).first, matching: tilesOf(s));
        // 18 since the worship-move commits (silat-al-rahim, quran-teacher,
        // kaffara, and now the kids habit ledger).
        expect(worship, findsNWidgets(18),
            reason: '${width}dp: the عبادات grid must be intact');
        // The first four tiles are one row: same top, one cell apart.
        final first = tester.getRect(worship.at(0));
        final cell =
            (tester.getRect(worship.at(1)).center - first.center).dx.abs();
        for (var i = 1; i < 4; i++) {
          final rect = tester.getRect(worship.at(i));
          expect((rect.top - first.top).abs(), lessThan(1),
              reason: 'tile ${i + 1} wrapped instead of joining row 1');
          expect((rect.center.dx - (first.center.dx - cell * i)).abs(),
              lessThan(1),
              reason: 'tile ${i + 1} is not one cell further along');
        }
        expect(cell - s, inInclusiveRange(18, 34),
            reason: '${width}dp neighbor gap ${cell - s}');
      }
    });

    testWidgets('at 600 the S-cap wins and the gap is the documented one',
        (tester) async {
      // S is capped at 72 so a tablet does not get poster-sized icons: past
      // ~450dp the edge gap grows instead of the tile.
      await pump(tester, 600);
      final s = expectedS(600);
      expect(s, 72);
      final worship =
          find.descendant(of: find.byType(AppCard).first, matching: tilesOf(s));
      final gap = (tester.getRect(worship.at(1)).center -
              tester.getRect(worship.at(0)).center)
          .dx
          .abs() -
          s;
      expect(gap, closeTo((600 - 20 - 12 - 1) / 4 - 72, .1));
      expect(gap, closeTo(69.75, .1));
    });

    testWidgets('a short last row starts at the start edge', (tester) async {
      await pump(tester, 412);
      final s = expectedS(412);
      // The merged عبادات card holds 18 items (since the worship-move commits)
      // → four full rows + 2 orphans.
      final worshipCard = find.byType(AppCard).first;
      final tiles = find.descendant(of: worshipCard, matching: tilesOf(s));
      expect(tiles, findsNWidgets(18));
      // Widget order is registry order, so it is the deterministic reference:
      // tile 0 is the RTL start of row 1, tile 1 the one left of it.
      final row1Start = tester.getRect(tiles.at(0));
      final rects = [
        for (var i = 0; i < 18; i++) tester.getRect(tiles.at(i)),
      ];
      final lastTop = rects.map((r) => r.top).reduce((a, b) => a > b ? a : b);
      final lastRow = [
        for (final r in rects)
          if ((r.top - lastTop).abs() < 1) r,
      ];
      expect(lastRow.length, 2);
      final orphanStart = lastRow.reduce((a, b) => a.right > b.right ? a : b);
      // RTL: the orphan row hugs the SAME (right) edge as row 1 — never
      // centered, and its first tile is the grid's 17th entry.
      expect(orphanStart.right, closeTo(row1Start.right, .5),
          reason: 'last-row tile must be start-aligned (RTL: right)');
      final cardRect = tester.getRect(worshipCard.first);
      expect((orphanStart.center.dx - cardRect.center.dx).abs(), greaterThan(1),
          reason: 'and must not be centered');
    });

    testWidgets('tiles advertise themselves as tappable buttons',
        (tester) async {
      await pump(tester, 412);
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == 'نماز'),
        findsOneWidget,
        reason: 'Semantics(button, title) is the accessibility contract',
      );
    });
  });

  group('next-prayer strip', () {
    testWidgets('the countdown measures the adhan, never the iqamah',
        (tester) async {
      final ticker = ClockTicker.idle()
        ..second.value = DateTime(2026, 10, 9, 12);
      final clock = PrayerClock(ticker, schedule: _scheduleAroundNoon())
        ..updateIqamahOffsets({PrayerId.dhuhr: 20});
      addTearDown(clock.dispose);
      addTearDown(ticker.dispose);

      await tester.binding.setSurfaceSize(const Size(412, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(
        MaterialApp(
          theme: _theme(1),
          home: const Directionality(
              textDirection: TextDirection.rtl, child: MoreScreen()),
        ),
        ticker: ticker,
        clock: clock,
      ));
      await tester.pumpAndSettle();

      // The strip names ظهر's adhan (12:10) and its iqamah (12:30) together;
      // the number has to be the ten minutes to the adhan it shows.
      expect(find.text('اذان ظهر'), findsOneWidget);
      expect(find.textContaining('اقامه'), findsOneWidget);
      expect(find.text('00:10:00'), findsOneWidget);
      expect(find.text('00:30:00'), findsNothing);
    });

    testWidgets(
        'A-02: at 320dp and text scale 1.333 both times stay visible, '
        'wrapping instead of being cut', (tester) async {
      final ticker = ClockTicker.idle()
        ..second.value = DateTime(2026, 10, 9, 12);
      final clock = PrayerClock(ticker, schedule: _scheduleAroundNoon())
        ..updateIqamahOffsets({PrayerId.dhuhr: 20});
      addTearDown(clock.dispose);
      addTearDown(ticker.dispose);

      // `setSurfaceSize` resizes layout but leaves MediaQuery at the default
      // 800x600, so a widget that reads MediaQuery (the countdown's width cap)
      // would be tested against the wrong screen. Drive the view instead.
      tester.view.physicalSize = const Size(320 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.333;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(_wrap(
        MaterialApp(
          theme: _theme(1),
          home: const Directionality(
              textDirection: TextDirection.rtl, child: MoreScreen()),
        ),
        ticker: ticker,
        clock: clock,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'the strip must grow, never overflow');

      final timeLine = find.textContaining('اقامه');
      expect(timeLine, findsOneWidget);
      expect(find.textContaining('12:30'), findsOneWidget,
          reason: 'the iqamah time itself must render');

      final text = tester.widget<Text>(timeLine);
      expect(text.maxLines, isNull,
          reason: 'a maxLines cap is what turned the second row into «…»');
      expect(text.overflow, isNot(TextOverflow.ellipsis));

      final paragraph =
          tester.renderObject<RenderParagraph>(timeLine);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.size.height, greaterThan(30),
          reason: 'at 1.333 the line needs two rows; one row is ~20px');
    });

    testWidgets('tapping the strip activates the home tab', (tester) async {
      final strip = _stripClock();
      addTearDown(strip.clock.dispose);
      addTearDown(strip.ticker.dispose);
      await tester.binding.setSurfaceSize(const Size(412, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(
        MaterialApp(
          theme: _theme(1),
          home: const Directionality(
              textDirection: TextDirection.rtl, child: MoreScreen()),
        ),
        ticker: strip.ticker,
        clock: strip.clock,
      ));
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(MoreScreen));
      final container = ProviderScope.containerOf(element);
      // Start from another tab, then use the strip as the shortcut it is.
      container.read(shellTabIndexProvider.notifier).setIndex(2);
      await tester.pump();
      expect(container.read(shellTabIndexProvider), 2);

      await tester.tap(find.textContaining('اذان').first);
      await tester.pumpAndSettle();
      expect(container.read(shellTabIndexProvider), 0);
    });

    testWidgets('the page stays flat: no blur and no drop shadows',
        (tester) async {
      final strip = _stripClock();
      addTearDown(strip.clock.dispose);
      addTearDown(strip.ticker.dispose);
      await tester.binding.setSurfaceSize(const Size(412, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(
        MaterialApp(
          theme: _theme(1),
          home: const Directionality(
              textDirection: TextDirection.rtl, child: MoreScreen()),
        ),
        ticker: strip.ticker,
        clock: strip.clock,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
      for (final box in tester.widgetList<Container>(find.byType(Container))) {
        final deco = box.decoration;
        if (deco is BoxDecoration) {
          expect(deco.boxShadow, anyOf(isNull, isEmpty),
              reason: 'large-blur shadows are banned on the tiles');
        }
      }
    });
  });

  testWidgets('every registry entry navigates to its own destination',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = _router();
    await tester.pumpWidget(_wrap(MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();

    for (final item in kMoreItems) {
      await tester.tap(find.text(item.title).first);
      await tester.pumpAndSettle();

      // The locked entry may or may not still ask, depending on whether an
      // earlier test in this file already unlocked it for the session.
      if (find.byType(AlertDialog).evaluate().isNotEmpty) {
        await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(TextField)),
          item.lockCode!,
        );
        await tester.tap(find.text('ورود'));
        await tester.pumpAndSettle();
      }

      final expected = switch (item.kind) {
        MoreKind.route || MoreKind.lockedRoute => 'MARK:${item.destination}',
        MoreKind.web => 'MARK:web:${item.destination}',
        MoreKind.audioCategory => 'MARK:audio:${item.destination}',
      };
      expect(find.text(expected), findsOneWidget,
          reason: '${item.id} did not open ${item.destination}');

      router.go('/more');
      await tester.pumpAndSettle();
    }
  });
}
