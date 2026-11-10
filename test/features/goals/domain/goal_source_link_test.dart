import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/goals/domain/goal_source_link.dart';
import 'package:tawheeed/features/hifz/data/daos/hifz_dao.dart';
import 'package:tawheeed/features/hifz/domain/entities/hafiz_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_lesson_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_review_model.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/features/khatm/domain/repositories/khatm_repository.dart';
import 'package:tawheeed/features/notes/domain/repositories/note_repository.dart';

class _Notes implements NoteRepository {
  _Notes(this.rows);
  final List<NoteTableData> rows;

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<List<NoteTableData>> getAllNotes() async => rows;

  @override
  Future<NoteTableData?> getNote(String id) async {
    for (final r in rows) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<void> upsertNote(NoteTableData note) async {}
}

class _Hifz implements HifzDao {
  _Hifz({this.hafiz, this.lessons = const [], this.reviews = const []});
  final HafizModel? hafiz;
  final List<HifzLessonModel> lessons;
  final List<HifzReviewModel> reviews;

  @override
  Future<HafizModel?> getHafiz(String id) async =>
      hafiz != null && hafiz!.id == id ? hafiz : null;

  @override
  Future<List<HifzLessonModel>> getLessons(String hafizId) async => lessons;

  @override
  Future<List<HifzReviewModel>> getReviews(String hafizId) async => reviews;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not used here');
}

class _Khatms implements KhatmRepository {
  _Khatms(this.row);
  final KhatmModel? row;

  @override
  Future<KhatmModel?> getKhatm(String id) async => row?.id == id ? row : null;

  @override
  Future<List<KhatmModel>> getAllKhatms() async => row == null ? [] : [row!];

  @override
  Future<void> deleteKhatm(String id) async {}

  @override
  Future<void> upsertKhatm(KhatmModel khatm) async {}
}

class _Throwing implements KhatmRepository {
  @override
  Future<KhatmModel?> getKhatm(String id) async => throw StateError('db gone');

  @override
  Future<List<KhatmModel>> getAllKhatms() async => const [];

  @override
  Future<void> deleteKhatm(String id) async {}

