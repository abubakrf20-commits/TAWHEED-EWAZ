import 'package:flutter/material.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/hifz/domain/entities/hafiz_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_lesson_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_review_model.dart';
import 'package:tawheeed/features/hifz/domain/hifz_helpers.dart';
import 'package:tawheeed/features/hifz/presentation/providers/hifz_provider.dart';
import 'package:tawheeed/features/hifz/presentation/screens/hifz_report_screen.dart';
import 'package:tawheeed/features/hifz/presentation/widgets/hifz_form_sheets.dart';
import 'package:tawheeed/features/hifz/presentation/widgets/hifz_range_picker.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';
import 'package:tawheeed/shared/utils/date_range.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

/// `#RRGGBB` → Color. A restored backup (or a hand-edited row) can carry a
/// value that is not a hex colour; `int.parse` threw inside build and took
/// the whole screen down, so an unreadable value falls back to the module
/// accent instead.
Color _hex(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', '0xFF'));
  return value == null ? TopicHues.hifz : Color(value);
}

/// Persian day names (Shaturday=شنبه through Friday=جمعه)
const _dayNames = [
  'شنبه',
  'یکشنبه',
  'دوشنبه',
  'سه‌شنبه',
  'چهارشنبه',
  'پنجشنبه',
  'جمعه'
];

/// Returns the Jalali day-of-week index (0=Saturday … 6=Friday).
int _jDayOfWeek(DateTime d) {
  final j = Jalali.fromDateTime(d);
  return j.weekDay - 1; // Jalali weekDay: 1=Sat … 7=Fri
}

Color _qualityColor(ReviewQuality q, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  switch (q) {
    case ReviewQuality.weak:
      return isDark ? AppTheme.darkError : AppTheme.lightError;
    case ReviewQuality.medium:
      return isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    case ReviewQuality.excellent:
      return isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
  }
}

bool _inLastDays(DateTime d, int days) =>
    !d.isBefore(DateTime.now().subtract(Duration(days: days)));

/// سَبَق suggestion: the union of lessons delivered within the hafiz's
/// sabaq window (e.g. last 7 days), or null when there are none.
HifzRange? _sabaqSuggestion(HafizModel hafiz, List<HifzLessonModel> lessons) {
  final inWindow =
      lessons.where((l) => _inLastDays(l.date, hafiz.sabaqWindowDays)).toList();
  if (inWindow.isEmpty) return null;
  final union = unionOfLessons([
    for (final l in inWindow)
      (sFrom: l.surahFrom, aFrom: l.ayahFrom, sTo: l.surahTo, aTo: l.ayahTo),
  ])!;
  return (
    sFrom: union.sFrom,
    aFrom: union.aFrom,
    sTo: union.sTo,
    aTo: union.aTo,
    pages: pagesForRange(union.sFrom, union.aFrom, union.sTo, union.aTo),
  );
}

class HifzScreen extends ConsumerStatefulWidget {
  const HifzScreen({super.key});

  @override
  ConsumerState<HifzScreen> createState() => _HifzScreenState();
}

class _HifzScreenState extends ConsumerState<HifzScreen> {
  DateTime _selectedDate = DateTime.now();

