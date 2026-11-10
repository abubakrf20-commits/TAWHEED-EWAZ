import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/books/presentation/providers/reading_plan_provider.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

class StudyTodayProgressCard extends StatelessWidget {
  final ReadingPlanState state;
  final ReadingPlan? notifier;
  const StudyTodayProgressCard({super.key, required this.state, this.notifier});

  String _jalaliDate() {
    final now = DateTime.now();
    final jalali = Jalali.fromDateTime(now);
    final months = DateConstants.persianMonths;
    final days = [
      'شنبه',
      'یکشنبه',
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنجشنبه',
      'جمعه'
    ];
    return '${days[jalali.weekDay - 1]}، ${jalali.day} ${months[jalali.month - 1]} ${jalali.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final activeBooks = state.books.where((b) => !b.isCompleted).toList();
    final totalDailyTarget =
        activeBooks.fold<int>(0, (sum, b) => sum + b.dailyTarget);
    final effectiveTarget =
        totalDailyTarget > 0 ? totalDailyTarget : state.dailyTarget;
    final progress = effectiveTarget > 0
        ? (state.pagesReadToday / effectiveTarget).clamp(0.0, 1.0)
        : 0.0;
    const accent = TopicHues.study;
    final completedCount = state.books.where((b) => b.isCompleted).length;
    final isComplete = progress >= 1.0 && effectiveTarget > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark
            ? t.card
            : isComplete
                ? AppTheme.successBg
                : accent.withValues(alpha: 0.10),
        border: Border.all(
          color: isComplete
              ? success.withValues(alpha: 0.3)
              : accent.withValues(alpha: isDark ? 0.3 : 0.25),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child:
                    const Icon(Icons.calendar_today, size: 13, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _jalaliDate(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 10.5),
                      color: accent,
                      fontWeight: FontWeight.w500),
                ),
              ),
              if (state.pagesReadToday > 0 && notifier != null)
                GestureDetector(
                  onTap: () => _confirmResetToday(context, notifier!),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh, size: 11, color: accent),
                        const SizedBox(width: 4),
                        Text('بازنشانی',
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 10),
                                color: accent)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isComplete
                          ? 'به هدف روزانه رسیدی!'
                          : activeBooks.isNotEmpty
                              ? '${effectiveTarget - state.pagesReadToday} صفحه باقی‌مانده'
                              : 'همه کتاب‌ها تمام شدند',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w600,
                        color: isComplete
                            ? success
                            : t.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${state.pagesReadToday}',
                            style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 22),
                              fontWeight: FontWeight.w900,
                              color: isComplete
                                  ? success
                                  : accent,
                              height: 1,
                            ),
                          ),
                          TextSpan(
                            text: ' از $effectiveTarget صفحه',
                            style: TextStyle(
                                fontSize:
                                    AppTheme.scaledFontSize(context, 11.5),
                                color: t.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isComplete ? success : accent)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: (isComplete ? success : accent)
                          .withValues(alpha: 0.28)),
                ),
                child: Text(
                  '${(progress * 100).round()}٪',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w900,
                    color: isComplete ? success : accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: accent.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                  isComplete ? success : accent),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _miniStat(context, Icons.menu_book, '${activeBooks.length}',
                  'کتاب فعال', accent),
              const SizedBox(width: 8),
              _miniStat(context, Icons.trending_up, '${state.pagesReadToday}',
                  'صفحه امروز', accent),
              if (completedCount > 0) ...[
                const SizedBox(width: 8),
                _miniStat(context, Icons.emoji_events, '$completedCount',
                    'تکمیل شده', accent),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, IconData icon, String value,
      String label, Color accent) {
    final t = TimeThemeKit.of(context).palette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: t.card.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    color: t.textPrimary)),
            Text(label,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 9),
                    color: t.textMuted)),
          ],
        ),
      ),
    );
  }

  void _confirmResetToday(BuildContext context, ReadingPlan notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازنشانی صفحات امروز'),
        content:
            const Text('آیا از بازنشانی صفحات خوانده شده امروز اطمینان دارید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.resetToday();
            },
            child: const Text('بازنشانی'),
          ),
        ],
      ),
    );
  }
}

class StudyBooksSection extends StatelessWidget {
  final ReadingPlanState state;
  final ReadingPlan notifier;
  const StudyBooksSection(
      {super.key, required this.state, required this.notifier});

