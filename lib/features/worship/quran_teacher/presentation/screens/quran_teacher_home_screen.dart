import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';
import 'package:tawheeed/features/worship/quran_teacher/data/quran_teacher_dao.dart';
import 'package:tawheeed/features/worship/quran_teacher/domain/quran_teacher_logic.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/providers/quran_teacher_providers.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/screens/teacher_settings_sheet.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

/// «دفتر مربی قرآن» — class home: class chips, the session hero, and the
/// student rows with four attendance buttons each.
class QuranTeacherHomeScreen extends ConsumerStatefulWidget {
  const QuranTeacherHomeScreen({super.key});

  @override
  ConsumerState<QuranTeacherHomeScreen> createState() => _QuranTeacherHomeScreenState();
}

class _QuranTeacherHomeScreenState extends ConsumerState<QuranTeacherHomeScreen> {
  String? _selectedClassId;

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(quranTeacherHomeProvider);
    // Keeps the reminder queue in step with the day (class start, unrecorded
    // lesson, Friday review) — all gated by the settings row.
    ref.watch(quranTeacherReminderSyncProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          accent: Personal2Colors.teacher,
          title: 'دفتر مربی قرآن',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'بازگشت',
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              tooltip: 'یادآورها',
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () => showQuranTeacherReminderSheet(context, ref),
            ),
            PopupMenuButton<String>(
              tooltip: 'بیشتر',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) async {
                switch (value) {
                  case 'classes':
                    context.push(RouteNames.quranTeacherClasses);
                  case 'history':
                    final classes =
                        ref.read(quranTeacherHomeProvider).value?.classes ??
                            const <ClassGroupRecord>[];
                    final id = _selectedClassId ??
                        (classes.isEmpty ? null : classes.first.id);
                    if (id != null) {
                      context.push(
                        RouteNames.quranTeacherSessionHistory,
                        extra: id,
                      );
                    }
                  case 'settings':
                    await showTeacherSettingsSheet(context, ref);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'classes', child: Text('مدیریت کلاس‌ها')),
                PopupMenuItem(value: 'history', child: Text('سابقهٔ جلسه‌ها')),
                PopupMenuItem(value: 'settings', child: Text('تنظیمات دفتر')),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: home.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FailureView(
              id: 'quran_teacher_home_load',
              title: 'دفتر مربی قرآن باز نشد',
              detail: 'کلاس‌ها و حضورها پاک نشده‌اند؛ فقط خواندنشان '
                  'ناموفق بود.',
              onRetry: () => ref.invalidate(quranTeacherHomeProvider),
              layout: FailureLayout.page,
              error: e,
            ),
            data: (data) {
              if (data.classes.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                      DsSpacing.page, 24, DsSpacing.page, 40),
                  children: [
                    AppEmptyState(
                      icon: Icons.groups_rounded,
                      accent: Personal2Colors.teacher,
                      message: 'هنوز کلاسی ثبت نشده',
                      subtitle:
                          'یک کلاس بسازید تا حضور و درس‌ها را ثبت کنید.',
                      actionLabel: 'مدیریت کلاس‌ها',
                      onAction: () => context.push(RouteNames.quranTeacherClasses),
                    ),
                  ],
                );
              }

              // A selected class id can outlive a deletion; fall back to the
              // first class rather than showing an empty page.
              final selected = data.classes.any((c) => c.id == _selectedClassId)
                  ? _selectedClassId!
                  : data.classes.first.id;

