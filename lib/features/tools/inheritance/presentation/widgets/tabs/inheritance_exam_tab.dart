import 'dart:math';

import 'package:tawheeed/shared/widgets/currency_aware_state.dart';
import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/problem_generator.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/inheritance_palette.dart';

class InheritanceExamTab extends StatefulWidget {
  const InheritanceExamTab({super.key});

  @override
  State<InheritanceExamTab> createState() => _InheritanceExamTabState();
}

class _InheritanceExamTabState
    extends State<InheritanceExamTab>
    with CurrencyAwareState<InheritanceExamTab> {
  static const Color _accent = InheritancePalette.accent;

  final _rng = Random();
  List<GeneratedProblem> _exam = const [];
  int _index = 0;
  final Map<int, Map<HeirType, double>> _answers = {};
  Map<int, AnswerCheck>? _checks;
  bool _examMode = false;

  static const List<(String, double)> _commonFractions = [
    ('ارث ندارد (0)', 0),
    ('1/2', 0.5),
    ('1/3', 1 / 3),
    ('1/4', 0.25),
    ('1/6', 1 / 6),
    ('1/8', 0.125),
    ('2/3', 2 / 3),
    ('3/4', 0.75),
    ('5/6', 5 / 6),
  ];

  void _startExam() {
    setState(() {
      _examMode = true;
      _exam = generateExam(questionCount: 5, random: _rng);
      _index = 0;
      _answers.clear();
      _checks = null;
    });
  }

  void _single() {
    setState(() {
      _examMode = false;
      _exam = [generateRandomProblem(random: _rng)];
      _index = 0;
      _answers.clear();
      _checks = null;
    });
  }

  Map<HeirType, double> _currentAnswers() => _answers[_index] ?? {};

  void _submit() {
    if (_exam.isEmpty) return;
    final checks = <int, AnswerCheck>{};
    for (var i = 0; i < _exam.length; i++) {
      checks[i] = checkProblemAnswer(_exam[i], _answers[i] ?? {});
    }
    setState(() => _checks = checks);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? InheritancePalette.accentDark : _accent;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        _header(isDark, accent),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _single,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('مسأله تصادفی'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: TimeThemeKit.of(context).palette.card,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _startExam,
                icon: const Icon(Icons.quiz_outlined, size: 18),
                label: const Text('آزمون 5 سؤالی'),
                style: FilledButton.styleFrom(
                  backgroundColor: TimeThemeKit.of(context).palette.surfaceAlt,
                  foregroundColor: accent,
                  side: BorderSide(color: accent.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
        ),
        if (_exam.isNotEmpty) ...[
          const SizedBox(height: 16),
          if (_examMode) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _exam.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _index = i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _index
                            ? accent
                            : (_checks != null &&
                                    ((_checks![i]?.score ?? 0) >= 0.99)
                                ? Colors.green
                                : TimeThemeKit.of(context).palette.surfaceAlt),
                        border: Border.all(
                            color: i == _index
                                ? accent
                                : TimeThemeKit.of(context).palette.outline),
                      ),
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              fontWeight: FontWeight.w700,
                              color: i == _index ||
                                      (_checks != null &&
                                          (_checks![i]?.score ?? 0) >= 0.99)
                                  ? TimeThemeKit.of(context).palette.card
                                  : TimeThemeKit.of(context).palette.textPrimary)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _questionCard(_exam[_index], isDark, accent),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _index > 0 ? () => setState(() => _index--) : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('قبلی'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _index < _exam.length - 1
                      ? () => setState(() => _index++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('بعدی'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.fact_check_outlined, size: 20),
            label: const Text('ثبت و بررسی پاسخ‌ها'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: TimeThemeKit.of(context).palette.card,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
          if (_checks != null) ...[
            const SizedBox(height: 16),
            _summaryCard(_checks!, isDark, accent),
          ],
        ],
      ],
    );
  }

  Widget _header(bool isDark, Color accent) {
    return TabIntroCard(
      icon: Icons.quiz_outlined,
      accent: accent,
      title: 'تولید مسأله و آزمون',
      subtitle: 'تمرین و تمرکز روی سهم کسرها در مسائل ارث',
    );
  }

  Widget _questionCard(GeneratedProblem p, bool isDark, Color accent) {
    final answers = _currentAnswers();
    final check = _checks?[_index];
    final currentIsCorrect = check != null && check.score >= 0.99;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: currentIsCorrect
                ? Colors.green.withValues(alpha: 0.1)
                : accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: currentIsCorrect
                    ? Colors.green.withValues(alpha: 0.5)
                    : accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('سؤال ${_index + 1} از ${_exam.length}',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: accent)),
              const SizedBox(height: 6),
              Text('وارثان حاضر: ${p.description}',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w700,
                      color: TimeThemeKit.of(context).palette.textPrimary,
                      height: 1.5)),
              const SizedBox(height: 6),
              Text('ترکه: ${NumberFormat.formatMoney(p.result.netEstate, unit)}',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: TimeThemeKit.of(context).palette.textSecondary)),
              const SizedBox(height: 8),
              Text('سهم هر وارث (به صورت کسر) چقدر است؟',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w600,
                      color: TimeThemeKit.of(context).palette.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final s in p.result.shares) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: TimeThemeKit.of(context).palette.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: check != null
                      ? (check.results[s.type] ?? false)
                          ? Colors.green.withValues(alpha: 0.5)
                          : Colors.red.withValues(alpha: 0.4)
                      : TimeThemeKit.of(context).palette.outline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${heirLabel(s.type)}${s.count > 1 ? ' ×${s.count}' : ''}',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w600,
                        color: TimeThemeKit.of(context).palette.textPrimary),
                  ),
                ),
                if (check != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      (check.results[s.type] ?? false)
                          ? Icons.check_circle
                          : Icons.cancel,
                      size: 18,
                      color: (check.results[s.type] ?? false)
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<double>(
                    initialValue: answers[s.type],
                    hint: Text('انتخاب',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12))),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      for (final f in _fractionOptions(s))
                        DropdownMenuItem(
                            value: f.$2,
                            child: Text(f.$1,
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 12)))),
                    ],
                    onChanged: check == null
                        ? (v) {
                            setState(() {
                              final m = _answers[_index] ?? {};
                              if (v == null) {
                                m.remove(s.type);
                              } else {
                                m[s.type] = v;
                              }
                              _answers[_index] = m;
                            });
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (check != null && !currentIsCorrect) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final f in check.feedback)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• $f',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            color: Colors.red.shade700,
                            height: 1.5)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<(String, double)> _fractionOptions(InheritanceShare s) {
    final correct = s.fraction.toArString();
    final options = <(String, double)>[
      for (final f in _commonFractions)
        if (f.$1 != correct) f,
      (correct, s.fraction.toDouble()),
    ];
    options.sort((a, b) => a.$2.compareTo(b.$2));
    return options;
  }

  Widget _summaryCard(Map<int, AnswerCheck> checks, bool isDark, Color accent) {
    var total = 0.0;
    var count = 0;
    for (final c in checks.values) {
      total += c.score;
      count++;
    }
    final avg = count == 0 ? 0.0 : total / count;
    final percent = (avg * 100).round();
    final color = percent >= 70
        ? Colors.green
        : percent >= 40
            ? InheritancePalette.highlight
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('نتیجه آزمون',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 15),
                      fontWeight: FontWeight.w700,
                      color: TimeThemeKit.of(context).palette.textPrimary)),
              Text('$percent٪',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 22),
                      fontWeight: FontWeight.w800,
                      color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            percent >= 70
                ? 'عالی! تسلط خوبی بر مسائل ارث داری.'
                : percent >= 40
                    ? 'قابل قبول است؛ با تمرین بیشتر بهتر می‌شود.'
                    : 'نیاز به مطالعه بیشتر داری؛ مسائل را مرور کن.',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12.5),
                color: TimeThemeKit.of(context).palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
