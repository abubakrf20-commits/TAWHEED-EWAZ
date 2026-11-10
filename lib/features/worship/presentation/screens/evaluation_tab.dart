import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/features/worship/presentation/widgets/evaluation_stats_widget.dart';

class EvaluationTab extends StatelessWidget {
  const EvaluationTab({super.key});

  @override
  Widget build(BuildContext context) {
    // No AppBar and no fat TabBar: a 40dp page header, then the stats body
    // (user request, 2026-10-14). The body's own first row is the
    // day/week/month segmented control, so the top chrome went 56 + 40 →
    // 40 + 40.
    //
    // The old page-header reset was ONE global action, and it read as broken:
    // it cleared the evaluation's own rows but the prayers, adhkar and tasbih
    // the score is built from survived, so the score re-derived itself at once.
    // The reset now lives INSIDE each tab and wipes only that tab's range
    // (user decision, 2026-11-05) — see EvaluationStatsWidget._resetScope.
    return const SectionShell.fixed(
      title: 'ارزیابی و گزارش',
      child: EvaluationStatsWidget(),
    );
  }
}
