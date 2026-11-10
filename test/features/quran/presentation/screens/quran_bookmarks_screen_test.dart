import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/quran/data/daos/quran_bookmark_dao.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';
import 'package:tawheeed/features/quran/presentation/providers/quran_bookmark_provider.dart';
import 'package:tawheeed/features/quran/presentation/screens/quran_bookmarks_screen.dart';

/// The bookmark list, read through the reader's own palette (report §6.1).
///
/// It used to read the app's time theme, so opening it from a night page
/// cross-faded into the light theme and its rows wore the theme's flat accent
/// tile. These tests pin what changed: every surface follows the paper the
/// screen was opened from, the row is the shared reader kit row — which is also
/// what now carries a note (§7.4) — and the list is fed by the shared provider
/// rather than a stream rebuilt on every frame.
///
/// The store below is a fake: drift's streams carry a live timer that a widget
/// test's fake clock can never drain, so the real store is exercised in
/// `test/features/quran/data/daos/quran_bookmark_note_test.dart` instead.
class _FakeBookmarkDao extends QuranBookmarkDao {
  // The generated mixin needs an AppDatabase, and drift warns when a process
  // builds more than one — so the whole file shares this never-opened,
  // in-memory instance, which nothing here ever queries.
  static final AppDatabase _db =
      AppDatabase.withConnection(NativeDatabase.memory());

  _FakeBookmarkDao() : super(_db);

  final List<QuranBookmarkTableData> rows = [];
  final StreamController<List<QuranBookmarkTableData>> _updates =
      StreamController<List<QuranBookmarkTableData>>.broadcast();

  int _nextId = 1;

  /// Puts a bookmark straight in, before the screen has subscribed. Returns its
  /// row id, which is what the row's own key carries. Later seeds are newer
  /// (a millisecond apart), which is what makes the newest-first default
  /// observable to the sort test.
  int seed(int surah, int ayah, {String? note}) {
    final row = QuranBookmarkTableData(
      id: _nextId++,
      surah: surah,
      ayah: ayah,
      note: note,
      createdAt: DateTime(2026, 10, 12).add(Duration(milliseconds: _nextId)),
    );
    rows.add(row);
    return row.id;
  }

  Future<void> dispose() => _updates.close();

  void _emit() => _updates.add(List.of(rows));

  @override
  Stream<List<QuranBookmarkTableData>> watchAll() async* {
    yield List.of(rows);
    yield* _updates.stream;
  }

  @override
  Future<QuranBookmarkTableData?> getByAyah(int surah, int ayah) async {
    for (final r in rows) {
      if (r.surah == surah && r.ayah == ayah) return r;
    }
    return null;
  }

  @override
  Future<int> add(int surah, int ayah, {String? note}) async {
    final id = seed(surah, ayah, note: note);
    _emit();
    return id;
  }

  @override
  Future<bool> removeByAyah(int surah, int ayah) async {
    final before = rows.length;
    rows.removeWhere((r) => r.surah == surah && r.ayah == ayah);
    if (rows.length == before) return false;
    _emit();
    return true;
  }

  @override
  Future<String?> setNote(int surah, int ayah, String? note) async {
    final stored = (note == null || note.trim().isEmpty) ? null : note.trim();
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      if (r.surah == surah && r.ayah == ayah) {
        rows[i] = QuranBookmarkTableData(
          id: r.id,
          surah: r.surah,
          ayah: r.ayah,
          note: stored,
          createdAt: r.createdAt,
        );
      }
    }
    _emit();
    return stored;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBookmarkDao dao;

  setUp(() {
    dao = _FakeBookmarkDao();
  });

  tearDown(() async {
    await dao.dispose();
  });

  /// A row by its own key. `find.byType(Dismissible)` cannot be used: a SnackBar
  /// wraps itself in a Dismissible too, so the swipe tests would find the undo
  /// bar's instead of the row's.
  Finder rowFinder(int id) => find.byKey(ValueKey('bm_$id'));