              return Column(
                children: [
                  _classChips(context, data, selected),
                  Expanded(child: _classBody(context, selected)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _classChips(BuildContext context, TeacherHomeState data, String selected) {
    final t = TimeThemeKit.of(context).palette;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.page),
        itemCount: data.classes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final klass = data.classes[i];
          final isSelected = klass.id == selected;
          return GestureDetector(
            onTap: () => setState(() => _selectedClassId = klass.id),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? Personal2Colors.teacher
                    : t.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                klass.name,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : t.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _classBody(BuildContext context, String classId) {
    final t = TimeThemeKit.of(context).palette;
    final day = ref.watch(quranClassDayProvider(classId));

    return day.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => FailureView(
        id: 'quran_class_day_load',
        title: 'جلسهٔ کلاس باز نشد',
        detail: 'حضور و درس‌های امروز پاک نشده‌اند؛ فقط خواندنشان ناموفق بود.',
        onRetry: () => ref.invalidate(quranClassDayProvider(classId)),
        error: e,
      ),
      data: (state) {
        if (state == null) {
          return const Center(child: Text('این کلاس پیدا نشد.'));
        }
        final session = state.session;
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(quranClassDayProvider(classId)),
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(DsSpacing.page, 10, DsSpacing.page, 40),
            children: [
              _ClassSummary(classId: classId),
              if (session == null)
                AppCard(
                  child: Text(
                    'امروز جلسه‌ای برای این کلاس برنامه‌ریزی نشده است.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: t.textSecondary,
                    ),
                  ),
                )
              else ...[
                _sessionHero(context, state),
                const SizedBox(height: 12),
                // A class with nobody in it can neither take attendance nor
                // record a lesson: say how to fill it instead of drawing an
                // empty roster and two dead buttons.
                if (state.students.isEmpty)
                  AppEmptyState(
                    icon: Icons.person_add_alt_1_rounded,
                    accent: Personal2Colors.teacher,
                    message: 'هنوز شاگردی در این کلاس نیست',
                    subtitle:
                        'نخست شاگردها را اضافه کنید تا حضور و درس ثبت شود.',
                    actionLabel: 'افزودن شاگرد',
                    onAction: () =>
                        context.push(RouteNames.quranTeacherClasses),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _markAllPresent(state),
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: const Text('همه حاضر'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: state.unrecordedCount > 0
                              ? null
                              : () => _closeSession(state),
                          style: FilledButton.styleFrom(
                            backgroundColor: Personal2Colors.teacher,
                          ),
                          child: const Text('ثبت جلسه'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SectionHeader(
                    title: 'شاگردان',
                    accent: Personal2Colors.teacher,
                    count: '${state.students.length}',
                  ),
                  const SizedBox(height: 6),
                  for (final student in state.students)
                    _studentRow(context, state, student),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sessionHero(BuildContext context, ClassDayState state) {
    final session = state.session!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dsContentColor(context, Personal2Colors.teacher),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'جلسهٔ ${session.number}',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [
              _jalaliLabel(session.date),
              if (state.classGroup.startMinutes != null)
                classTimeLabel(state.classGroup.startMinutes!),
              if (state.classGroup.place.isNotEmpty) state.classGroup.place,
            ].join(' · '),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: Colors.white.withValues(alpha: .85),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${state.presentCount} از ${state.students.length} حاضر',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: .25)),
                  FractionallySizedBox(
                    widthFactor: state.students.isEmpty
                        ? 0
                        : state.presentCount / state.students.length,
                    child: Container(color: Personal2Colors.kidsStars),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _heroChip(Icons.person_off_rounded, 'غایب ${state.absentCount}'),
              const SizedBox(width: 8),
              _heroChip(Icons.schedule_rounded, 'تأخیر ${state.lateCount}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentRow(
    BuildContext context,
    ClassDayState state,
    StudentRecord student,
  ) {
    final t = TimeThemeKit.of(context).palette;
    final status = state.statusFor(student.id);
    final lesson = state.lessonFor(student.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        onLongPress: () => context.push(
          RouteNames.quranTeacherStudent,
          extra: student.id,
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Personal2Colors.teacher,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                student.name.characters.first,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  Text(
                    lesson == null
                        ? 'تکلیف ثبت نشده'
                        : 'صفحهٔ ${lesson.pageStart}'
                            '${lesson.pageEnd != lesson.pageStart ? '–${lesson.pageEnd}' : ''}',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10,
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            // Four attendance buttons — ح / غ / ت / م.
            for (final entry in const [
              (AttendanceStatus.present, 'ح'),
              (AttendanceStatus.absent, 'غ'),
              (AttendanceStatus.late, 'ت'),
              (AttendanceStatus.excused, 'م'),
            ])
              _attendanceButton(
                context,
                state,
                student,
                entry.$1,
                entry.$2,
                status == entry.$1,
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'ثبت درس',
              icon: const Icon(Icons.edit_note_rounded, size: 22),
              onPressed: () => context.push(
                RouteNames.quranTeacherLesson,
                extra: (classId: state.classGroup.id, studentId: student.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attendanceButton(
    BuildContext context,
    ClassDayState state,
    StudentRecord student,
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
    return GestureDetector(
      onTap: () async {
        final session = state.session;
        if (session == null) return;
        final ok = await ref.read(quranTeacherDaoProvider).setAttendance(
              sessionId: session.id,
              studentId: student.id,
              status: status,
            );
        ref.invalidate(quranClassDayProvider(state.classGroup.id));
        ref.invalidate(quranClassHistoryProvider(state.classGroup.id));
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ثبت حضور ${student.name} ممکن نشد؛ دوباره تلاش کنید.',
                style: TextStyle(fontFamily: AppTheme.fontFamily),
              ),
            ),
          );
        }
      },
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
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
    );
  }

  Future<void> _markAllPresent(ClassDayState state) async {
    final session = state.session;
    if (session == null) return;
    await ref.read(quranTeacherDaoProvider).markAllPresent(
          sessionId: session.id,
          studentIds: [for (final s in state.students) s.id],
        );
    ref.invalidate(quranClassDayProvider(state.classGroup.id));
  }

  Future<void> _closeSession(ClassDayState state) async {
    final session = state.session;
    if (session == null) return;
    final ok = await ref.read(quranTeacherDaoProvider).closeSession(session.id);
    ref.invalidate(quranClassDayProvider(state.classGroup.id));
    ref.invalidate(quranClassHistoryProvider(state.classGroup.id));
    ref.invalidate(quranTeacherHomeProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'جلسه ثبت شد. بعداً هم می‌توانید از «سابقهٔ جلسه‌ها» ویرایش کنید.'
              : 'ثبت جلسه ممکن نشد؛ حضورها ذخیره شده‌اند.',
          style: TextStyle(fontFamily: AppTheme.fontFamily),
        ),
      ),
    );
  }

  /// Jalali label with Latin digits, through the app's single formatter.
  static String _jalaliLabel(DateTime date) => jalaliYmdShort(Jalali.fromDateTime(date));
}

/// The class's own numbers, under its name: attendance, pages per student and
/// how many sessions have been held.
///
/// These come from [ClassHistoryState], which pools every recorded session —
/// so the card does not jump when today's attendance is edited (that row was
/// already counted), and it never becomes a leaderboard.
class _ClassSummary extends ConsumerWidget {
  const _ClassSummary({required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(quranClassHistoryProvider(classId));
    return history.maybeWhen(
      data: (state) {
        if (state == null || state.sessions.isEmpty) {
          return const SizedBox.shrink();
        }
        final t = TimeThemeKit.of(context).palette;
        final rate = state.attendanceRate;
        final pages = state.pagesPerStudent;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: _chip(
                  context,
                  t.textMuted,
                  'حضور',
                  rate == null ? '—' : '${(rate * 100).round()}٪',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _chip(
                  context,
                  t.textMuted,
                  'صفحه/شاگرد',
                  pages == null ? '—' : pages.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _chip(
                  context,
                  t.textMuted,
                  'جلسه',
                  '${state.sessions.length}',
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _chip(
    BuildContext context,
    Color labelColor,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Personal2Colors.teacher.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Personal2Colors.teacher,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 9,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// «یادآورها» — the settings row's notification switches, which had no reader
/// and no surface until now.
///
/// Only the three nudges this tool really schedules are offered: کلاس، ثبت درس
/// امروز، و خلاصهٔ هفته. A switch that changes nothing is what this sheet is
/// here to avoid.
Future<void> showQuranTeacherReminderSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final dao = ref.read(quranTeacherDaoProvider);
  final settings = await dao.settings();
  if (!context.mounted) return;

  var enabled = settings.remindersEnabled;
  var classStart = settings.classStartReminder;
  var unrecorded = settings.unrecordedReminder;
  var weekly = settings.weeklySummary;

  TeacherSettingsRecord withValues() => TeacherSettingsRecord(
        className: settings.className,
        mosqueName: settings.mosqueName,
        teacherName: settings.teacherName,
        excusedExcluded: settings.excusedExcluded,
        absenceStreakAlert: settings.absenceStreakAlert,
        remindersEnabled: enabled,
        classStartReminder: classStart,
        unrecordedReminder: unrecorded,
        weeklySummary: weekly,
        quietStartMinutes: settings.quietStartMinutes,
        quietEndMinutes: settings.quietEndMinutes,
      );

  Future<void> save() async {
    await dao.saveSettings(withValues());
    ref.invalidate(quranTeacherHomeProvider);
    ref.invalidate(quranTeacherReminderSyncProvider);
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: TimeThemeKit.of(context).palette.surface,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final t = TimeThemeKit.of(sheetContext).palette;
        Widget row({
          required String title,
          required String subtitle,
          required bool value,
          required ValueChanged<bool> onChanged,
        }) =>
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: Personal2Colors.teacher,
              title: Text(
                title,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: enabled ? t.textPrimary : t.textMuted,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(sheetContext, 10),
                  height: 1.6,
                  color: t.textMuted,
                ),
              ),
              value: enabled && value,
              onChanged: enabled
                  ? (v) async {
                      onChanged(v);
                      setSheetState(() {});
                      await save();
                    }
                  : null,
            );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'یادآورها',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'همهٔ این یادآوری‌ها در بازهٔ سکوت شب ارسال نمی‌شوند و با '
                  'خاموش‌کردن هر مورد، همان لحظه از صف حذف می‌شوند.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    height: 1.7,
                    color: t.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Personal2Colors.teacher,
                  title: Text(
                    'یادآوری‌ها',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  value: enabled,
                  onChanged: (v) async {
                    setSheetState(() => enabled = v);
                    await save();
                  },
                ),
                const Divider(height: 12),
                row(
                  title: 'نیم ساعت قبل از کلاس',
                  subtitle: 'از ساعت شروع همان کلاس در «مدیریت کلاس‌ها»',
                  value: classStart,
                  onChanged: (v) => classStart = v,
                ),
                row(
                  title: 'ثبت درس امروز',
                  subtitle: 'اگر جلسهٔ امروز ثبت شده ولی درسی برایش نوشته نشده',
                  value: unrecorded,
                  onChanged: (v) => unrecorded = v,
                ),
                row(
                  title: 'خلاصهٔ هفته',
                  subtitle: 'جمعه شب، یک یادآوری برای مرور هفته',
                  value: weekly,
                  onChanged: (v) => weekly = v,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
