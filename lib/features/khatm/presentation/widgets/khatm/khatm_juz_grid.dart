import 'package:flutter/material.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/khatm/presentation/widgets/khatm/khatm_common.dart';
import 'package:tawheeed/features/khatm/presentation/widgets/khatm/khatm_utils.dart';

class JuzGridWidget extends StatelessWidget {
  final KhatmModel khatm;
  const JuzGridWidget({super.key, required this.khatm});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final completedCount = List.generate(30, (i) => i + 1)
        .where((j) => isJuzCompletedOf(khatm, j))
        .length;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KhatmSectionHeader(
            icon: Icons.grid_view,
            color: TopicHues.khatm,
            title: 'اجزاء قرآن',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: success.withValues(alpha: 0.30)),
              ),
              child: Text(
                '$completedCount از 30 جزء',
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w700,
                  color: dsContentColor(context, success),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'هر جزء 20 صفحه است — با خواندن هر صفحه، کتابِ جزء رنگ می‌گیرد',
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              LegendDot(color: success, label: 'تکمیل شده'),
              const SizedBox(width: 14),
              LegendDot(
                  color: success.withValues(alpha: 0.55),
                  label: 'در حال خواندن'),
              const SizedBox(width: 14),
              LegendDot(color: t.outline, label: 'شروع نشده'),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.88,
            ),
            itemCount: 30,
            itemBuilder: (context, index) {
              final juz = index + 1;
              final progress = juzProgressOf(khatm, juz);
              return JuzBook(
                juz: juz,
                progress: progress,
                completed: progress >= 1.0,
                color: success,
              );
            },
          ),
        ],
      ),
    );
  }
}

class JuzBook extends StatelessWidget {
  final int juz;
  final double progress;
  final bool completed;
  final Color color;
  const JuzBook({
    super.key,
    required this.juz,
    required this.progress,
    required this.completed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final started = !completed && progress > 0;

    // پرکنندهٔ سادهٔ سبز برای کتاب‌های کامل‌شده
    final bottom = Color.lerp(color, Colors.black, dark ? 0.45 : 0.28) ?? color;

    return Container(
      decoration: BoxDecoration(
        color: completed
            ? color
            : started
                ? color.withValues(alpha: 0.08)
                : t.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: completed
              ? bottom
              : started
                  ? color.withValues(alpha: 0.40)
                  : t.outline.withValues(alpha: 0.6),
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              '$juz',
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 11),
                fontWeight: FontWeight.w700,
                color: completed
                    ? Colors.white
                    : started
                        ? dsContentColor(context, color)
                        : t.textSecondary,
              ),
            ),
          ),
          if (completed)
            const Positioned(
              top: 3,
              left: 3,
              child: Icon(Icons.check_circle, size: 11, color: Colors.white),
            ),
          if (started)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(9)),
                child: SizedBox(
                  height: 4,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    alignment: Alignment.centerRight,
                    child: ColoredBox(color: color),
                  ),
                ),
              ),
            ),
          // Page counter for started books.
          if (started)
            Positioned(
              right: 3,
              top: 3,
              child: Text(
                '${(progress * 20).round()}',
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 8),
                  fontWeight: FontWeight.w600,
                  color: dsContentColor(context, color),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