  List<StudyBook> get _activeBooks =>
      state.books.where((b) => !b.isCompleted).toList();
  List<StudyBook> get _completedBooks =>
      state.books.where((b) => b.isCompleted).toList()
        ..sort((a, b) => (b.completedAt ?? DateTime(2000))
            .compareTo(a.completedAt ?? DateTime(2000)));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    const accent = TopicHues.study;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.2))),
              child: const Icon(Icons.auto_stories, size: 14, color: accent),
            ),
            const SizedBox(width: 8),
            Text('کتاب‌های من',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'افزودن کتاب',
                onPressed: () => _showAddBookSheet(context, notifier, state),
                color: accent,
                splashRadius: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_activeBooks.isEmpty && _completedBooks.isEmpty)
          StudyEmptyState(notifier: notifier, state: state)
        else ...[
          ..._activeBooks.asMap().entries.map((entry) => StudyBookCard(
                key: ValueKey(entry.value.id),
                book: entry.value,
                notifier: notifier,
                state: state,
                index: entry.key,
              )),
          if (_completedBooks.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            success.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.checklist,
                      size: 14, color: success),
                ),
                const SizedBox(width: 8),
                Text('کتاب‌های خوانده شده',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 12.5),
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_completedBooks.length}',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w700,
                        color: success),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._completedBooks.map((book) =>
                StudyCompletedBookCard(book: book, notifier: notifier)),
          ],
        ],
      ],
    );
  }

  void _showAddBookSheet(
      BuildContext context, ReadingPlan notifier, ReadingPlanState state) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final currentCtrl = TextEditingController();
    final totalPagesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: TimeThemeKit.of(ctx).palette.divider,
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                Text('افزودن کتاب جدید',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'نام کتاب',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)))),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: totalPagesCtrl,
                  decoration: const InputDecoration(
                      labelText: 'تعداد کل صفحات',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)))),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  decoration: const InputDecoration(
                      labelText: 'هدف روزانه (صفحه)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)))),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: currentCtrl,
                  decoration: const InputDecoration(
                      labelText: 'صفحه فعلی',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)))),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final currentPage = int.tryParse(
                              NumberFormat.normalizeDigits(currentCtrl.text)) ??
                          0;
                      final totalPages = int.tryParse(
                              NumberFormat.normalizeDigits(
                                  totalPagesCtrl.text)) ??
                          0;
                      final dailyTarget = int.tryParse(
                              NumberFormat.normalizeDigits(targetCtrl.text)) ??
                          0;
                      Navigator.pop(ctx);
                      notifier.addBook(name,
                          dailyTarget: dailyTarget,
                          totalPages: totalPages,
                          currentPage: currentPage);
                    },
                    child: Text('افزودن کتاب',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 15))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      nameCtrl.dispose();
      targetCtrl.dispose();
      currentCtrl.dispose();
      totalPagesCtrl.dispose();
    });
  }
}

// ═══════════════════════════════════════════════════════════════
// STUDY BOOK CARD — redesigned with circular mini-progress,
// gradient side bar, and prominent log button
// ═══════════════════════════════════════════════════════════════

class StudyBookCard extends StatelessWidget {
  final StudyBook book;
  final ReadingPlan notifier;
  final ReadingPlanState state;
  final int index;
  const StudyBookCard(
      {super.key,
      required this.book,
      required this.notifier,
      required this.state,
      required this.index});

