import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/features/reminders/presentation/providers/reminder_provider.dart';
import 'package:tawheeed/features/reminders/data/models/reminder_model.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';
import 'package:tawheeed/shared/widgets/async_screen.dart';
import 'package:tawheeed/features/reminders/presentation/widgets/reminder/reminder_card.dart';
import 'package:tawheeed/features/reminders/presentation/widgets/reminder/reminder_filter_chip.dart';
import 'package:tawheeed/features/reminders/presentation/utils/reminder_colors.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final onPrimary = dsOnAccent(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'یادآورها'),
      body: const _RemindersBody(),
      // Clears the 3-button system bar (zero on gesture phones, so nothing
      // is added where there is no bar).
      floatingActionButton: InsetFab(
        inset: MediaQuery.paddingOf(context).bottom,
        child: FloatingActionButton.extended(
          onPressed: () => context.push(RouteNames.reminderEditor),
          tooltip: 'یادآور جدید',
          backgroundColor: t.primary,
          foregroundColor: onPrimary,
          icon: const Icon(Icons.add),
          label: Text('یادآور جدید',
              style: TextStyle(fontFamily: AppTheme.fontFamily)),
        ),
      ),
    );
  }
}

class _RemindersBody extends StatefulWidget {
  const _RemindersBody();

  @override
  State<_RemindersBody> createState() => _RemindersBodyState();
}

