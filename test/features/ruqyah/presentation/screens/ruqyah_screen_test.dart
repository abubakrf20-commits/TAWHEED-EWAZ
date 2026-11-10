import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/ruqyah/presentation/screens/ruqyah_screen.dart';

void main() {
  // The screens are long lazy ListViews — a very tall viewport lays out every
  // item so tests can reach headers without scrolling.
  void useTallViewport(WidgetTester tester, {double height = 20000}) {
    tester.view.physicalSize = Size(800, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets(
      'study tab renders hero, intro, first chapter, conclusion and tips',
      (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: RuqyahScreen()));
    await tester.pumpAndSettle();

    // AppBar title + hero title
    expect(find.text('رقیه شرعی'), findsNWidgets(2));
    // Hero verse reference
    expect(find.text('الإسراء: 82'), findsOneWidget);
    // Intro
    expect(find.text('مقدمه'), findsOneWidget);
    expect(find.text('رقیه در لغت'), findsOneWidget);
    // First chapter is expanded by default → its content is visible
    expect(find.text('فصل اول: مشروعیت و ادله رقیه شرعی'), findsOneWidget);
    expect(find.text('ادله از قرآن کریم'), findsOneWidget);
    // Conclusion + final recommendations
    expect(find.text('خاتمه'), findsOneWidget);
    expect(find.text('توصیه‌های نهایی'), findsOneWidget);
    expect(
      find.text(
          'در هنگام بیماری، ابتدا به پزشک مراجعه کنید و از درمان‌های پزشکی غافل نشوید.'),
      findsOneWidget,
    );
  });

  testWidgets('duplicated chapters are removed from the study tab',
      (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: RuqyahScreen()));
    await tester.pumpAndSettle();

    // Chapters 8 & 9 are now fully covered by the practical tab.
    expect(
        find.text('فصل هشتم: آیات و سوره‌های مؤثر در رقیه شرعی'), findsNothing);
    expect(find.text('فصل نهم: اذکار و دعاهای مأثور از سنت نبوی در رقیه'),
        findsNothing);
  });

  testWidgets('all chapters are expanded by default and can be collapsed',
      (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: RuqyahScreen()));
    await tester.pumpAndSettle();

    // A later chapter (فصل دوم) is open by default → its content is visible.
    final header = find.text('فصل دوم: اقسام رقیه');
    expect(header, findsOneWidget);
    expect(find.text('رقیه مشروع (شرعی)').hitTestable(), findsOneWidget);

    // Tapping the header collapses it.
    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(find.text('رقیه مشروع (شرعی)').hitTestable(), findsNothing);
  });

  testWidgets(
      'practical tab shows verses, hadiths, duas, instructions and daily adhkar',
      (tester) async {
    useTallViewport(tester, height: 30000);
    await tester.pumpWidget(const MaterialApp(home: RuqyahScreen()));
    await tester.pumpAndSettle();

    // Switch to the practical tab.
    await tester.tap(find.text('عملی'));
    await tester.pumpAndSettle();

    // Section 1 — verses
    expect(find.text('بخش اول: آیات قرآن کریم در رقیه شرعی'), findsOneWidget);
    expect(find.text('سوره فاتحه (7 آیه)'), findsOneWidget);
    expect(find.text('سوره بقره — آیه 255 (آیه الکرسی)'), findsOneWidget);
    // Section 2 — duas (hadiths moved to the study tab)
    expect(find.text('بخش دوم: دعاهای مأثور در رقیه شرعی'), findsOneWidget);
    expect(find.text('دعای جبرئیل (ع)'), findsOneWidget);
    expect(find.text('دعای شفا (دعای رب الناس)'), findsOneWidget);
    // No hadiths section anymore in the practical tab.
    expect(find.text('بخش دوم: احادیث نبوی در مورد رقیه شرعی'), findsNothing);
    // Section 3 — full instructions
    expect(find.text('بخش سوم: دستورالعمل کامل رقیه شرعی (صفة الرقیة)'),
        findsOneWidget);
    expect(find.text('مرحله اول: آماده‌سازی'), findsOneWidget);
    expect(find.text('مرحله دوم: قرائت آیات'), findsOneWidget);
    // Section 4 — daily adhkar
    expect(
        find.text('بخش چهارم: اذکار و دعاهای حفاظتی روزانه'), findsOneWidget);
    expect(
        find.text('3. هنگام دیدن چیزی که در دیگری می‌پسندید'), findsOneWidget);
  });

  testWidgets('study tab shows the full sunna hadiths under فصل اول',
      (tester) async {
    useTallViewport(tester, height: 30000);
    await tester.pumpWidget(const MaterialApp(home: RuqyahScreen()));
    await tester.pumpAndSettle();

    // Study tab is the default; فصل اول is expanded.
    expect(find.text('1. جواز رقیه (به شرط عدم شرک)'), findsOneWidget);
    expect(find.text('2. چشم زخم حق است'), findsOneWidget);
    expect(find.text('7. نفث و دعا بر بیمار'), findsOneWidget);
  });

  group('the in-section search', () {
    test('indexes both reading tabs', () {
      final entries = ruqyahSearchEntries();
      expect(entries.length, greaterThan(40));
      expect(entries.map((e) => e.tab).toSet(), {0, 1});
      expect(entries.every((e) => (e.tabLabel ?? '').isNotEmpty), isTrue);
      // Nothing is indexed with an empty title — a result card with no heading
      // is worse than no result.
      expect(entries.every((e) => e.title.trim().isNotEmpty), isTrue);
    });

    testWidgets('a symptom word finds the chapter that names it',
        (tester) async {
      useTallViewport(tester, height: 2400);
      await tester.pumpWidget(const MaterialApp(home: RuqyahScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.text('جست‌وجو در رقیه شرعی'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'چشم زخم');
      await tester.pumpAndSettle();

      expect(find.textContaining('چشم زخم'), findsWidgets);
      expect(find.text('چیزی در رقیه شرعی پیدا نشد.'), findsNothing);
    });
  });
}
