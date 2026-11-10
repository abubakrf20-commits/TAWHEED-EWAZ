import 'package:flutter/material.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

class KhatmSelector extends StatelessWidget {
  final List<KhatmModel> allKhatms;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  const KhatmSelector(
      {super.key,
      required this.allKhatms,
      required this.selectedId,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final active = allKhatms.where((k) => !k.isCompleted).toList();

    if (active.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: active.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final k = active[index];
            final isSelected = k.id == selectedId;
            return KhatmChip(
              label: k.title,
              isSelected: isSelected,
              color: dsContentColor(context, TopicHues.khatm),
              onTap: () => onSelect(k.id),
            );
          },
        ),
      ),
    );
  }
}

class KhatmChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  const KhatmChip(
      {super.key,
      required this.label,
      required this.isSelected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : t.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : t.outline.withValues(alpha: 0.4),
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: isSelected
                ? AppTheme.scaledFontSize(context, 12)
                : AppTheme.scaledFontSize(context, 11),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (dsOnAccent(context))
                : t.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------- Shared building blocks ----------
