/// Pure domain logic for «دفتر مربی قرآن».
///
/// Same rules as the kids side: no Flutter, no database, no clock reads. The
/// mushaf facts it needs (604 pages, 15 lines, juz boundaries) are passed in or
/// read through the app's existing helpers by the caller — this file never
/// stores or reproduces Quran text.
///
/// CONTENT RULE: tajweed tag keys are LABELS chosen by the teacher from an
/// editable asset. Nothing here asserts a ruling.
library;

import 'package:shamsi_date/shamsi_date.dart';

/// The physical facts of this mushaf. The app has one mushaf, so these are
/// constants, but they are parameters everywhere it matters so a future
/// edition cannot silently reuse the arithmetic.
class MushafMeta {
  const MushafMeta({this.pageCount = 604, this.linesPerPage = 15});

  final int pageCount;
  final int linesPerPage;

  static const MushafMeta standard = MushafMeta();

  bool validPage(int page) => page >= 1 && page <= pageCount;
  bool validLine(int line) => line >= 1 && line <= linesPerPage;
}

/// `p2_lesson_record.type`.
enum LessonType {
  recitation('recitation', 'تلاوت'),
  hifz('hifz', 'حفظ'),
  review('review', 'مرور'),
  tajweed('tajweed', 'تجوید');

  const LessonType(this.wire, this.titleFa);
  final String wire;
  final String titleFa;

  static LessonType fromWire(String? value) {
    for (final t in LessonType.values) {
      if (t.wire == value) return t;
    }
    return LessonType.recitation;
  }
}

/// `p2_attendance.status`.
enum AttendanceStatus {
  present('present', 'حاضر'),
  absent('absent', 'غایب'),
  late('late', 'تأخیر'),
  excused('excused', 'مرخص');

  const AttendanceStatus(this.wire, this.titleFa);
  final String wire;
  final String titleFa;

  static AttendanceStatus fromWire(String? value) {
    for (final s in AttendanceStatus.values) {
      if (s.wire == value) return s;
    }
    return AttendanceStatus.present;
  }
}

/// One lesson record as the maths sees it.
class LessonRecordSpec {
  const LessonRecordSpec({
    required this.id,
    required this.studentId,
    required this.sessionId,
    required this.dayKey,
    required this.type,
    required this.pageStart,
    required this.pageEnd,
    this.lineStart,
    this.lineEnd,
    this.gradeKey,
    this.mistakeCount = 0,
    this.tajweedTags = const [],
    this.note = '',
    this.nextPageStart,
    this.nextPageEnd,
    this.nextLineStart,
    this.nextLineEnd,
    this.date,
  });

  final String id;
  final String studentId;
  final String sessionId;
  final String dayKey;
  final LessonType type;
  final int pageStart;
  final int pageEnd;
  final int? lineStart;
  final int? lineEnd;
  final String? gradeKey;
  final int mistakeCount;
  final List<String> tajweedTags;
  final String note;
  final int? nextPageStart;
  final int? nextPageEnd;
  final int? nextLineStart;
  final int? nextLineEnd;
  final DateTime? date;
}

/// One attendance row.
class AttendanceRecordSpec {
  const AttendanceRecordSpec({
    required this.sessionId,
    required this.studentId,
    required this.status,
    required this.dayKey,
  });

  final String sessionId;
  final String studentId;
  final AttendanceStatus status;
  final String dayKey;
}

/// ════════════════════════════════════════════════════════════════════
/// VALIDATION
/// ════════════════════════════════════════════════════════════════════

/// Why a lesson record is invalid, or null when it is fine.
///
/// Returns a Persian message the sheet can show directly: the sheet must never
/// silently accept a page 700 or a start after its end, because those become
/// unrecoverable progress numbers.
String? validateLesson({
  required int pageStart,
  required int pageEnd,
  int? lineStart,
  int? lineEnd,
  MushafMeta meta = MushafMeta.standard,
}) {
  if (!meta.validPage(pageStart)) return 'شمارهٔ صفحه باید بین ۱ و ۶۰۴ باشد.';
  if (!meta.validPage(pageEnd)) return 'شمارهٔ صفحه باید بین ۱ و ۶۰۴ باشد.';
  if (pageStart > pageEnd) return 'صفحهٔ پایان نمی‌تواند پیش از صفحهٔ شروع باشد.';
  if (lineStart != null && !meta.validLine(lineStart)) {
    return 'شمارهٔ سطر باید بین ۱ و ۱۵ باشد.';
  }
  if (lineEnd != null && !meta.validLine(lineEnd)) {
    return 'شمارهٔ سطر باید بین ۱ و ۱۵ باشد.';
  }
  // Lines only make sense on a single page: a range across pages has no
  // meaningful line comparison, so the fields are rejected together.
  if (lineStart != null && lineEnd != null && lineStart > lineEnd) {
    return 'سطر پایان نمی‌تواند پیش از سطر شروع باشد.';
  }
  if (pageStart != pageEnd && (lineStart != null || lineEnd != null)) {
    return 'سطر فقط برای یک صفحه معنی دارد؛ برای چند صفحه آن را خالی بگذارید.';
  }
  return null;
}

