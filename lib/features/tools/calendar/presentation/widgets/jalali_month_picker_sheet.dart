import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/constants/date_constants.dart';

// ══════════════════════════════════════════════════════════════
//  QUICK JUMP — Jalali year & month picker sheet
// ══════════════════════════════════════════════════════════════

class JalaliMonthPickerSheet extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  final void Function(int year, int month) onSelected;

  const JalaliMonthPickerSheet({
    super.key,
    required this.initialYear,
    required this.initialMonth,
    required this.onSelected,
  });

  @override
  State<JalaliMonthPickerSheet> createState() => _JalaliMonthPickerSheetState();
}

class _JalaliMonthPickerSheetState extends State<JalaliMonthPickerSheet> {
  static const _yearStep = 25;
  static const double _yearItemExtent = 64;
  late int _year;
  late int _month;
  late final int _startYear;
  late final int _endYear;
  late final ScrollController _yearController;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
    _startYear = widget.initialYear - _yearStep;
    _endYear = widget.initialYear + _yearStep;
    // The strip is built around the initial year, so the offset is exactly
    // _yearStep items — the selected year lands at the leading edge. (It used
    // to be computed against a 72px extent while itemExtent is 64, which left
    // the current year scrolled about two chips out of view.)
    _yearController = ScrollController(
      initialScrollOffset: _yearStep * _yearItemExtent,
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  void _select(int year, int month) {
    widget.onSelected(year, month);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final gold = t.tertiary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'پرش سریع به تاریخ',
              // A plain (non-flex) child of the header row: it is measured in
              // the inflexible pass, so it cannot squash the title.
              trailing: IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: t.textMuted),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'بستن',
                visualDensity: VisualDensity.compact,
              ),
            ),
            Text(
              'سال $_year',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w600,
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: DsSpacing.rowGap),
            SizedBox(
              height: 40,
              child: ListView.builder(
                controller: _yearController,
                scrollDirection: Axis.horizontal,
                itemExtent: _yearItemExtent,
                itemCount: _endYear - _startYear + 1,
                itemBuilder: (context, index) {
                  final y = _startYear + index;
                  final selected = y == _year;
                  return GestureDetector(
                    onTap: () => setState(() => _year = y),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? gold : t.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? gold.withValues(alpha: 0.6)
                              : t.outline,
                        ),
                      ),
                      child: Text(
                        '$y',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w700,
                          color: selected ? t.heroBottom : t.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: DsSpacing.gap),
            Text(
              'ماه',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w600,
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: DsSpacing.rowGap),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: DsSpacing.rowGap,
              crossAxisSpacing: DsSpacing.rowGap,
              childAspectRatio: 1.5,
              children: List.generate(12, (i) {
                final m = i + 1;
                final selected = m == _month;
                return GestureDetector(
                  onTap: () => _select(_year, m),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? gold : t.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            selected ? gold.withValues(alpha: 0.6) : t.outline,
                      ),
                    ),
                    child: Text(
                      DateConstants.persianMonths[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w700,
                        color: selected ? t.heroBottom : t.textPrimary,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
