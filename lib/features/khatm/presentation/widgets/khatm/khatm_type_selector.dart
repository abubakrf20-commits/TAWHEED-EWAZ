import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart';

class KhatmTypeSelector extends StatelessWidget {
  final KhatmType? selectedType;
  final void Function(KhatmType type) onSelected;
  const KhatmTypeSelector(
      {super.key, required this.selectedType, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final onPrimary = dsOnAccent(context);
    final types = [
      const KhatmType('ختم عادی', 30, Icons.book, 'ختم قرآن - عادی'),
      const KhatmType('ختم سریع', 7, Icons.bolt, 'ختم قرآن - سریع'),
      const KhatmType('ختم متوسط', 14, Icons.speed, 'ختم قرآن - متوسط'),
      const KhatmType('ختم لیلة القدر', 10, Icons.nightlight, 'ختم لیلة القدر'),
      const KhatmType('ختم اختصاصی', 0, Icons.tune, 'ختم اختصاصی'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((khatmType) {
        final isSelected = identical(khatmType, selectedType);
        return ActionChip(
          avatar: Icon(khatmType.icon,
              size: 18, color: isSelected ? onPrimary : t.textSecondary),
          label: Text(khatmType.label,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: isSelected ? onPrimary : t.textPrimary)),
          backgroundColor: isSelected ? t.primary : t.surfaceAlt,
          side: BorderSide(
              color: isSelected ? t.primary : t.outline.withValues(alpha: 0.5)),
          shape: const StadiumBorder(),
          onPressed: () => onSelected(khatmType),
        );
      }).toList(),
    );
  }
}

class KhatmType {
  final String label;
  final int days;
  final IconData icon;
  final String defaultTitle;
  const KhatmType(this.label, this.days, this.icon, this.defaultTitle);
}

class QuickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const QuickChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return ActionChip(
      label: Text(label,
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10),
              color: selected
                  ? (dsOnAccent(context))
                  : t.textPrimary)),
      backgroundColor: selected ? t.primary : t.surfaceAlt,
      side: BorderSide(
          color: selected ? t.primary : t.outline.withValues(alpha: 0.5)),
      shape: const StadiumBorder(),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
