import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/features/personal2/shared/mushaf_preview.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';
import 'package:tawheeed/features/personal2/shared/template_store.dart';
import 'package:tawheeed/features/worship/quran_teacher/data/quran_teacher_dao.dart';
import 'package:tawheeed/features/worship/quran_teacher/domain/quran_teacher_logic.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/providers/quran_teacher_providers.dart';

/// «برگهٔ درس» — the per-student lesson record: type, page/line range, grade,
/// mistakes, tajweed tags, note and the suggested next assignment.
///
/// The mushaf link opens the reader in PREVIEW mode, so checking a student's
/// page never moves the teacher's own reading position.
class LessonSheetScreen extends ConsumerStatefulWidget {
  const LessonSheetScreen({
    super.key,
    required this.classId,
    required this.studentId,
  });

  final String classId;
  final String studentId;

  @override
  ConsumerState<LessonSheetScreen> createState() => _LessonSheetScreenState();
}

class _LessonSheetScreenState extends ConsumerState<LessonSheetScreen> {
  final _pageStartCtrl = TextEditingController();
  final _pageEndCtrl = TextEditingController();
  final _lineStartCtrl = TextEditingController();
  final _lineEndCtrl = TextEditingController();
  final _mistakesCtrl = TextEditingController(text: '0');
  final _noteCtrl = TextEditingController();

  LessonType _type = LessonType.recitation;
  String? _gradeKey;
  final Set<String> _tags = {};
  String? _error;
  bool _saving = false;

  /// The page fields are filled from the student's own history exactly once:
  /// the suggestion is a starting point the teacher can overwrite, not a value
  /// that reappears after they clear it.
  bool _rangeSeeded = false;

  @override
  void dispose() {
    _pageStartCtrl.dispose();
    _pageEndCtrl.dispose();
    _lineStartCtrl.dispose();
    _lineEndCtrl.dispose();
    _mistakesCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(quranClassDayProvider(widget.classId));
    final templates = ref.watch(personal2TemplatesProvider).value;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          accent: Personal2Colors.teacher,
          title: 'ثبت درس',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'بازگشت',
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: day.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FailureView(
              id: 'quran_lesson_load',
              title: 'ثبت درس باز نشد',
              detail: 'درس‌های ثبت‌شده پاک نشده‌اند؛ فقط خواندنشان ناموفق بود.',
              onRetry: () =>
                  ref.invalidate(quranClassDayProvider(widget.classId)),
              layout: FailureLayout.page,
              error: e,
            ),
            data: (state) {
              if (state == null) {
                return const Center(child: Text('این کلاس پیدا نشد.'));
              }
              final student = state.students
                  .where((s) => s.id == widget.studentId)
                  .firstOrNull;
              if (student == null) {
                return const Center(child: Text('این شاگرد پیدا نشد.'));
              }
              _seedRange(student.id);
              return _body(context, state, student, templates);
            },
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    ClassDayState state,
    StudentRecord student,
    Personal2Templates? templates,
  ) {
    final t = TimeThemeKit.of(context).palette;
    const accent = Personal2Colors.teacher;

    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        AppCard(
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  student.name.characters.first,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  student.name,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Type segmented control.
        SegmentedButton<LessonType>(
          segments: [
            for (final type in LessonType.values)
              ButtonSegment(value: type, label: Text(type.titleFa)),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 12),
        const SectionHeader(title: 'تکلیف', accent: accent),
        const SizedBox(height: 6),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pageStartCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'صفحهٔ شروع',
                        hintText: '۱ تا ۶۰۴',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _pageEndCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'صفحهٔ پایان',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lineStartCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'سطر شروع (اختیاری)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _lineEndCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'سطر پایان',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _quickNextPage,
                    child: const Text('صفحهٔ بعد'),
                  ),
                  OutlinedButton(
                    onPressed: _quickRepeat,
                    child: const Text('تکرار'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openInMushaf,
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text('باز کردن در مصحف'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader(title: 'نمره', accent: accent),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final grade in templates?.grades ?? const <GradeScaleEntry>[])
              ChoiceChip(
                label: Text(grade.titleFa),
                selected: _gradeKey == grade.key,
                onSelected: (v) =>
                    setState(() => _gradeKey = v ? grade.key : null),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const SectionHeader(title: 'اشتباه‌ها و نکته‌ها', accent: accent),
        const SizedBox(height: 6),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'تعداد اشتباه',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _mistakesCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in templates?.tajweedTags ?? const <TajweedTag>[])
                    FilterChip(
                      label: Text(tag.titleFa),
                      selected: _tags.contains(tag.key),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _tags.add(tag.key);
                        } else {
                          _tags.remove(tag.key);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'یادداشت',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              color: DsStatus.danger(context),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _saving ? null : () => _save(state),
                style: FilledButton.styleFrom(backgroundColor: accent),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ثبت و شاگرد بعدی'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'تگ‌های تجوید فقط برچسب‌اند و از فایل قابل ویرایش خوانده می‌شوند؛ این '
          'برنامه هیچ حکم تجویدی صادر نمی‌کند و متنی از قرآن ذخیره نمی‌شود.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 10,
            height: 1.7,
            color: t.textMuted,
          ),
        ),
      ],
    );
  }

