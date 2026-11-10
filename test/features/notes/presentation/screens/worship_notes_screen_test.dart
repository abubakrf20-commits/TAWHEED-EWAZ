import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/notes/data/daos/note_dao.dart';
import 'package:tawheeed/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:tawheeed/features/notes/presentation/screens/worship_notes_screen.dart';
import '../../../../core/database/mock_daos.dart';

NoteTableData _note(
  String id,
  String title, {
  String content = '',
  String tags = '',
  String folder = '',
  bool isDone = false,
  bool isPinned = false,
  DateTime? updatedAt,
}) {
  final now = DateTime.now();
  return NoteTableData(
    id: id,
    title: title,
    content: content,
    createdAt: now,
    updatedAt: updatedAt ?? now,
    tags: tags,
    folder: folder,
    isDone: isDone,
    colorIndex: 0,
    isPinned: isPinned,
    audioPath: '',
    audioDurationMs: 0,
  );
}

Widget _app(MockNoteDao dao) {
  return ProviderScope(
    overrides: [noteDaoProvider.overrideWithValue(dao)],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const WorshipNotesScreen(),
          ),
          GoRoute(
            path: RouteNames.noteEditor,
            builder: (_, state) => NoteEditorScreen(
              note: state.extra is NoteTableData
                  ? state.extra as NoteTableData
                  : null,
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty state shows writing virtues and CTA opens the editor',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(MockNoteDao()));
    await tester.pumpAndSettle();

    expect(find.text('دیوار نوشته‌ها'), findsOneWidget);
    expect(find.text('افزودن اولین یادداشت'), findsOneWidget);
    expect(find.text('دانش را با نوشتن به بند بکش؛ نوشتن، نگهبان دانش است'),
        findsOneWidget);

    await tester.tap(find.text('افزودن اولین یادداشت'));
    await tester.pumpAndSettle();

    // Editor opened (its app-bar title; the FAB behind is offstage).
    expect(find.text('یادداشت جدید'), findsOneWidget);
    expect(find.text('عنوان...'), findsOneWidget);
  });

  testWidgets('hero, week card and time sections render from persisted data',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final dao = MockNoteDao();
    await dao.upsertNote(_note('1', 'سنجاق شده', isPinned: true));
    await dao.upsertNote(
        _note('2', 'یادداشت امروز', content: 'متن امروز', tags: 'کار'));
    await dao.upsertNote(_note('3', 'یادداشت این هفته',
        updatedAt: now.subtract(const Duration(days: 3))));
    await dao.upsertNote(_note('4', 'یادداشت قدیمی',
        updatedAt: now.subtract(const Duration(days: 40))));
    await dao.upsertNote(_note('5', 'یادداشت انجام شده', isDone: true));

    await tester.pumpWidget(_app(dao));
    await tester.pumpAndSettle();

    // Single compact summary card + app bar title.
    expect(find.text('یادداشت‌ها'), findsWidgets);
    expect(find.text('5 یادداشت'), findsWidgets);

    // Time-bucket sections.
    expect(find.text('سنجاق شده'), findsWidgets);
    expect(find.text('امروز'), findsWidgets);
    expect(find.text('این هفته'), findsWidgets);
    expect(find.text('گذشته'), findsOneWidget);
    expect(find.text('انجام شده'), findsWidgets);

    // All notes visible.
    expect(find.text('سنجاق شده'), findsWidgets);
    expect(find.text('یادداشت امروز'), findsOneWidget);
    expect(find.text('یادداشت این هفته'), findsOneWidget);
    expect(find.text('یادداشت قدیمی'), findsOneWidget);
    expect(find.text('یادداشت انجام شده'), findsOneWidget);
  });

  testWidgets('pinned filter keeps only pinned notes', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dao = MockNoteDao();
    await dao.upsertNote(_note('1', 'پین شده', isPinned: true));
    await dao.upsertNote(_note('2', 'عادی'));

    await tester.pumpWidget(_app(dao));
    await tester.pumpAndSettle();

    expect(find.text('عادی'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note_filter_pinned')));
    await tester.pumpAndSettle();

    expect(find.text('پین شده'), findsOneWidget);
    expect(find.text('عادی'), findsNothing);
    expect(find.text('گذشته'), findsNothing);
  });

  testWidgets('search matches title and text only', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dao = MockNoteDao();
    await dao.upsertNote(_note('1', 'مطالعه قرآن', content: 'سورهٔ مبارکه'));
    await dao.upsertNote(_note('2', 'یادداشت دیگر', tags: 'قرآن'));

    await tester.pumpWidget(_app(dao));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'مطالعه');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('مطالعه قرآن'), findsOneWidget);
    expect(find.text('یادداشت دیگر'), findsNothing);

    // A tag alone no longer matches anything: it is not a search axis any more.
    await tester.enterText(find.byType(TextField).first, 'قرآن');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('مطالعه قرآن'), findsOneWidget);
    expect(find.text('یادداشت دیگر'), findsNothing);
  });

  testWidgets('no folder or tag filters are offered any more', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dao = MockNoteDao();
    await dao.upsertNote(_note('1', 'یادداشت فقه', tags: 'کار', folder: 'فقه'));
    await dao.upsertNote(_note('2', 'یادداشت بدون پوشه'));

    await tester.pumpWidget(_app(dao));
    await tester.pumpAndSettle();

    // The filter rows are gone, so legacy tags/folders can no longer be used
    // as a filter axis.
    expect(find.byKey(const ValueKey('note_tag_کار')), findsNothing);
    expect(find.byKey(const ValueKey('note_folder_فقه')), findsNothing);
    expect(find.text('همه برچسب‌ها'), findsNothing);
    expect(find.text('همه پوشه‌ها'), findsNothing);
    // The chips are gone from the card as well.
    expect(find.text('فقه'), findsNothing);
    expect(find.text('کار'), findsNothing);

    // Both notes stay listed.
    expect(find.text('یادداشت فقه'), findsOneWidget);
    expect(find.text('یادداشت بدون پوشه'), findsOneWidget);
  });

  testWidgets('done section is collapsible', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dao = MockNoteDao();
    await dao.upsertNote(_note('1', 'انجام شده', isDone: true));
    await dao.upsertNote(_note('2', 'در حال انجام'));

    await tester.pumpWidget(_app(dao));
    await tester.pumpAndSettle();

    expect(find.text('انجام شده'), findsWidgets);
    expect(find.text('در حال انجام'), findsOneWidget);

    // Collapse the done section.
    await tester.tap(find.text('انجام شده').last);
    await tester.pumpAndSettle();

    expect(find.text('انجام شده'), findsOneWidget);
  });

  testWidgets('deleting a note shows an undo snackbar that restores it',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dao = MockNoteDao();
    await dao.upsertNote(_note('1', 'یادداشت مهم', content: 'متن مهم'));

    await tester.pumpWidget(_app(dao));
    await tester.pumpAndSettle();
    expect(find.text('یادداشت مهم'), findsOneWidget);

    // Tile menu → حذف → confirm dialog → حذف.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pumpAndSettle();

    // Deleted + undo offered.
    expect(find.text('یادداشت مهم'), findsNothing);
    expect(find.text('یادداشت حذف شد'), findsOneWidget);

    // Undo brings it back (UI + database).
    await tester.tap(find.text('بازگردانی'));
    await tester.pumpAndSettle();
    expect(find.text('یادداشت مهم'), findsOneWidget);
    expect(await dao.getAllNotes(), hasLength(1));
  });

  testWidgets('the editor is just a title and the text, with pin and save',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A long note that already carries a folder and tags: opening it must not
    // offer folder/tag inputs any more, and a re-save must not drop them.
    final dao = MockNoteDao();
    await dao.upsertNote(_note(
      '1',
      'عنوان بلند',
      content: 'متن یادداشت خیلی طولانی',
      tags: 'مهم,مطالعه',
      folder: 'فقه',
    ));

    await tester.pumpWidget(_app(dao));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عنوان بلند'));
    await tester.pumpAndSettle();

    // Simple: title, then the text area.
    expect(find.text('عنوان...'), findsOneWidget);
    expect(find.text('متن یادداشت...'), findsOneWidget);

    // Organising controls are gone from the editor.
    expect(find.text('پوشه (اختیاری)...'), findsNothing);
    expect(find.text('برچسب‌ها (با کاما جدا کنید)...'), findsNothing);
    // …and the folder quick-pick chips with them.
    expect(find.widgetWithText(ActionChip, 'فقه'), findsNothing);

    // Voice recording is gone: nothing to press, no mic anywhere.
    expect(find.text('ضبط'), findsNothing);
    expect(find.text('بدون یادداشت صوتی'), findsNothing);
    expect(find.byIcon(Icons.mic_none), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);

    // Pin and save stay in the app bar.
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Title on top, text below it.
    final title = tester.getRect(find.text('عنوان...'));
    final content = tester.getRect(find.text('متن یادداشت...'));
    expect(title.top, lessThan(content.top));
    expect(content.bottom, greaterThan(title.bottom));

    // Re-saving keeps the folder and tags that the editor no longer edits.
    await tester.enterText(
        find.widgetWithText(TextField, 'متن یادداشت...'), 'متن ویرایش‌شده');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final saved = (await dao.getAllNotes()).single;
    expect(saved.content, 'متن ویرایش‌شده');
    expect(saved.folder, 'فقه', reason: 'the editor must not wipe the folder');
    expect(saved.tags, 'مهم,مطالعه', reason: 'nor the tags');
  });
}
