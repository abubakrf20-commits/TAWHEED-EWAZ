import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════
/// YaqeenProgress — پیشرفت مطالعهٔ بخش «یقین»
///
/// درس‌های خوانده‌شده (مجموعهٔ id) و آخرین درسِ بازشده در
/// SharedPreferences نگهداری می‌شود؛ فونت خوانشگر هم همین‌جا.
/// ═══════════════════════════════════════════════════════════════

class YaqeenProgress {
  static const String _kRead = 'yaqeen.readLessonIds';
  static const String _kLast = 'yaqeen.lastLessonId';
  static const String _kFontSize = 'yaqeen.readerFontSize';
  static const String _kQuiz = 'yaqeen.quizScores';

  static const double defaultFontSize = 16;
  static const double minFontSize = 13;
  static const double maxFontSize = 24;

  Future<Set<String>> readIds() async {
    final sp = await SharedPreferences.getInstance();
    return (sp.getStringList(_kRead) ?? const []).toSet();
  }

  Future<bool> isRead(String lessonId) async =>
      (await readIds()).contains(lessonId);

  Future<void> setRead(String lessonId, {required bool read}) async {
    final sp = await SharedPreferences.getInstance();
    final ids = (sp.getStringList(_kRead) ?? const []).toSet();
    if (read) {
      ids.add(lessonId);
    } else {
      ids.remove(lessonId);
    }
    await sp.setStringList(_kRead, ids.toList());
  }

  Future<String?> lastLessonId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kLast);
  }

  Future<void> setLastLesson(String lessonId) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLast, lessonId);
  }

  Future<double> fontSize() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getDouble(_kFontSize) ?? defaultFontSize;
    return v.clamp(minFontSize, maxFontSize);
  }

  Future<void> setFontSize(double size) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_kFontSize, size.clamp(minFontSize, maxFontSize));
  }

  /// بهترین نمرهٔ هر درس: lessonId → تعداد پاسخ‌های درست.
  Future<Map<String, int>> quizScores() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_kQuiz) ?? const [];
    final out = <String, int>{};
    for (final entry in raw) {
      final i = entry.indexOf(':');
      if (i <= 0 || i == entry.length - 1) continue;
      final score = int.tryParse(entry.substring(i + 1));
      if (score != null) out[entry.substring(0, i)] = score;
    }
    return out;
  }

  /// ذخیرهٔ نمرهٔ آزمون — فقط اگر بهتر از بهترین نمرهٔ قبلی باشد.
  Future<void> saveQuizScore(String lessonId, int correct) async {
    final sp = await SharedPreferences.getInstance();
    final scores = await quizScores();
    final best = scores[lessonId];
    if (best != null && best >= correct) return;
    scores[lessonId] = correct;
    await sp.setStringList(
        _kQuiz, [for (final e in scores.entries) '${e.key}:${e.value}']);
  }
}