  Color _themeColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final gold = isDark ? t.primary : t.tertiary;
    if (book.progress >= 1.0) return success;
    return book.progress > 0.6 ? gold : gold.withValues(alpha: 0.7);
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final themeColor = _themeColor(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.outline.withValues(alpha: 0.5)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Gradient side bar
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: themeColor,
                  borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(18),
                      bottomRight: Radius.circular(18)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row with mini progress ring
                      Row(
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: book.progress,
                                  strokeWidth: 3,
                                  backgroundColor:
                                      themeColor.withValues(alpha: 0.12),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(themeColor),
                                  strokeCap: StrokeCap.round,
                                ),
                                Text(
                                  '${(book.progress * 100).round()}',
                                  style: TextStyle(
                                      fontSize:
                                          AppTheme.scaledFontSize(context, 8),
                                      fontWeight: FontWeight.w800,
                                      color: themeColor),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              book.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 14),
                                  color: t.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          StudyBookMenuButton(book: book, notifier: notifier),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Info chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _chip(
                              context,
                              Icons.pageview_outlined,
                              '${book.currentPage}${book.totalPages > 0 ? '/${book.totalPages}' : ''}',
                              themeColor),
                          _chip(context, Icons.speed_outlined,
                              'روزانه ${book.dailyTarget}', themeColor),
                          if (book.partInfo.isNotEmpty)
                            _chip(context, Icons.auto_stories, book.partInfo,
                                themeColor),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Progress bar
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: book.progress,
                                minHeight: 6,
                                backgroundColor:
                                    themeColor.withValues(alpha: 0.1),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(themeColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${book.currentPage}',
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w600,
                                color: t.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Log button
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: themeColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () =>
                                    _showLogPagesSheet(context, book, notifier),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.add,
                                          size: 14, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text('ثبت صفحه',
                                          style: TextStyle(
                                              fontSize: AppTheme.scaledFontSize(
                                                  context, 11),
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'صفحه ${book.currentPage}',
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 11),
                                color: t.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 10),
                  fontWeight: FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }

  void _showLogPagesSheet(
      BuildContext context, StudyBook book, ReadingPlan notifier) {
    final t = TimeThemeKit.of(context).palette;
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: TimeThemeKit.of(ctx).palette.divider,
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.post_add, size: 22, color: _themeColor(context)),
                    const SizedBox(width: 8),
                    Text('ثبت صفحات',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(book.name,
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        color: t.textMuted)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: _themeColor(context).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(Icons.pageview,
                          size: 16, color: _themeColor(context)),
                      const SizedBox(width: 8),
                      Text('صفحه فعلی: ',
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              color: t.textSecondary)),
                      Text('${book.currentPage}',
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              fontWeight: FontWeight.w700,
                              color: _themeColor(context))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: 'تعداد صفحات (منفی برای اصلاح)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: () {
                      final v =
                          int.tryParse(NumberFormat.normalizeDigits(ctrl.text));
                      if (v != null && v != 0) {
                        Navigator.pop(ctx);
                        notifier.logPages(book.id, v);
                      }
                    },
                    child: Text('ثبت',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 15))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => ctrl.dispose());
  }
}

// ═══════════════════════════════════════════════════════════════
// MENU BUTTON — edit / reset / delete per book
// ═══════════════════════════════════════════════════════════════

class StudyBookMenuButton extends StatelessWidget {
  final StudyBook book;
  final ReadingPlan notifier;
  const StudyBookMenuButton(
      {super.key, required this.book, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'edit') _showEditSheet(context, book, notifier);
        if (v == 'delete') notifier.removeBook(book.id);
        if (v == 'reset') notifier.logPages(book.id, -book.currentPage);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'edit',
            child: ListTile(
                leading: Icon(Icons.edit_outlined, size: 20),
                title: Text('ویرایش'),
                dense: true,
                contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(
            value: 'reset',
            child: ListTile(
                leading: Icon(Icons.refresh, size: 20),
                title: Text('بازنشانی'),
                dense: true,
                contentPadding: EdgeInsets.zero)),
        PopupMenuItem(
            value: 'delete',
            child: ListTile(
                leading: Icon(Icons.delete_outline,
                    size: 20, color: danger),
                title: Text('حذف', style: TextStyle(color: danger)),
                dense: true,
                contentPadding: EdgeInsets.zero)),
      ],
      icon:
          Icon(Icons.more_horiz, size: 20, color: t.textMuted),
      splashRadius: 20,
    );
  }

  void _showEditSheet(
      BuildContext context, StudyBook book, ReadingPlan notifier) {
    final nameCtrl = TextEditingController(text: book.name);
    final targetCtrl = TextEditingController(text: book.dailyTarget.toString());
    final pagesCtrl = TextEditingController(
        text: book.totalPages > 0 ? book.totalPages.toString() : '');
    final currentPageCtrl =
        TextEditingController(text: book.currentPage.toString());
    final partCtrl = TextEditingController(text: book.partInfo);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: TimeThemeKit.of(ctx).palette.divider,
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                Text('ویرایش ${book.name}',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'نام کتاب',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)))),
                    textDirection: TextDirection.rtl),
                const SizedBox(height: 12),
                TextField(
                    controller: targetCtrl,
                    decoration: const InputDecoration(
                        labelText: 'هدف روزانه',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)))),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(
                    controller: pagesCtrl,
                    decoration: const InputDecoration(
                        labelText: 'تعداد کل صفحات',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)))),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(
                    controller: currentPageCtrl,
                    decoration: const InputDecoration(
                        labelText: 'صفحه فعلی',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)))),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(
                    controller: partCtrl,
                    decoration: const InputDecoration(
                        labelText: 'جزء / جلد / بخش',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)))),
                    textDirection: TextDirection.rtl),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: () {
                      Navigator.pop(ctx);
                      notifier.updateBook(
                        book.id,
                        name: nameCtrl.text,
                        dailyTarget: int.tryParse(NumberFormat.normalizeDigits(
                                targetCtrl.text)) ??
                            book.dailyTarget,
                        totalPages: int.tryParse(
                                NumberFormat.normalizeDigits(pagesCtrl.text)) ??
                            0,
                        partInfo: partCtrl.text,
                        currentPage: int.tryParse(
                            NumberFormat.normalizeDigits(currentPageCtrl.text)),
                      );
                    },
                    child: Text('ذخیره',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 15))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      nameCtrl.dispose();
      targetCtrl.dispose();
      pagesCtrl.dispose();
      currentPageCtrl.dispose();
      partCtrl.dispose();
    });
  }
}