  Widget host(
    MushafPalette palette, {
    void Function(int surah, int ayah)? onGoToPage,
  }) =>
      ProviderScope(
        overrides: [quranBookmarkDaoProvider.overrideWithValue(dao)],
        child: MaterialApp(
          // RTL like the app, so the swipe direction and the row order are the
          // real ones.
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: QuranBookmarksScreen(
              palette: palette,
              onGoToPage: onGoToPage,
            ),
          ),
        ),
      );

  /// Draws until both the frame queue and the list stream are idle.
  ///
  /// A stream event can land on the microtask that follows the last frame (the
  /// dismiss animation finishes, *then* the store write and its emission), so a
  /// single `pumpAndSettle` can return one frame early.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('the empty state speaks for the reader', (tester) async {
    await tester.pumpWidget(host(MushafPalette.light));
    await settle(tester);

    expect(find.text('هنوز نشانی ثبت نشده'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('chrome, paper and rows follow the palette, not the app theme',
      (tester) async {
    const night = MushafPalette.night;
    dao.seed(1, 1, note: 'یادداشت من');

    await tester.pumpWidget(host(night));
    await settle(tester);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, night.background,
        reason: 'the paper is the reader\'s, not the app theme\'s');

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, night.chrome);
    expect(appBar.foregroundColor, night.onChrome);

    // The row carries the ayah identity and the reader's own note.
    expect(find.textContaining('آیه'), findsOneWidget);
    expect(find.textContaining('یادداشت من', findRichText: true),
        findsOneWidget);
  });

  testWidgets('the swipe reveals the paper\'s own error red', (tester) async {
    final id = dao.seed(2, 255);

    await tester.pumpWidget(host(MushafPalette.night));
    await settle(tester);

    // The revealed card is the Dismissible's own `background`, so assert on it
    // rather than on the first Container found in the subtree (the row's icon
    // tile is one too). Night paper takes the brighter red.
    final dismissible = tester.widget<Dismissible>(rowFinder(id));
    final background = dismissible.background! as Container;
    final decoration = background.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFEF5350),
        reason: 'the card no longer asks the app theme for its error colour');
  });

  testWidgets('tapping a row hands the reader its ayah', (tester) async {
    final jumps = <String>[];
    final id = dao.seed(2, 255);

    await tester.pumpWidget(host(
      MushafPalette.light,
      onGoToPage: (surah, ayah) => jumps.add('$surah:$ayah'),
    ));
    await settle(tester);

    await tester.tap(rowFinder(id));
    await settle(tester);

    expect(jumps, ['2:255']);
  });

  testWidgets('a swipe deletes, and the undo bar puts it back with its note',
      (tester) async {
    final id = dao.seed(18, 10, note: 'تدبر');

    await tester.pumpWidget(host(MushafPalette.light));
    await settle(tester);
    expect(rowFinder(id), findsOneWidget);

    // `endToStart` in an RTL tree runs left-to-right on screen.
    await tester.drag(rowFinder(id), const Offset(600, 0));
    await settle(tester);

    expect(rowFinder(id), findsNothing);
    expect(find.text('هنوز نشانی ثبت نشده'), findsOneWidget);
    expect(find.text('بازگردانی'), findsOneWidget);
    expect(await dao.getByAyah(18, 10), isNull);

    await tester.tap(find.text('بازگردانی'));
    await settle(tester);

    final back = await dao.getByAyah(18, 10);
    expect(back, isNotNull, reason: 'the undo re-inserts the bookmark');
    expect(back!.note, 'تدبر', reason: 'and it brings the note back with it');
    expect(rowFinder(back.id), findsOneWidget);

    // Let the undo bar expire so no timer outlives the test.
    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
  });

  testWidgets('the control chips sort and filter the list in place',
      (tester) async {
    // Seed order = oldest first, so the default (newest-first) shows سورهٔ
    // 3, then 2, then 1; the «ترتیب سوره» chip flips that to Mushaf order.
    final s1 = dao.seed(1, 5);
    final s2 = dao.seed(2, 255, note: 'آیةالکرسی');
    final s3 = dao.seed(3, 190);
    await tester.pumpWidget(host(MushafPalette.light));
    await settle(tester);

    int firstRowKey() {
      final keys = tester
          .widgetList<Dismissible>(find.byType(Dismissible))
          .map((d) => d.key! as ValueKey)
          .where((k) => (k.value as String).startsWith('bm_'))
          .toList();
      return int.parse((keys.first.value as String).substring(3));
    }

    // Newest first: the last seed leads.
    expect(firstRowKey(), s3);

    await tester.tap(find.text('ترتیب سوره'));
    await settle(tester);
    expect(firstRowKey(), s1, reason: 'Mushaf order: surah 1 leads');

    await tester.tap(find.text('فقط یادداشت‌دار'));
    await settle(tester);
    // The filter leaves only the annotated mark, still in Mushaf order.
    expect(find.byKey(ValueKey('bm_$s2')), findsOneWidget);
    expect(find.byKey(ValueKey('bm_$s1')), findsNothing);
    expect(find.byKey(ValueKey('bm_$s3')), findsNothing);

    // Both chips off again: the full list returns, newest first.
    await tester.tap(find.text('ترتیب سوره'));
    await tester.tap(find.text('فقط یادداشت‌دار'));
    await settle(tester);
    expect(find.byKey(ValueKey('bm_$s1')), findsOneWidget);
    expect(firstRowKey(), s3);
  });

  testWidgets('long-press opens the note writer and saving updates the row',
      (tester) async {
    final id = dao.seed(18, 1, note: 'قدیم');
    await tester.pumpWidget(host(MushafPalette.light));
    await settle(tester);

    await tester.longPress(rowFinder(id));
    await settle(tester);
    expect(find.text('یادداشت نشان'), findsOneWidget);

    // The dialog opens pre-filled.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'قدیم');

    await tester.enterText(find.byType(TextField), 'الرحمن در آغاز است');
    await tester.tap(find.text('ذخیره'));
    await settle(tester);

    // The dialog is gone and the row re-renders the new note through the
    // watched stream — no manual refresh anywhere.
    expect(find.text('یادداشت نشان'), findsNothing);
    expect(find.textContaining('الرحمن در آغاز است', findRichText: true),
        findsOneWidget);
    expect(dao.rows.single.note, 'الرحمن در آغاز است');
  });

  testWidgets('the filtered-empty state is not the nothing-marked state',
      (tester) async {
    dao.seed(1, 1);
    await tester.pumpWidget(host(MushafPalette.light));
    await settle(tester);

    await tester.tap(find.text('فقط یادداشت‌دار'));
    await settle(tester);

    expect(find.text('هیچ نشانی یادداشت‌دار نیست'), findsOneWidget);
    expect(find.text('هنوز نشانی ثبت نشده'), findsNothing);
  });
}
