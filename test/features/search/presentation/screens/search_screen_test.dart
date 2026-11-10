import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/search/search.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/notes/data/daos/note_dao.dart';
import '../../../../core/database/mock_daos.dart';

NoteTableData _note(String id, String title, String content) {
  final now = DateTime.now();
  return NoteTableData(
    id: id,
    title: title,
    content: content,
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

/// Opens the global search overlay the same way the app does (through
/// [openGlobalSearch]) so the delegate, its debounce and its category chips
/// are exercised end to end.
Future<void> openGlobalSearchScreen(WidgetTester tester,
    {NoteDao? noteDao}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (noteDao != null) noteDaoProvider.overrideWithValue(noteDao),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            return Center(
              child: ElevatedButton(
                onPressed: () => openGlobalSearch(context, ref),
                child: const Text('open-search'),
              ),
            );
          }),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open-search'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('short query shows the minimum-length hint and category chips',
      (tester) async {
    await openGlobalSearchScreen(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('حداقل 2 حرف وارد کنید'), findsOneWidget);
    for (final label in ['همه', 'دعاها', 'یادداشت‌ها', 'اذکار', 'قرآن']) {
      expect(find.text(label), findsWidgets, reason: 'missing chip: $label');
    }
  });

  testWidgets('a category chip becomes the active filter', (tester) async {
    await openGlobalSearchScreen(tester);

    final quranChip = find.widgetWithText(FilterChip, 'قرآن');
    final allChip = find.widgetWithText(FilterChip, 'همه');
    expect(tester.widget<FilterChip>(allChip).selected, isTrue);

    await tester.tap(quranChip);
    await tester.pump();

    expect(tester.widget<FilterChip>(quranChip).selected, isTrue);
    expect(tester.widget<FilterChip>(allChip).selected, isFalse);
  });

  testWidgets('typing a usable query starts the debounced search',
      (tester) async {
    // Notes-only with the DAO faked: the Quran/Azkar sources load bundled
    // assets through an isolate the fake-async test clock cannot observe,
    // and the real notes DAO needs a database the harness never answers.
    // The mock resolves in microtasks, so the awaited search future
    // completes deterministically.
    await openGlobalSearchScreen(tester, noteDao: MockNoteDao());
    await tester.tap(find.widgetWithText(FilterChip, 'یادداشت‌ها'));
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'یادداشت‌ها'))
          .selected,
      isTrue,
    );

    await tester.enterText(find.byType(TextField), 'نماز');
    await tester.pump();

    // Before the 250ms debounce fires there is no future yet, so the
    // delegate shows its loading state instead of running the search in
    // the build phase.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // The search ran to completion (every source is guarded) and rendered
    // one of its two terminal states: grouped results or the explicit
    // no-results message.
    final noResults = find.textContaining('یافت نشد');
    final results = find.byType(ListView);
    expect(noResults.evaluate().isNotEmpty || results.evaluate().isNotEmpty,
        isTrue,
        reason: 'expected results or the no-results state after the debounce');
  });

  testWidgets('clear returns the overlay to the hint', (tester) async {
    await openGlobalSearchScreen(tester);

    await tester.enterText(find.byType(TextField), 'نماز');
    await tester.pump();
    expect(find.byIcon(Icons.clear), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(find.byIcon(Icons.clear), findsNothing);
    expect(find.text('حداقل 2 حرف وارد کنید'), findsOneWidget);
  });

  testWidgets('a query lists the notes whose normalized text matches it',
      (tester) async {
    final dao = MockNoteDao();
    await dao.upsertNote(_note('n1', 'یادداشت نماز', 'برنامه روزانه'));
    await dao.upsertNote(_note('n2', 'بازدید', 'مهمان'));

    await openGlobalSearchScreen(tester, noteDao: dao);
    await tester.tap(find.widgetWithText(FilterChip, 'یادداشت‌ها'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'نماز');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('یادداشت نماز'), findsOneWidget);
    expect(find.text('بازدید'), findsNothing);
  });
}
