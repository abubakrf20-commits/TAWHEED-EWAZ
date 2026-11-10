import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_palette.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/dhikr_view_prefs.dart';

/// «فهرست | تایم‌لاین | تمرکز» — one selector for all ten collections.
///
/// It sits under the app bar on every collection page and writes the global
/// preference, so the reader's choice follows them from «فضائل فجر» to
/// «اذکار النوم» without being asked again.
class DhikrViewSelector extends StatelessWidget {
  const DhikrViewSelector({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final DhikrViewMode mode;
  final ValueChanged<DhikrViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.darkOutline : DhikrPalette.hairline;
    final base = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        children: [
          for (final option in DhikrViewMode.values)
            Expanded(
              child: _Segment(
                option: option,
                selected: option == mode,
                onTap: () => onChanged(option),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final DhikrViewMode option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? DhikrPalette.cream
        : Theme.of(context).textTheme.bodySmall?.color;
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: Material(
        color: selected ? DhikrPalette.navy : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Center(
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
