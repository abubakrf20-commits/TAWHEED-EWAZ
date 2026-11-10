import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/features/personal2/shared/template_store.dart';
import 'package:tawheeed/features/worship/quran_teacher/data/quran_teacher_dao.dart';
import 'package:tawheeed/features/worship/quran_teacher/domain/quran_teacher_logic.dart';
import 'package:tawheeed/features/worship/quran_teacher/services/quran_teacher_reminders.dart';

/// Everything the class-home screen needs for one class and one day.
class ClassDayState {
  const ClassDayState({
    required this.classGroup,
    required this.students,
    required this.session,
    required this.attendance,
    required this.lessons,
    required this.settings,
    required this.todayKey,
  });

  final ClassGroupRecord classGroup;
  final List<StudentRecord> students;
  final SessionRecord? session;
  final List<AttendanceRow> attendance;
  final List<LessonRecordRow> lessons;
  final TeacherSettingsRecord settings;
  final String todayKey;

  AttendanceStatus? statusFor(String studentId) {
    for (final a in attendance) {
      if (a.studentId == studentId) return a.status;
    }
    return null;
  }

  LessonRecordRow? lessonFor(String studentId) {
    for (final l in lessons) {
      if (l.studentId == studentId) return l;
    }
    return null;
  }

  int get presentCount => students
      .where((s) => {
            AttendanceStatus.present,
            AttendanceStatus.late,
          }.contains(statusFor(s.id)))
      .length;

  int get absentCount => students
      .where((s) => statusFor(s.id) == AttendanceStatus.absent)
      .length;

  int get lateCount => students
      .where((s) => statusFor(s.id) == AttendanceStatus.late)
      .length;

  /// Students with no attendance recorded yet — the «ثبت جلسه» precondition.
  int get unrecordedCount =>
      students.where((s) => statusFor(s.id) == null).length;
}

/// The classes list plus the teacher's settings.
class TeacherHomeState {
  const TeacherHomeState({
    required this.classes,
    required this.settings,
    required this.todayKey,
  });

  final List<ClassGroupRecord> classes;
  final TeacherSettingsRecord settings;
  final String todayKey;
}

final quranTeacherHomeProvider = FutureProvider<TeacherHomeState>((ref) async {
  final dao = ref.read(quranTeacherDaoProvider);
  return TeacherHomeState(
    classes: await dao.classes(),
    settings: await dao.settings(),
    todayKey: teacherDayKey(DateTime.now()),
  );
});

/// The teacher reminders' scheduler, overridable in tests.
final quranTeacherRemindersServiceProvider = Provider<QuranTeacherReminders>(
  (ref) => QuranTeacherReminders(),
);

/// Schedules the three nudges the settings row describes (class start,
/// unrecorded lesson, weekly review) for today.
///
/// A provider so it re-runs when a session is saved or attendance changes —
/// «ثبت شد» must also cancel the evening nudge it would have produced.
final quranTeacherReminderSyncProvider = FutureProvider<void>((ref) async {
  final home = await ref.watch(quranTeacherHomeProvider.future);
  final dao = ref.read(quranTeacherDaoProvider);
  final service = ref.read(quranTeacherRemindersServiceProvider);
  final now = DateTime.now();
  final dayKey = teacherDayKey(now);

  final unrecorded = <String>[];
  for (final klass in home.classes) {
    if (klass.archived) continue;
    final session = await dao.sessionForDay(klass.id, dayKey);
    if (session == null) continue;
    final lessons = await dao.lessonsForSession(session.id);
    if (lessons.isEmpty) unrecorded.add(klass.name);
  }

  await service.sync(
    settings: home.settings,
    classes: home.classes,
    unrecordedClassNames: unrecorded,
    now: now,
  );
});

/// One class on today's date. `classId` is null-safe: with no classes the home
/// screen offers «افزودن کلاس» and this provider simply returns null.
final quranClassDayProvider =
    FutureProvider.family<ClassDayState?, String>((ref, classId) async {
  final dao = ref.read(quranTeacherDaoProvider);
  final now = DateTime.now();
  final todayKey = teacherDayKey(now);

  final classes = await dao.classes(includeArchived: true);
  final klass = classes.where((c) => c.id == classId).firstOrNull;
  if (klass == null) return null;

  final settings = await dao.settings();
  final students = await dao.students(classId);

  // Today's session is created on open when the class meets today — the
  // brief's «جلسهٔ امروز» — and never for a day the class does not meet.
  final session = await dao.ensureTodaySession(
    classId: classId,
    dayKey: todayKey,
    weekdaysMask: klass.weekdaysMask,
    now: now,
  );

  final attendance = session == null
      ? const <AttendanceRow>[]
      : await dao.attendanceForSession(session.id);
  final lessons = session == null
      ? const <LessonRecordRow>[]
      : await dao.lessonsForSession(session.id);

  return ClassDayState(
    classGroup: klass,
    students: students,
    session: session,
    attendance: attendance,
    lessons: lessons,
    settings: settings,
    todayKey: todayKey,
  );
});

