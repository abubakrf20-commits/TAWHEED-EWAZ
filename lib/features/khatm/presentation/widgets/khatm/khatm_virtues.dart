import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/khatm/presentation/widgets/khatm/khatm_common.dart';

class KhatmVirtuesScreen extends StatelessWidget {
  final VoidCallback onStart;
  const KhatmVirtuesScreen({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final virtues = [
      const KhatmVirtueData(
        icon: Icons.shield,
        text: 'قرآن شفاعت‌کننده در روز قیامت خواهد بود',
        color: Color(0xFF1565C0),
      ),
      const KhatmVirtueData(
        icon: Icons.auto_awesome,
        text: 'هر حرفی از قرآن یک ثواب دارد و هر ثوابی ده برابر می‌شود',
        source: 'حدیث شریف',
        color: Color(0xFF6A1B9A),
      ),
      const KhatmVirtueData(
        icon: Icons.home,
        text: 'قرآن در خانه‌ای که خوانده شود، برکت می‌یابد',
        color: Color(0xFF00695C),
      ),
      const KhatmVirtueData(
        icon: Icons.light_mode,
        text: 'با ختم قرآن، نور و روشنایی در قلب و خانه ایجاد می‌شود',
        color: AppTheme.error,
      ),
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
            decoration: BoxDecoration(
              color: TopicHues.khatm.withValues(alpha: 0.06),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TopicHues.khatm.withValues(alpha: 0.12),
                        border: Border.all(
                            color: TopicHues.khatm.withValues(alpha: 0.35)),
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: TopicHues.khatm,
                      ),
                      child: const Icon(Icons.menu_book,
                          size: 40, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'ختم قرآن',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 28),
                      fontWeight: FontWeight.bold,
                      color: t.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'فضائل و اهداف',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 15),
                    color: dsContentColor(context, TopicHues.khatm),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'قرآن کریم کتاب هدایت و سعادت است',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      color: t.textSecondary),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: TopicHues.khatm.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: TopicHues.khatm.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      color: dsContentColor(context, TopicHues.khatm),
                    ),
                  ),
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
                GradientButton(
                  label: 'شروع ختم جدید',
                  icon: Icons.add,
                  onPressed: onStart,
                ),
                const SizedBox(height: 12),
                Text(
                  'با نیت خالص شروع کنید و هر روز چند صفحه بخوانید',
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

class KhatmVirtueData {
  final IconData icon;
  final String text;
  final String? source;
  final Color color;

  const KhatmVirtueData({
    required this.icon,
    required this.text,
    this.source,
    required this.color,
  });
}
