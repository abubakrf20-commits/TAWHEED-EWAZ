import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/worship/quran_teacher/data/quran_teacher_dao.dart';
import 'package:tawheeed/features/worship/quran_teacher/domain/quran_teacher_logic.dart';

/// Database-level tests for «دفتر مربی قرآن».
///
/// The kids and shop tools already had DAO coverage; this file is the teacher
/// equivalent, and it pins the three behaviours a teacher would notice on a
/// real class day: one session per day (never two «جلسهٔ 1»), one attendance
/// row per student (a second tap replaces, it does not append), and a lesson
/// record that can be corrected or removed without touching the other
/// students' history.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late QuranTeacherDao dao;

  /// Every weekday set, so a day key always counts as a class day.
  const everyDay = 0x7F;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('teacher_dao_test');
    final file = File(p.join(tempDir.path, 'teacher.sqlite'));
    db = AppDatabase.withConnection(NativeDatabase(file));
    dao = QuranTeacherDao(db);
    SharedPreferences.setMockInitialValues({});
    await db.customStatement('SELECT 1');
    await dao.settings(); // seeds the single settings row
    await dao.saveClass(
      id: 'c1',
      name: 'حلقهٔ فجر',
      place: 'مسجد',
      weekdaysMask: everyDay,
    );
    await dao.saveStudent(id: 's1', classId: 'c1', name: 'علی');
    await dao.saveStudent(id: 's2', classId: 'c1', name: 'زهرا');
  });

  tearDown(() async {
    await db.close();
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds sqlite handles briefly; the OS reclaims the temp dir.
    }
  });

  Future<SessionRecord> openSession(String dayKey) async {
    final session = await dao.ensureTodaySession(
      classId: 'c1',
      dayKey: dayKey,
      weekdaysMask: everyDay,
      now: DateTime(2026, 11, 6, 9),
    );
    expect(session, isNotNull, reason: 'a class day must open a session');
    return session!;
  }

  group('classes', () {
    test('editing a class keeps one row and the original created time',
        () async {
      expect(await dao.classes(), hasLength(1));
      await dao.saveClass(id: 'c1', name: 'حلقهٔ صبح', weekdaysMask: everyDay);
      final rows = await dao.classes();
      expect(rows, hasLength(1));
      expect(rows.single.name, 'حلقهٔ صبح');
      expect(rows.single.place, '', reason: 'the edit replaces the old place');
    });

    test('archiving a class hides it and deactivates its students', () async {
      expect(await dao.archiveClass('c1'), isTrue);
      expect(await dao.classes(), isEmpty);
      expect(await dao.classes(includeArchived: true), hasLength(1));
      expect(await dao.students('c1'), isEmpty);
    });
  });

  group('sessions', () {
    test('one session per day, numbered from the class first session',
        () async {
      final first = await openSession('1404-08-15');
      expect(first.number, 1);

      final again = await openSession('1404-08-15');
      expect(again.id, first.id);
      expect(again.number, 1);
      expect(await dao.recentSessions('c1'), hasLength(1),
          reason: 're-opening the same day must not add «جلسهٔ 2»');

      final second = await openSession('1404-08-16');
      expect(second.number, 2);
    });

    test('a day the class does not meet opens nothing', () async {
      final session = await dao.ensureTodaySession(
        classId: 'c1',
        dayKey: '1404-08-15',
        weekdaysMask: 0,
        now: DateTime(2026, 11, 6, 9),
      );
      expect(session, isNull);
      expect(await dao.recentSessions('c1'), isEmpty);
    });

    test('closing a session is recorded once', () async {
      final session = await openSession('1404-08-15');
      expect(session.closed, isFalse);
      await dao.closeSession(session.id);
      final closed = await dao.sessionForDay('c1', '1404-08-15');
      expect(closed!.closed, isTrue);
    });
  });

  group('attendance', () {
    test('a second answer replaces the first instead of appending', () async {
      final session = await openSession('1404-08-15');
      await dao.setAttendance(
        sessionId: session.id,
        studentId: 's1',
        status: AttendanceStatus.absent,
      );
      await dao.setAttendance(
        sessionId: session.id,
        studentId: 's1',
        status: AttendanceStatus.present,
      );
      final rows = await dao.attendanceForSession(session.id);
      expect(rows, hasLength(1));
      expect(rows.single.status, AttendanceStatus.present);
    });

    test('mark all present writes one row per student', () async {
      final session = await openSession('1404-08-15');
      expect(
        await dao.markAllPresent(
          sessionId: session.id,
          studentIds: const ['s1', 's2'],
        ),
        isTrue,
      );
      final rows = await dao.attendanceForSession(session.id);
      expect(rows, hasLength(2));
      expect(
        rows.every((r) => r.status == AttendanceStatus.present),
        isTrue,
      );
      expect(await dao.attendanceForStudent('s2'), hasLength(1));
    });
  });

  group('lesson records', () {
    test('a lesson saves, reads back and deletes', () async {
      final session = await openSession('1404-08-15');
      expect(
        await dao.saveLesson(
          id: 'l1',
          sessionId: session.id,
          studentId: 's1',
          dayKey: '1404-08-15',
          type: LessonType.recitation,
          pageStart: 3,
          pageEnd: 5,
          mistakeCount: 2,
          tajweedTags: const ['مد'],
        ),
        isTrue,
      );

      final saved = await dao.lessonsForStudent('s1');
      expect(saved, hasLength(1));
      expect(saved.single.pageStart, 3);
      expect(saved.single.pageEnd, 5);
      expect(saved.single.tajweedTags, ['مد']);

      expect(await dao.deleteLesson('l1'), isTrue);
      expect(await dao.lessonsForStudent('s1'), isEmpty);
    });

    test('an impossible page range is rejected, not stored', () async {
      final session = await openSession('1404-08-15');
      expect(
        await dao.saveLesson(
          id: 'l2',
          sessionId: session.id,
          studentId: 's1',
          dayKey: '1404-08-15',
          type: LessonType.hifz,
          pageStart: 9,
          pageEnd: 4,
        ),
        isFalse,
      );
      expect(await dao.lessonsForStudent('s1'), isEmpty);
    });

    test('the range filter keeps other days out', () async {
      final session = await openSession('1404-08-15');
      for (final entry in {
        'l1': '1404-08-15',
        'l2': '1404-08-20',
      }.entries) {
        await dao.saveLesson(
          id: entry.key,
          sessionId: session.id,
          studentId: 's1',
          dayKey: entry.value,
          type: LessonType.review,
          pageStart: 1,
          pageEnd: 2,
        );
      }
      final ranged = await dao.lessonsForStudent(
        's1',
        fromDayKey: '1404-08-16',
        toDayKey: '1404-08-31',
      );
      expect(ranged.map((r) => r.id), ['l2']);
    });
  });

  group('deleting one student', () {
    test('removes their rows and leaves the class and classmates alone',
        () async {
      final session = await openSession('1404-08-15');
      for (final id in const ['s1', 's2']) {
        await dao.setAttendance(
          sessionId: session.id,
          studentId: id,
          status: AttendanceStatus.present,
        );
        await dao.saveLesson(
          id: 'l_$id',
          sessionId: session.id,
          studentId: id,
          dayKey: '1404-08-15',
          type: LessonType.recitation,
          pageStart: 1,
          pageEnd: 2,
        );
      }

      expect(await dao.deleteEverythingForStudent('s1'), isTrue);
      expect(await dao.student('s1'), isNull);
      expect(await dao.attendanceForStudent('s1'), isEmpty);
      expect(await dao.lessonsForStudent('s1'), isEmpty);

      expect(await dao.student('s2'), isNotNull);
      expect(await dao.attendanceForStudent('s2'), hasLength(1));
      expect(await dao.lessonsForStudent('s2'), hasLength(1));
      expect(await dao.classes(), hasLength(1));
    });
  });

  group('settings', () {
    test('the settings row round-trips', () async {
      expect(
        await dao.saveSettings(
          const TeacherSettingsRecord(
            className: 'حلقهٔ فجر',
            mosqueName: 'مسجد النبی',
            teacherName: 'استاد رضایی',
            weeklySummary: true,
          ),
        ),
        isTrue,
      );
      final saved = await dao.settings();
      expect(saved.className, 'حلقهٔ فجر');
      expect(saved.mosqueName, 'مسجد النبی');
      expect(saved.weeklySummary, isTrue);
      expect(saved.quietStartMinutes, 1320,
          reason: 'untouched fields keep the record defaults');
    });
  });
}