/// One past session, reduced to the numbers a list row shows.
class SessionHistoryEntry {
  const SessionHistoryEntry({
    required this.session,
    required this.breakdown,
    required this.lessonCount,
    required this.studentCount,
  });

  final SessionRecord session;
  final AttendanceBreakdown breakdown;
  final int lessonCount;
  final int studentCount;

  /// Students of the class who have no answer for this session yet.
  int get unrecorded =>
      (studentCount - breakdown.total).clamp(0, studentCount);

  bool get complete => unrecorded == 0;
}

/// A class's whole recorded history: every session, its counts, and the two
/// numbers the class summary card prints.
class ClassHistoryState {
  const ClassHistoryState({
    required this.classGroup,
    required this.students,
    required this.sessions,
    required this.attendanceRate,
    required this.pagesPerStudent,
  });

  final ClassGroupRecord classGroup;
  final List<StudentRecord> students;

  /// Newest first.
  final List<SessionHistoryEntry> sessions;

  /// Pooled attendance across every recorded row, with the tool's
  /// «مرخص از مخرج حذف شود» setting applied.
  final double? attendanceRate;

  /// Distinct pages per student, averaged over the roster — never a ranking.
  final double? pagesPerStudent;

  AttendanceBreakdown get totals {
    var present = 0;
    var absent = 0;
    var late = 0;
    var excused = 0;
    for (final s in sessions) {
      present += s.breakdown.present;
      absent += s.breakdown.absent;
      late += s.breakdown.late;
      excused += s.breakdown.excused;
    }
    return AttendanceBreakdown(
      present: present,
      absent: absent,
      late: late,
      excused: excused,
    );
  }

  /// Sessions whose lesson records are still empty — the teacher's to-do list.
  int get sessionsWithoutLessons =>
      sessions.where((s) => s.lessonCount == 0).length;
}

/// The class history, newest session first.
///
/// One read per session is deliberate: the tool has at most a few dozen
/// sessions per class and each query is tiny, and this keeps the DAO free of a
/// second join-shaped shape that would have to be maintained alongside it.
final quranClassHistoryProvider =
    FutureProvider.family<ClassHistoryState?, String>((ref, classId) async {
  final dao = ref.read(quranTeacherDaoProvider);
  final settings = await dao.settings();
  final classes = await dao.classes(includeArchived: true);
  final klass = classes.where((c) => c.id == classId).firstOrNull;
  if (klass == null) return null;

  final students = await dao.students(classId, includeInactive: true);
  final sessions = await dao.recentSessions(classId, limit: 200);

  final entries = <SessionHistoryEntry>[];
  final attendanceSpecs = <AttendanceRecordSpec>[];
  final lessonSpecs = <LessonRecordSpec>[];
  for (final session in sessions) {
    final attendance = await dao.attendanceForSession(session.id);
    final lessons = await dao.lessonsForSession(session.id);
    entries.add(
      SessionHistoryEntry(
        session: session,
        breakdown: attendanceBreakdown(
          [for (final a in attendance) _attendanceSpec(a, session.dayKey)],
        ),
        lessonCount: lessons.length,
        studentCount: students.length,
      ),
    );
    attendanceSpecs.addAll(
      [for (final a in attendance) _attendanceSpec(a, session.dayKey)],
    );
    lessonSpecs.addAll([for (final l in lessons) l.toSpec()]);
  }

  final averages = classAverages(
    attendance: attendanceSpecs,
    studentIds: [for (final s in students) s.id],
    lessons: lessonSpecs,
    excusedExcluded: settings.excusedExcluded,
  );

  return ClassHistoryState(
    classGroup: klass,
    students: students,
    sessions: entries,
    attendanceRate: averages.attendance,
    pagesPerStudent: averages.pagesPerStudent,
  );
});

/// One past session, with the roster and its rows — the editable «سابقه» sheet.
class SessionDetailState {
  const SessionDetailState({
    required this.classGroup,
    required this.session,
    required this.students,
    required this.attendance,
    required this.lessons,
  });

  final ClassGroupRecord classGroup;
  final SessionRecord session;
  final List<StudentRecord> students;
  final List<AttendanceRow> attendance;
  final List<LessonRecordRow> lessons;

  AttendanceStatus? statusFor(String studentId) {
    for (final a in attendance) {
      if (a.studentId == studentId) return a.status;
    }
    return null;
  }

  LessonRecordRow? lessonFor(String studentId) {
    for (final l in lessons) {
      if (l.studentId == studentId) return l;
    }
    return null;
  }

  AttendanceBreakdown get breakdown => attendanceBreakdown([
        for (final a in attendance) _attendanceSpec(a, session.dayKey),
      ]);
}