// ═══════════════════════════════════════════════════════════════
// COMPLETED BOOK CARD — trophy / achievement style with edit/notes/delete
// ═══════════════════════════════════════════════════════════════

class StudyCompletedBookCard extends StatelessWidget {
  final StudyBook book;
  final ReadingPlan notifier;
  const StudyCompletedBookCard(
      {super.key, required this.book, required this.notifier});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final j = Jalali.fromDateTime(dt);
    final months = DateConstants.persianMonths;
    return '${j.day} ${months[j.month - 1]} ${j.year}';
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const trophyColor = Color(0xFFFFB300);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: trophyColor.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: trophyColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    size: 22, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: AppTheme.scaledFontSize(context, 14),
                            color: t.textPrimary)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.pageview,
                            size: 11, color: t.textSecondary),
                        const SizedBox(width: 3),
                        Text('${book.totalPages} صفحه',
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 11),
                                color: t.textSecondary)),
                        const SizedBox(width: 10),
                        Icon(Icons.calendar_today,
                            size: 11, color: t.textSecondary),
                        const SizedBox(width: 3),
                        Text(_formatDate(book.completedAt),
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 11),
                                color: t.textSecondary)),
                      ],
                    ),
                    if (book.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.notes,
                              size: 11,
                              color: t.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(book.notes,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 10),
                                    color: t.textMuted)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              StudyCompletedMenuButton(book: book, notifier: notifier),
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: trophyColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('تکمیل شد',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 10),
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COMPLETED MENU BUTTON — edit / notes / delete
// ═══════════════════════════════════════════════════════════════

class StudyCompletedMenuButton extends StatelessWidget {
  final StudyBook book;
  final ReadingPlan notifier;
  const StudyCompletedMenuButton(
      {super.key, required this.book, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'edit') _showEditSheet(context, book, notifier);
        if (v == 'notes') _showNotesSheet(context, book, notifier);
        if (v == 'delete') _confirmDelete(context, book, notifier);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'edit',
            child: ListTile(
                leading: Icon(Icons.edit_outlined, size: 20),
                title: Text('ویرایش'),
                dense: true,
                contentPadding: EdgeInsets.zero)),
        PopupMenuItem(
            value: 'notes',
            child: ListTile(
              leading: Icon(Icons.notes,
                  size: 20,
                  color: book.notes.isEmpty ? null : const Color(0xFF7C4DFF)),
              title: Text(book.notes.isEmpty ? 'افزودن یادداشت' : 'یادداشت'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            )),
        PopupMenuItem(
            value: 'delete',
            child: ListTile(
                leading: Icon(Icons.delete_outline,
                    size: 20, color: danger),
                title: Text('حذف', style: TextStyle(color: danger)),
                dense: true,
                contentPadding: EdgeInsets.zero)),
      ],
      icon:
          Icon(Icons.more_horiz, size: 20, color: t.textMuted),
      splashRadius: 20,
    );
  }

  void _confirmDelete(
      BuildContext context, StudyBook book, ReadingPlan notifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف کتاب'),
        content: Text('آیا از حذف "${book.name}" اطمینان دارید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: danger),
            onPressed: () {
              Navigator.pop(ctx);
              notifier.removeBook(book.id);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(
      BuildContext context, StudyBook book, ReadingPlan notifier) {
    final nameCtrl = TextEditingController(text: book.name);
    final targetCtrl = TextEditingController(text: book.dailyTarget.toString());
    final pagesCtrl = TextEditingController(
        text: book.totalPages > 0 ? book.totalPages.toString() : '');
    final currentPageCtrl =
        TextEditingController(text: book.currentPage.toString());
    final partCtrl = TextEditingController(text: book.partInfo);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: TimeThemeKit.of(ctx).palette.divider,
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                Text('ویرایش ${book.name}',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'نام کتاب',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)))),
                    textDirection: TextDirection.rtl),
                const SizedBox(height: 12),
                TextField(
                    controller: targetCtrl,
                    decoration: const InputDecoration(
                        labelText: 'هدف روزانه',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)))),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(
                    controller: pagesCtrl,
                    decoration: const InputDecoration(
                        labelText: 'تعداد کل صفحات',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)))),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(
                    controller: currentPageCtrl,
                    decoration: const InputDecoration(
                        labelText: 'صفحه فعلی',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)))),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(
                    controller: partCtrl,
                    decoration: const InputDecoration(
                        labelText: 'جزء / جلد / بخش',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)))),
                    textDirection: TextDirection.rtl),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: () {
                      Navigator.pop(ctx);
                      notifier.updateBook(
                        book.id,
                        name: nameCtrl.text,
                        dailyTarget: int.tryParse(NumberFormat.normalizeDigits(
                                targetCtrl.text)) ??
                            book.dailyTarget,
                        totalPages: int.tryParse(
                                NumberFormat.normalizeDigits(pagesCtrl.text)) ??
                            0,
                        partInfo: partCtrl.text,
                        currentPage: int.tryParse(
                            NumberFormat.normalizeDigits(currentPageCtrl.text)),
                      );
                    },
                    child: Text('ذخیره',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 15))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      nameCtrl.dispose();
      targetCtrl.dispose();
      pagesCtrl.dispose();
      currentPageCtrl.dispose();
      partCtrl.dispose();
    });
  }

  void _showNotesSheet(
      BuildContext context, StudyBook book, ReadingPlan notifier) {
    final notesCtrl = TextEditingController(text: book.notes);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: TimeThemeKit.of(ctx).palette.divider,
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.notes, size: 22, color: Color(0xFFFFB300)),
                    const SizedBox(width: 8),
                    Text('یادداشت — ${book.name}',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    hintText: 'یادداشت‌های خود را وارد کنید...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  maxLines: 5,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: () {
                      Navigator.pop(ctx);
                      notifier.updateBookNotes(book.id, notesCtrl.text.trim());
                    },
                    child: Text('ذخیره یادداشت',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 15))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => notesCtrl.dispose());
  }
}

