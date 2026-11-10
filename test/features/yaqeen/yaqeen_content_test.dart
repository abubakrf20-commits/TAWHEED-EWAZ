import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_content.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_gamification.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_progress.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_quiz_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('YaqeenRepository (bundled content)', () {
    test('loads 4 levels and 22 unique lessons with sections', () async {
      final repo = YaqeenRepository();
      final levels = await repo.levels();

      expect(levels.length, 4);
      expect(levels.map((l) => l.id).toSet(),
          {'core', 'critique', 'doubts', 'summary'});

      final all = await repo.allLessons();
      expect(all.length, 22);
      expect(all.map((h) => h.lesson.id).toSet().length, 22,
          reason: 'lesson ids must be unique');

      for (final hit in all) {
        expect(hit.lesson.title, isNotEmpty);
        expect(hit.lesson.sections, isNotEmpty,
            reason: '${hit.lesson.id} has no sections');
        expect(hit.lesson.minutes, greaterThanOrEqualTo(1));
        for (final s in hit.lesson.sections) {
          expect(s.paragraphs, isNotEmpty,
              reason: '${hit.lesson.id} has an empty section');
        }
      }

      // The core level carries ~80% of lessons per the plan.
      final core = levels.firstWhere((l) => l.id == 'core');
      expect(core.lessons.length, 14);
      expect(core.chapters.length, 7);
    });

    test('search is multi-term AND and diacritics/ye-ke tolerant', () async {
      final repo = YaqeenRepository();

      // AND semantics, verified against the data itself: adding a term
      // must narrow results to a non-empty subset.
      final oneTerm =
          (await repo.search('برهان')).map((h) => h.lesson.id).toSet();
      final twoTerms =
          (await repo.search('برهان حدوث')).map((h) => h.lesson.id).toSet();
      expect(oneTerm, isNotEmpty);
      expect(twoTerms, isNotEmpty);
      expect(twoTerms.difference(oneTerm), isEmpty,
          reason: 'AND results must be a subset of single-term results');
      expect(twoTerms.length, lessThan(oneTerm.length),
          reason: 'adding a term must narrow the results');
      expect(twoTerms, contains('l05'),
          reason:
              'the Hadus proof lesson must match'); // Persian ke vs Arabic ke must not change results.
      final hitsKe = await repo.search('برهان حدوث'.replaceAll('ک', 'ك'));
      expect(hitsKe.map((h) => h.lesson.id).toSet(), twoTerms);

      // Nonsense term yields nothing.
      expect(await repo.search('xyzناموجود123'), isEmpty);
    });

    test('normalizeText unifies diacritics and Persian/Arabic letters', () {
      expect(YaqeenRepository.normalizeText('بَرْهانِ حُدوث'),
          YaqeenRepository.normalizeText('برهان حدوث'));
      // Canonical direction is Persian forms (shared normalizeForSearch).
      expect(YaqeenRepository.normalizeText('شک'), 'شک');
      expect(YaqeenRepository.normalizeText('یقين'), 'یقین');
    });
  });

  group('YaqeenProgress', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('setRead / isRead round-trip', () async {
      final p = YaqeenProgress();
      expect(await p.isRead('l01'), isFalse);
      await p.setRead('l01', read: true);
      expect(await p.isRead('l01'), isTrue);
      await p.setRead('l01', read: false);
      expect(await p.isRead('l01'), isFalse);
    });

    test('lastLessonId round-trip', () async {
      final p = YaqeenProgress();
      expect(await p.lastLessonId(), isNull);
      await p.setLastLesson('l07');
      expect(await p.lastLessonId(), 'l07');
    });

    test('fontSize clamps to allowed range', () async {
      final p = YaqeenProgress();
      expect(await p.fontSize(), YaqeenProgress.defaultFontSize);
      await p.setFontSize(99);
      expect(await p.fontSize(), YaqeenProgress.maxFontSize);
      await p.setFontSize(2);
      expect(await p.fontSize(), YaqeenProgress.minFontSize);
    });

    test('quizScores keeps the best score per lesson', () async {
      final p = YaqeenProgress();
      await p.saveQuizScore('l05', 1);
      expect((await p.quizScores())['l05'], 1);
      await p.saveQuizScore('l05', 3);
      expect((await p.quizScores())['l05'], 3,
          reason: 'higher score must replace the old one');
      await p.saveQuizScore('l05', 2);
      expect((await p.quizScores())['l05'], 3,
          reason: 'lower score must NOT replace the best score');
    });
  });

  group('YaqeenQuizData', () {
    test('every question is well-formed and bound to a real lesson', () async {
      final repo = YaqeenRepository();
      final lessonIds =
          (await repo.allLessons()).map((h) => h.lesson.id).toSet();

      expect(YaqeenQuizData.questions.length, greaterThanOrEqualTo(30));
      for (final q in YaqeenQuizData.questions) {
        expect(q.options.length, 4,
            reason: '${q.id} must have exactly 4 options');
        expect(q.correctIndex, inInclusiveRange(0, 3),
            reason: '${q.id} correctIndex out of range');
        expect(q.explanation, isNotEmpty);
        expect(lessonIds, contains(q.lessonId),
            reason: '${q.id} references unknown lesson ${q.lessonId}');
        expect(q.options.toSet().length, 4,
            reason: '${q.id} has duplicate options');
      }
    });

    test('every core-level lesson has at least one question', () async {
      final repo = YaqeenRepository();
      final core = (await repo.levels()).firstWhere((l) => l.id == 'core');
      for (final lesson in core.lessons) {
        expect(YaqeenQuizData.forLesson(lesson.id), isNotEmpty,
            reason: '${lesson.id} (${lesson.title}) has no quiz');
      }
    });
  });

  group('YaqeenGamification', () {
    test('points math', () {
      expect(YaqeenGamification.points(0, 0), 0);
      expect(
          YaqeenGamification.points(3, 4),
          3 * YaqeenGamification.pointsPerLesson +
              4 * YaqeenGamification.pointsPerCorrectAnswer);
    });

    test('user level thresholds', () {
      expect(YaqeenGamification.userLevel(0), 'مبتدی');
      expect(YaqeenGamification.userLevel(4), 'مبتدی');
      expect(YaqeenGamification.userLevel(5), 'متوسط');
      expect(YaqeenGamification.userLevel(12), 'پیشرفته');
      expect(YaqeenGamification.userLevel(22), 'عالی‌مرتبه');
    });

    test('daily lesson index is deterministic per day and bounded', () {
      const total = 22;
      final d1 = DateTime(2026, 8, 28, 10, 30);
      final d1Later = DateTime(2026, 8, 28, 23);
      final d2 = DateTime(2026, 8, 29, 8);
      expect(YaqeenGamification.dailyLessonIndex(d1, totalLessons: total),
          YaqeenGamification.dailyLessonIndex(d1Later, totalLessons: total));
      expect(YaqeenGamification.dailyLessonIndex(d1, totalLessons: total),
          isNot(YaqeenGamification.dailyLessonIndex(d2, totalLessons: total)));
      expect(YaqeenGamification.dailyLessonIndex(d1, totalLessons: total),
          inInclusiveRange(0, total - 1));
      expect(YaqeenGamification.dailyLessonIndex(d1, totalLessons: 0), 0);
    });

    test('badges unlock from read lessons and perfect quizzes', () async {
      final repo = YaqeenRepository();
      final all = (await repo.allLessons()).map((h) => h.lesson).toList();
      int countQuestions(String id) => YaqeenQuizData.forLesson(id).length;

      final none = YaqeenGamification.badges({}, {});
      expect(none.every((b) => !b.earned), isTrue);

      // Core proofs chapter complete → «متخصص برهان» و «تازه‌کار یقین».
      final readProofs = {
        'l01',
        'l02',
        'l03',
        'l04',
        'l05',
        'l06',
        'l07',
        'l08',
        'l09'
      }.toSet();
      final badges1 = YaqeenGamification.badges(readProofs, {});
      expect(badges1.firstWhere((b) => b.id == 'rookie').earned, isTrue);
      expect(badges1.firstWhere((b) => b.id == 'proofs').earned, isTrue);
      expect(badges1.firstWhere((b) => b.id == 'master').earned, isFalse);

      // Perfect quizzes on 5 different lessons → «عالِم آزموده».
      final scores = {
        for (final l in all.take(5)) l.id: countQuestions(l.id),
      };
      expect(scores.length, 5);
      final badges2 = YaqeenGamification.badges({}, scores);
      expect(badges2.firstWhere((b) => b.id == 'examined').earned, isTrue);

      // Everything read → «عالی‌مرتبه».
      final badges3 =
          YaqeenGamification.badges(all.map((l) => l.id).toSet(), {});
      expect(badges3.firstWhere((b) => b.id == 'master').earned, isTrue);
    });
  });
}