class _RemindersBodyState extends State<_RemindersBody> {
  /// 0 = همه, 1 = فعال, 2 = غیرفعال, 3 = امروز
  int _filterIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final remindersAsync = ref.watch(reminderProvider);
        // AsyncScreen keeps loading/error distinct from empty: rendering
        // `value ?? []` made a slow or failed query flash the virtues
        // empty state.
        return AsyncScreen<List<ReminderModel>>(
          asyncValue: remindersAsync,
          onRetry: () => ref.invalidate(reminderProvider),
          data: (all) {
            final filtered = _applyFilter(all);
            final enabledCount = all.where((r) => r.isEnabled).length;

            if (all.isEmpty) {
              return _RemindersVirtuesScreen(
                onStart: () => context.push(RouteNames.reminderEditor),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(reminderProvider);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _RemindersSummary(all: all)),
                  SliverToBoxAdapter(child: _buildFilterBar(all, enabledCount)),
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildFilterEmpty(context),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          DsSpacing.page, 4, DsSpacing.page, 100),
                      sliver: SliverList.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => ReminderCard(
                          reminder: filtered[i],
                          onToggle: () => ref
                              .read(reminderProvider.notifier)
                              .toggleEnabled(filtered[i].id),
                          onEdit: () => context.push(
                            RouteNames.reminderEditor,
                            extra: filtered[i],
                          ),
                          onDelete: () => _confirmDelete(context,
                              ref.read(reminderProvider.notifier), filtered[i]),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<ReminderModel> _applyFilter(List<ReminderModel> all) {
    switch (_filterIndex) {
      case 1:
        return all.where((r) => r.isEnabled).toList();
      case 2:
        return all.where((r) => !r.isEnabled).toList();
      case 3:
        return all.where((r) => r.isEnabled && r.matchesToday()).toList();
      default:
        return all;
    }
  }

  Widget _buildFilterBar(List<ReminderModel> all, int enabledCount) {
    final enabled = enabledCount;
    final disabled = all.length - enabled;
    final today = all.where((r) => r.isEnabled && r.matchesToday()).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 4),
      child: Row(
        children: [
          ReminderFilterChip(
            label: 'همه (${all.length})',
            isSelected: _filterIndex == 0,
            onTap: () => setState(() => _filterIndex = 0),
          ),
          const SizedBox(width: 8),
          ReminderFilterChip(
            label: 'فعال ($enabled)',
            isSelected: _filterIndex == 1,
            onTap: () => setState(() => _filterIndex = 1),
          ),
          const SizedBox(width: 8),
          ReminderFilterChip(
            label: 'غیرفعال ($disabled)',
            isSelected: _filterIndex == 2,
            onTap: () => setState(() => _filterIndex = 2),
          ),
          const SizedBox(width: 8),
          ReminderFilterChip(
            label: 'امروز ($today)',
            isSelected: _filterIndex == 3,
            onTap: () => setState(() => _filterIndex = 3),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, Reminder notifier, ReminderModel reminder) {
    final messenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف یادآور'),
        content: Text('«${reminder.title}» حذف شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  isDark ? AppTheme.darkError : AppTheme.lightError,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await notifier.deleteReminder(reminder.id);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: const Text('یادآور حذف شد'),
                  duration: const Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'بازگردانی',
                    onPressed: notifier.undoLastDelete,
                  ),
                ));
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterEmpty(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.filter_list_off,
      message: 'یادآوری در این دسته وجود ندارد',
      subtitle: 'فیلتر دیگری را انتخاب کنید',
      accent: ReminderColors.accent,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// EMPTY STATE — virtues screen (khatm/tasks pattern)
// ══════════════════════════════════════════════════════════════
class _RemindersVirtuesScreen extends StatelessWidget {
  final VoidCallback onStart;
  const _RemindersVirtuesScreen({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = ReminderColors.accent;
    const virtues = [
      _VirtueData(
        icon: Icons.notifications_active,
        text:
            'یادآوریِ به‌موقع، کارها را از گم‌شدن نجات می‌دهد و نظم را پایدار می‌کند',
        color: Color(0xFFE64A19),
      ),
      _VirtueData(
        icon: Icons.schedule,
        text:
            'وقت از دست‌رفته برنمی‌گردد؛ یادآور، سرمایهٔ وقت تو را محافظت می‌کند',
        color: Color(0xFFF9A825),
      ),
      _VirtueData(
        icon: Icons.wb_twilight,
        text:
            'نماز اول وقت با یادآوریِ اذان، آرامش دل و برکت روز را تضمین می‌کند',
        source: 'توصیهٔ اهل‌دل',
        color: Color(0xFF00695C),
      ),
      _VirtueData(
        icon: Icons.auto_awesome,
        text:
            'ادبِ بندگی، حفظِ وقتِ نماز و اذکار است؛ و یادآور، یاورِ این ادب است',
        color: AppTheme.error,
      ),
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.12),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.35)),
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                      child: const Icon(Icons.alarm,
                          size: 28, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'یادآورها',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 22),
                      fontWeight: FontWeight.bold,
                      color: t.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'نظم در عبادت و زندگی',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: dsContentColor(context, accent),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'هنوز یادآوری تنظیم نکرده‌اید',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: t.textSecondary),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding:
              const EdgeInsets.fromLTRB(DsSpacing.page, 8, DsSpacing.page, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final v = virtues[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.card,
                        border: Border(
                          right: BorderSide(color: v.color, width: 4),
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: v.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: v.color.withValues(alpha: 0.30)),
                                ),
                                child: Icon(v.icon, color: v.color, size: 24),
                              ),
                              Positioned(
                                top: -2,
                                left: -2,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: v.color,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize:
                                          AppTheme.scaledFontSize(context, 9),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.text,
                                  style: TextStyle(
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 14.5),
                                    fontWeight: FontWeight.w600,
                                    height: 1.6,
                                    color: t.textPrimary,
                                  ),
                                ),
                                if (v.source != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    v.source!,
                                    style: TextStyle(
                                      fontSize:
                                          AppTheme.scaledFontSize(context, 12),
                                      color: t.textMuted,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: virtues.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                DsSpacing.page, 8, DsSpacing.page, 32),
            child: Column(
              children: [
                _GradientButton(
                  label: 'افزودن اولین یادآور',
                  icon: Icons.add_alarm,
                  onPressed: onStart,
                ),
                const SizedBox(height: 12),
                Text(
                  'نماز، دارو، قرارها — هیچ چیز مهمی را از یاد نبر',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VirtueData {
  final IconData icon;
  final String text;
  final String? source;
  final Color color;
  const _VirtueData({
    required this.icon,
    required this.text,
    this.source,
    required this.color,
  });
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const accent = ReminderColors.accent;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 14.5),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// COMPACT SUMMARY — slim single-row header (enabled count + next)
// ══════════════════════════════════════════════════════════════
class _RemindersSummary extends StatelessWidget {
  final List<ReminderModel> all;
  const _RemindersSummary({required this.all});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = ReminderColors.accent;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;

    final total = all.length;
    final enabled = all.where((r) => r.isEnabled).length;
    final disabled = total - enabled;
    final pct = total == 0 ? 0 : (enabled * 100 / total).round();
    final progress = total == 0 ? 0.0 : (enabled / total);

    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final todayEnabled = all
        .where((r) => r.isEnabled && r.matchesToday())
        .toList()
      ..sort((a, b) => a.totalMinutes.compareTo(b.totalMinutes));

    ReminderModel? next;
    for (final r in todayEnabled) {
      if (r.totalMinutes >= nowMin) {
        next = r;
        break;
      }
    }
    final allPassed = todayEnabled.isNotEmpty && next == null;
    final noReminderToday = todayEnabled.isEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(DsSpacing.page, 8, DsSpacing.page, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: const Icon(Icons.alarm, size: 15, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'پیشرفت یادآورها',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: dsContentColor(context, accent),
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
              backgroundColor: t.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? success : accent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ReminderInlineStat(
                icon: Icons.today,
                label: 'امروز',
                value: '${todayEnabled.length}',
                color: warning,
              ),
              _ReminderInlineStat(
                icon: Icons.check_circle_outline,
                label: 'فعال',
                value: '$enabled',
                color: success,
              ),
              _ReminderInlineStat(
                icon: Icons.cancel_outlined,
                label: 'غیرفعال',
                value: '$disabled',
                color: danger,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                noReminderToday
                    ? Icons.notifications_off
                    : (allPassed
                        ? Icons.check_circle
                        : Icons.notifications_active),
                size: 13,
                color: noReminderToday
                    ? t.textMuted
                    : (allPassed ? success : accent),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  noReminderToday
                      ? 'امروز یادآوری فعالی ندارید'
                      : (allPassed
                          ? 'یادآورهای امروز تمام شد 🎉'
                          : 'یادآور بعدی: ${next!.title}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w600,
                    color: t.textSecondary,
                  ),
                ),
              ),
              if (!allPassed && !noReminderToday) ...[
                const SizedBox(width: 6),
                Text(
                  next!.timeString,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w800,
                    color: dsContentColor(context, accent),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ReminderInlineStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _ReminderInlineStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 9.5),
                color: t.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12.5),
              fontWeight: FontWeight.w800,
              color: dsContentColor(context, color),
            ),
          ),
        ],
      ),
    );
  }
}
