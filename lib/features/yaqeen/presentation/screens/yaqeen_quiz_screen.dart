import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_content.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_gamification.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_progress.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_quiz_data.dart';

/// ═══════════════════════════════════════════════════════════════
/// YaqeenQuizScreen — آزمون تعاملی پایان درس
///
/// سؤال‌به‌سؤال با بازخورد فوری (سبز/قرمز + توضیح)، نتیجهٔ نهایی و
/// امتیاز کسب‌شده. بهترین نمرهٔ درس ذخیره می‌شود (YaqeenProgress).
/// ═══════════════════════════════════════════════════════════════

class YaqeenQuizScreen extends StatefulWidget {
  final YaqeenLesson lesson;
  final List<YaqeenQuizQuestion> questions;

  const YaqeenQuizScreen({
    super.key,
    required this.lesson,
    required this.questions,
  });

  @override
  State<YaqeenQuizScreen> createState() => _YaqeenQuizScreenState();
}

class _YaqeenQuizScreenState extends State<YaqeenQuizScreen> {
  static const Color accent = TopicHues.yaqeen;

  final YaqeenProgress _progress = YaqeenProgress();

  int _index = 0;
  int? _selected;
  bool _answered = false;
  int _correct = 0;
  bool _finished = false;
  bool _scoreSaved = false;

  YaqeenQuizQuestion get _q => widget.questions[_index];

  void _select(int i) {
    if (_answered) return;
    setState(() {
      _selected = i;
      _answered = true;
      if (i == _q.correctIndex) _correct++;
    });
  }

  void _next() {
    if (_index + 1 < widget.questions.length) {
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
      });
    } else {
      setState(() => _finished = true);
      if (!_scoreSaved) {
        _scoreSaved = true;
        _progress.saveQuizScore(widget.lesson.id, _correct);
      }
    }
  }

  void _retry() {
    setState(() {
      _index = 0;
      _selected = null;
      _answered = false;
      _correct = 0;
      _finished = false;
      _scoreSaved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'آزمون: ${widget.lesson.title}',
      ),
      body: _finished ? _buildResult(context) : _buildQuestion(context),
    );
  }

  // ─── Question ─────────────────────────────────────────────────

  Widget _buildQuestion(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final q = _q;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(DsSpacing.page),
              children: [
                Row(
                  children: [
                    Text('سؤال ${_index + 1} از ${widget.questions.length}',
                        style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 12), color: t.textMuted)),
                    const Spacer(),
                    Text('✓ $_correct',
                        style: TextStyle(
                            color: success, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_index + 1) / widget.questions.length,
                    minHeight: 5,
                    backgroundColor: accent.withValues(alpha: 0.10),
                    valueColor: const AlwaysStoppedAnimation(accent),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  q.question,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 16), fontWeight: FontWeight.bold, height: 1.8),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < q.options.length; i++)
                  _buildOption(context, i, q.options[i]),
                if (_answered) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _selected == q.correctIndex
                              ? Icons.check_circle
                              : Icons.info_outline,
                          size: 18,
                          color: _selected == q.correctIndex
                              ? success
                              : accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            q.explanation,
                            style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 13), height: 1.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DsSpacing.page, 8, DsSpacing.page, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: accent),
                onPressed: _answered ? _next : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _index + 1 < widget.questions.length
                          ? 'سؤال بعدی'
                          : 'دیدن نتیجه',
                      style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 13)),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _index + 1 < widget.questions.length
                          ? Icons.arrow_forward
                          : Icons.task_alt,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, int i, String text) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    Color? fill;
    Color? border;
    Color? textColor;
    IconData? trailing;

    if (_answered) {
      if (i == _q.correctIndex) {
        fill = success.withValues(alpha: 0.12);
        border = success;
        textColor = success;
        trailing = Icons.check_circle;
      } else if (i == _selected) {
        fill = danger.withValues(alpha: 0.10);
        border = danger;
        textColor = danger;
        trailing = Icons.cancel;
      }
    } else {
      border = t.divider.withValues(alpha: 0.5);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: fill ?? t.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _answered ? null : () => _select(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border ?? Colors.transparent),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        height: 1.6,
                        color: textColor ?? t.textPrimary),
                  ),
                ),
                if (trailing != null)
                  Icon(trailing,
                      size: 18,
                      color: i == _q.correctIndex ? success : danger),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Result ───────────────────────────────────────────────────

  Widget _buildResult(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final total = widget.questions.length;
    final perfect = _correct >= total;
    final earned = _correct * YaqeenGamification.pointsPerCorrectAnswer;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              perfect
                  ? Icons.emoji_events_outlined
                  : (_correct > 0 ? Icons.task_alt : Icons.refresh_outlined),
              size: 72,
              color: perfect ? Colors.amber : accent,
            ),
            const SizedBox(height: 16),
            Text(
              perfect
                  ? 'آفرین! نمرهٔ کامل'
                  : (_correct > 0 ? 'خوب بود!' : 'دوباره تلاش کن'),
              style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 19), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('$_correct از $total پاسخ درست',
                style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 16), color: t.textMuted)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    '+$earned امتیاز',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: AppTheme.scaledFontSize(context, 15)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('تلاش دوباره'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: accent),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('پایان'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
