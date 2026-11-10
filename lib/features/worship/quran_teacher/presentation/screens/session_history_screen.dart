import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';
import 'package:tawheeed/features/worship/quran_teacher/data/quran_teacher_dao.dart';
import 'package:tawheeed/features/worship/quran_teacher/domain/quran_teacher_logic.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/providers/quran_teacher_providers.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

/// «سابقهٔ جلسه‌ها» — every session this class has held, newest first.
///
/// Until now a session could only be seen on its own day: a teacher who was
/// ill, or whose phone was at home, lost the ability to record that day's
/// attendance for good. This page is the way back in — each row opens the same
/// attendance sheet, and a session can be reopened after it was «ثبت»ed.
class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(quranClassHistoryProvider(classId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          accent: Personal2Colors.teacher,
          title: 'سابقهٔ جلسه‌ها',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'بازگشت',
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: history.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FailureView(
              id: 'quran_session_history_load',
              title: 'سابقهٔ جلسه‌ها باز نشد',
              detail: 'حضور و درس‌های ثبت‌شده پاک نشده‌اند؛ فقط خواندنشان '
                  'ناموفق بود.',
              onRetry: () => ref.invalidate(quranClassHistoryProvider(classId)),
              layout: FailureLayout.page,
              error: e,
            ),
            data: (state) {
              if (state == null) {
                return const Center(child: Text('این کلاس پیدا نشد.'));
              }
              if (state.sessions.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.event_note_rounded,
                  accent: Personal2Colors.teacher,
                  message: 'هنوز جلسه‌ای ثبت نشده',
                  subtitle: 'با باز کردن صفحهٔ کلاس در یک روز جلسه، اولین جلسه '
                      'ساخته می‌شود.',
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                    DsSpacing.page, 12, DsSpacing.page, 40),
                children: [
                  _summaryCard(context, state),
                  const SizedBox(height: 14),
                  SectionHeader(
                    title: 'جلسه‌ها',
                    accent: Personal2Colors.teacher,
                    count: '${state.sessions.length}',
                  ),
                  const SizedBox(height: 6),
                  for (final entry in state.sessions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _sessionRow(context, ref, entry),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, ClassHistoryState state) {
    final t = TimeThemeKit.of(context).palette;
    final rate = state.attendanceRate;
    final pages = state.pagesPerStudent;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            state.classGroup.name,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [
              '${state.sessions.length} جلسه',
              '${state.students.length} شاگرد',
              if (state.sessionsWithoutLessons > 0)
                '${state.sessionsWithoutLessons} جلسهٔ بی‌درس',
            ].join(' · '),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10,
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _stat(
                context,
                'حضور کلاس',
                rate == null ? '—' : '${(rate * 100).round()}٪',
              ),
              _stat(
                context,
                'صفحه به‌ازای هر شاگرد',
                pages == null ? '—' : pages.toStringAsFixed(1),
              ),
              _stat(context, 'کل جلسه‌ها', '${state.sessions.length}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final t = TimeThemeKit.of(context).palette;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Personal2Colors.teacher,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 9,
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionRow(
    BuildContext context,
    WidgetRef ref,
    SessionHistoryEntry entry,
  ) {
    final t = TimeThemeKit.of(context).palette;
    final b = entry.breakdown;
    final session = entry.session;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => showSessionDetailSheet(context, ref, session.id),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Personal2Colors.teacher.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${session.number}',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Personal2Colors.teacher,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جلسهٔ ${session.number} · '
                  '${jalaliYmdShort(Jalali.fromDateTime(session.date))}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    '${b.attended} حاضر',
                    if (b.absent > 0) '${b.absent} غایب',
                    if (b.excused > 0) '${b.excused} مرخص',
                    if (entry.unrecorded > 0) '${entry.unrecorded} بی‌پاسخ',
                    '${entry.lessonCount} درس',
                  ].join(' · '),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (session.closed)
            Icon(Icons.done_all_rounded,
                size: 16, color: DsStatus.success(context))
          else if (!entry.complete)
            Icon(Icons.pending_actions_rounded,
                size: 16, color: DsStatus.warning(context)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_left_rounded, size: 18, color: t.textMuted),
        ],
      ),
    );
  }
}

/// The editable view of one session — attendance, notes and its lessons.
///
/// It writes immediately (like the home screen's attendance buttons) rather
/// than behind a save button, because a teacher taps one letter and leaves;
/// holding that until a second confirmation is how a row silently goes missing.
Future<void> showSessionDetailSheet(
  BuildContext context,
  WidgetRef ref,
  String sessionId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: TimeThemeKit.of(context).palette.surface,
    builder: (_) => _SessionDetailSheet(sessionId: sessionId),
  );
}

