import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/personal2/data/personal2_tables.dart';
import 'package:tawheeed/features/worship/quran_teacher/domain/quran_teacher_logic.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// A class/mosque group.
class ClassGroupRecord {
  const ClassGroupRecord({
    required this.id,
    required this.name,
    required this.place,
    required this.weekdaysMask,
    this.startMinutes,
    this.durationMin,
    required this.archived,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String place;
  final int weekdaysMask;
  final int? startMinutes;
  final int? durationMin;
  final bool archived;
  final DateTime createdAt;
}

/// A student.
class StudentRecord {
  const StudentRecord({
    required this.id,
    required this.classId,
    required this.name,
    this.birthYear,
    required this.parentName,
    required this.parentPhone,
    required this.note,
    required this.active,
    required this.joinedAt,
  });

  final String id;
  final String classId;
  final String name;
  final int? birthYear;
  final String parentName;
  final String parentPhone;

  /// Typed manually by the teacher. The tool never reads the contacts
  /// permission — the brief forbids it.
  final String note;
  final bool active;
  final DateTime joinedAt;
}

/// One session (a day the class met).
class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.classId,
    required this.dayKey,
    required this.date,
    required this.number,
    required this.note,
    required this.createdAt,
    required this.closed,
  });

  final String id;
  final String classId;
  final String dayKey;
  final DateTime date;
  final int number;
  final String note;
  final DateTime createdAt;
  final bool closed;
}

/// One attendance row.
class AttendanceRow {
  const AttendanceRow({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.status,
    required this.note,
  });

  final String id;
  final String sessionId;
  final String studentId;
  final AttendanceStatus status;
  final String note;
}

/// One lesson record.
class LessonRecordRow {
  const LessonRecordRow({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.dayKey,
    required this.date,
    required this.type,
    required this.pageStart,
    required this.pageEnd,
    this.lineStart,
    this.lineEnd,
    this.gradeKey,
    required this.mistakeCount,
    required this.tajweedTags,
    required this.note,
    this.nextPageStart,
    this.nextPageEnd,
    this.nextLineStart,
    this.nextLineEnd,
  });

  final String id;
  final String sessionId;
  final String studentId;
  final String dayKey;
  final DateTime date;
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

  /// Domain projection for the pure maths.
  LessonRecordSpec toSpec() => LessonRecordSpec(
        id: id,
        studentId: studentId,
        sessionId: sessionId,
        dayKey: dayKey,
        type: type,
        pageStart: pageStart,
        pageEnd: pageEnd,
        lineStart: lineStart,
        lineEnd: lineEnd,
        gradeKey: gradeKey,
        mistakeCount: mistakeCount,
        tajweedTags: tajweedTags,
        note: note,
        nextPageStart: nextPageStart,
        nextPageEnd: nextPageEnd,
        nextLineStart: nextLineStart,
        nextLineEnd: nextLineEnd,
        date: date,
      );
}

/// The tool's settings row (single row, id = 'teacher').
class TeacherSettingsRecord {
  const TeacherSettingsRecord({
    this.className = '',
    this.mosqueName = '',
    this.teacherName = '',
    this.excusedExcluded = true,
    this.absenceStreakAlert = true,
    this.remindersEnabled = false,
    this.classStartReminder = true,
    this.unrecordedReminder = true,
    this.weeklySummary = false,
    this.quietStartMinutes = 1320,
    this.quietEndMinutes = 420,
  });

  final String className;
  final String mosqueName;
  final String teacherName;
  final bool excusedExcluded;
  final bool absenceStreakAlert;
  final bool remindersEnabled;
  final bool classStartReminder;
  final bool unrecordedReminder;
  final bool weeklySummary;
  final int quietStartMinutes;
  final int quietEndMinutes;
}

/// Raw-SQL access to the teacher tables. Same swallow-and-log contract as the
/// kids DAO.
class QuranTeacherDao {
  QuranTeacherDao(this.db);

  final AppDatabase db;

  static const String settingsId = 'teacher';

  static DateTime _date(Object? v) =>
      (v as int?) == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(v as int);