// ════════════════════════════════════════════════════════════════════
/// PROGRESS — distinct pages, highest page, juz coverage
// ═════════════════════════════════════════════════════════════════════

/// Pages covered by one record (inclusive).
Set<int> pagesOf(LessonRecordSpec r) {
  final out = <int>{};
  for (var p = r.pageStart; p <= r.pageEnd; p++) {
    out.add(p);
  }
  return out;
}

/// Distinct pages recited: the UNION of every recitation range.
///
/// Counting ranges instead would let «صفحه ۱ تا ۵» in five sessions look like
/// 25 pages of progress. The brief says "set of distinct pages", and that is
/// what a teacher actually means by coverage.
Set<int> distinctRecitationPages(Iterable<LessonRecordSpec> records) {
  final out = <int>{};
  for (final r in records.where((r) => r.type == LessonType.recitation)) {
    out.addAll(pagesOf(r));
  }
  return out;
}

/// Distinct pages memorised (hifz records only).
Set<int> distinctHifzPages(Iterable<LessonRecordSpec> records) {
  final out = <int>{};
  for (final r in records.where((r) => r.type == LessonType.hifz)) {
    out.addAll(pagesOf(r));
  }
  return out;
}

/// Highest page reached in [pages], or 0 when empty.
int highestPage(Iterable<int> pages) {
  var max = 0;
  for (final p in pages) {
    if (p > max) max = p;
  }
  return max;
}

/// Progress as a 0..1 fraction of the mushaf.
double pageProgress(int highest, {int pageCount = 604}) {
  if (pageCount <= 0) return 0;
  return (highest / pageCount).clamp(0.0, 1.0);
}

/// Pages newly covered inside [fromDayKey]..[toDayKey] (inclusive).
///
/// "New" means not covered by any record BEFORE the range, so re-reciting an
/// old page does not count as this month's progress — the number in the parent
/// report should mean what a parent thinks it means.
Set<int> newPagesInRange(
  List<LessonRecordSpec> records,
  String fromDayKey,
  String toDayKey,
) {
  final before = <int>{};
  final inside = <int>{};
  for (final r in records) {
    if (r.dayKey.compareTo(fromDayKey) < 0) {
      before.addAll(pagesOf(r));
    } else if (r.dayKey.compareTo(toDayKey) <= 0) {
      inside.addAll(pagesOf(r));
    }
  }
  return inside.difference(before);
}

/// Which of the 30 juz are touched by [pages].
///
/// [juzOfPage] is the app's own mapper (`getCurrentJuzNumberForPage`), passed
/// in so this stays testable and the app keeps one source of truth for the
/// page→juz mapping.
Set<int> juzCovered(Iterable<int> pages, int Function(int page) juzOfPage) {
  final out = <int>{};
  for (final p in pages) {
    final j = juzOfPage(p);
    if (j >= 1 && j <= 30) out.add(j);
  }
  return out;
}

/// The 30 cells of the juz strip: true when covered.
List<bool> juzStrip(Set<int> covered) =>
    [for (var j = 1; j <= 30; j++) covered.contains(j)];

// ════════════════════════════════════════════════════════════════════
/// ATTENDANCE
// ════════════════════════════════════════════════════════════════════

