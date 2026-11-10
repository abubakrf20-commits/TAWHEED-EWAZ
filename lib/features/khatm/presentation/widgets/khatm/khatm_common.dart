import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

class IconChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  const IconChip({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

/// Khatm-local section header: [IconChip] row + title + optional trailing.
/// Named to stay clear of the design kit's own `SectionHeader`.
class KhatmSectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget? trailing;
  const KhatmSectionHeader(
      {super.key,
      required this.icon,
      required this.color,
      required this.title,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        IconChip(icon: icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 14),
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              )),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const GradientButton(
      {super.key,
      required this.label,
      required this.icon,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: TextStyle(fontFamily: AppTheme.fontFamily)),
      style: FilledButton.styleFrom(
        backgroundColor: TopicHues.khatm,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTheme.scaledFontSize(context, 9.5),
          color: dsContentColor(context, color),
          fontWeight: FontWeight.w700,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

class LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const LegendDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.scaledFontSize(context, 10.5),
            color: t.textSecondary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ],
    );
  }
}

// ---------- Virtues Screen ----------