  static List<String> _tags(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'tags unreadable: $e');
    }
    return const [];
  }

  // ── Classes ──────────────────────────────────────────────────────────

  Future<List<ClassGroupRecord>> classes({bool includeArchived = false}) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.classGroup} '
        '${includeArchived ? '' : 'WHERE archived = 0 '}'
        'ORDER BY created_at ASC',
      ).get();
      return [
        for (final r in rows)
          ClassGroupRecord(
            id: r.read<String>('id'),
            name: r.read<String>('name'),
            place: r.read<String>('place'),
            weekdaysMask: r.read<int>('weekdays_mask'),
            startMinutes: r.readNullable<int>('start_minutes'),
            durationMin: r.readNullable<int>('duration_min'),
            archived: r.read<int>('archived') == 1,
            createdAt: _date(r.read<int>('created_at')),
          ),
      ];
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'classes read failed: $e');
      return const [];
    }
  }

  Future<bool> saveClass({
    required String id,
    required String name,
    String place = '',
    int weekdaysMask = 0x7F,
    int? startMinutes,
    int? durationMin,
  }) async {
    try {
      await db.customStatement(
        'INSERT OR REPLACE INTO ${Personal2Tables.classGroup} '
        '(id, name, place, weekdays_mask, start_minutes, duration_min, '
        'archived, created_at) '
        'SELECT ?, ?, ?, ?, ?, ?, 0, ? '
        'WHERE NOT EXISTS (SELECT 1 FROM ${Personal2Tables.classGroup} '
        'WHERE id = ?)',
        [
          id,
          name,
          place,
          weekdaysMask,
          startMinutes,
          durationMin,
          DateTime.now().millisecondsSinceEpoch,
          id,
        ],
      );
      // The REPLACE above deliberately cannot run for an existing row (it
      // would reset created_at and archived); an update handles the edit.
      await db.customStatement(
        'UPDATE ${Personal2Tables.classGroup} SET name = ?, place = ?, '
        'weekdays_mask = ?, start_minutes = ?, duration_min = ? WHERE id = ?',
        [name, place, weekdaysMask, startMinutes, durationMin, id],
      );
      return true;
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'class save failed: $e');
      return false;
    }
  }

  Future<bool> archiveClass(String classId) async {
    try {
      await db.transaction(() async {
        await db.customStatement(
          'UPDATE ${Personal2Tables.classGroup} SET archived = 1 WHERE id = ?',
          [classId],
        );
        await db.customStatement(
          'UPDATE ${Personal2Tables.student} SET active = 0 WHERE class_id = ?',
          [classId],
        );
      });
      return true;
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'class archive failed: $e');
      return false;
    }
  }

  // ── Students ─────────────────────────────────────────────────────────

  Future<List<StudentRecord>> students(String classId,
      {bool includeInactive = false}) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.student} WHERE class_id = ? '
        '${includeInactive ? '' : 'AND active = 1 '}ORDER BY joined_at ASC',
        variables: [Variable.withString(classId)],
      ).get();
      return [for (final r in rows) _student(r)];
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'students read failed: $e');
      return const [];
    }
  }

  Future<StudentRecord?> student(String studentId) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.student} WHERE id = ?',
        variables: [Variable.withString(studentId)],
      ).get();
      if (rows.isEmpty) return null;
      return _student(rows.first);
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'student read failed: $e');
      return null;
    }
  }

  Future<bool> saveStudent({
    required String id,
    required String classId,
    required String name,
    int? birthYear,
    String parentName = '',
    String parentPhone = '',
    String note = '',
    bool active = true,
  }) async {
    try {
      final existing = await db.customSelect(
        'SELECT id FROM ${Personal2Tables.student} WHERE id = ?',
        variables: [Variable.withString(id)],
      ).get();
      if (existing.isEmpty) {
        await db.customStatement(
          'INSERT INTO ${Personal2Tables.student} '
          '(id, class_id, name, birth_year, parent_name, parent_phone, note, '
          'active, joined_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            id,
            classId,
            name,
            birthYear,
            parentName,
            parentPhone,
            note,
            active ? 1 : 0,
            DateTime.now().millisecondsSinceEpoch,
          ],
        );
      } else {
        await db.customStatement(
          'UPDATE ${Personal2Tables.student} SET class_id = ?, name = ?, '
          'birth_year = ?, parent_name = ?, parent_phone = ?, note = ?, '
          'active = ? WHERE id = ?',
          [
            classId,
            name,
            birthYear,
            parentName,
            parentPhone,
            note,
            active ? 1 : 0,
            id,
          ],
        );
      }
      return true;
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'student save failed: $e');
      return false;
    }
  }

  /// The per-student «delete everything».
  ///
  /// Removes the student, their attendance and their lesson records — and
  /// leaves the class, the sessions and every other student untouched.
  Future<bool> deleteEverythingForStudent(String studentId) async {
    try {
      await db.transaction(() async {
        await db.customStatement(
          'DELETE FROM ${Personal2Tables.lessonRecord} WHERE student_id = ?',
          [studentId],
        );
        await db.customStatement(
          'DELETE FROM ${Personal2Tables.attendance} WHERE student_id = ?',
          [studentId],
        );
        await db.customStatement(
          'DELETE FROM ${Personal2Tables.student} WHERE id = ?',
          [studentId],
        );
      });
      return true;
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'student delete failed: $e');
      return false;
    }
  }

  // ── Sessions ─────────────────────────────────────────────────────────

  Future<SessionRecord?> sessionForDay(String classId, String dayKey) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.session} '
        'WHERE class_id = ? AND day_key = ?',
        variables: [Variable.withString(classId), Variable.withString(dayKey)],
      ).get();
      if (rows.isEmpty) return null;
      return _session(rows.first);
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'session read failed: $e');
      return null;
    }
  }

  /// One session by id — the entry point for the «سابقهٔ جلسه‌ها» list, whose
  /// rows are sessions from other days.
  Future<SessionRecord?> sessionById(String sessionId) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.session} WHERE id = ?',
        variables: [Variable.withString(sessionId)],
      ).get();
      if (rows.isEmpty) return null;
      return _session(rows.first);
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'session read failed: $e');
      return null;
    }
  }

  /// Creates today's session if the class meets today and it does not exist.
  ///
  /// Session numbering is «جلسهٔ N» counted from the class's first session, so
  /// a skipped day does not renumber history.
  Future<SessionRecord?> ensureTodaySession({
    required String classId,
    required String dayKey,
    required int weekdaysMask,
    required DateTime now,
  }) async {
    final existing = await sessionForDay(classId, dayKey);
    if (existing != null) return existing;
    if (!classMeetsOn(dayKey, weekdaysMask)) return null;
    try {
      final countRows = await db.customSelect(
        'SELECT COUNT(*) AS n FROM ${Personal2Tables.session} WHERE class_id = ?',
        variables: [Variable.withString(classId)],
      ).get();
      final number = countRows.first.read<int>('n') + 1;
      final id = 'ses_${classId}_$dayKey';
      await db.customStatement(
        'INSERT OR IGNORE INTO ${Personal2Tables.session} '
        '(id, class_id, day_key, date, number, note, created_at, closed) '
        'VALUES (?, ?, ?, ?, ?, \'\', ?, 0)',
        [
          id,
          classId,
          dayKey,
          now.millisecondsSinceEpoch,
          number,
          now.millisecondsSinceEpoch,
        ],
      );
      return sessionForDay(classId, dayKey);
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'ensure session failed: $e');
      return null;
    }
  }

  Future<bool> closeSession(String sessionId) async {
    try {
      await db.customStatement(
        'UPDATE ${Personal2Tables.session} SET closed = 1 WHERE id = ?',
        [sessionId],
      );
      return true;
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'close session failed: $e');
      return false;
    }
  }

  /// Opens or closes a session. A closed session is «ثبت‌شده»; opening it
  /// again is how a teacher fixes a mistake they spotted days later, so this
  /// is a toggle, not a one-way door.
  Future<bool> setSessionClosed(String sessionId, bool closed) async {
    try {
      await db.customStatement(
        'UPDATE ${Personal2Tables.session} SET closed = ? WHERE id = ?',
        [closed ? 1 : 0, sessionId],
      );
      return true;
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'session toggle failed: $e');
      return false;
    }
  }

  /// The session's own note («این جلسه تعطیل شد»، «درس جبرانی»).
  Future<bool> saveSessionNote(String sessionId, String note) async {
    try {
      await db.customStatement(
        'UPDATE ${Personal2Tables.session} SET note = ? WHERE id = ?',
        [note, sessionId],
      );
      return true;
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'session note save failed: $e');
      return false;
    }
  }

  Future<List<SessionRecord>> recentSessions(String classId, {int limit = 20}) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.session} WHERE class_id = ? '
        'ORDER BY date DESC LIMIT $limit',
        variables: [Variable.withString(classId)],
      ).get();
      return [for (final r in rows) _session(r)];
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'sessions read failed: $e');
      return const [];
    }
  }

  // ── Attendance ───────────────────────────────────────────────────────

  Future<List<AttendanceRow>> attendanceForSession(String sessionId) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.attendance} WHERE session_id = ?',
        variables: [Variable.withString(sessionId)],
      ).get();
      return [for (final r in rows) _attendance(r)];
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'attendance read failed: $e');
      return const [];
    }
  }

  Future<List<AttendanceRow>> attendanceForStudent(String studentId) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.attendance} WHERE student_id = ?',
        variables: [Variable.withString(studentId)],
      ).get();
      return [for (final r in rows) _attendance(r)];
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'student attendance read failed: $e');
      return const [];
    }
  }

  /// Records one student's status, replacing any earlier answer for the same
  /// session (a teacher tapping غ then ح means «حاضر», not two rows).
  Future<bool> setAttendance({
    required String sessionId,
    required String studentId,
    required AttendanceStatus status,
  }) async {
    try {
      await db.customStatement(
        'INSERT OR REPLACE INTO ${Personal2Tables.attendance} '
        '(id, session_id, student_id, status, note, created_at) '
        'VALUES (?, ?, ?, ?, \'\', ?)',
        [
          'att_${sessionId}_$studentId',
          sessionId,
          studentId,
          status.wire,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      return true;
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'attendance save failed: $e');
      return false;
    }
  }

  /// Marks every student present in one pass («همه حاضر»).
  Future<bool> markAllPresent({
    required String sessionId,
    required List<String> studentIds,
  }) async {
    if (studentIds.isEmpty) return true;
    try {
      await db.transaction(() async {
        for (final id in studentIds) {
          await setAttendance(
            sessionId: sessionId,
            studentId: id,
            status: AttendanceStatus.present,
          );
        }
      });
      return true;
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'mark all present failed: $e');
      return false;
    }
  }

  // ── Lesson records ───────────────────────────────────────────────────

  Future<List<LessonRecordRow>> lessonsForStudent(
    String studentId, {
    String? fromDayKey,
    String? toDayKey,
  }) async {
    try {
      final where = StringBuffer('WHERE student_id = ?');
      final vars = <Variable<Object>>[Variable.withString(studentId)];
      if (fromDayKey != null) {
        where.write(' AND day_key >= ?');
        vars.add(Variable.withString(fromDayKey));
      }
      if (toDayKey != null) {
        where.write(' AND day_key <= ?');
        vars.add(Variable.withString(toDayKey));
      }
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.lessonRecord} $where '
        'ORDER BY date ASC, created_at ASC',
        variables: vars,
      ).get();
      return [for (final r in rows) _lesson(r)];
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'lessons read failed: $e');
      return const [];
    }
  }

  Future<List<LessonRecordRow>> lessonsForSession(String sessionId) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.lessonRecord} WHERE session_id = ? '
        'ORDER BY created_at ASC',
        variables: [Variable.withString(sessionId)],
      ).get();
      return [for (final r in rows) _lesson(r)];
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'session lessons read failed: $e');
      return const [];
    }
  }

  /// Saves a lesson record. Validation is the caller's job (the sheet runs
  /// `validateLesson` first), but the obvious nonsense is refused here too so
  /// a programmatic path cannot write page 0.
  Future<bool> saveLesson({
    required String id,
    required String sessionId,
    required String studentId,
    required String dayKey,
    required LessonType type,
    required int pageStart,
    required int pageEnd,
    int? lineStart,
    int? lineEnd,
    String? gradeKey,
    int mistakeCount = 0,
    List<String> tajweedTags = const [],
    String note = '',
    int? nextPageStart,
    int? nextPageEnd,
    int? nextLineStart,
    int? nextLineEnd,
    MushafMeta meta = MushafMeta.standard,
  }) async {
    final problem = validateLesson(
      pageStart: pageStart,
      pageEnd: pageEnd,
      lineStart: lineStart,
      lineEnd: lineEnd,
      meta: meta,
    );
    if (problem != null) {
      AppLogger.warning('QuranTeacherDao', 'lesson rejected: $problem');
      return false;
    }
    try {
      await db.customStatement(
        'INSERT OR REPLACE INTO ${Personal2Tables.lessonRecord} '
        '(id, session_id, student_id, day_key, date, type, page_start, '
        'page_end, line_start, line_end, grade_key, mistake_count, '
        'tajweed_tags, note, next_page_start, next_page_end, '
        'next_line_start, next_line_end, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          sessionId,
          studentId,
          dayKey,
          DateTime.now().millisecondsSinceEpoch,
          type.wire,
          pageStart,
          pageEnd,
          lineStart,
          lineEnd,
          gradeKey,
          mistakeCount,
          jsonEncode(tajweedTags),
          note,
          nextPageStart,
          nextPageEnd,
          nextLineStart,
          nextLineEnd,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      return true;
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'lesson save failed: $e');
      return false;
    }
  }

  Future<bool> deleteLesson(String lessonId) async {
    try {
      await db.customStatement(
        'DELETE FROM ${Personal2Tables.lessonRecord} WHERE id = ?',
        [lessonId],
      );
      return true;
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'lesson delete failed: $e');
      return false;
    }
  }

  // ── Settings ─────────────────────────────────────────────────────────

  Future<TeacherSettingsRecord> settings() async {
    const fallback = TeacherSettingsRecord();
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.teacherSettings} WHERE id = ?',
        variables: [Variable.withString(settingsId)],
      ).get();
      if (rows.isEmpty) return fallback;
      final r = rows.first;
      return TeacherSettingsRecord(
        className: r.read<String>('class_name'),
        mosqueName: r.read<String>('mosque_name'),
        teacherName: r.read<String>('teacher_name'),
        excusedExcluded: r.read<int>('excused_excluded') == 1,
        absenceStreakAlert: r.read<int>('absence_streak_alert') == 1,
        remindersEnabled: r.read<int>('reminders_enabled') == 1,
        classStartReminder: r.read<int>('class_start_reminder') == 1,
        unrecordedReminder: r.read<int>('unrecorded_reminder') == 1,
        weeklySummary: r.read<int>('weekly_summary') == 1,
        quietStartMinutes: r.read<int>('quiet_start_minutes'),
        quietEndMinutes: r.read<int>('quiet_end_minutes'),
      );
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'settings read failed: $e');
      return fallback;
    }
  }

  Future<bool> saveSettings(TeacherSettingsRecord s) async {
    try {
      await db.customStatement(
        'INSERT OR REPLACE INTO ${Personal2Tables.teacherSettings} '
        '(id, class_name, mosque_name, teacher_name, excused_excluded, '
        'absence_streak_alert, reminders_enabled, class_start_reminder, '
        'unrecorded_reminder, weekly_summary, quiet_start_minutes, '
        'quiet_end_minutes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          settingsId,
          s.className,
          s.mosqueName,
          s.teacherName,
          s.excusedExcluded ? 1 : 0,
          s.absenceStreakAlert ? 1 : 0,
          s.remindersEnabled ? 1 : 0,
          s.classStartReminder ? 1 : 0,
          s.unrecordedReminder ? 1 : 0,
          s.weeklySummary ? 1 : 0,
          s.quietStartMinutes,
          s.quietEndMinutes,
        ],
      );
      return true;
    } catch (e) {
      AppLogger.warning('QuranTeacherDao', 'settings save failed: $e');
      return false;
    }
  }

  // ── Row mappers ──────────────────────────────────────────────────────

  static StudentRecord _student(dynamic r) => StudentRecord(
        id: r.read<String>('id'),
        classId: r.read<String>('class_id'),
        name: r.read<String>('name'),
        birthYear: r.readNullable<int>('birth_year'),
        parentName: r.read<String>('parent_name'),
        parentPhone: r.read<String>('parent_phone'),
        note: r.read<String>('note'),
        active: r.read<int>('active') == 1,
        joinedAt: _date(r.read<int>('joined_at')),
      );

  static SessionRecord _session(dynamic r) => SessionRecord(
        id: r.read<String>('id'),
        classId: r.read<String>('class_id'),
        dayKey: r.read<String>('day_key'),
        date: _date(r.read<int>('date')),
        number: r.read<int>('number'),
        note: r.read<String>('note'),
        createdAt: _date(r.read<int>('created_at')),
        closed: r.read<int>('closed') == 1,
      );

  static AttendanceRow _attendance(dynamic r) => AttendanceRow(
        id: r.read<String>('id'),
        sessionId: r.read<String>('session_id'),
        studentId: r.read<String>('student_id'),
        status: AttendanceStatus.fromWire(r.read<String>('status')),
        note: r.read<String>('note'),
      );

  static LessonRecordRow _lesson(dynamic r) => LessonRecordRow(
        id: r.read<String>('id'),
        sessionId: r.read<String>('session_id'),
        studentId: r.read<String>('student_id'),
        dayKey: r.read<String>('day_key'),
        date: _date(r.read<int>('date')),
        type: LessonType.fromWire(r.read<String>('type')),
        pageStart: r.read<int>('page_start'),
        pageEnd: r.read<int>('page_end'),
        lineStart: r.readNullable<int>('line_start'),
        lineEnd: r.readNullable<int>('line_end'),
        gradeKey: r.readNullable<String>('grade_key'),
        mistakeCount: r.read<int>('mistake_count'),
        tajweedTags: _tags(r.read<String>('tajweed_tags')),
        note: r.read<String>('note'),
        nextPageStart: r.readNullable<int>('next_page_start'),
        nextPageEnd: r.readNullable<int>('next_page_end'),
        nextLineStart: r.readNullable<int>('next_line_start'),
        nextLineEnd: r.readNullable<int>('next_line_end'),
      );
}

final quranTeacherDaoProvider = Provider<QuranTeacherDao>(
  (ref) => QuranTeacherDao(ref.read(appDatabaseProvider)),
);