/// Attendance percentage.
///
/// [excusedExcluded] implements the brief's setting: by default a مرخص absence
/// is out of the denominator, because a documented excuse is not a lapse.
/// Returns null when there is nothing to divide by — the UI shows «—» rather
/// than a fake 0 %.
double? attendancePercent(
  Iterable<AttendanceRecordSpec> records, {
  bool excusedExcluded = true,
}) {
  var present = 0;
  var denominator = 0;
  for (final r in records) {
    if (r.status == AttendanceStatus.excused && excusedExcluded) continue;
    denominator++;
    if (r.status == AttendanceStatus.present ||
        r.status == AttendanceStatus.late) {
      present++;
    }
  }
  if (denominator == 0) return null;
  return present / denominator;
}

/// Consecutive absences at the END of [dayKeys], oldest first.
///
/// A `late` is not an absence (the student came), and an `excused` break the
/// run without counting — a documented excuse is not a reason to call home.
int absenceStreak({
  required List<String> dayKeys,
  required Map<String, AttendanceStatus> statusByDay,
}) {
  var streak = 0;
  for (var i = dayKeys.length - 1; i >= 0; i--) {
    final status = statusByDay[dayKeys[i]];
    if (status == null) continue; // no session / not recorded
    if (status == AttendanceStatus.absent) {
      streak++;
      continue;
    }
    break;
  }
  return streak;
}

/// The brief's in-app suggestion threshold.
bool shouldSuggestCalling({required int streak, int threshold = 3}) =>
    streak >= threshold;

/// Per-status counts for one session (or any slice of attendance).
///
/// The home screen needs «۳ حاضر · ۱ غایب · ۱ مرخص» for a *past* session, and
/// the class history needs the same numbers for every session it lists; both
/// read them from here so a card and a list can never disagree.
class AttendanceBreakdown {
  const AttendanceBreakdown({
    this.present = 0,
    this.absent = 0,
    this.late = 0,
    this.excused = 0,
  });

  final int present;
  final int absent;
  final int late;
  final int excused;

  int get total => present + absent + late + excused;

  /// Students who came, on time or not.
  int get attended => present + late;

  /// Students who were not there — an excused absence is still an absence from
  /// the room, so it is counted here; only the percentage may drop it.
  int get missing => absent + excused;

  bool get isEmpty => total == 0;

  /// Share of the recorded students who came, or null when nothing was
  /// recorded (the UI prints «—», never a fake 0 %).
  double? get rate => total == 0 ? null : attended / total;

  /// The same rate with documented excuses out of the denominator, matching
  /// [attendancePercent]'s setting.
  double? rateExcludingExcused() {
    final denominator = present + absent + late;
    if (denominator == 0) return null;
    return attended / denominator;
  }
}

/// Counts [records] by status.
AttendanceBreakdown attendanceBreakdown(
  Iterable<AttendanceRecordSpec> records,
) {
  var present = 0;
  var absent = 0;
  var late = 0;
  var excused = 0;
  for (final r in records) {
    switch (r.status) {
      case AttendanceStatus.present:
        present++;
      case AttendanceStatus.absent:
        absent++;
      case AttendanceStatus.late:
        late++;
      case AttendanceStatus.excused:
        excused++;
    }
  }
  return AttendanceBreakdown(
    present: present,
    absent: absent,
    late: late,
    excused: excused,
  );
}

/// The page to assign after [record] — the next page of the mushaf, or null
/// when that record already reached the end.
///
/// This is «next page» applied to ONE record, which is what the lesson sheet
/// stores: the suggestion belongs to the record that just happened, so a later
/// edit cannot move it.
int? nextPageAfter(LessonRecordSpec record, {int pageCount = 604}) {
  final next = record.pageEnd + 1;
  return next > pageCount ? null : next;
}

// ════════════════════════════════════════════════════════════════════
/// GRADES AND TAGS
//═══════════════════════════════════════════════════════════════════

/// Average of the numeric grade values, or null when nothing is graded.
double? averageGrade(
  Iterable<LessonRecordSpec> records,
  int? Function(String gradeKey) valueOf,
) {
  var sum = 0;
  var count = 0;
  for (final r in records) {
    final key = r.gradeKey;
    if (key == null) continue;
    final v = valueOf(key);
    if (v == null) continue;
    sum += v;
    count++;
  }
  if (count == 0) return null;
  return sum / count;
}

/// Total mistakes across [records].
int mistakeTotal(Iterable<LessonRecordSpec> records) {
  var total = 0;
  for (final r in records) {
    total += r.mistakeCount;
  }
  return total;
}

