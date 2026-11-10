import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/yaqeen/data/yaqeen_content.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_progress.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_quiz_data.dart';
import 'package:tawheeed/features/yaqeen/presentation/screens/yaqeen_home_screen.dart';
import 'package:tawheeed/features/yaqeen/presentation/screens/yaqeen_lesson_screen.dart';
import 'package:tawheeed/features/yaqeen/presentation/screens/yaqeen_level_screen.dart';
import 'package:tawheeed/features/yaqeen/presentation/screens/yaqeen_quiz_screen.dart';

/// «تثبیت یقین» reads its progress from SharedPreferences and its content from
/// the bundled `assets/content/yaqeen.json`, so every widget here is pumped
/// against the real asset with a mocked preference store — no database, no
/// Riverpod container.
Widget _app(Widget child) => MaterialApp(home: child);

/// The fixture question set is written here, not read from the shipped data:
/// a quiz test that depended on the curriculum's wording would break on any
/// copy edit, while this one pins the *mechanics* (feedback → score → save).
const _quiz = [
  YaqeenQuizQuestion(
    id: 't1',
    lessonId: 'test-lesson',
    question: 'پرسش نخست',
    options: ['گزینهٔ درست', 'گزینهٔ نادرست'],
    correctIndex: 0,
    explanation: 'توضیح پرسش نخست',
  ),
  YaqeenQuizQuestion(
    id: 't2',
    lessonId: 'test-lesson',
    question: 'پرسش دوم',
    options: ['الف', 'ب'],
    correctIndex: 1,
    explanation: 'توضیح پرسش دوم',
  ),
];

const _lessonA = YaqeenLesson(
  id: 'test-a',
  title: 'درس الف',
  excerpt: 'خلاصهٔ الف',
  minutes: 2,
  sections: [
    YaqeenSection(paragraphs: ['یک', 'دو']),
  ],
);
const _lessonB = YaqeenLesson(
  id: 'test-b',
  title: 'درس ب',
  excerpt: 'خلاصهٔ ب',
  minutes: 2,
  sections: [
    YaqeenSection(paragraphs: ['یک', 'دو']),
  ],
);

const _lessonC = YaqeenLesson(
  id: 'test-c',
  title: 'درس ج',
  excerpt: 'خلاصهٔ ج',
  minutes: 3,
  sections: [
    YaqeenSection(paragraphs: ['یک', 'دو']),
  ],
);
const _lessonD = YaqeenLesson(
  id: 'test-d',
  title: 'درس د',
  excerpt: 'خلاصهٔ د',
  minutes: 3,
  sections: [
    YaqeenSection(paragraphs: ['یک', 'دو']),
  ],
);

/// A level the test owns: two chapters, two lessons, deterministic counts.
const _level = YaqeenLevel(
  id: 'test-level',
  title: 'مسیر آزمون',
  subtitle: 'زیرنویس مسیر',
  chapters: [
    YaqeenChapter(id: 'c1', title: 'فصل نخست', lessons: [_lessonA, _lessonB]),
    YaqeenChapter(
      id: 'c2',
      title: 'فصل دوم',
      lessons: [_lessonC, _lessonD],
    ),
  ],
);

YaqeenLesson _quizLesson() => const YaqeenLesson(
      id: 'test-lesson',
      title: 'درس آزمون',
      excerpt: 'خلاصه',
      minutes: 3,
      sections: [
        YaqeenSection(paragraphs: ['یک پاراگراف برای آزمون.']),
      ],
    );

