import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/features/personal2/shared/mini_charts.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';
import 'package:tawheeed/features/worship/quran_teacher/data/quran_teacher_dao.dart';
import 'package:tawheeed/features/worship/quran_teacher/domain/quran_teacher_logic.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/providers/quran_teacher_providers.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/screens/student_edit_sheet.dart';
import 'package:tawheeed/features/quran/data/quran_helpers.dart';

/// «پروندهٔ شاگرد» — attendance ring, progress (pages + juz strip), top
/// mistakes, recent sessions and the call/report actions.
class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(quranStudentProfileProvider(studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          accent: Personal2Colors.teacher,
          title: 'پروندهٔ شاگرد',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'بازگشت',
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              tooltip: 'ویرایش اطلاعات',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                final state =
                    ref.read(quranStudentProfileProvider(studentId)).value;
                if (state == null) return;
                showStudentEditSheet(
                  context,
                  ref,
                  classId: state.classGroup.id,
                  existing: state.student,
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: profile.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FailureView(
              id: 'quran_student_profile_load',
              title: 'پروندهٔ شاگرد باز نشد',
              detail: 'پرونده پاک نشده است؛ فقط خواندنش ناموفق بود.',
              onRetry: () =>
                  ref.invalidate(quranStudentProfileProvider(studentId)),
              layout: FailureLayout.page,
              error: e,
            ),
            data: (state) => state == null
                ? const Center(child: Text('این شاگرد پیدا نشد.'))
                : _body(context, ref, state),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, StudentProfileState state) {
    final t = TimeThemeKit.of(context).palette;
    const accent = Personal2Colors.teacher;
    final pct = state.attendancePct;

    // Juz coverage uses the app's own page→juz mapper, so the strip agrees
    // with every other progress view in the app.
    final covered = juzCovered(state.recitedPages, getCurrentJuzNumberForPage);
    final strip = juzStrip(covered);

    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        AppCard(
          child: Row(
            children: [
              MiniRing(
                progress: pct ?? 0,
                color: accent,
                size: 58,
                semanticLabel: 'درصد حضور ${state.student.name}',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.student.name,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        state.classGroup.name,
                        if (state.student.birthYear != null)
                          '${DateTime.now().year - state.student.birthYear!} ساله',
                        pct == null
                            ? 'حضور: —'
                            : 'حضور ${(pct * 100).round()}٪',
                      ].join(' · '),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (state.student.note.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sticky_note_2_outlined,
                    size: 18, color: t.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.student.note,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      height: 1.7,
                      color: t.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (state.settings.absenceStreakAlert &&
            state.currentAbsenceStreak >= 3) ...[
          const SizedBox(height: 10),
          AppCard(
            borderColor: DsStatus.warning(context).withValues(alpha: .45),
            child: Row(
              children: [
                Icon(Icons.phone_in_talk_rounded,
                    size: 20, color: DsStatus.warning(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${state.currentAbsenceStreak} جلسهٔ متوالی غیبت؛ بهتر است با '
                    'ولی تماس بگیرید.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      height: 1.7,
                      color: t.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        const SectionHeader(title: 'پیشرفت', accent: accent),
        const SizedBox(height: 6),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'تلاوت تا صفحهٔ ${state.highest} از ۶۰۴',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${state.recitedPages.length} صفحه',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: t.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              MiniBars(
                color: accent,
                items: [
                  MiniBarItem(
                    label: 'تلاوت',
                    value: state.recitedPages.length.toDouble(),
                    max: 604,
                  ),
                  if (state.hifzPages.isNotEmpty)
                    MiniBarItem(
                      label: 'حفظ',
                      value: state.hifzPages.length.toDouble(),
                      max: 604,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'مصاحف پوشش‌داده‌شده: ${covered.length} از ۳۰ جزء',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  color: t.textSecondary,
                ),
              ),
              if (state.nextAssignment != null) ...[
                const SizedBox(height: 6),
                Text(
                  'تکلیف جلسهٔ بعد: صفحهٔ ${state.nextAssignment}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Personal2Colors.teacher,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              // 30-cell juz strip.
              Wrap(
                spacing: 2,
                runSpacing: 2,
                children: [
                  for (var i = 0; i < strip.length; i++)
                    Container(
                      width: 8,
                      height: 16,
                      decoration: BoxDecoration(
                        color: strip[i]
                            ? accent
                            : t.outline.withValues(alpha: .28),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const SectionHeader(title: 'اشتباه‌های پرتکرار (۳۰ روز گذشته)', accent: accent),
        const SizedBox(height: 6),
        _mistakeBars(context, state),
        const SizedBox(height: 14),
        const SectionHeader(title: 'جلسه‌های اخیر', accent: accent),
        const SizedBox(height: 6),
        _recentSessions(context, ref, state),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: state.student.parentPhone.isEmpty
                    ? null
                    : () => _callParent(state.student.parentPhone),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('تماس با ولی'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push(
                  RouteNames.quranTeacherReport,
                  extra: studentId,
                ),
                style: FilledButton.styleFrom(backgroundColor: accent),
                icon: const Icon(Icons.description_rounded, size: 18),
                label: const Text('گزارش والدین'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => _confirmDelete(context, ref, state),
            style: TextButton.styleFrom(
              foregroundColor: DsStatus.danger(context),
            ),
            child: const Text('حذف همهٔ داده‌های این شاگرد'),
          ),
        ),
      ],
    );
  }

  Widget _mistakeBars(BuildContext context, StudentProfileState state) {
    final t = TimeThemeKit.of(context).palette;
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent = state.lessons
        .where((l) => l.date.isAfter(cutoff))
        .map((l) => l.toSpec());
    final counts = tagCounts(recent);
    if (counts.isEmpty) {
      return AppCard(
        child: Text(
          'در ۳۰ روز گذشته تگی ثبت نشده است.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            color: t.textSecondary,
          ),
        ),
      );
    }
    final top = counts.take(5).toList();
    final maxCount = top.first.count;
    return AppCard(
      child: MiniBars(
        color: Personal2Colors.teacher,
        barHeight: 7,
        items: [
          for (final c in top)
            MiniBarItem(
              label: c.tag,
              value: c.count.toDouble(),
              max: maxCount.toDouble(),
            ),
        ],
      ),
    );
  }

  Widget _recentSessions(
    BuildContext context,
    WidgetRef ref,
    StudentProfileState state,
  ) {
    final t = TimeThemeKit.of(context).palette;
    if (state.lessons.isEmpty) {
      return AppCard(
        child: Text(
          'هنوز درسی ثبت نشده.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            color: t.textSecondary,
          ),
        ),
      );
    }
    final recent = state.lessons.reversed.take(6).toList();
    return Column(
      children: [
        for (final lesson in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${lesson.type.titleFa} · صفحهٔ ${lesson.pageStart}'
                          '${lesson.pageEnd != lesson.pageStart ? '–${lesson.pageEnd}' : ''}',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: t.textPrimary,
                          ),
                        ),
                        Text(
                          '${jalaliYmdShort(Jalali.fromDateTime(lesson.date))} · '
                          '${lesson.mistakeCount} اشتباه',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10,
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (lesson.gradeKey != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Personal2Colors.teacher.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        state.gradeTitle(lesson.gradeKey!),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                          color: Personal2Colors.teacher,
                        ),
                      ),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'حذف این درس',
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 17, color: DsStatus.danger(context)),
                    onPressed: () =>
                        _confirmDeleteLesson(context, ref, state, lesson),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Removing one wrong lesson — a page typed for the wrong student, a grade
  /// entered twice — without touching the rest of the record.
  Future<void> _confirmDeleteLesson(
    BuildContext context,
    WidgetRef ref,
    StudentProfileState state,
    LessonRecordRow lesson,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف این درس؟'),
        content: Text(
          '${lesson.type.titleFa} · صفحهٔ ${lesson.pageStart} از سابقهٔ '
          '${state.student.name} پاک می‌شود. حضور جلسه دست نمی‌خورد.',
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
    if (!ok) {
      if (!context.mounted) return;
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
    ref.invalidate(quranStudentProfileProvider(state.student.id));
    ref.invalidate(quranClassDayProvider(state.classGroup.id));
    ref.invalidate(quranClassHistoryProvider(state.classGroup.id));
  }

  Future<void> _callParent(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    // tel: only — the brief forbids reading the contacts permission, and the
    // number is whatever the teacher typed.
    await launchUrl(uri);
  }

  /// The brief's per-student «delete everything», confirmed explicitly.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    StudentProfileState state,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف همهٔ داده‌های این شاگرد؟'),
        content: Text(
          'نام، حضور و درس‌های ${state.student.name} برای همیشه پاک می‌شود. '
          'کلاس و دیگر شاگردان دست نمی‌خورند.',
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
    await ref
        .read(quranTeacherDaoProvider)
        .deleteEverythingForStudent(state.student.id);
    ref.invalidate(quranTeacherHomeProvider);
    ref.invalidate(quranClassDayProvider(state.classGroup.id));
    if (context.mounted) Navigator.of(context).pop();
  }
}
