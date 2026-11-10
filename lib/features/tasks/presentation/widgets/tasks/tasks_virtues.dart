import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tasks/presentation/widgets/tasks/tasks_common.dart';
import 'package:tawheeed/core/design_system/components/components.dart';

class TasksVirtuesScreen extends StatelessWidget {
  final VoidCallback onStart;
  const TasksVirtuesScreen({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final virtues = [
      const TaskVirtueData(
        icon: Icons.flag,
        text: 'کارهای مهم را اول انجام بده؛ اولویت‌بندی نصف راه موفقیت است',
        color: Color(0xFFE53935),
      ),
      const TaskVirtueData(
        icon: Icons.widgets,
        text: 'کارهای بزرگ را به قدم‌های کوچک تقسیم کن تا از انجامشان نترسی',
        color: Color(0xFF6A1B9A),
      ),
      const TaskVirtueData(
        icon: Icons.route,
        text: 'برنامه‌ریزی و نظم، گم‌راهی در کارها را از بین می‌برد',
        source: 'اصل مدیریت',
        color: Color(0xFF00695C),
      ),
      const TaskVirtueData(
        icon: Icons.auto_awesome,
        text:
            'ثبات در انجام کارهای کوچک، از تلاش پراکنده در کارهای بزرگ بهتر است',
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
              color: tasksAccent.withValues(alpha: 0.06),
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
                        color: tasksAccent.withValues(alpha: 0.12),
                        border: Border.all(
                            color: tasksAccent.withValues(alpha: 0.35)),
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tasksAccent,
                      ),
                      child: const Icon(Icons.task_alt,
                          size: 28, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'مدیریت کارها',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 22),
                      fontWeight: FontWeight.bold,
                      color: t.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'نظم و برنامه‌ریزی',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: dsContentColor(context, tasksAccent),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'هنوز کاری ثبت نشده',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: t.textSecondary),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final v = virtues[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: v.color, width: 4),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
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
                                      fontSize: AppTheme.scaledFontSize(
                                          context, 14.5),
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
                                        fontSize: AppTheme.scaledFontSize(
                                            context, 12),
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
                  ),
                );
              },
              childCount: virtues.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              children: [
                GradientButton(
                  label: 'افزودن اولین کار',
                  icon: Icons.add,
                  onPressed: onStart,
                ),
                const SizedBox(height: 12),
                Text(
                  'هر روز یک قدم کوچک به سوی اهدافت بردار',
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

class TaskVirtueData {
  final IconData icon;
  final String text;
  final String? source;
  final Color color;

  const TaskVirtueData({
    required this.icon,
    required this.text,
    this.source,
    required this.color,
  });
}

// ══════════════════════════════════════════════════════════════
// HERO — progress card (khatm pattern)
// ══════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
// COMPACT SUMMARY — slim single-row header (progress + today stats)
// ══════════════════════════════════════════════════════════════
