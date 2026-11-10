// Result-card half of [_InheritanceCalculatorTabState] (M5 file split):
// `setState` is `@protected`, so the analyzer flags it outside the class body —
// the receiver here is still the State itself, so the calls are valid.
// ignore_for_file: invalid_use_of_protected_member

part of 'inheritance_calculator_tab.dart';

extension _InheritanceResultCard on _InheritanceCalculatorTabState {
  // ── Result card with per-heir share + reason ──
  Widget _buildResultCard(InheritanceResult result, bool isDark, Color accent) {
    final net = result.netEstate;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              _br(
                  result.mandatoryWillAmount > 0
                      ? 'ترکه پس از هزینه، دیون و وصیت عادی'
                      : 'ترکه قابل تقسیم',
                  NumberFormat.formatMoney(net, unit),
                  accent,
                  bold: true),
              if (result.mandatoryWillAmount > 0) ...[
                const SizedBox(height: 4),
                _br(
                    'وصیت واجبه (کسر شده)',
                    NumberFormat.formatMoney(result.mandatoryWillAmount, unit),
                    accent,
                    valColor: InheritancePalette.purpleMid),
                const SizedBox(height: 4),
                _br('مانده برای وراث اصلی',
                    NumberFormat.formatMoney(result.estateForMainHeirs, unit), accent,
                    bold: true),
              ],
              const SizedBox(height: 4),
              _br('مذهب', madhabLabel(result.madhab), accent),
              const SizedBox(height: 4),
              _br('روش تقسیم', result.methodLabel, accent),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareResultText(result),
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('اشتراک متن'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _shareResultImage(result),
                      icon: const Icon(Icons.image_outlined, size: 16),
                      label: const Text('اشتراک تصویر'),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _shareResultPdf(result),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('گزارش PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              if (result.awlApplied)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _br('تخصیص‌یافته',
                      NumberFormat.formatMoney(result.totalAllocated, unit), accent,
                      valColor: warning),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Pie chart
        Center(
          child: InheritancePieChart(
            shares: result.shares,
            size: 180,
            strokeWidth: 35,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: InheritancePieLegend(shares: result.shares),
        ),
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: warning.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        size: 16, color: warning),
                    const SizedBox(width: 8),
                    Text('تنبیه',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w700,
                            color: warning)),
                  ],
                ),
                const SizedBox(height: 6),
                ...result.warnings.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $w',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              color: TimeThemeKit.of(context).palette.textSecondary,
                              height: 1.5)),
                    )),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'سهم هر وارث و دلیل آن',
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14),
              fontWeight: FontWeight.w700,
              color: accent),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 8),
        ...result.shares.map((s) => _heirResultCard(s, isDark, accent)),
        if (result.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  TimeThemeKit.of(context).palette.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: TimeThemeKit.of(context).palette.textMuted),
                    const SizedBox(width: 8),
                    Text('نکات محاسبه',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w700,
                            color: TimeThemeKit.of(context).palette.textPrimary)),
                  ],
                ),
                const SizedBox(height: 6),
                ...result.notes.map((n) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $n',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              color: TimeThemeKit.of(context).palette.textSecondary,
                              height: 1.5)),
                    )),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _showFractionCalc = !_showFractionCalc),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:
                  TimeThemeKit.of(context).palette.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate_outlined, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('حساب کسرها (اصل‌گیری و تصحیح مسأله)',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w700,
                          color: TimeThemeKit.of(context).palette.textPrimary)),
                ),
                Icon(_showFractionCalc ? Icons.expand_less : Icons.expand_more,
                    color: TimeThemeKit.of(context).palette.textMuted),
              ],
            ),
          ),
        ),
        if (_showFractionCalc) ...[
          const SizedBox(height: 12),
          _buildFractionCalc(_result!, isDark, accent),
        ],
        if (_solution != null) ...[
          const SizedBox(height: 16),
          if (_solution!.namedProblem != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: InheritancePalette.highlight.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: InheritancePalette.highlight.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 18, color: InheritancePalette.highlight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'این مسأله مشهور است: ${_solution!.namedProblem}',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12.5),
                          fontWeight: FontWeight.w700,
                          color: InheritancePalette.note),
                    ),
                  ),
                ],
              ),
            ),
          if (_solution!.namedProblems.length > 1)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: InheritancePalette.highlight.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: InheritancePalette.highlight.withValues(alpha: 0.2)),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final p in _solution!.namedProblems)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: InheritancePalette.highlight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(p.fullName,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 11),
                              fontWeight: FontWeight.w600,
                              color: InheritancePalette.note)),
                    ),
                ],
              ),
            ),
          if (_lastInput != null && estateGoesToBaytAlMal(_lastInput!))
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance,
                      size: 18, color: danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'وارث اصلی وجود ندارد؛ دارایی به بیت‌المال می‌رسد.',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w700,
                          color: danger),
                    ),
                  ),
                ],
              ),
            ),
          if (_blockedHeirs != null && _blockedHeirs!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildBlockedHeirs(_blockedHeirs!, isDark, accent),
          ],
          GestureDetector(
            onTap: () => setState(() => _showDetailed = !_showDetailed),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:
                    TimeThemeKit.of(context).palette.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text('حل تفصیلی گام‌به‌گام',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w700,
                          color: TimeThemeKit.of(context).palette.textPrimary)),
                  const Spacer(),
                  Icon(_showDetailed ? Icons.expand_less : Icons.expand_more,
                      color: TimeThemeKit.of(context).palette.textMuted),
                ],
              ),
            ),
          ),
          if (_showDetailed) ...[
            const SizedBox(height: 12),
            _buildDetailedSolution(_solution!, isDark, accent),
          ],
        ],
      ],
    );
  }
}