  void _selectDate(DateTime d) => setState(() => _selectedDate = d);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hifzProvider);
    final notifier = ref.read(hifzProvider.notifier);
    const accent = TopicHues.hifz;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          title: 'حفظ قرآن',
          actions: [
            if (state.hafizs.isNotEmpty)
              IconButton(
                tooltip: 'گزارش ماهانه و سالانه',
                icon: const Icon(Icons.insert_chart_outlined),
                onPressed: () {
                  final h = state.selectedHafiz;
                  if (h == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HifzReportScreen(
                        hafiz: h,
                        lessons: state.lessonsOf(h.id),
                        reviews: state.reviewsOf(h.id),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        body: !state.loaded
            ? const Center(child: CircularProgressIndicator())
            : state.hafizs.isEmpty
                ? const _EmptyState(accent: accent)
                : _buildContent(context, state, notifier, accent),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    HifzState state,
    HifzNotifier notifier,
    Color accent,
  ) {
    final t = TimeThemeKit.of(context).palette;
    final hafiz = state.selectedHafiz!;
    final lessons = state.lessonsOf(hafiz.id);
    final reviews = state.reviewsOf(hafiz.id);
    final sabaqs = reviews.where((r) => r.type == ReviewType.sabaq).toList();
    final murajaahs =
        reviews.where((r) => r.type == ReviewType.murajaah).toList();
    final memorized = state.memorizedPagesOf(hafiz.id);
    final progress = (memorized / totalQuranPages).clamp(0.0, 1.0);

    final weekLessons = lessons
        .where((l) => _inLastDays(l.date, 7))
        .fold(0, (sum, l) => sum + l.pages);
    final weekSabaq = sabaqs.where((r) => _inLastDays(r.date, 7)).length;
    final weekMurajaah = murajaahs.where((r) => _inLastDays(r.date, 7)).length;

    final sabaqSuggestion = _sabaqSuggestion(hafiz, lessons);

    // Records belonging to the selected day only — days without data are
    // intentionally left empty instead of showing every record.
    bool sameDay(DateTime d) {
      final a = Jalali.fromDateTime(d);
      final b = Jalali.fromDateTime(_selectedDate);
      return a.year == b.year && a.month == b.month && a.day == b.day;
    }

    final dayLessons = lessons.where((l) => sameDay(l.date)).toList();
    final daySabaqs = sabaqs.where((r) => sameDay(r.date)).toList();
    final dayMurajaahs = murajaahs.where((r) => sameDay(r.date)).toList();

    return ListView(
      // The system-bar inset rides on top of the page's own bottom padding:
      // the last card scrolls above the 3-button bar, and zero is added
      // where there is no bar.
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 40 + MediaQuery.paddingOf(context).bottom),
      children: [
        // ── Hafiz selector ────────────────────────────────────────
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final h in state.hafizs)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: ChoiceChip(
                    avatar: CircleAvatar(
                      backgroundColor: _hex(h.colorHex),
                      radius: 10,
                      child: Text(
                        h.name.isEmpty ? '؟' : h.name.characters.first,
                        style:
                            TextStyle(color: Colors.white, fontSize: AppTheme.scaledFontSize(context, 11)),
                      ),
                    ),
                    label: Text(h.name),
                    selected: h.id == hafiz.id,
                    onSelected: (_) => notifier.selectHafiz(h.id),
                  ),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('حافظ جدید'),
                  onPressed: () => showHafizFormSheet(context, ref),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Dashboard card ────────────────────────────────────────
        _DashboardCard(
          hafiz: hafiz,
          memorizedPages: memorized,
          progress: progress,
          accent: accent,
          onEdit: () => showHafizFormSheet(context, ref, hafiz: hafiz),
          onDelete: () => _confirmDeleteHafiz(context, hafiz),
        ),
        const SizedBox(height: 14),

        // ── This-week summary ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: t.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryItem(
                  label: 'حفظ (هفته)', value: '${en(weekLessons)} صفحه'),
              _SummaryItem(label: 'سبق', value: en(weekSabaq)),
              _SummaryItem(label: 'مراجعه', value: en(weekMurajaah)),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ── Day selector ──────────────────────────────────────────
        _DaySelector(
          accent: accent,
          selectedDate: _selectedDate,
          onDateChanged: _selectDate,
          lessons: lessons,
          reviews: reviews,
        ),
        const SizedBox(height: 22),

        // ── Lessons (حفظ جدید) ────────────────────────────────────
        _SectionHeader(
          title: 'حفظ جدید',
          icon: Icons.menu_book,
          accent: accent,
          onAdd: () => showLessonFormSheet(context, ref, hafiz),
        ),
        if (dayLessons.isEmpty)
          const _InlineEmpty(text: 'در این روز حفظی ثبت نشده است.')
        else
          for (final l in dayLessons)
            _LessonTile(
              lesson: l,
              accent: accent,
              onTap: () => showLessonFormSheet(context, ref, hafiz, lesson: l),
              onDelete: () => _confirmDeleteLesson(context, l),
            ),
        const SizedBox(height: 20),

        // ── Sabaq (سبق) ───────────────────────────────────────────
        _SectionHeader(
          title: 'سبق',
          icon: Icons.history_edu,
          accent: accent,
          onAdd: () => showReviewFormSheet(context, ref, hafiz,
              type: ReviewType.sabaq, suggested: sabaqSuggestion),
        ),
        if (daySabaqs.isEmpty)
          _InlineEmpty(
            text: sabaqSuggestion == null
                ? 'ابتدا «حفظ جدید» ثبت کنید — سپس سبق از محفوظات ${en(hafiz.sabaqWindowDays)} روز اخیر پیشنهاد میشود.'
                : 'سبقی در این روز ثبت نشده — با دکمهٔ بالا از پیشنهاد خودکار استفاده کنید.',
          )
        else
          for (final r in daySabaqs)
            _ReviewTile(
              review: r,
              onTap: () => showReviewFormSheet(context, ref, hafiz,
                  type: ReviewType.sabaq, review: r),
              onDelete: () => _confirmDeleteReview(context, r),
            ),
        const SizedBox(height: 20),

        // ── Muraja'ah (مراجعه) ────────────────────────────────────
        _SectionHeader(
          title: 'مراجعه',
          icon: Icons.auto_stories,
          accent: accent,
          onAdd: () => showReviewFormSheet(context, ref, hafiz,
              type: ReviewType.murajaah),
        ),
        if (dayMurajaahs.isEmpty)
          const _InlineEmpty(
              text:
                  'مراجعهای در این روز ثبت نشده — مرور حفظ قدیم (مثلاً نیم جزء) را ثبت کنید.')
        else
          for (final r in dayMurajaahs)
            _ReviewTile(
              review: r,
              onTap: () => showReviewFormSheet(context, ref, hafiz,
                  type: ReviewType.murajaah, review: r),
              onDelete: () => _confirmDeleteReview(context, r),
            ),
      ],
    );
  }

  Future<void> _confirmDeleteHafiz(
    BuildContext context,
    HafizModel hafiz,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف حافظ'),
        content: Text(
            'همهٔ رکوردهای «${hafiz.name}» (حفظ، سبق و مراجعه) حذف میشوند. ادامه میدهید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) await ref.read(hifzProvider.notifier).deleteHafiz(hafiz.id);
  }

  Future<void> _confirmDeleteLesson(
    BuildContext context,
    HifzLessonModel l,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف رکورد حفظ'),
        content: Text(
            '«${rangeLabel(l.surahFrom, l.ayahFrom, l.surahTo, l.ayahTo)}» حذف شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(hifzProvider.notifier).deleteLesson(l.id, l.hafizId);
    }
  }

  Future<void> _confirmDeleteReview(
    BuildContext context,
    HifzReviewModel r,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف رکورد ${r.type.label}'),
        content: Text(
            '«${rangeLabel(r.surahFrom, r.ayahFrom, r.surahTo, r.ayahTo)}» حذف شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(hifzProvider.notifier).deleteReview(r.id, r.hafizId);
    }
  }
}

// ── Empty state (no hafizs yet) ─────────────────────────────────────

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppEmptyState(
      icon: Icons.menu_book,
      message: 'هنوز حافظی ثبت نشده است',
      subtitle:
          'برای پیگیری حفظ قرآن اعضای خانواده، حافظ اضافه کنید — سپس هر روز «حفظ جدید»، «سبق» و «مراجعه» را ثبت کنید.',
      accent: dsContentColor(context, accent),
      actionLabel: 'افزودن اولین حافظ',
      onAction: () => showHafizFormSheet(context, ref),
    );
  }
}

