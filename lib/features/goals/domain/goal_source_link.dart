import 'package:tawheeed/features/hifz/data/daos/hifz_dao.dart';
import 'package:tawheeed/features/khatm/domain/repositories/khatm_repository.dart';
import 'package:tawheeed/features/notes/domain/repositories/note_repository.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// A read-only snapshot of whatever a goal is linked to.
///
/// Strictly read-only by design. A goal is a *plan*; the note, the hafiz record
/// and the khatm are the *data*. Letting a goal write to them means a stray
/// "log progress" tap on the goals screen mutates a Quran memorization record
/// or a shared khatm that other people are counting on. So every type here is
/// a value object produced by a read, and nothing in the goals feature can
/// turn one back into a write.
class LinkedSourceSnapshot {
  /// `note` / `hifz` / `khatm`, matching `goal_table.linked_type`.
  final String type;

  /// Display name of the source, empty when it no longer exists.
  final String title;

  /// One-line human summary of the source's own state, already formatted.
  final String summary;

  /// 0..1, or null when the source reports no meaningful ratio.
  final double? fraction;

  /// The linked row was deleted, or its type is not one we can read.
  ///
  /// Shown as a warning with an "unlink" action instead of an empty card: a
  /// silent gap reads as "the app lost my data", and the goal is otherwise
  /// perfectly usable.
  final bool missing;

  const LinkedSourceSnapshot({
    required this.type,
    required this.title,
    required this.summary,
    this.fraction,
    this.missing = false,
  });

  static const LinkedSourceSnapshot unknown = LinkedSourceSnapshot(
    type: '',
    title: '',
    summary: '',
    missing: true,
  );
}

/// The kinds of source a goal may point at.
///
/// A const map rather than an enum because the value is persisted in the
/// `linked_type` column; an enum would need a converter and a migration to
/// rename a value, and the set is expected to stay small.
const Map<String, String> kGoalLinkTypeLabels = {
  'note': 'یادداشت',
  'hifz': 'حافظ',
  'khatm': 'ختم',
};

/// Whether [type] is a link kind this build can read.
bool isKnownGoalLinkType(String type) => kGoalLinkTypeLabels.containsKey(type);

/// Resolves a goal's `linked_type` / `linked_id` into a displayable snapshot.
///
/// Takes its collaborators as arguments instead of reaching for providers, so
/// it is unit-testable with three fakes and does not drag the notes, hifz and
/// khatm provider graphs into the goals domain. The editor and the detail
/// screen pass the real ones.
///
/// Never throws: a link is decoration on top of a goal, so a failure to read
/// it must never take the goal screen down with it.
class GoalSourceLinkResolver {
  final NoteRepository? Function() notes;
  final HifzDao? Function() hifz;
  final KhatmRepository? Function() khatm;

  const GoalSourceLinkResolver({
    required this.notes,
    required this.hifz,
    required this.khatm,
  });

  Future<LinkedSourceSnapshot> resolve(String type, String id) async {
    if (type.isEmpty || id.isEmpty) return LinkedSourceSnapshot.unknown;
    try {
      // `await` on every branch, not a bare `return _note(id)`: returning the
      // future hands it back to the caller and the error arrives *after* this
      // frame has already returned, so the catch below never runs. A failing
      // source would then take the whole goal screen down.
      switch (type) {
        case 'note':
          return await _note(id);
        case 'hifz':
          return await _hifz(id);
        case 'khatm':
          return await _khatm(id);
        default:
          // A type written by a newer build, or a value that predates the
          // feature. Reported as missing rather than dropped, so the user can
          // clear it.
          return LinkedSourceSnapshot(
            type: type,
            title: kGoalLinkTypeLabels[type] ?? type,
            summary: 'نوع اتصال پشتیبانی نمی‌شود.',
            missing: true,
          );
      }
    } catch (e) {
      AppLogger.warning('GoalSourceLink', 'resolve $type/$id failed: $e');
      return LinkedSourceSnapshot(
        type: type,
        title: kGoalLinkTypeLabels[type] ?? type,
        summary: 'خواندن منبع متصل ممکن نشد.',
        missing: true,
      );
    }
  }

  Future<LinkedSourceSnapshot> _note(String id) async {
    final repo = notes();
    if (repo == null) return LinkedSourceSnapshot.unknown;
    final note = await repo.getNote(id);
    if (note == null) {
      return const LinkedSourceSnapshot(
        type: 'note',
        title: 'یادداشت',
        summary: 'یادداشت حذف شده است.',
        missing: true,
      );
    }
    final body = note.content.trim();
    // Note has no ratio, so no progress bar — a fake 0% would be a lie.
    return LinkedSourceSnapshot(
      type: 'note',
      title: note.title.isEmpty ? 'بدون عنوان' : note.title,
      summary: body.isEmpty ? 'بدون محتوا' : body,
    );
  }

  Future<LinkedSourceSnapshot> _hifz(String id) async {
    final dao = hifz();
    if (dao == null) return LinkedSourceSnapshot.unknown;
    final hafiz = await dao.getHafiz(id);
    if (hafiz == null) {
      return const LinkedSourceSnapshot(
        type: 'hifz',
        title: 'حافظ',
        summary: 'حافظ حذف شده است.',
        missing: true,
      );
    }
    final lessons = await dao.getLessons(id);
    final reviews = await dao.getReviews(id);
    // A hafiz with no lessons is not 0% complete, it is unstarted, so the
    // fraction stays null and the UI shows a count instead of an empty bar.
    final pages = lessons.fold<int>(0, (sum, l) => sum + l.pages);
    return LinkedSourceSnapshot(
      type: 'hifz',
      title: hafiz.name,
      summary: lessons.isEmpty
          ? 'هنوز درسی ثبت نشده'
          : '${lessons.length} درس • $pages صفحه • ${reviews.length} مرور',
    );
  }

  Future<LinkedSourceSnapshot> _khatm(String id) async {
    final repo = khatm();
    if (repo == null) return LinkedSourceSnapshot.unknown;
    final k = await repo.getKhatm(id);
    if (k == null) {
      return const LinkedSourceSnapshot(
        type: 'khatm',
        title: 'ختم',
        summary: 'ختم حذف شده است.',
        missing: true,
      );
    }
    // A khatm counts pages of the 604-page mushaf, not parts — the read-page
    // list is the single source of truth for how far along it is.
    return LinkedSourceSnapshot(
      type: 'khatm',
      title: k.title,
      summary: '${k.readPages} از ${k.totalPages} صفحه'
          ' • ${k.isCompleted ? 'تمام‌شده' : '${k.remainingPages} صفحه باقی'}',
      fraction: k.progress,
    );
  }
}
