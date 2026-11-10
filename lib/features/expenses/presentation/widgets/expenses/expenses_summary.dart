import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart'
    show dsContentColor;
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/expenses/presentation/widgets/expenses/expenses_common.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

class ExpensesSummary extends StatelessWidget {
  final double balance;
  final double income;
  final double expense;
  final double monthIncome;
  final double monthExpense;

  /// واحد پول دفتر هزینه‌ها — همان واحدی که کاربر تراکنش‌ها را با آن ثبت
  /// کرده است، نه واحد حسابگرهای زکات/میراث.
  final String unit;

  const ExpensesSummary({
    super.key,
    required this.balance,
    required this.income,
    required this.expense,
    required this.monthIncome,
    required this.monthExpense,
    this.unit = 'تومان',
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final negative = balance < 0;
    final accent = negative ? expenseColor : expensesAccent;
    final monthBalance = monthIncome - monthExpense;
    final monthBalanceColor = monthBalance < 0
        ? expenseColor
        : (monthBalance == 0 ? expensesAccent : incomeColor);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                child:
                    Icon(Icons.account_balance_wallet, size: 15, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'مانده کل',
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
                  negative ? 'بدهی' : 'موجودی',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: dsContentColor(context, accent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              NumberFormat.formatMoney(balance, unit),
              maxLines: 1,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 22),
                fontWeight: FontWeight.w800,
                color: t.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: HeroMiniStat(
                  icon: Icons.arrow_upward,
                  label: 'درآمد',
                  amount: income,
                  color: incomeColor,
                ),
              ),
              Container(
                  width: 1, height: 22, color: t.outline),
              Expanded(
                child: HeroMiniStat(
                  icon: Icons.arrow_downward,
                  label: 'هزینه',
                  amount: expense,
                  color: expenseColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
              height: 1,
              color: t.outline.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: MonthStat(
                  icon: Icons.arrow_upward,
                  label: 'درآمد ماه',
                  amount: monthIncome,
                  color: incomeColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: MonthStat(
                  icon: Icons.arrow_downward,
                  label: 'هزینه ماه',
                  amount: monthExpense,
                  color: expenseColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: MonthStat(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'مانده ماه',
                  amount: monthBalance,
                  color: monthBalanceColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HeroMiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;
  final Color color;
  const HeroMiniStat({
    super.key,
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: t.textMuted,
            )),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            NumberFormat.formatPlain(amount),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class MonthStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;
  final Color color;
  const MonthStat({
    super.key,
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 10),
                    color: t.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              NumberFormat.formatPlain(amount),
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 15),
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED HEADERS
// ══════════════════════════════════════════════════════════════
class SectionLabel extends StatelessWidget {
  final String title;
  final int count;
  const SectionLabel({super.key, required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: expensesAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12.5),
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: expensesAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              fontWeight: FontWeight.w700,
              color: expensesAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class MonthTopCategoryCard extends StatelessWidget {
  final String category;
  const MonthTopCategoryCard({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: expenseColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: expenseColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_down, size: 15, color: expenseColor),
          const SizedBox(width: 8),
          // Expanded: the category is free text up to 24 characters, and a
          // fixed Text in this Row overflowed the card on a 320 dp phone.
          Expanded(
            child: Text(
              'بیشترین هزینه ماه: $category',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w700,
                color: expenseColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