  /// «تکلیف بعدی» from the previous lesson: the page after where the student
  /// actually stopped. One read of the history, once per sheet.
  Future<void> _seedRange(String studentId) async {
    if (_rangeSeeded) return;
    _rangeSeeded = true;
    final history = await ref
        .read(quranTeacherDaoProvider)
        .lessonsForStudent(studentId);
    if (!mounted || _pageStartCtrl.text.isNotEmpty) return;
    final suggestion =
        suggestNextAssignment([for (final r in history) r.toSpec()]);
    final page = suggestion?.pageStart ?? 1;
    setState(() {
      _pageStartCtrl.text = '$page';
      _pageEndCtrl.text = '$page';
    });
  }

  // ── Range helpers ────────────────────────────────────────────────────

  void _quickNextPage() {
    final last = int.tryParse(_pageStartCtrl.text.trim());
    final next = (last ?? 0) + 1;
    if (next > 604) return;
    setState(() {
      _pageStartCtrl.text = '$next';
      _pageEndCtrl.text = '$next';
    });
  }

  /// Copies the previous record's range — what "repeat the last lesson" means
  /// to a teacher. Loaded lazily on first use so the sheet does not query on
  /// open for a button that may never be tapped.
  Future<void> _quickRepeat() async {
    final history = await ref
        .read(quranTeacherDaoProvider)
        .lessonsForStudent(widget.studentId);
    if (history.isEmpty || !mounted) return;
    final previous = history.last;
    setState(() {
      _pageStartCtrl.text = '${previous.pageStart}';
      _pageEndCtrl.text = '${previous.pageEnd}';
    });
  }

  Future<void> _openInMushaf() async {
    final page = int.tryParse(_pageStartCtrl.text.trim()) ?? 1;
    if (!mounted) return;
    // Preview-only: the teacher's own reading position is never touched. The
    // reader is a shell TAB, not a route, so opening it means switching the
    // shell's tab index (1 = قرآن) rather than pushing a path — pushing `/`
    // would stack a second shell over this screen.
    final container = ProviderScope.containerOf(context, listen: false);
    ref.read(mushafPreviewLauncherProvider).open(
          page: page,
          openQuranTab: () {
            container.read(shellTabIndexProvider.notifier).setIndex(1);
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          },
        );
  }

  Future<void> _save(ClassDayState state) async {
    final session = state.session;
    if (session == null) {
      setState(() => _error = 'برای امروز جلسه‌ای وجود ندارد.');
      return;
    }
    final pageStart = int.tryParse(_pageStartCtrl.text.trim());
    final pageEnd = int.tryParse(_pageEndCtrl.text.trim());
    if (pageStart == null || pageEnd == null) {
      setState(() => _error = 'صفحهٔ شروع و پایان را وارد کنید.');
      return;
    }
    final lineStart = int.tryParse(_lineStartCtrl.text.trim());
    final lineEnd = int.tryParse(_lineEndCtrl.text.trim());

    final problem = validateLesson(
      pageStart: pageStart,
      pageEnd: pageEnd,
      lineStart: lineStart,
      lineEnd: lineEnd,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    // The next assignment belongs to THIS record: page after where it ended.
    // Computing it from the history before the save would suggest the page
    // that was just recorded.
    final nextPage = pageEnd + 1 <= 604 ? pageEnd + 1 : null;

    final ok = await ref.read(quranTeacherDaoProvider).saveLesson(
          id: 'lesson_${DateTime.now().microsecondsSinceEpoch}',
          sessionId: session.id,
          studentId: widget.studentId,
          dayKey: state.todayKey,
          type: _type,
          pageStart: pageStart,
          pageEnd: pageEnd,
          lineStart: lineStart,
          lineEnd: lineEnd,
          gradeKey: _gradeKey,
          mistakeCount: int.tryParse(_mistakesCtrl.text.trim()) ?? 0,
          tajweedTags: _tags.toList(),
          note: _noteCtrl.text.trim(),
          nextPageStart: nextPage,
          nextPageEnd: nextPage,
        );

    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      setState(() => _error = 'ثبت درس ممکن نشد.');
      return;
    }

    ref.invalidate(quranClassDayProvider(widget.classId));
    ref.invalidate(quranStudentProfileProvider(widget.studentId));
    ref.invalidate(quranClassHistoryProvider(widget.classId));

    // «ثبت و شاگرد بعدی»: move to the next student who has no lesson today,
    // skipping anyone already recorded. Falls back to closing the sheet.
    final next = state.students
        .where((s) =>
            s.id != widget.studentId && state.lessonFor(s.id) == null)
        .firstOrNull;
    if (next == null) {
      context.pop();
      return;
    }
    context.pushReplacement('/worship/quran-teacher/lesson',
        extra: (classId: widget.classId, studentId: next.id));
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