// ── Dashboard card ──────────────────────────────────────────────────

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.hafiz,
    required this.memorizedPages,
    required this.progress,
    required this.accent,
    required this.onEdit,
    required this.onDelete,
  });

  final HafizModel hafiz;
  final int memorizedPages;
  final double progress;
  final Color accent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accentInk = dsContentColor(context, accent);
    final percent = (progress * 100).round();
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: accent.withValues(alpha: 0.10),
      borderColor: accent.withValues(alpha: 0.25),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _hex(hafiz.colorHex),
                child: Text(
                  hafiz.name.isEmpty ? '؟' : hafiz.name.characters.first,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: AppTheme.scaledFontSize(context, 19),
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hafiz.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${en(memorizedPages)} از ${en(totalQuranPages)} صفحه حفظ شده',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('ویرایش حافظ')),
                  PopupMenuItem(value: 'delete', child: Text('حذف حافظ')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: accent.withValues(alpha: 0.15),
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${en(percent)}٪ از قرآن',
              style: TextStyle(
                color: accentInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header with add button ──────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.accent,
    required this.onAdd,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final accentInk = dsContentColor(context, accent);
    return Row(
      children: [
        Icon(icon, size: 20, color: accentInk),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('ثبت'),
          style: TextButton.styleFrom(foregroundColor: accentInk),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: t.textMuted,
            ),
      ),
    );
  }
}

