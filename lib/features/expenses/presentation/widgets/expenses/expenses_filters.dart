import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/expenses/presentation/widgets/expenses/expenses_common.dart';

class ExpenseFilterChip extends StatelessWidget {
  final String label;
  final ExpenseFilter filter;
  final IconData icon;
  final ExpenseFilter current;
  final ValueChanged<ExpenseFilter> onChanged;

  const ExpenseFilterChip({
    super.key,
    required this.label,
    required this.filter,
    required this.icon,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = current == filter;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(filter),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? expensesAccent
                : (isDark
                    ? t.surfaceAlt
                    : expensesAccentSoft.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? expensesAccent : t.outline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color:
                    selected ? Colors.white : t.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : t.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