/// Tag counts, most frequent first. The parent report prints the top one.
List<({String tag, int count})> tagCounts(
  Iterable<LessonRecordSpec> records,
) {
  final counts = <String, int>{};
  for (final r in records) {
    for (final t in r.tajweedTags) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
  }
  final out = [
    for (final e in counts.entries) (tag: e.key, count: e.value),
  ];
  out.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    // Stable tie-break so the report does not reshuffle between opens.
    return byCount != 0 ? byCount : a.tag.compareTo(b.tag);
  });
  return out;
}

/// Class averages WITHOUT ranking.
///
/// The brief is explicit: no leaderboard. This returns the two numbers a class
/// card shows and nothing ordered by student.
({double? attendance, double? pagesPerStudent}) classAverages({
  required Iterable<AttendanceRecordSpec> attendance,
  required List<String> studentIds,
  required Iterable<LessonRecordSpec> lessons,
  bool excusedExcluded = true,
}) {
  final pct = attendancePercent(attendance, excusedExcluded: excusedExcluded);
  if (studentIds.isEmpty) {
    return (attendance: pct, pagesPerStudent: null);
  }
  final byStudent = <String, Set<int>>{};
  for (final r in lessons) {
    byStudent.putIfAbsent(r.studentId, () => <int>{}).addAll(pagesOf(r));
  }
  var totalPages = 0;
  for (final id in studentIds) {
    totalPages += byStudent[id]?.length ?? 0;
  }
  return (
    attendance: pct,
    pagesPerStudent: totalPages / studentIds.length,
  );
}

// ════════════════════════════════════════════════════════════════════
/// NEXT ASSIGNMENT
//═══════════════════════════════════════════════════════════════════

/// The suggested next assignment: the page after the LAST range.
///
/// "Last" is chronological, not "furthest page ever": a teacher who returned to
/// review page 20 should be suggested 21, because the next lesson continues
/// from wherever the class actually stopped. Ties (and records with no date)
/// fall back to the larger pageEnd so the suggestion still moves forward.
/// Returns null when the mushaf is finished.
({int pageStart, int pageEnd})? suggestNextAssignment(
  List<LessonRecordSpec> records, {
  int pageCount = 604,
}) {
  if (records.isEmpty) return null;

  LessonRecordSpec last = records.first;
  for (final r in records.skip(1)) {
    final rDate = r.date;
    final lastDate = last.date;
    final bool newer;
    if (rDate != null && lastDate != null) {
      newer = rDate.isAfter(lastDate) ||
          (rDate.isAtSameMomentAs(lastDate) && r.pageEnd > last.pageEnd);
    } else if (rDate != null) {
      newer = true; // a dated record outranks an undated one
    } else if (lastDate != null) {
      newer = false;
    } else {
      newer = r.pageEnd > last.pageEnd;
    }
    if (newer) last = r;
  }

  final next = last.pageEnd + 1;
  if (next > pageCount) return null;
  // A suggested assignment is deliberately one page: small, finishable, and it
  // does not assume how much time the next session has.
  return (pageStart: next, pageEnd: next);
}

// ════════════════════════════════════════════════════════════════════
/// PARENT REPORT TEXT
//═══════════════════════════════════════════════════════════════════

/// The facts the report template reads. Every field is optional because a
/// report may be built for a student with no attendance or no grades yet.
class ReportFacts {
  const ReportFacts({
    required this.studentName,
    required this.className,
    required this.fromDayKey,
    required this.toDayKey,
    this.attendancePercent,
    this.sessionsAttended,
    this.sessionsTotal,
    this.newPages = 0,
    this.highestPage = 0,
    this.averageGrade,
    this.topTagTitle,
    this.nextAssignment,
    this.teacherName,
  });

  final String studentName;
  final String className;
  final String fromDayKey;
  final String toDayKey;
  final double? attendancePercent;
  final int? sessionsAttended;
  final int? sessionsTotal;
  final int newPages;
  final int highestPage;
  final double? averageGrade;
  final String? topTagTitle;
  final String? nextAssignment;
  final String? teacherName;
}

