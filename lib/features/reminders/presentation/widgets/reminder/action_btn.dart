import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

class ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const ActionBtn(this.icon,
      {super.key, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    // No SizedBox here: it clamped the whole button (including Material's
    // padded tap target) to 30 dp. With tight constraints the paint stays
    // 30×30, while the default padded tap target keeps the 48 dp hit area.
    return IconButton(
      icon: Icon(icon, size: 16),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      tooltip: tooltip,
      color: t.textMuted,
      style: IconButton.styleFrom(
        backgroundColor: t.textMuted.withValues(alpha: 0.08),
      ),
    );
  }
}
