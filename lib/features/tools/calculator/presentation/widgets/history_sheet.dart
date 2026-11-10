import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/calculator/data/calculator_history.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

class HistorySheet extends StatelessWidget {
  final List<CalculationRecord> history;
  final VoidCallback onClear;
  final Function(CalculationRecord) onSelect;
  final Function(CalculationRecord record) onDeleteItem;
  final Color accentColor;

  const HistorySheet({
    super.key,
    required this.history,
    required this.onClear,
    required this.onSelect,
    required this.onDeleteItem,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final textColor = t.textPrimary;
    final mutedColor = t.textMuted;
    final danger = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkError
        : AppTheme.lightError;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, color: accentColor, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'تاریخچه محاسبات',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 16),
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    if (history.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('پاک کردن تاریخچه'),
                              content: const Text(
                                  'آیا از پاک کردن تمام تاریخچه اطمینان دارید؟'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('لغو'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    onClear();
                                  },
                                  child: const Text('پاک کردن'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('پاک کردن'),
                        style: TextButton.styleFrom(
                          foregroundColor: danger,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // History list
              if (history.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calculate_outlined,
                            size: 48, color: mutedColor),
                        const SizedBox(height: 12),
                        Text(
                          'تاریخچه‌ای وجود ندارد',
                          style: TextStyle(color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final record = history[index];
                      return _HistoryItem(
                        record: record,
                        onTap: () => onSelect(record),
                        onDelete: () => onDeleteItem(record),
                        textColor: textColor,
                        mutedColor: mutedColor,
                        accentColor: accentColor,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final CalculationRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Color textColor;
  final Color mutedColor;
  final Color accentColor;

  const _HistoryItem({
    required this.record,
    required this.onTap,
    required this.onDelete,
    required this.textColor,
    required this.mutedColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final danger = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkError
        : AppTheme.lightError;
    final j = Jalali.fromDateTime(record.timestamp);
    final timeStr =
        '${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')} '
        '- ${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';

    return Dismissible(
      key: Key(record.timestamp.toIso8601String()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: danger.withValues(alpha: 0.1),
        child: Icon(Icons.delete_outline, color: danger),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('حذف آیتم'),
            content: const Text('آیا از حذف این آیتم اطمینان دارید؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('لغو'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: AppCard(
          padding: const EdgeInsets.all(14),
          onTap: onTap,
          child: Row(
            children: [
              if (record.isScientific)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'حرفه‌ای',
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (record.isScientific) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.expression,
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        color: mutedColor,
                        fontFamily: 'monospace',
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '= ${NumberFormat.groupDigits(record.result)}',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 18),
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                        fontFamily: 'monospace',
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(Icons.chevron_left, color: mutedColor, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