// ═══════════════════════════════════════════════════════════════
// EMPTY STATE — creative visual
// ═══════════════════════════════════════════════════════════════

class StudyEmptyState extends StatelessWidget {
  final ReadingPlan notifier;
  final ReadingPlanState state;
  const StudyEmptyState(
      {super.key, required this.notifier, required this.state});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = TopicHues.study;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Layered circles illustration
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(38),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(Icons.auto_stories_outlined,
                    size: 32, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('هنوز کتابی اضافه نشده',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: t.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'با افزودن کتاب، پیشرفت مطالعه خود را\nروزانه پیگیری کن',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: t.textMuted,
                height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _showAddBookSheet(context, notifier, state),
            icon: const Icon(Icons.add, size: 18),
            label: Text('افزودن اولین کتاب',
                style:
                    TextStyle(fontSize: AppTheme.scaledFontSize(context, 14))),
          ),
        ],
      ),
    );
  }

  void _showAddBookSheet(
      BuildContext context, ReadingPlan notifier, ReadingPlanState state) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final currentCtrl = TextEditingController();
    final totalPagesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: TimeThemeKit.of(ctx).palette.divider,
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('افزودن کتاب جدید',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'نام کتاب',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)))),
                    textDirection: TextDirection.rtl),
                const SizedBox(height: 12),
                TextField(
                    controller: totalPagesCtrl,
                    decoration: const InputDecoration(
                        labelText: 'تعداد کل صفحات',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)))),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(
                    controller: targetCtrl,
                    decoration: const InputDecoration(
                        labelText: 'هدف روزانه (صفحه)',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)))),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(
                    controller: currentCtrl,
                    decoration: const InputDecoration(
                        labelText: 'صفحه فعلی',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)))),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final currentPage = int.tryParse(
                              NumberFormat.normalizeDigits(currentCtrl.text)) ??
                          0;
                      final totalPages = int.tryParse(
                              NumberFormat.normalizeDigits(
                                  totalPagesCtrl.text)) ??
                          0;
                      final dailyTarget = int.tryParse(
                              NumberFormat.normalizeDigits(targetCtrl.text)) ??
                          0;
                      Navigator.pop(ctx);
                      notifier.addBook(name,
                          dailyTarget: dailyTarget,
                          totalPages: totalPages,
                          currentPage: currentPage);
                    },
                    child: Text('افزودن کتاب',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 15))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      nameCtrl.dispose();
      targetCtrl.dispose();
      currentCtrl.dispose();
      totalPagesCtrl.dispose();
    });
  }
}