class _SessionDetailSheet extends ConsumerStatefulWidget {
  const _SessionDetailSheet({required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<_SessionDetailSheet> createState() =>
      _SessionDetailSheetState();
}

class _SessionDetailSheetState extends ConsumerState<_SessionDetailSheet> {
  final _noteCtrl = TextEditingController();
  bool _noteSeeded = false;
  bool _noteDirty = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(quranSessionDetailProvider(widget.sessionId));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .9,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: detail.when(
            loading: () => const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => FailureView(
              id: 'quran_session_detail_load',
              title: 'این جلسه باز نشد',
              detail: 'ردیف‌های این جلسه پاک نشده‌اند؛ فقط خواندنشان ناموفق '
                  'بود.',
              onRetry: () =>
                  ref.invalidate(quranSessionDetailProvider(widget.sessionId)),
              error: e,
            ),
            data: (state) => state == null
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('این جلسه پیدا نشد.')),
                  )
                : _body(context, state),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, SessionDetailState state) {
    final t = TimeThemeKit.of(context).palette;
    final session = state.session;
    final b = state.breakdown;

    // The note is seeded once so a rebuild never eats what the teacher typed.
    if (!_noteSeeded) {
      _noteSeeded = true;
      _noteCtrl.text = session.note;
    }

    return ListView(
      shrinkWrap: true,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'جلسهٔ ${session.number} · '
                '${jalaliYmdShort(Jalali.fromDateTime(session.date))}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _toggleClosed(session),
              icon: Icon(
                session.closed
                    ? Icons.lock_outline_rounded
                    : Icons.lock_open_rounded,
                size: 16,
              ),
              label: Text(
                session.closed ? 'ثبت‌شده' : 'باز',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          [
            '${b.attended} حاضر',
            if (b.absent > 0) '${b.absent} غایب',
            if (b.excused > 0) '${b.excused} مرخص',
            if (state.classGroup.place.isNotEmpty) state.classGroup.place,
          ].join(' · '),
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 10,
            color: t.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        SectionHeader(
          title: 'حضور',
          accent: Personal2Colors.teacher,
          count: '${state.students.length}',
        ),
        const SizedBox(height: 6),
        for (final student in state.students)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _studentRow(student, state),
          ),
        const SizedBox(height: 12),
        const SectionHeader(
          title: 'یادداشت جلسه',
          accent: Personal2Colors.teacher,
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _noteCtrl,
          maxLines: 2,
          onChanged: (_) => setState(() => _noteDirty = true),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'مثلاً «جلسهٔ جبرانی» یا «تعطیل به‌خاطر باران»',
            suffixIcon: _noteDirty
                ? IconButton(
                    tooltip: 'ذخیرهٔ یادداشت',
                    icon: const Icon(Icons.check_rounded),
                    onPressed: () => _saveNote(session),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader(
          title: 'درس‌های این جلسه',
          accent: Personal2Colors.teacher,
        ),
        const SizedBox(height: 6),
        if (state.lessons.isEmpty)
          AppCard(
            child: Text(
              'برای این جلسه درسی ثبت نشده.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: t.textMuted,
              ),
            ),
          )
        else
          for (final lesson in state.lessons)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _lessonRow(state, lesson),
            ),
      ],
    );
  }

  Widget _studentRow(StudentRecord student, SessionDetailState state) {
    final t = TimeThemeKit.of(context).palette;
    final status = state.statusFor(student.id);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      onTap: () => context.push(
        '/worship/quran-teacher/student',
        extra: student.id,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              student.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: t.textPrimary,
              ),
            ),
          ),
          for (final entry in const [
            (AttendanceStatus.present, 'ح'),
            (AttendanceStatus.absent, 'غ'),
            (AttendanceStatus.late, 'ت'),
            (AttendanceStatus.excused, 'م'),
          ])
            _attendanceButton(student, state, entry.$1, entry.$2,
                status == entry.$1),
        ],
      ),
    );
  }

  Widget _attendanceButton(
    StudentRecord student,
    SessionDetailState state,
    AttendanceStatus status,
    String letter,
    bool selected,
  ) {
    final color = switch (status) {
      AttendanceStatus.present => DsStatus.success(context),
      AttendanceStatus.absent => DsStatus.danger(context),
      AttendanceStatus.late => DsStatus.warning(context),
      AttendanceStatus.excused => Personal2Colors.teacher,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Material(
        color: selected ? color : color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _setAttendance(student, state, status),
          child: SizedBox(
            width: 26,
            height: 26,
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lessonRow(SessionDetailState state, LessonRecordRow lesson) {
    final t = TimeThemeKit.of(context).palette;
    final ends = lesson.pageEnd != lesson.pageStart ? '–${lesson.pageEnd}' : '';
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    state.students
                        .where((s) => s.id == lesson.studentId)
                        .map((s) => s.name)
                        .firstOrNull,
                    '${lesson.type.titleFa} · صفحهٔ ${lesson.pageStart}$ends',
                  ].whereType<String>().join(' — '),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: t.textPrimary,
                  ),
                ),
                Text(
                  [
                    if (lesson.mistakeCount > 0)
                      '${lesson.mistakeCount} اشتباه',
                    if (lesson.gradeKey != null) lesson.gradeKey!,
                    if (lesson.note.isNotEmpty) lesson.note,
                  ].join(' · '),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'حذف این درس',
            icon: Icon(Icons.delete_outline_rounded,
                size: 18, color: DsStatus.danger(context)),
            onPressed: () => _confirmDeleteLesson(lesson),
          ),
        ],
      ),
    );
  }

  Future<void> _setAttendance(
    StudentRecord student,
    SessionDetailState state,
    AttendanceStatus status,
  ) async {
    await ref.read(quranTeacherDaoProvider).setAttendance(
          sessionId: state.session.id,
          studentId: student.id,
          status: status,
        );
    ref.invalidate(quranSessionDetailProvider(widget.sessionId));
    ref.invalidate(quranClassHistoryProvider(state.classGroup.id));
    ref.invalidate(quranClassDayProvider(state.classGroup.id));
  }

  Future<void> _toggleClosed(SessionRecord session) async {
    final ok = await ref
        .read(quranTeacherDaoProvider)
        .setSessionClosed(session.id, !session.closed);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تغییر وضعیت جلسه ممکن نشد.',
            style: TextStyle(fontFamily: AppTheme.fontFamily),
          ),
        ),
      );
      return;
    }
    ref.invalidate(quranSessionDetailProvider(widget.sessionId));
    ref.invalidate(quranClassHistoryProvider(session.classId));
    ref.invalidate(quranClassDayProvider(session.classId));
  }

  Future<void> _saveNote(SessionRecord session) async {
    await ref
        .read(quranTeacherDaoProvider)
        .saveSessionNote(session.id, _noteCtrl.text.trim());
    if (!mounted) return;
    setState(() => _noteDirty = false);
    ref.invalidate(quranSessionDetailProvider(widget.sessionId));
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'یادداشت جلسه ذخیره شد.',
          style: TextStyle(fontFamily: AppTheme.fontFamily),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteLesson(LessonRecordRow lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف این درس؟'),
        content: Text(
          'این ردیف از سابقهٔ شاگرد پاک می‌شود و صفحه‌هایش از پیشرفت کم '
          'می‌شوند. حضور جلسه دست نمی‌خورد.',
          style: TextStyle(fontFamily: AppTheme.fontFamily, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: DsStatus.danger(dialogContext),
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref
        .read(quranTeacherDaoProvider)
        .deleteLesson(lesson.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حذف درس ممکن نشد.',
            style: TextStyle(fontFamily: AppTheme.fontFamily),
          ),
        ),
      );
      return;
    }
    ref.invalidate(quranSessionDetailProvider(widget.sessionId));
    ref.invalidate(quranStudentProfileProvider(lesson.studentId));
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
