import 'package:flutter/material.dart';

import 'package:tawheeed/features/yaqeen/data/yaqeen_quiz_data.dart';

/// ═══════════════════════════════════════════════════════════════
/// YaqeenGamification — امتیاز، سطح کاربر و نشان‌ها (طبق نقشهٔ یقین)
///
/// • امتیاز: هر درس خوانده‌شده 100 امتیاز + هر پاسخ درست آزمون 20 امتیاز
/// • سطح کاربر بر اساس تعداد درس‌های خوانده‌شده: مبتدی تا عالی
/// • نشان‌ها از روی پیشرفت استخراج می‌شوند (بدون ذخیرهٔ اضافه)
/// ═══════════════════════════════════════════════════════════════

class YaqeenBadge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool earned;

  const YaqeenBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.earned,
  });
}

abstract final class YaqeenGamification {
  /// Points per fully-read lesson.
  static const int pointsPerLesson = 100;

  /// Points per correct quiz answer.
  static const int pointsPerCorrectAnswer = 20;

  /// امتیاز کل کاربر از پیشرفت و آزمون‌ها.
  static int points(int lessonsRead, int correctAnswers) =>
      lessonsRead * pointsPerLesson + correctAnswers * pointsPerCorrectAnswer;

  /// سطح کاربر بر اساس تعداد درس‌های خوانده‌شده.
  static String userLevel(int lessonsRead, {int totalLessons = 22}) {
    if (lessonsRead >= totalLessons) return 'عالی‌مرتبه';
    if (lessonsRead >= 12) return 'پیشرفته';
    if (lessonsRead >= 5) return 'متوسط';
    return 'مبتدی';
  }

  /// Index of today's suggested lesson over the flattened curriculum —
  /// deterministic within one calendar day, always in `0..totalLessons`.
  /// (The modulo lives inside so no caller can forget it and index out of
  /// range when the curriculum grows past 22 lessons.)
  static int dailyLessonIndex(DateTime now, {required int totalLessons}) {
    if (totalLessons <= 0) return 0;
    final startOfYear = DateTime(now.year);
    final dayOfYear = now.difference(startOfYear).inDays;
    return dayOfYear % totalLessons;
  }

  /// نشان‌های بخش یقین — وضعیت از روی پیشرفتِ واقعی کاربر استخراج می‌شود.
  static List<YaqeenBadge> badges(
    Set<String> readIds,
    Map<String, int> quizScores,
  ) {
    bool all(List<String> ids) => ids.every(readIds.contains);
    // «نمرهٔ کامل» = تعداد پاسخ‌های درست برابر کل سؤالات همان درس.
    int perfectQuizzes = 0;
    for (final e in quizScores.entries) {
      final total = YaqeenQuizData.forLesson(e.key).length;
      if (total > 0 && e.value >= total) perfectQuizzes++;
    }

    return [
      YaqeenBadge(
        id: 'rookie',
        title: 'تازه‌کار یقین',
        description: 'تکمیل 5 درس اول',
        icon: Icons.flag_outlined,
        earned: all(['l01', 'l02', 'l03', 'l04', 'l05']),
      ),
      YaqeenBadge(
        id: 'proofs',
        title: 'متخصص برهان',
        description: 'تکمیل فصل براهین اثبات خدا',
        icon: Icons.psychology_outlined,
        earned: all(['l05', 'l06', 'l07', 'l08', 'l09']),
      ),
      YaqeenBadge(
        id: 'heritage',
        title: 'عالِم معارف',
        description: 'تکمیل درس‌های قرآن و سنت نبوی',
        icon: Icons.menu_book_outlined,
        earned: all(['l15', 'l16']),
      ),
      YaqeenBadge(
        id: 'critic',
        title: 'ناقد الحاد',
        description: 'تکمیل مسیر نقد جریان‌های فکری',
        icon: Icons.shield_outlined,
        earned: all(['l10', 'l11']),
      ),
      YaqeenBadge(
        id: 'answers',
        title: 'پاسخ‌گوی شبهات',
        description: 'تکمیل هر 5 درس پاسخ به شبهات',
        icon: Icons.question_answer_outlined,
        earned: all(['l12', 'l19', 'l20', 'l21', 'l22']),
      ),
      YaqeenBadge(
        id: 'examined',
        title: 'عالِم آزموده',
        description: 'نمرهٔ کامل در 5 آزمون',
        icon: Icons.fact_check_outlined,
        earned: perfectQuizzes >= 5,
      ),
      YaqeenBadge(
        id: 'master',
        title: 'عالی‌مرتبه',
        description: 'تکمیل تمام دروس',
        icon: Icons.emoji_events_outlined,
        earned: readIds.length >= 22,
      ),
    ];
  }
}