final quranSessionDetailProvider =
    FutureProvider.family<SessionDetailState?, String>((ref, sessionId) async {
  final dao = ref.read(quranTeacherDaoProvider);
  final session = await dao.sessionById(sessionId);
  if (session == null) return null;
  final classes = await dao.classes(includeArchived: true);
  final klass = classes.where((c) => c.id == session.classId).firstOrNull;
  if (klass == null) return null;

  final roster = await dao.students(session.classId);
  final attendance = await dao.attendanceForSession(sessionId);
  final lessons = await dao.lessonsForSession(sessionId);

  // A student who has since left the class still owns their old attendance
  // rows; the sheet lists the roster plus anyone the session actually
  // recorded, so a number is never hidden from the teacher.
  final extra = <StudentRecord>[];
  final known = {for (final s in roster) s.id};
  final recordedIds = <String>[
    for (final a in attendance) a.studentId,
    for (final l in lessons) l.studentId,
  ];
  for (final id in recordedIds) {
    if (!known.add(id)) continue;
    final student = await dao.student(id);
    if (student != null) extra.add(student);
  }

  return SessionDetailState(
    classGroup: klass,
    session: session,
    students: [...roster, ...extra],
    attendance: attendance,
    lessons: lessons,
  );
});

AttendanceRecordSpec _attendanceSpec(AttendanceRow row, String dayKey) =>
    AttendanceRecordSpec(
      sessionId: row.sessionId,
      studentId: row.studentId,
      status: row.status,
      dayKey: dayKey,
    );

/// A student's full history — profile, progress and the parent report source.
class StudentProfileState {
  const StudentProfileState({
    required this.student,
    required this.classGroup,
    required this.attendance,
    required this.lessons,
    required this.settings,
    required this.sessions,
    this.grades = const [],
  });

  final StudentRecord student;
  final ClassGroupRecord classGroup;
  final List<AttendanceRow> attendance;
  final List<LessonRecordRow> lessons;
  final TeacherSettingsRecord settings;
  final List<SessionRecord> sessions;

  /// The editable grade scale, so averages use the teacher's own numbers and a
  /// disabled/edited entry is honoured instead of a hard-coded 4/3/2/1.
  final List<GradeScaleEntry> grades;

  Set<int> get recitedPages =>
      distinctRecitationPages(lessons.map((l) => l.toSpec()));

  Set<int> get hifzPages => distinctHifzPages(lessons.map((l) => l.toSpec()));

  int get highest => highestPage(recitedPages);

  double? get attendancePct => attendancePercent(
        [for (final a in attendance) _att(a)],
        excusedExcluded: settings.excusedExcluded,
      );

  double? get averageGradeValue => averageGrade(
        lessons.map((l) => l.toSpec()),
        gradeValue,
      );

  /// Numeric value of a grade key, from the scale asset (null when unknown).
  int? gradeValue(String key) {
    for (final g in grades) {
      if (g.key == key) return g.value;
    }
    return null;
  }

  String gradeTitle(String key) {
    for (final g in grades) {
      if (g.key == key) return g.titleFa;
    }
    return key;
  }

  /// The page the teacher stored as «تکلیف جلسهٔ بعد» — the newest record that
  /// carries one, so an older edit cannot overwrite it.
  int? get nextAssignment {
    for (final lesson in lessons.reversed) {
      if (lesson.nextPageStart != null) return lesson.nextPageStart;
    }
    return null;
  }

  /// Consecutive absences at the end of the recorded sessions, oldest first.
  ///
  /// Attendance rows carry a session id, so they are paired to sessions here to
  /// get their day keys; a session the teacher never took attendance for is
  /// simply absent from the map and is skipped by [absenceStreak], which is the
  /// behaviour that function already pins.
  int get currentAbsenceStreak {
    final statusByDay = <String, AttendanceStatus>{};
    for (final session in sessions) {
      for (final row in attendance) {
        if (row.sessionId == session.id) {
          statusByDay[session.dayKey] = row.status;
        }
      }
    }
    return absenceStreak(
      dayKeys: [for (final s in sessions.reversed) s.dayKey],
      statusByDay: statusByDay,
    );
  }

  static AttendanceRecordSpec _att(AttendanceRow row) => AttendanceRecordSpec(
        sessionId: row.sessionId,
        studentId: row.studentId,
        status: row.status,
        dayKey: '',
      );
}

/// Built with the grade scale so the average uses the teacher's own numbers.
final quranStudentProfileProvider =
    FutureProvider.family<StudentProfileState?, String>((ref, studentId) async {
  final dao = ref.read(quranTeacherDaoProvider);
  final student = await dao.student(studentId);
  if (student == null) return null;

  final classes = await dao.classes(includeArchived: true);
  final klass = classes.where((c) => c.id == student.classId).firstOrNull;
  if (klass == null) return null;

  final templates = await ref.read(templateStoreProvider).load();

  return StudentProfileState(
    student: student,
    classGroup: klass,
    attendance: await dao.attendanceForStudent(studentId),
    lessons: await dao.lessonsForStudent(studentId),
    settings: await dao.settings(),
    sessions: await dao.recentSessions(student.classId, limit: 200),
    grades: templates.grades,
  );
});

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

/// Students of one class — declared here, not beside the screen that reads it,
/// so the declaration sits with the rest of the teacher providers.
final quranStudentsProvider =
    FutureProvider.family<List<StudentRecord>, String>((ref, classId) {
  return ref.read(quranTeacherDaoProvider).students(classId);
});
