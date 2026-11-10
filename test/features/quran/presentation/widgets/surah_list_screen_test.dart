import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/quran/mushaf/quran_surah_list_screen.dart';
import 'package:tawheeed/shared/services/daily_content_format.dart';
import 'package:tawheeed/shared/services/daily_verse_source.dart';
import 'package:tawheeed/shared/utils/persian_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildScreen() {
    return MaterialApp(
      home: QuranSurahListScreen(onSelect: (_) {}),
    );
  }

  testWidgets(
      'QuranSurahListScreen shows the آیه روز banner with today\'s verse',
      (tester) async {
    await tester.pumpWidget(buildScreen());

    expect(find.text('آیه روز'), findsOneWidget);
    expect(find.text('فهرست سوره‌ها'), findsOneWidget);

    final verse = DailyVerseSource.verseForDate(DateTime.now());
    expect(find.text(spacedZwnj(verse['verse'] ?? '')), findsWidgets);

    // The banner's tail line uses the shared daily-content format:
    // the translation (if any) on its own line followed by the source.
    final tail = dailyContentTail(
      text: verse['verse'] ?? '',
      ref: verse['ref'] ?? '',
      trans: verse['trans'] ?? '',
    );
    expect(find.text(tail), findsOneWidget);
  });

  testWidgets('QuranSurahListScreen lists the 114 surahs and reports taps',
      (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(home: QuranSurahListScreen(onSelect: (n) => selected = n)),
    );

    expect(find.text('الفاتحة'), findsOneWidget);
    expect(find.text('البقرة'), findsWidgets);

    // Tap the first surah row (after the daily-verse banner card).
    await tester.tap(find.text('الفاتحة'));
    await tester.pumpAndSettle();
    expect(selected, 1);
  });
}