  @override
  Future<void> upsertKhatm(KhatmModel khatm) async {}
}

/// Shared "whenever" for the fixtures. The resolver never compares dates
/// against it, so one fixed value keeps the fixtures readable.
final _when = DateTime(2026);

NoteTableData note(String id, {String title = 'یاد', String content = 'متن'}) =>
    NoteTableData(
      id: id,
      title: title,
      content: content,
      createdAt: _when,
      updatedAt: _when,
      tags: '',
      folder: '',
      isDone: false,
      colorIndex: 0,
      isPinned: false,
      audioPath: '',
      audioDurationMs: 0,
    );

KhatmModel khatm({int read = 0, bool done = false}) => KhatmModel(
      id: 'k1',
      title: 'ختم جمعه',
      startDate: _when,
      targetDays: 30,
      pagesRead: [for (var i = 0; i < 604; i++) i < read],
      isCompleted: done,
      participantNames: const [],
      participantAssignedJuzs: const [],
      dailyRead: const {},
    );

HafizModel hafiz(String id) =>
    HafizModel(id: id, name: 'امیر', createdAt: _when);

HifzLessonModel lesson({int pages = 2}) => HifzLessonModel(
      id: 'l1',
      hafizId: 'h1',
      date: DateTime(2026, 1, 2),
      surahFrom: 1,
      ayahFrom: 1,
      surahTo: 1,
      ayahTo: 5,
      pages: pages,
      createdAt: DateTime(2026, 1, 2),
    );

HifzReviewModel review() => HifzReviewModel(
      id: 'r1',
      hafizId: 'h1',
      date: DateTime(2026, 1, 3),
      type: ReviewType.murajaah,
      surahFrom: 1,
      ayahFrom: 1,
      surahTo: 1,
      ayahTo: 5,
      pages: 1,
      quality: ReviewQuality.medium,
      createdAt: DateTime(2026, 1, 3),
    );

/// Resolver with nothing wired — the "no link at all" shape.
const _unwired = GoalSourceLinkResolver(
  notes: _nullNotes,
  hifz: _nullHifz,
  khatm: _nullKhatm,
);

NoteRepository? _nullNotes() => null;
HifzDao? _nullHifz() => null;
KhatmRepository? _nullKhatm() => null;

/// Wired, but the row is gone — exercises the not-found path.
HifzDao _emptyHifz() => _Hifz();
KhatmRepository _noKhatm() => _Khatms(null);
KhatmRepository _throwingKhatm() => _Throwing();

void main() {
  group('an unlinked goal resolves to nothing', () {
    test('empty type and id both mean "no card"', () async {
      expect(
          await _unwired.resolve('', ''), same(LinkedSourceSnapshot.unknown));
      expect(await _unwired.resolve('note', ''),
          same(LinkedSourceSnapshot.unknown));
      expect(
          await _unwired.resolve('', 'n1'), same(LinkedSourceSnapshot.unknown));
    });

    test('a source that is simply not wired reads as unknown', () async {
      expect(await _unwired.resolve('hifz', 'h1'),
          same(LinkedSourceSnapshot.unknown));
    });
  });

  group('note', () {
    test('title and body are reported, with no invented ratio', () async {
      final r = GoalSourceLinkResolver(
        notes: () => _Notes([note('n1', title: 'برنامه', content: 'خط اول')]),
        hifz: _nullHifz,
        khatm: _nullKhatm,
      );
      final s = await r.resolve('note', 'n1');
      expect(s.type, 'note');
      expect(s.title, 'برنامه');
      expect(s.summary, 'خط اول');
      expect(s.missing, isFalse);
      // A note has no completion, so a progress bar here would be a fiction.
      expect(s.fraction, isNull);
    });

    test('a titleless note still renders a name', () async {
      final r = GoalSourceLinkResolver(
        notes: () => _Notes([note('n1', title: '')]),
        hifz: _nullHifz,
        khatm: _nullKhatm,
      );
      expect((await r.resolve('note', 'n1')).title, 'بدون عنوان');
    });

    test('an empty body does not produce a blank line', () async {
      final r = GoalSourceLinkResolver(
        notes: () => _Notes([note('n1', content: '   ')]),
        hifz: _nullHifz,
        khatm: _nullKhatm,
      );
      expect((await r.resolve('note', 'n1')).summary, 'بدون محتوا');
    });

    test('a deleted note is reported as missing, not as an error', () async {
      final r = GoalSourceLinkResolver(
        notes: () => _Notes(const []),
        hifz: _nullHifz,
        khatm: _nullKhatm,
      );
      final s = await r.resolve('note', 'gone');
      expect(s.missing, isTrue);
      expect(s.summary, contains('حذف'));
    });
  });

  group('hifz', () {
    test('lesson, page and review counts are summed', () async {
      final r = GoalSourceLinkResolver(
        notes: _nullNotes,
        hifz: () => _Hifz(
          hafiz: hafiz('h1'),
          lessons: [lesson(), lesson(pages: 3)],
          reviews: [review()],
        ),
        khatm: _nullKhatm,
      );
      final s = await r.resolve('hifz', 'h1');
      expect(s.title, 'امیر');
      expect(s.summary, contains('2 درس'));
      expect(s.summary, contains('5 صفحه'));
      // Only lessons contribute pages; a review is a pass over material, not
      // new memorization, so it is counted separately.
      expect(s.summary, contains('1 مرور'));
      expect(s.missing, isFalse);
    });

    test('no lessons reads as "not started", not as 0%', () async {
      final r = GoalSourceLinkResolver(
        notes: _nullNotes,
        hifz: () => _Hifz(hafiz: hafiz('h1')),
        khatm: _nullKhatm,
      );
      final s = await r.resolve('hifz', 'h1');
      expect(s.summary, contains('ثبت نشده'));
      expect(s.fraction, isNull, reason: 'an unstarted hafiz has no ratio');
    });

    test('a deleted hafiz is reported as missing', () async {
      const r = GoalSourceLinkResolver(
        notes: _nullNotes,
        hifz: _emptyHifz,
        khatm: _nullKhatm,
      );
      expect((await r.resolve('hifz', 'h1')).missing, isTrue);
    });
  });

  group('khatm', () {
    test('pages read out of 604, with a real fraction', () async {
      final r = GoalSourceLinkResolver(
        notes: _nullNotes,
        hifz: _nullHifz,
        khatm: () => _Khatms(khatm(read: 151)),
      );
      final s = await r.resolve('khatm', 'k1');
      expect(s.title, 'ختم جمعه');
      expect(s.summary, contains('151 از 604 صفحه'));
      expect(s.fraction, closeTo(0.25, 0.001));
    });

    test('a finished khatm says so instead of showing a remainder', () async {
      final r = GoalSourceLinkResolver(
        notes: _nullNotes,
        hifz: _nullHifz,
        khatm: () => _Khatms(khatm(read: 604, done: true)),
      );
      expect((await r.resolve('khatm', 'k1')).summary, contains('تمام‌شده'));
    });

    test('a deleted khatm is reported as missing', () async {
      const r = GoalSourceLinkResolver(
        notes: _nullNotes,
        hifz: _nullHifz,
        khatm: _noKhatm,
      );
      expect((await r.resolve('khatm', 'k1')).missing, isTrue);
    });
  });

  group('failures stay contained', () {
    test('a throwing source yields "missing", it does not propagate', () async {
      // The link is decoration on a goal the user still needs. A database
      // error while reading it must not take the whole goal screen down.
      const r = GoalSourceLinkResolver(
        notes: _nullNotes,
        hifz: _nullHifz,
        khatm: _throwingKhatm,
      );
      final s = await r.resolve('khatm', 'k1');
      expect(s.missing, isTrue);
      expect(s.summary, contains('ممکن نشد'));
    });

    test('an unknown type is reported, so the user can clear it', () async {
      final s = await _unwired.resolve('from_the_future', 'x1');
      expect(s.missing, isTrue);
      expect(s.summary, contains('پشتیبانی نمی‌شود'));
    });
  });

  group('kGoalLinkTypeLabels', () {
    test('the editor and the resolver agree on the offered types', () {
      // The editor renders its picker from this map, so a type missing here is
      // a type the user can link but the detail screen cannot read.
      expect(kGoalLinkTypeLabels.keys.toSet(), {'note', 'hifz', 'khatm'});
      for (final t in kGoalLinkTypeLabels.keys) {
        expect(isKnownGoalLinkType(t), isTrue);
      }
    });

    test('an empty or unknown type is not known', () {
      expect(isKnownGoalLinkType(''), isFalse);
      expect(isKnownGoalLinkType('made_up'), isFalse);
    });
  });
}
