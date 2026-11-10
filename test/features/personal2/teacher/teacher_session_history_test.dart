import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/worship/quran_teacher/data/quran_teacher_dao.dart';
import 'package:tawheeed/features/worship/quran_teacher/domain/quran_teacher_logic.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/screens/session_history_screen.dart';

/// «سابقهٔ جلسه‌ها» — the page that made a past session reachable again.
///
/// Two things are under test: the arithmetic a past session prints (so a card
/// and a list can never disagree about who was present), and the fact that a
/// session from last week can still be opened, corrected and re-closed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('session arithmetic', () {
    test('breaks attendance down by status and counts «حاضر» as came', () {
      final b = attendanceBreakdown(const [
        AttendanceRecordSpec(
          sessionId: 's',
          studentId: 'a',
          status: AttendanceStatus.present,
          dayKey: 'd',
        ),
        AttendanceRecordSpec(
          sessionId: 's',
          studentId: 'b',
          status: AttendanceStatus.late,
          dayKey: 'd',
        ),
        AttendanceRecordSpec(
          sessionId: 's',
          studentId: 'c',
          status: AttendanceStatus.absent,
          dayKey: 'd',
        ),
        AttendanceRecordSpec(
          sessionId: 's',
          studentId: 'd',
          status: AttendanceStatus.excused,
          dayKey: 'd',
        ),
      ]);
      expect(b.present, 1);
      expect(b.late, 1);
      expect(b.absent, 1);
      expect(b.excused, 1);
      expect(b.attended, 2);
      expect(b.missing, 2);
      expect(b.rate, 2 / 4);
      // The tool's setting drops a documented excuse from the denominator.
      expect(b.rateExcludingExcused(), 2 / 3);
    });

    test('an empty session has no rate, not a zero', () {
      final b = attendanceBreakdown(const []);
      expect(b.isEmpty, isTrue);
      expect(b.rate, isNull);
      expect(b.rateExcludingExcused(), isNull);
    });

    test('the next page after a record is the page after its end', () {
      final spec = LessonRecordSpec(
        id: 'l',
        studentId: 's',
        sessionId: 'x',
        dayKey: 'd',
        type: LessonType.recitation,
        pageStart: 10,
        pageEnd: 12,
      );
      expect(nextPageAfter(spec), 13);

      final last = LessonRecordSpec(
        id: 'l2',
        studentId: 's',
        sessionId: 'x',
        dayKey: 'd',
        type: LessonType.recitation,
        pageStart: 604,
        pageEnd: 604,
      );
      expect(nextPageAfter(last), isNull);
    });

    test('class time labels use Latin digits and wrap the day', () {
      expect(classTimeLabel(17 * 60 + 30), '17:30');
      expect(classTimeLabel(0), '00:00');
      expect(classTimeLabel(1439), '23:59');
    });

    test('juz helper refuses nonsense pages', () {
      expect(juzOfPageOrNull(1), 1);
      expect(juzOfPageOrNull(604), 30);
      expect(juzOfPageOrNull(0), isNull);
      expect(juzOfPageOrNull(605), isNull);
    });
  });

  group('quran teacher sessions', () {
    late Directory tempDir;
    late AppDatabase db;
    late QuranTeacherDao dao;

    const everyDay = 0x7F;
    const pastDay = '1405-01-10';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('teacher_session_test');
      final file = File(p.join(tempDir.path, 'sessions.sqlite'));
      db = AppDatabase.withConnection(NativeDatabase(file));
      dao = QuranTeacherDao(db);
      SharedPreferences.setMockInitialValues({});
      await db.customStatement('SELECT 1');
      await dao.settings();
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
        // Windows keeps the handle for a moment; the OS reclaims the temp dir.
      }
    });

    Future<SessionRecord> pastSession() async {
      final session = await dao.ensureTodaySession(
        classId: 'c1',
        dayKey: pastDay,
        weekdaysMask: everyDay,
        now: DateTime(2026, 4, 1, 18),
      );
      expect(session, isNotNull);
      return session!;
    }

    test('a past session can be read back by id', () async {
      final created = await pastSession();
      final read = await dao.sessionById(created.id);
      expect(read?.dayKey, pastDay);
      expect(read?.number, 1);
    });

    test('a recorded session can be reopened and closed again', () async {
      final session = await pastSession();
      await dao.closeSession(session.id);
      expect((await dao.sessionById(session.id))?.closed, isTrue);

      await dao.setSessionClosed(session.id, false);
      expect((await dao.sessionById(session.id))?.closed, isFalse);

      await dao.setSessionClosed(session.id, true);
      expect((await dao.sessionById(session.id))?.closed, isTrue);
    });

    test('a session keeps its own note', () async {
      final session = await pastSession();
      await dao.saveSessionNote(session.id, 'جلسهٔ جبرانی');
      expect((await dao.sessionById(session.id))?.note, 'جلسهٔ جبرانی');
    });

    test('attendance for a past session is still writable', () async {
      final session = await pastSession();
      await dao.setAttendance(
        sessionId: session.id,
        studentId: 's1',
        status: AttendanceStatus.absent,
      );
      final rows = await dao.attendanceForSession(session.id);
      expect(rows, hasLength(1));
      expect(rows.first.status, AttendanceStatus.absent);

      // A second tap replaces the first answer instead of appending.
      await dao.setAttendance(
        sessionId: session.id,
        studentId: 's1',
        status: AttendanceStatus.excused,
      );
      final updated = await dao.attendanceForSession(session.id);
      expect(updated, hasLength(1));
      expect(updated.first.status, AttendanceStatus.excused);
    });

    test('the class keeps a schedule time for its reminder', () async {
      await dao.saveClass(
        id: 'c1',
        name: 'حلقهٔ فجر',
        place: 'مسجد',
        weekdaysMask: everyDay,
        startMinutes: 17 * 60 + 30,
        durationMin: 90,
      );
      final classes = await dao.classes();
      expect(classes.single.startMinutes, 17 * 60 + 30);
      expect(classes.single.durationMin, 90);
    });

    testWidgets('the history page lists a past session with its counts',
        (tester) async {
      final session = await pastSession();
      await dao.setAttendance(
        sessionId: session.id,
        studentId: 's1',
        status: AttendanceStatus.present,
      );
      await dao.setAttendance(
        sessionId: session.id,
        studentId: 's2',
        status: AttendanceStatus.absent,
      );

      await _pump(tester, db, const SessionHistoryScreen(classId: 'c1'));

      expect(find.text('جلسه‌ها'), findsWidgets);
      // One present, one absent, no unrecorded students.
      expect(
        find.textContaining('1 حاضر'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a session opens its sheet and writes attendance',
        (tester) async {
      final session = await pastSession();

      await _pump(tester, db, const SessionHistoryScreen(classId: 'c1'));
      await tester.tap(find.textContaining('جلسهٔ 1'));
      await tester.pumpAndSettle();

      // The sheet lists both students with the four letters each.
      expect(find.text('حضور'), findsWidgets);
      expect(find.text('سابقهٔ جلسه‌ها'), findsOneWidget);

      await tester.tap(find.text('ح').first);
      await tester.pumpAndSettle();

      final rows = await dao.attendanceForSession(session.id);
      expect(rows, hasLength(1));
      expect(rows.first.status, AttendanceStatus.present);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pump(WidgetTester tester, AppDatabase db, Widget screen) async {
  tester.view.physicalSize = const Size(320 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 1400),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: screen,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  FlutterError.onError = previous;
  tester.takeException();
  expect(errors, isEmpty,
      reason: errors.map((e) => e.toString()).join(' | '));
}