/// Rule-based paragraphs, in the order the report prints them.
///
/// No AI, no generated judgement: every sentence is a template chosen by a
/// condition, and the teacher edits the result before sending. The tone rules
/// from the brief: state attendance plainly, state progress as a number, and
/// pair the most common tag with a gentle suggestion rather than a criticism.
List<String> buildReportParagraphs(ReportFacts facts, {bool includeGrades = true}) {
  final out = <String>[];

  // Attendance.
  final pct = facts.attendancePercent;
  if (pct != null) {
    final percentText = (pct * 100).round();
    final attended = facts.sessionsAttended;
    final total = facts.sessionsTotal;
    if (attended != null && total != null) {
      out.add(
        'در ${_fa(attended)} جلسه از ${_fa(total)} جلسهٔ این دوره حاضر بوده‌اید '
        '(${_fa(percentText)}٪ حضور).',
      );
    } else {
      out.add('میزان حضور در این دوره ${_fa(percentText)}٪ بوده است.');
    }
  }

  // Progress.
  if (facts.newPages > 0 || facts.highestPage > 0) {
    final parts = <String>[];
    if (facts.newPages > 0) {
      parts.add('${_fa(facts.newPages)} صفحهٔ تازه');
    }
    if (facts.highestPage > 0) {
      parts.add('تا صفحهٔ ${_fa(facts.highestPage)}');
    }
    out.add('پیشرفت این دوره: ${parts.join(' · ')}.');
  }

  // Grades.
  if (includeGrades && facts.averageGrade != null) {
    final v = facts.averageGrade!;
    // Round to one decimal with Latin digits, per the product standard.
    final text = v.toStringAsFixed(1);
    out.add('میانگین نمرهٔ درس‌ها $text از ۴ است.');
  }

  // Most common tag + gentle suggestion.
  final tag = facts.topTagTitle;
  if (tag != null && tag.isNotEmpty) {
    out.add(
      'بیشترین نکته‌ای که در این دوره تکرار شده «$tag» بوده است؛ '
      'تمرین کوتاه روزانه روی همین مورد کمک‌کننده است.',
    );
  }

  // Next assignment.
  final next = facts.nextAssignment;
  if (next != null && next.isNotEmpty) {
    out.add('تکلیف جلسهٔ بعد: $next.');
  }

  return out;
}

/// Which part of the mushaf a number of pages represents, in words a parent
/// reads without a table: «جزء ۲». Null for page 0 / out of range.
int? juzOfPageOrNull(int page, {int pageCount = 604}) {
  if (page < 1 || page > pageCount) return null;
  return ((page - 1) ~/ (pageCount / 30)).clamp(0, 29) + 1;
}

/// One warm closing line, always safe to print.
String reportClosing({String? teacherName}) {
  final who = (teacherName == null || teacherName.trim().isEmpty)
      ? ''
      : ' ${teacherName.trim()}';
  return 'با سپاس از همراهی شما.$who';
}

/// Persian digits for a count, ASCII for the product's numeric standard.
/// The *labels* are Persian; numerals stay Latin app-wide, so this keeps
/// numbers ASCII and only writes them into a Persian sentence.
String _fa(int n) => n.toString();

// ════════════════════════════════════════════════════════════════════
/// SESSIONS
//═══════════════════════════════════════════════════════════════════

/// Whether [classWeekdaysMask] schedules a session on [dayKey].
///
/// Bit 0 = Saturday, the same mask convention as the kids habits.
bool classMeetsOn(String dayKey, int classWeekdaysMask) {
  final parts = _parseDayKey(dayKey);
  if (parts == null) return false;
  final bit = Jalali(parts.$1, parts.$2, parts.$3).weekDay - 1;
  return (classWeekdaysMask & (1 << bit)) != 0;
}

/// Minutes since midnight → «17:30», Latin digits like every other number in
/// the app. Used for the class start time the reminders are measured from.
String classTimeLabel(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}';
}

/// The Jalali day key for a DateTime, matching the kids tool's format so both
/// tools can share a range query.
String teacherDayKey(DateTime instant) {
  final j = Jalali.fromDateTime(instant);
  return '${j.year.toString().padLeft(4, '0')}-'
      '${j.month.toString().padLeft(2, '0')}-'
      '${j.day.toString().padLeft(2, '0')}';
}

(int, int, int)? _parseDayKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return (y, m, d);
}

/// The seven day keys of the week containing [dayKey], oldest first.
List<String> teacherWeekKeys(String dayKey) {
  final parts = _parseDayKey(dayKey);
  if (parts == null) return const [];
  final j = Jalali(parts.$1, parts.$2, parts.$3);
  return [
    for (var back = 6; back >= 0; back--)
      () {
        final d = j.addDays(-back);
        return '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
      }(),
  ];
}