/// A searchable word lifted out of the lesson's own text: bare Arabic letters
/// only, so the query survives normalization whatever the data carries (a
/// ZWNJ or a diacritic would otherwise change it into a word that is not
/// there).
String _searchableWordIn(String text) {
  final word = RegExp(r'(?<![\u0600-\u06FF])[\u0600-\u06FF]{4,}(?![\u0600-\u06FF])')
      .allMatches(text)
      .map((m) => m.group(0)!)
      .firstWhere(
        (w) => !const {'الماسی', 'می‌شود'}.contains(w),
        orElse: () => '',
      );
  expect(word, isNotEmpty, reason: 'no searchable word in the fixture text');
  return word;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<YaqeenLevel> levels;
  late List<YaqeenSearchHit> all;

  setUpAll(() async {
    final repo = YaqeenRepository();
    levels = await repo.levels();
    all = await repo.allLessons();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('YaqeenHomeScreen', () {
    testWidgets('lists the curriculum paths and the untouched progress',
        (tester) async {
      await tester.pumpWidget(_app(const YaqeenHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('تثبیت ایمان، پیش از رسیدن شبهه'), findsOneWidget);
      expect(find.text('پیشرفت شما: 0 از ${all.length} درس'), findsOneWidget);
      expect(find.text('${all.length} درس'), findsOneWidget);
      expect(find.text('سطح: مبتدی'), findsOneWidget);
      expect(find.text('0 امتیاز'), findsOneWidget);

      // The first path card is on screen; the rest are further down the list.
      expect(find.text(levels.first.title), findsWidgets);
      expect(find.text('${levels.first.lessons.length} درس'), findsWidgets);
      expect(find.text(levels.first.subtitle), findsOneWidget);
    });

    testWidgets('badges card sits at the end of the page and starts locked',
        (tester) async {
      await tester.pumpWidget(_app(const YaqeenHomeScreen()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('نشان‌ها:'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('نشان‌ها: 0 از 7'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(7));
    });

    testWidgets('a saved progress turns into a count, points and a level',
        (tester) async {
      final read = levels.first.lessons.take(5).map((l) => l.id).toList();
      SharedPreferences.setMockInitialValues({
        'yaqeen.readLessonIds': read,
        'yaqeen.quizScores': ['${read.first}:3'],
      });

      await tester.pumpWidget(_app(const YaqeenHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('پیشرفت شما: 5 از ${all.length} درس'), findsOneWidget);
      // 5 lessons × 100 + 3 correct answers × 20.
      expect(find.text('560 امتیاز'), findsOneWidget);
      expect(find.text('سطح: متوسط'), findsOneWidget);
    });

    testWidgets('«درس امروز» resumes the last opened lesson', (tester) async {
      final last = all[3];
      SharedPreferences.setMockInitialValues({
        'yaqeen.lastLessonId': last.lesson.id,
      });

      await tester.pumpWidget(_app(const YaqeenHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ادامه مطالعه'), findsOneWidget);
      expect(find.text(last.lesson.title), findsOneWidget);
      // The daily card names the path, and so does the path card itself.
      expect(find.text(last.level.title), findsWidgets);
      // The last lesson is unread, so the card carries no «خوانده شد» tick.
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('without a saved lesson the daily card falls back to the first '
        'unread lesson', (tester) async {
      final read = all.take(2).map((h) => h.lesson.id).toList();
      SharedPreferences.setMockInitialValues({'yaqeen.readLessonIds': read});

      await tester.pumpWidget(_app(const YaqeenHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text(all[2].lesson.title), findsOneWidget);
      expect(find.text(all[1].lesson.title), findsNothing);
    });

    testWidgets('tapping a path opens its chapters', (tester) async {
      await tester.pumpWidget(_app(const YaqeenHomeScreen()));
      await tester.pumpAndSettle();

      // The daily card names the same path above the tiles, so the last match
      // is the path card.
      await tester.tap(find.text(levels.first.title).last);
      await tester.pumpAndSettle();

      expect(find.text(levels.first.subtitle), findsOneWidget);
      expect(find.text(levels.first.chapters.first.title), findsWidgets);
      expect(find.text(levels.first.lessons.first.title), findsWidgets);
    });

    testWidgets('search answers from the bundled text, then explains an empty '
        'result', (tester) async {
      await tester.pumpWidget(_app(const YaqeenHomeScreen()));
      await tester.pumpAndSettle();

      final term = _searchableWordIn(all.first.lesson.fullText);
      await tester.enterText(find.byType(TextField), term);
      await tester.pumpAndSettle();

      expect(find.text('نتیجه‌ای یافت نشد'), findsNothing);
      expect(find.textContaining('نتیجه'), findsWidgets);
      expect(find.text(all.first.lesson.title), findsWidgets);

      await tester.enterText(find.byType(TextField), 'ژژژژژ');
      await tester.pumpAndSettle();
      expect(find.text('نتیجه‌ای یافت نشد'), findsOneWidget);

      // Clearing brings the curriculum back instead of leaving the empty box.
      await tester.tap(find.byTooltip('پاک کردن جستجو'));
      await tester.pumpAndSettle();
      expect(find.text('نتیجه‌ای یافت نشد'), findsNothing);
      expect(find.text('پیشرفت شما: 0 از ${all.length} درس'), findsOneWidget);
    });
  });

  group('YaqeenLevelScreen', () {
    testWidgets('renders every chapter with its read count and lessons',
        (tester) async {
      // A level the test owns, so laziness in the real 22-lesson list cannot
      // make the assertion depend on the viewport height.
      await tester.pumpWidget(_app(const YaqeenLevelScreen(level: _level)));
      await tester.pumpAndSettle();

      expect(find.text('زیرنویس مسیر'), findsOneWidget);
      expect(find.text('فصل نخست'), findsOneWidget);
      expect(find.text('فصل دوم'), findsOneWidget);
      expect(find.text('0/2'), findsNWidgets(2));
      for (final lesson in _level.lessons) {
        expect(find.text(lesson.title), findsOneWidget);
      }
      // Every tile carries the section count as its subtitle.
      expect(find.textContaining('بخش'), findsWidgets);
    });

    testWidgets('a saved read id shows as read and counts in its chapter',
        (tester) async {
      final lesson = levels.first.chapters.first.lessons.first;
      SharedPreferences.setMockInitialValues({
        'yaqeen.readLessonIds': [lesson.id],
      });

      await tester.pumpWidget(_app(YaqeenLevelScreen(level: levels.first)));
      await tester.pumpAndSettle();

      expect(find.text('1/${levels.first.chapters.first.lessons.length}'),
          findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      final title = tester.widget<Text>(find.text(lesson.title));
      expect(title.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('opening a lesson lands on the reader', (tester) async {
      final lesson = levels.first.lessons.first;
      await tester.pumpWidget(_app(YaqeenLevelScreen(level: levels.first)));
      await tester.pumpAndSettle();

      await tester.tap(find.text(lesson.title).first);
      await tester.pumpAndSettle();

      expect(find.text('درس 1 از ${levels.first.lessons.length}'), findsOneWidget);
      expect(find.text(lesson.title), findsWidgets);
    });
  });

  group('YaqeenLessonScreen', () {
    testWidgets('marks the lesson read and remembers it', (tester) async {
      final lesson = levels.first.lessons.first;
      await tester.pumpWidget(_app(YaqeenLessonScreen(
        level: levels.first,
        initialLessonId: lesson.id,
      )));
      await tester.pumpAndSettle();

      expect(find.byTooltip('علامت‌گذاری'), findsOneWidget);
      await tester.tap(find.byTooltip('علامت‌گذاری'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('خوانده شد'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('yaqeen.readLessonIds'), [lesson.id]);
    });

    testWidgets('moving forward marks the lesson read on the way', (tester) async {
      final lesson = levels.first.lessons.first;
      final next = levels.first.lessons[1];
      await tester.pumpWidget(_app(YaqeenLessonScreen(
        level: levels.first,
        initialLessonId: lesson.id,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('درس بعدی'));
      await tester.pumpAndSettle();

      expect(find.text('درس 2 از ${levels.first.lessons.length}'), findsOneWidget);
      expect(find.text(next.title), findsWidgets);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('yaqeen.readLessonIds'), contains(lesson.id));
      expect(prefs.getString('yaqeen.lastLessonId'), next.id);
    });

    testWidgets('the reader font size survives a reopen', (tester) async {
      final lesson = levels.first.lessons.first;
      await tester.pumpWidget(_app(YaqeenLessonScreen(
        level: levels.first,
        initialLessonId: lesson.id,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('بزرگ‌تر'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('yaqeen.readerFontSize'), 17.5);

      // A fresh screen reads that value back and clamps it on the way in.
      await tester.pumpWidget(_app(YaqeenLessonScreen(
        level: levels.first,
        initialLessonId: lesson.id,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('بزرگ‌تر'));
      await tester.pumpAndSettle();
      expect(prefs.getDouble('yaqeen.readerFontSize'), 19.0);
    });

    testWidgets('the quiz button in the reader opens the shipped quiz',
        (tester) async {
      final hit = all.firstWhere(
        (h) => YaqeenQuizData.forLesson(h.lesson.id).isNotEmpty,
      );
      final quiz = YaqeenQuizData.forLesson(hit.lesson.id);

      await tester.pumpWidget(_app(YaqeenLessonScreen(
        level: hit.level,
        initialLessonId: hit.lesson.id,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('آزمون — ${quiz.length} سؤال'));
      await tester.pumpAndSettle();

      expect(find.text('آزمون: ${hit.lesson.title}'), findsOneWidget);
      expect(find.text('سؤال 1 از ${quiz.length}'), findsOneWidget);
      expect(find.text(quiz.first.question), findsOneWidget);
    });
  });

  group('YaqeenQuizScreen', () {
    testWidgets('answers one question at a time with instant feedback',
        (tester) async {
      await tester.pumpWidget(_app(YaqeenQuizScreen(
        lesson: _quizLesson(),
        questions: _quiz,
      )));
      await tester.pumpAndSettle();

      expect(find.text('سؤال 1 از 2'), findsOneWidget);
      expect(find.text('✓ 0'), findsOneWidget);

      await tester.tap(find.text('گزینهٔ درست'));
      await tester.pumpAndSettle();

      expect(find.text('توضیح پرسش نخست'), findsOneWidget);
      expect(find.text('✓ 1'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsWidgets);

      await tester.tap(find.text('سؤال بعدی'));
      await tester.pumpAndSettle();
      expect(find.text('سؤال 2 از 2'), findsOneWidget);
      expect(find.text('پرسش دوم'), findsOneWidget);
    });

    testWidgets('a finished quiz scores, saves the best result and can retry',
        (tester) async {
      await tester.pumpWidget(_app(YaqeenQuizScreen(
        lesson: _quizLesson(),
        questions: _quiz,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('گزینهٔ درست'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('سؤال بعدی'));
      await tester.pumpAndSettle();

      // Deliberately the wrong option, so the result is 1 of 2.
      await tester.tap(find.text('الف'));
      await tester.pumpAndSettle();
      expect(find.text('توضیح پرسش دوم'), findsOneWidget);

      await tester.tap(find.text('دیدن نتیجه'));
      await tester.pumpAndSettle();

      expect(find.text('خوب بود!'), findsOneWidget);
      expect(find.text('1 از 2 پاسخ درست'), findsOneWidget);
      expect(find.text('+20 امتیاز'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('yaqeen.quizScores'), ['test-lesson:1']);

      await tester.tap(find.text('تلاش دوباره'));
      await tester.pumpAndSettle();
      expect(find.text('سؤال 1 از 2'), findsOneWidget);
      expect(find.text('✓ 0'), findsOneWidget);
    });

    testWidgets('a perfect run reports the full score', (tester) async {
      await tester.pumpWidget(_app(YaqeenQuizScreen(
        lesson: _quizLesson(),
        questions: _quiz,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('گزینهٔ درست'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('سؤال بعدی'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ب'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('دیدن نتیجه'));
      await tester.pumpAndSettle();

      expect(find.text('آفرین! نمرهٔ کامل'), findsOneWidget);
      expect(find.text('2 از 2 پاسخ درست'), findsOneWidget);
      expect(find.text('+40 امتیاز'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    });

    testWidgets('a saved score is never replaced by a lower one',
        (tester) async {
      final progress = YaqeenProgress();
      await progress.saveQuizScore('test-lesson', 2);
      expect(await progress.quizScores(), {'test-lesson': 2});

      await progress.saveQuizScore('test-lesson', 1);
      expect(await progress.quizScores(), {'test-lesson': 2});

      await progress.saveQuizScore('test-lesson', 3);
      expect(await progress.quizScores(), {'test-lesson': 3});
    });
  });

  group('YaqeenQuizData', () {
    test('every shipped question belongs to a lesson that exists', () {
      final ids = all.map((h) => h.lesson.id).toSet();
      for (final q in YaqeenQuizData.questions) {
        expect(ids.contains(q.lessonId), isTrue,
            reason: '${q.id} points at a missing lesson ${q.lessonId}');
        expect(q.options, isNotEmpty);
        expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1));
      }
    });
  });
}