// ── Lesson tile ─────────────────────────────────────────────────────

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.accent,
    required this.onTap,
    required this.onDelete,
  });

  final HifzLessonModel lesson;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accentInk = dsContentColor(context, accent);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: accent.withValues(alpha: 0.15),
            child: Icon(Icons.menu_book, size: 18, color: accentInk),
          ),
          title: Text(
            rangeLabel(lesson.surahFrom, lesson.ayahFrom, lesson.surahTo,
                lesson.ayahTo),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${jalaliLabelFa(lesson.date)} · ${en(lesson.pages)} صفحه'
            '${lesson.notes != null && lesson.notes!.isNotEmpty ? ' · ${lesson.notes}' : ''}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _qualityColor(lesson.quality, context)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lesson.quality.label,
                  style: TextStyle(
                    color: _qualityColor(lesson.quality, context),
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onDelete,
                tooltip: 'حذف جلسه',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Review tile ─────────────────────────────────────────────────────

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.review,
    required this.onTap,
    required this.onDelete,
  });

  final HifzReviewModel review;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  Color _qualityColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (review.quality) {
      case ReviewQuality.weak:
        return isDark ? AppTheme.darkError : AppTheme.lightError;
      case ReviewQuality.medium:
        return isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
      case ReviewQuality.excellent:
        return isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    }
  }

  @override
  Widget build(BuildContext context) {
    final qc = _qualityColor(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: qc.withValues(alpha: 0.15),
            child: Icon(
              review.type == ReviewType.sabaq
                  ? Icons.history_edu
                  : Icons.auto_stories,
              size: 18,
              color: qc,
            ),
          ),
          title: Text(
            rangeLabel(review.surahFrom, review.ayahFrom, review.surahTo,
                review.ayahTo),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${jalaliLabelFa(review.date)} · ${en(review.pages)} صفحه'
            '${review.notes != null && review.notes!.isNotEmpty ? ' · ${review.notes}' : ''}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: qc.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  review.quality.label,
                  style: TextStyle(
                    color: qc,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onDelete,
                tooltip: 'حذف مرور',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Day selector ───────────────────────────────────────────────────
// Shows one week (Saturday → Friday) at a time with prev/next week arrows
// and a calendar button to jump to any day of the year. Selecting a day
// filters the حفظ/سبق/مراجعه lists below (days without data stay empty).

class _DaySelector extends StatefulWidget {
  const _DaySelector({
    required this.accent,
    required this.selectedDate,
    required this.onDateChanged,
    required this.lessons,
    required this.reviews,
  });

  final Color accent;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final List<HifzLessonModel> lessons;
  final List<HifzReviewModel> reviews;

  @override
  State<_DaySelector> createState() => _DaySelectorState();
}

class _DaySelectorState extends State<_DaySelector> {
  late DateTime _weekStart; // Saturday of the displayed week

  @override
  void initState() {
    super.initState();
    _weekStart = _saturdayOf(widget.selectedDate);
  }

  @override
  void didUpdateWidget(_DaySelector old) {
    super.didUpdateWidget(old);
    // Snap the displayed week when the selection changes externally
    // (e.g. date picker or hafiz switch) to a week we are not showing.
    final week = _saturdayOf(widget.selectedDate);
    if (week != _weekStart) _weekStart = week;
  }

  static DateTime _saturdayOf(DateTime d) {
    final dow = _jDayOfWeek(d); // 0 = Saturday
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: dow));
  }

  bool _sameDay(DateTime a, DateTime b) {
    final ja = Jalali.fromDateTime(a);
    final jb = Jalali.fromDateTime(b);
    return ja.year == jb.year && ja.month == jb.month && ja.day == jb.day;
  }

  int _countFor(DateTime day) {
    int count = 0;
    for (final l in widget.lessons) {
      if (_sameDay(l.date, day)) count++;
    }
    for (final r in widget.reviews) {
      if (_sameDay(r.date, day)) count++;
    }
    return count;
  }

  Future<void> _pickDate() async {
    final picked = await ShamsiDatePicker.show(
      context,
      initialDate: widget.selectedDate,
    );
    if (picked == null || !mounted) return;
    setState(() => _weekStart = _saturdayOf(picked));
    widget.onDateChanged(picked);
  }

  String _weekLabel() {
    final jStart = Jalali.fromDateTime(_weekStart);
    final jEnd = Jalali.fromDateTime(_weekStart.add(const Duration(days: 6)));
    if (jStart.month == jEnd.month) {
      return '${en(jStart.day)} تا ${en(jEnd.day)} '
          '${_persianMonth(jStart.month)} ${en(jStart.year)}';
    }
    if (jStart.year == jEnd.year) {
      return '${en(jStart.day)} ${_persianMonth(jStart.month)} تا '
          '${en(jEnd.day)} ${_persianMonth(jEnd.month)} ${en(jStart.year)}';
    }
    return '${en(jStart.day)} ${_persianMonth(jStart.month)} ${en(jStart.year)} تا '
        '${en(jEnd.day)} ${_persianMonth(jEnd.month)} ${en(jEnd.year)}';
  }

  String _persianMonth(int m) => DateConstants.persianMonths[m - 1];

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final accentInk = dsContentColor(context, widget.accent);
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_outlined,
                  size: 15, color: Colors.transparent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'انتخاب روز',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: accentInk,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'هفتهٔ قبل',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left, size: 22),
                color: accentInk,
                onPressed: () =>
                    setState(() => _weekStart = _weekStart.calendarDaysAgo(7)),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _weekLabel(),
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 12)),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'هفتهٔ بعد',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right, size: 22),
                color: accentInk,
                onPressed: () => setState(() =>
                    _weekStart = _weekStart.addCalendarDaysFromMidnight(7)),
              ),
              IconButton(
                tooltip: 'انتخاب از تقویم',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.calendar_month_outlined, size: 20),
                color: accentInk,
                onPressed: _pickDate,
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final day = _weekStart.add(Duration(days: i));
                final isSelected = _sameDay(day, widget.selectedDate);
                final isToday = _sameDay(day, today);
                final count = _countFor(day);

                return GestureDetector(
                  onTap: () => widget.onDateChanged(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? widget.accent
                          : widget.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? widget.accent
                            : widget.accent.withValues(alpha: 0.15),
                        width: isToday && !isSelected ? 1.6 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _dayNames[i],
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 10),
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : accentInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          en(Jalali.fromDateTime(day).day),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 14),
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : t.textPrimary,
                          ),
                        ),
                        if (count > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : widget.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              en(count),
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 9),
                                color: isSelected ? Colors.white : accentInk,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
