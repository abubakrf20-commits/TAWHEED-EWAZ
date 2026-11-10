import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/failure_view.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';
import 'package:tawheeed/features/quran/mushaf/quran_reciter_sheet.dart';
import 'package:tawheeed/features/quran/services/mp3quran_service.dart';

/// The reader's one reciter picker (report §6.3/§7.2).
///
/// The player's reciter sheet and the download page's picker were two sheets
/// over the same reciters, so one list read as two features. These tests pin the
/// shared one: what a row says, how the search narrows it, the three empty-ish
/// states, and the two taps that must stay distinct — choosing the reciter to
/// listen to, and fetching one surah from a reciter who is *not* the active one.
void main() {
  const alafasy = Mp3QuranReciter(
    identifier: 'ar.alafasy',
    name: 'مشاري العفاسي',
  );
  const husary = Mp3QuranReciter(
    identifier: 'ar.husary',
    name: 'محمود خليل الحصري',
    surahCount: 60,
  );

  late List<ReciterPick> picks;

  setUp(() => picks = <ReciterPick>[]);

  Future<void> pumpSheet(
    WidgetTester tester, {
    String? selectedId = 'ar.alafasy',
    bool loading = false,
    String? error,
    VoidCallback? onRetry,
    String? Function(Mp3QuranReciter)? sizeLabel,
    int? downloadSurahNumber,
    // The error state only appears when the list could not be fetched and there
    // is nothing cached to fall back on.
    List<Mp3QuranReciter>? reciters,
    // The loading state spins forever, so it can only be pumped, not settled.
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          // RTL like the app, so the row order and the ink targets are real.
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ReciterPickerSheet(
              palette: MushafPalette.light,
              reciters: reciters ?? const [alafasy, husary],
              selectedId: selectedId,
              onSelect: picks.add,
              loading: loading,
              error: error,
              onRetry: onRetry,
              sizeLabel: sizeLabel,
              downloadSurahNumber: downloadSurahNumber,
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('a row names the reciter and how much of it is recorded',
      (tester) async {
    await pumpSheet(tester);

    expect(find.text('مشاري العفاسي'), findsOneWidget);
    expect(find.text('محمود خليل الحصري'), findsOneWidget);
    // Each row says which surahs the recording covers...
    expect(find.text('114 سوره'), findsOneWidget);
    expect(find.text('60 سوره'), findsOneWidget);
    // ...and the active reciter is the one wearing the check.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('the size line only appears where a caller can estimate one',
      (tester) async {
    await pumpSheet(tester, sizeLabel: (r) => '~${r.surahCount} مگابایت');

    expect(find.text('114 سوره • ~114 مگابایت'), findsOneWidget);
    expect(find.text('60 سوره • ~60 مگابایت'), findsOneWidget);
  });

  testWidgets('the search narrows the list, and says so when nothing matches',
      (tester) async {
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField), 'حصري');
    await tester.pumpAndSettle();
    expect(find.text('محمود خليل الحصري'), findsOneWidget);
    expect(find.text('مشاري العفاسي'), findsNothing);

    await tester.enterText(find.byType(TextField), 'لا أحد بهذا الاسم');
    await tester.pumpAndSettle();
    expect(find.textContaining('پیدا نشد'), findsOneWidget);
  });

  testWidgets('choosing a reciter and downloading one surah are two taps',
      (tester) async {
    await pumpSheet(tester, selectedId: null, downloadSurahNumber: 18);

    // Nothing is active yet, so both rows offer the surah download.
    expect(find.byIcon(Icons.download_for_offline_outlined), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.download_for_offline_outlined).first);
    await tester.pumpAndSettle();
    expect(picks, [const ReciterPick('ar.alafasy', downloadSurah: true)],
        reason: 'a download must not read as a reciter switch');

    await tester.tap(find.text('محمود خليل الحصري'));
    await tester.pumpAndSettle();
    expect(picks.last, const ReciterPick('ar.husary'));
    expect(picks.last.downloadSurah, isFalse);
  });

  testWidgets('the active reciter keeps its check and loses the download action',
      (tester) async {
    await pumpSheet(tester, downloadSurahNumber: 18);

    // Only the reciter who is not already playing can be fetched from.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.download_for_offline_outlined), findsOneWidget);
  });

  testWidgets('a load in flight spins, and a failed one offers a retry',
      (tester) async {
    await pumpSheet(tester, loading: true, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    var retried = false;
    await pumpSheet(tester,
        reciters: const [], error: 'offline', onRetry: () => retried = true);
    expect(find.text(FailureView.retryLabel), findsOneWidget);
    expect(find.byKey(const ValueKey('failure_quran_reciters')), findsOneWidget);

    await tester.tap(find.text(FailureView.retryLabel));
    await tester.pumpAndSettle();
    expect(retried, isTrue);
  });
}
