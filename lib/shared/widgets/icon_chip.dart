import 'package:flutter/material.dart';

/// Rounded gradient chip that frames a single icon.
///
/// Originally duplicated in `khatm_common.dart` and `tasks_common.dart`;
/// this is the canonical definition. The tasks copy uses a smaller size
/// (28px) — when migrating tasks, add optional size parameters here rather
/// than redefining the widget.
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
