import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/khatm/presentation/providers/khatm_provider.dart';
import 'package:tawheeed/features/khatm/presentation/screens/khatm_stats_screen.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/features/khatm/domain/entities/khatm_status.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/services/widget_sync_service.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/features/khatm/presentation/widgets/khatm/khatm_common.dart';
import 'package:tawheeed/features/khatm/presentation/widgets/khatm/khatm_selector.dart';
import 'package:tawheeed/features/khatm/presentation/widgets/khatm/khatm_virtues.dart';
import 'package:tawheeed/features/khatm/presentation/widgets/khatm/khatm_type_selector.dart';
import 'package:tawheeed/features/khatm/presentation/widgets/khatm/khatm_cards.dart';
import 'package:tawheeed/features/khatm/data/khatm_search_index.dart';

/// The three secondary app-bar actions that moved into an overflow menu so
/// «ختم قرآن» keeps its full width (audit P-05).
enum _KhatmOverflow { stats, share, history }

class KhatmScreen extends ConsumerWidget {
  const KhatmScreen({super.key});

  void _onKhatmOverflow(BuildContext context, KhatmModel? active,
      Khatm notifier, _KhatmOverflow action) {
    switch (action) {
      case _KhatmOverflow.stats:
        if (active == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => KhatmStatsScreen(khatm: active)),
        );
      case _KhatmOverflow.share:
        if (active == null) return;
        _shareKhatm(context, active, notifier);
      case _KhatmOverflow.history:
        unawaited(_showHistory(context, notifier));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final onPrimary = dsOnAccent(context);
    final activeAsync = ref.watch(khatmProvider);
    final allAsync = ref.watch(allKhatmsProvider);
    final active = activeAsync.value;
    final allKhatms = allAsync.value ?? const <KhatmModel>[];
    final notifier = ref.read(khatmProvider.notifier);

    // A pending read is not «no khatm»: the start-new hero used to paint on
    // the first frame (both loads unresolved) and then flip to the active
    // khatm — and after a failed read it stayed, telling the user they had no
    // khatm at all. Wait for both reads to settle, and surface a failure with
    // a retry instead of the hero.
    final settled = (activeAsync.hasValue || activeAsync.hasError) &&
        (allAsync.hasValue || allAsync.hasError);
    if (!settled) {
      return const _KhatmStatusScaffold(
        child: Center(
          child: CircularProgressIndicator(color: TopicHues.khatm),
        ),
      );
    }
    // With a khatm in hand the page can still render even if the full list
    // failed (only the selector is missing); with none, a failure anywhere
    // means «no khatm» cannot be asserted.
    if (active == null && (activeAsync.hasError || allAsync.hasError)) {
      return _KhatmStatusScaffold(
        child: FailureView(
          id: 'khatm_load',
          title: 'خواندن ختم‌ها ممکن نشد',
          detail: 'ختم‌های شما پاک نشده‌اند؛ فقط این صفحه باز نشد.',
          onRetry: () {
            ref.invalidate(khatmProvider);
            ref.invalidate(allKhatmsProvider);
          },
          layout: FailureLayout.page,
          icon: Icons.menu_book_outlined,
        ),
      );
    }

    if (allKhatms.isEmpty && active == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: SectionAppBar(
            title: 'ختم قرآن',
            actions: [
              // Finds a surah and names the juz that carries it — the one
              // lookup this page actually needs, since the grid is numbers
              // and the reader thinks in surah names.
              SectionSearchAction(
                sectionTitle: 'ختم قرآن',
                entries: KhatmSearchIndex.entries(),
              ),
            ],
          ),
          body: KhatmVirtuesScreen(
              onStart: () => _startNewKhatm(context, notifier, ref)),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          title: 'ختم قرآن',
          actions: [
            // Same index as the empty state: whichever khatm is open, the
            // question «این سوره در کدام جزء است؟» has the same answer.
            SectionSearchAction(
              sectionTitle: 'ختم قرآن',
              entries: KhatmSearchIndex.entries(),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'ختم جدید',
              onPressed: () => _startNewKhatm(context, notifier, ref),
            ),
            // Audit P-05: five icon buttons used to squeeze the title down to
            // «ختم ق…» at 320dp / textScale 1.3. Three stay one tap away in
            // the overflow menu; the bar now carries only the two primary
            // actions plus the menu, so the full title always fits.
            PopupMenuButton<_KhatmOverflow>(
              tooltip: 'گزینه‌های بیشتر',
              onSelected: (action) =>
                  _onKhatmOverflow(context, active, notifier, action),
              itemBuilder: (context) => [
                if (active != null)
                  const PopupMenuItem<_KhatmOverflow>(
                    value: _KhatmOverflow.stats,
                    child: Text('گزارش پیشرفت'),
                  ),
                if (active != null)
                  const PopupMenuItem<_KhatmOverflow>(
                    value: _KhatmOverflow.share,
                    child: Text('اشتراک‌گذاری'),
                  ),
                const PopupMenuItem<_KhatmOverflow>(
                  value: _KhatmOverflow.history,
                  child: Text('تاریخچه'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (allKhatms.length > 1)
              KhatmSelector(
                allKhatms: allKhatms,
                selectedId: active?.id,
                onSelect: notifier.selectKhatm,
              ),
            Expanded(
              child: active != null
                  ? KhatmContent(khatm: active)
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: TopicHues.khatm.withValues(alpha: 0.12),
                              border: Border.all(
                                color: TopicHues.khatm.withValues(alpha: 0.30),
                              ),
                            ),
                            child: Icon(Icons.menu_book,
                                size: 44,
                                color:
                                    dsContentColor(context, TopicHues.khatm)),
                          ),
                          const SizedBox(height: 18),
                          Text('ختمی انتخاب نشده',
                              style: TextStyle(
                                  color: t.textPrimary,
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 17),
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                              'از تاریخچه یک ختم انتخاب کنید یا ختم جدید بسازید',
                              style: TextStyle(
                                  color: t.textMuted,
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 12))),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: 200,
                            child: GradientButton(
                              label: 'ختم جدید',
                              icon: Icons.add,
                              onPressed: () =>
                                  _startNewKhatm(context, notifier, ref),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButton: active == null
            ? null
            : InsetFab(
                inset: MediaQuery.paddingOf(context).bottom,
                child: active.isCompleted
                    ? FloatingActionButton.extended(
                        onPressed: () =>
                            _startNewKhatm(context, notifier, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('ختم جدید'),
                        backgroundColor: t.primary,
                        foregroundColor: onPrimary,
                      )
                    : FloatingActionButton.extended(
                        onPressed: () => _addProgress(context, ref, notifier),
                        icon: const Icon(Icons.add),
                        label: const Text('ثبت پیشرفت'),
                        backgroundColor: t.primary,
                        foregroundColor: onPrimary,
                      ),
              ),
      ),
    );
  }

  Future<void> _startNewKhatm(
      BuildContext context, Khatm notifier, WidgetRef ref) async {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController();
    int targetDays = 30;
    bool isGroup = false;
    KhatmType? selectedType;
    final participantControllers = <TextEditingController>[];

    final result = await showDialog<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Row(
            children: [
              const IconChip(icon: Icons.menu_book, color: TopicHues.khatm),
              const SizedBox(width: 10),
              Text('شروع ختم جدید',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  KhatmTypeSelector(
                    selectedType: selectedType,
                    onSelected: (type) {
                      setState(() {
                        selectedType = type;
                        targetDays = type.days == 0 ? 30 : type.days;
                        titleController.text = type.defaultTitle;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                        labelText: 'عنوان ختم', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('ختم گروهی'),
                    value: isGroup,
                    onChanged: (v) => setState(() {
                      isGroup = v;
                      if (v && participantControllers.isEmpty) {
                        participantControllers.add(TextEditingController());
                      }
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (isGroup) ...[
                    const SizedBox(height: 8),
                    ...participantControllers
                        .asMap()
                        .entries
                        .map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: entry.value,
                                      decoration: InputDecoration(
                                        labelText:
                                            'نام شرکت‌کننده ${entry.key + 1}',
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      textInputAction: TextInputAction.next,
                                    ),
                                  ),
                                  if (participantControllers.length > 1)
                                    IconButton(
                                      icon: Icon(Icons.remove_circle,
                                          size: 20,
                                          color: isDark
                                              ? AppTheme.darkError
                                              : AppTheme.lightError),
                                      tooltip: 'حذف شرکت‌کننده',
                                      onPressed: () => setState(() =>
                                          participantControllers
                                              .removeAt(entry.key)),
                                    ),
                                ],
                              ),
                            )),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('افزودن شرکت‌کننده'),
                      onPressed: () => setState(() =>
                          participantControllers.add(TextEditingController())),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('هدف: '),
                      Expanded(
                        child: Slider(
                          value: targetDays.toDouble(),
                          min: 3,
                          max: 365,
                          divisions: 362,
                          activeColor: t.primary,
                          label: '$targetDays روز',
                          onChanged: (v) =>
                              setState(() => targetDays = v.toInt()),
                        ),
                      ),
                      Text('$targetDays روز'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('لغو')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('شروع')),
          ],
        ),
      ),
    );

    if (result == true) {
      if (isGroup && participantControllers.isNotEmpty) {
        final names = participantControllers
            .map((c) => c.text.trim())
            .where((n) => n.isNotEmpty)
            .toList();
        if (names.isEmpty) {
          await notifier.startNew(
              title: titleController.text, targetDays: targetDays);
        } else {
          final juzsPerPerson = (30 / names.length).floor();
          final extra = 30 - juzsPerPerson * names.length;
          final assigned = <int>[];
          for (int i = 0; i < names.length; i++) {
            assigned.add(juzsPerPerson + (i < extra ? 1 : 0));
          }
          await notifier.startNew(
            title: titleController.text,
            targetDays: targetDays,
            participantNames: names,
            participantAssignedJuzs: assigned,
          );
        }
      } else {
        await notifier.startNew(
            title: titleController.text, targetDays: targetDays);
      }
      // Reflect the new/active khatm on the home-screen widget.
      ref.read(widgetSyncServiceProvider).syncWidgetsNow(ref);
    }
    titleController.dispose();
    for (final c in participantControllers) {
      c.dispose();
    }
  }

  Future<void> _addProgress(
      BuildContext context, WidgetRef ref, Khatm notifier) async {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final startController = TextEditingController();
    final endController = TextEditingController();
    final khatm = ref.read(khatmProvider).value;
    final readPages = khatm?.readPages ?? 0;
    final totalPages = khatm?.totalPages ?? 604;
    final pct = totalPages > 0 ? (readPages / totalPages) : 0.0;
    final quickStart = readPages + 1;
    var quickCount = -1;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const IconChip(icon: Icons.menu_book, color: TopicHues.khatm),
              const SizedBox(width: 10),
              Text('ثبت پیشرفت',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: pct,
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          backgroundColor: t.divider,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            khatm?.isCompleted == true
                                ? success
                                : TopicHues.khatm,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${(pct * 100).round()}%',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 20),
                                fontWeight: FontWeight.bold,
                                color: dsContentColor(context, TopicHues.khatm),
                              )),
                          Text('$readPages/$totalPages',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 11),
                                color: t.textMuted,
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('انتخاب سریع:',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            color: t.textSecondary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            QuickChip(
                              label: '1 صفحه',
                              selected: quickCount == 1,
                              onTap: () => setDialogState(() {
                                quickCount = 1;
                                startController.text = '$quickStart';
                                endController.text = '$quickStart';
                              }),
                            ),
                            const SizedBox(width: 6),
                            QuickChip(
                              label: '5 صفحه',
                              selected: quickCount == 5,
                              onTap: () => setDialogState(() {
                                quickCount = 5;
                                startController.text = '$quickStart';
                                endController.text = '${quickStart + 4}';
                              }),
                            ),
                            const SizedBox(width: 6),
                            QuickChip(
                              label: '10 صفحه',
                              selected: quickCount == 10,
                              onTap: () => setDialogState(() {
                                quickCount = 10;
                                startController.text = '$quickStart';
                                endController.text = '${quickStart + 9}';
                              }),
                            ),
                            const SizedBox(width: 6),
                            QuickChip(
                              label: '20 صفحه',
                              selected: quickCount == 20,
                              onTap: () => setDialogState(() {
                                quickCount = 20;
                                startController.text = '$quickStart';
                                endController.text = '${quickStart + 19}';
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startController,
                        decoration: InputDecoration(
                          labelText: 'از صفحه',
                          hintText: '$quickStart',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 13)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child:
                          Icon(Icons.arrow_back, size: 16, color: t.textMuted),
                    ),
                    Expanded(
                      child: TextField(
                        controller: endController,
                        decoration: InputDecoration(
                          labelText: 'تا صفحه',
                          hintText: '$quickStart',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 13)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TopicHues.khatm.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: TopicHues.khatm.withValues(alpha: 0.14)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16,
                          color: dsContentColor(context, TopicHues.khatm)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'صفحات خوانده شده را وارد کنید. هر جزء 20 صفحه است.',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 10),
                              color: t.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('لغو',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check, size: 18),
              label: Text('ثبت',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
              style: FilledButton.styleFrom(
                backgroundColor: t.primary,
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final start = int.tryParse(startController.text.isEmpty
          ? quickStart.toString()
          : NumberFormat.normalizeDigits(startController.text));
      final end = int.tryParse(endController.text.isEmpty
          ? (quickStart).toString()
          : NumberFormat.normalizeDigits(endController.text));
      if (start != null &&
          end != null &&
          start >= 1 &&
          end <= 604 &&
          start <= end) {
        await notifier.markPageRange(start, end);
        // Update «صفحات امروز» on the home-screen widget right away.
        ref.read(widgetSyncServiceProvider).syncWidgetsNow(ref);
        if (context.mounted) {
          AppSnackBar.success(context, '${end - start + 1} صفحه ثبت شد');
        }
      } else {
        if (context.mounted) {
          AppSnackBar.error(
              context, 'لطفاً محدوده معتبری وارد کنید (1 تا 604)');
        }
      }
    }
    startController.dispose();
    endController.dispose();
  }

  void _shareKhatm(BuildContext context, KhatmModel khatm, Khatm notifier) {
    final readPages = khatm.readPages;
    final percent = (khatm.progress * 100).toStringAsFixed(1);
    final remaining = khatm.remainingPages;
    final shareText = khatm.isGroup
        ? 'ختم قرآن گروهی\n'
            'عنوان: ${khatm.title}\n'
            'تعداد شرکت‌کنندگان: ${khatm.participants.length}\n'
            'پیشرفت: $readPages از ${khatm.totalPages} صفحه ($percent%)\n'
            '$remaining صفحه باقی مانده'
        : 'ختم قرآن\n'
            'عنوان: ${khatm.title}\n'
            'پیشرفت: $readPages از ${khatm.totalPages} صفحه ($percent%)\n'
            '$remaining صفحه باقی مانده';
    ShareService.copyText(context, shareText,
        doneMessage: 'متن ختم در کلیپ‌بورد کپی شد');
  }

  Future<void> _showHistory(BuildContext context, Khatm notifier) async {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final error = isDark ? AppTheme.darkError : AppTheme.lightError;
    final history = await notifier.allKhatms;
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const IconChip(icon: Icons.history, color: TopicHues.khatm),
                  const SizedBox(width: 8),
                  Text('تاریخچه ختم‌ها',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 18),
                          fontWeight: FontWeight.w700,
                          fontFamily: AppTheme.fontFamily)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: TopicHues.khatm.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: TopicHues.khatm.withValues(alpha: 0.25)),
                    ),
                    child: Text('${history.length} ختم',
                        style: TextStyle(
                            color: dsContentColor(context, TopicHues.khatm),
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: t.divider),
            Expanded(
              child: history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book,
                              size: 48,
                              color: t.textMuted.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text('هنوز ختمی ثبت نشده',
                              style: TextStyle(
                                  color: t.textMuted,
                                  fontFamily: AppTheme.fontFamily)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      itemCount: history.length,
                      itemBuilder: (ctx, index) {
                        final khatm = history[index];
                        final isActive = !khatm.isCompleted;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: () {
                              Navigator.pop(ctx);
                              notifier.selectKhatm(khatm.id);
                            },
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color:
                                        (isActive ? TopicHues.khatm : success)
                                            .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          (isActive ? TopicHues.khatm : success)
                                              .withValues(alpha: 0.30),
                                    ),
                                  ),
                                  child: Icon(
                                    isActive
                                        ? Icons.pending
                                        : Icons.check_circle,
                                    color: isActive
                                        ? dsContentColor(
                                            context, TopicHues.khatm)
                                        : dsContentColor(context, success),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              khatm.title.isNotEmpty
                                                  ? khatm.title
                                                  : 'ختم قرآن',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize:
                                                    AppTheme.scaledFontSize(
                                                        context, 14),
                                                fontFamily: AppTheme.fontFamily,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          StatusChip(
                                            label: khatm.statusLabelFa,
                                            color: switch (khatm.status) {
                                              KhatmStatus.pending =>
                                                t.textSecondary,
                                              KhatmStatus.active => warning,
                                              KhatmStatus.completed => success,
                                              KhatmStatus.cancelled => error,
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        khatm.isCompleted
                                            ? (khatm.endDate
                                                    ?.toString()
                                                    .split(' ')
                                                    .first ??
                                                '')
                                            : '${khatm.readPages}/${khatm.totalPages} صفحه',
                                        style: TextStyle(
                                          fontSize: AppTheme.scaledFontSize(
                                              context, 11),
                                          color: t.textMuted,
                                          fontFamily: AppTheme.fontFamily,
                                        ),
                                      ),
                                      if (isActive && khatm.readPages > 0) ...[
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(2),
                                          child: LinearProgressIndicator(
                                            value: khatm.progress,
                                            minHeight: 4,
                                            backgroundColor: t.divider,
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                    Color>(
                                              TopicHues.khatm,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.chevron_left, color: t.textMuted),
                                GestureDetector(
                                  onTap: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: ctx,
                                      builder: (dCtx) => AlertDialog(
                                        title: const Text('حذف ختم'),
                                        content: Text(
                                            'آیا از حذف "${khatm.title}" اطمینان دارید؟ این عمل قابل بازگشت نیست.'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dCtx, false),
                                              child: const Text('لغو')),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    Theme.of(dCtx).brightness ==
                                                            Brightness.dark
                                                        ? AppTheme.darkError
                                                        : AppTheme.lightError),
                                            onPressed: () =>
                                                Navigator.pop(dCtx, true),
                                            child: const Text('حذف'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;
                                    if (!context.mounted) return;
                                    Navigator.pop(ctx);
                                    await notifier.delete(khatm.id);
                                    if (context.mounted) {
                                      AppSnackBar.success(context,
                                          'ختم "${khatm.title}" حذف شد');
                                    }
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: error.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.delete_outline,
                                        size: 18,
                                        semanticLabel: 'حذف ختم',
                                        color: error.withValues(alpha: 0.8)),
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
      ),
    );
  }
}

/// Chrome for the two states that are not the khatm itself — «still loading»
/// and «the read failed» — so neither has to borrow the start-new hero.
class _KhatmStatusScaffold extends StatelessWidget {
  const _KhatmStatusScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SectionAppBar(title: 'ختم قرآن'),
        body: child,
      ),
    );
  }
}
