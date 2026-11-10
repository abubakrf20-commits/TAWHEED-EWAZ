import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/expenses/presentation/widgets/expenses/expenses_common.dart';
import 'package:tawheeed/core/design_system/components/components.dart';

class ExpensesVirtuesScreen extends StatelessWidget {
  final VoidCallback onStart;
  const ExpensesVirtuesScreen({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final virtues = [
      const ExpenseVirtueData(
        icon: Icons.volunteer_activism,
        text: 'انفاق مال را کم نمی‌کند؛ بلکه برکت می‌آورد',
        source: 'پیامبر اکرم ﷺ',
        color: AppTheme.success,
      ),
      const ExpenseVirtueData(
        icon: Icons.balance,
        text: 'قناعت، ثروتی است که هیچ‌کس نمی‌تواند از تو بگیرد',
        color: Color(0xFF26A69A),
      ),
      const ExpenseVirtueData(
        icon: Icons.savings,
        text: 'میانه‌روی در هزینه، نیمی از معیشت است',
        source: 'حکمت',
        color: Color(0xFFE8A817),
      ),
      const ExpenseVirtueData(
        icon: Icons.receipt_long,
        text: 'ثبت مخارج و برنامه‌ریزی، دغدغه مالی را کم می‌کند',
        source: 'مدیریت مالی',
        color: Color(0xFF6A1B9A),
      ),
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: BoxDecoration(
              color: expensesAccent.withValues(alpha: 0.06),
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
                        color: expensesAccent.withValues(alpha: 0.12),
                        border: Border.all(
                            color: expensesAccent.withValues(alpha: 0.35)),
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: expensesAccent,
                      ),
                      child: const Icon(Icons.account_balance_wallet,
                          size: 28, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'هزینه‌ها',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 22),
                      fontWeight: FontWeight.bold,
                      color: t.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'ساماندهی مالی',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: dsContentColor(context, expensesAccent),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'هنوز تراکنشی ثبت نشده',
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
                                        fontSize: AppTheme.scaledFontSize(context, 10),
                                        fontWeight: FontWeight.w700,
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
                                          context, 13.5),
                                      height: 1.5,
                                      color: t.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (v.source != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      v.source!,
                                      style: TextStyle(
                                        fontSize: AppTheme.scaledFontSize(
                                            context, 11),
                                        color: dsContentColor(context, v.color),
                                        fontWeight: FontWeight.w600,
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
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.add, size: 20),
                    label: Text('افزودن اولین تراکنش',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: expensesAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'درآمد و هزینه را ثبت کن تا تصویر روشنی از مال خود داشته باشی',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11),
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

class ExpenseVirtueData {
  final IconData icon;
  final String text;
  final String? source;
  final Color color;
  const ExpenseVirtueData({
    required this.icon,
    required this.text,
    this.source,
    required this.color,
  });
}
