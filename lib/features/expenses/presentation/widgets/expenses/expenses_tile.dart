import 'package:flutter/material.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/expenses/presentation/widgets/expenses/expenses_common.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/features/expenses/domain/expense_recurrence.dart';

class ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const ExpenseTile({
    super.key,
    required this.expense,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final accent = expense.isIncome ? incomeColor : expenseColor;
    final j = Jalali.fromDateTime(expense.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: isDark
              ? t.outline.withValues(alpha: 0.4)
              : accent.withValues(alpha: 0.18),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(width: 4, height: 72, color: accent),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        expense.isIncome
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 20,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 14),
                              fontWeight: FontWeight.w700,
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Every cell here is Flexible: at 320 dp with the
                          // text scale at 1.3 the category, the date and the
                          // recurrence label together are wider than the column
                          // the amount and the delete button leave behind, and
                          // a fixed-width Text in a Row overflows instead of
                          // shrinking.
                          Row(
                            children: [
                              if (expense.category.isNotEmpty) ...[
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color:
                                          expensesAccent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      expense.category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize:
                                            AppTheme.scaledFontSize(context, 10),
                                        color: expensesAccent,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  jalaliYmdShort(j),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 11),
                                    color: t.textMuted,
                                  ),
                                ),
                              ),
                              if (expense.isRecurring &&
                                  ExpenseRecurrence.label(
                                          expense.recurringType) !=
                                      null) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.repeat,
                                    size: 13, color: expensesAccent),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    'تکرار ${ExpenseRecurrence.label(expense.recurringType)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize:
                                          AppTheme.scaledFontSize(context, 10),
                                      color: expensesAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 110 dp, not 150: at 320 dp the amount column used to take
              // almost half the tile, squeezing the title and category into
              // ~64 dp. Nine figures still fit — the FittedBox scales the
              // figure down instead of clipping it.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      '${expense.isIncome ? '+' : '-'}${NumberFormat.formatPlain(expense.amount)}',
                      maxLines: 1,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                ),
              ),
              // A compact hit target: the stock IconButton reserves 48 dp of
              // width the row does not have.
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: t.textMuted,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'حذف',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
