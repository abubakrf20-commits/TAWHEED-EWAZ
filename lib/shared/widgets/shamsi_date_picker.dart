import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/constants/date_constants.dart';

Future<DateTime?> showShamsiDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  Color? accentColor,
}) async {
  final now = Jalali.fromDateTime(initialDate ?? DateTime.now());
  final gold = accentColor ?? AppTheme.goldPale;
  final goldStrong = dsContentColor(context, gold);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final t = TimeThemeKit.of(context).palette;
  final danger = isDark ? AppTheme.darkError : AppTheme.lightError;

  int selYear = now.year;
  int selMonth = now.month;
  int selDay = now.day;
  int viewYear = selYear;
  int viewMonth = selMonth;

  final result = await showDialog<DateTime>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final jFirst = Jalali(viewYear, viewMonth);
          final daysInMonth = jFirst.monthLength;
          final startWeekday = jFirst.weekDay;
          final jToday = Jalali.fromDateTime(DateTime.now());

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: t.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'ماه قبل',
                    onPressed: () {
                      setDialogState(() {
                        if (viewMonth == 1) {
                          viewMonth = 12;
                          viewYear--;
                        } else {
                          viewMonth--;
                        }
                      });
                    },
                  ),
                  Text(
                    '${DateConstants.persianMonths[viewMonth - 1]} $viewYear',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 16),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'ماه بعد',
                    onPressed: () {
                      setDialogState(() {
                        if (viewMonth == 12) {
                          viewMonth = 1;
                          viewYear++;
                        } else {
                          viewMonth++;
                        }
                      });
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: List.generate(7, (i) {
                        const labels = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
                        return Expanded(
                          child: Center(
                            child: Text(
                              labels[i],
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w700,
                                color: i == 6
                                    ? danger
                                    : t.textMuted,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    ...List.generate((daysInMonth + startWeekday + 6) ~/ 7,
                        (row) {
                      return Row(
                        children: List.generate(7, (col) {
                          final dayNum = row * 7 + col - startWeekday + 1;
                          if (dayNum < 1 || dayNum > daysInMonth) {
                            return const Expanded(child: SizedBox(height: 40));
                          }
                          final isSelected = dayNum == selDay &&
                              viewMonth == selMonth &&
                              viewYear == selYear;
                          final isToday = dayNum == jToday.day &&
                              viewMonth == jToday.month &&
                              viewYear == jToday.year;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  selDay = dayNum;
                                  selMonth = viewMonth;
                                  selYear = viewYear;
                                });
                              },
                              child: Container(
                                height: 40,
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? goldStrong
                                      : (isToday
                                          ? gold.withValues(alpha: 0.12)
                                          : null),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '$dayNum',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize:
                                          AppTheme.scaledFontSize(context, 13),
                                      fontWeight: isSelected || isToday
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : (isToday
                                              ? goldStrong
                                              : t.textPrimary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$selYear/${selMonth.toString().padLeft(2, '0')}/${selDay.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 15),
                          fontWeight: FontWeight.w700,
                          color: goldStrong,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('لغو',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: t.textMuted)),
                ),
                TextButton(
                  onPressed: () {
                    final greg = Jalali(selYear, selMonth, selDay).toDateTime();
                    Navigator.pop(ctx, greg);
                  },
                  child: Text('تأیید',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: goldStrong,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  return result;
}
