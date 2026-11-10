import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart';

class ChecklistStep {
  final String title;
  final String detail;
  final bool isRukn;
  const ChecklistStep(this.title, this.detail, {this.isRukn = false});
}

/// Interactive step-by-step checklist card shared by the purification module
/// (wudu / ghusl / tayammum) and the prayer module.
///
/// Progress is persisted per day (SharedPreferences, key
/// `<prefix>_steps_<yyyy-MM-dd>`) and a fully completed checklist registers
/// [worshipId] in today's worship (evaluationProvider) — unchecking a step or
/// resetting un-registers it. The success chip is driven by the real worship
/// state so it can never claim a registration that isn't there.
class StepChecklistCard extends ConsumerStatefulWidget {
  const StepChecklistCard({
    super.key,
    required this.prefix,
    required this.title,
    required this.icon,
    required this.steps,
    required this.worshipId,
    required this.worshipLabel,
    required this.worshipIcon,
    required this.accent,
  });

  /// SharedPreferences key prefix: `<prefix>_steps_<yyyy-MM-dd>`.
  final String prefix;
  final String title;
  final IconData icon;
  final List<ChecklistStep> steps;
  final String worshipId;
  final String worshipLabel;
  final IconData worshipIcon;
  final Color accent;

  @override
  ConsumerState<StepChecklistCard> createState() => _StepChecklistCardState();
}

class _StepChecklistCardState extends ConsumerState<StepChecklistCard> {
  Set<int> _checked = {};
  bool _loading = true;

  String get _storageKey {
    final now = DateTime.now();
    final dk = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return '${widget.prefix}_steps_$dk';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved != null && saved.isNotEmpty) {
      _checked = saved
          .split(',')
          .map((e) => int.tryParse(e) ?? -1)
          .where((e) => e >= 0)
          .toSet();
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Keeps today's worship item in sync: all steps checked → done;
  /// any step unchecked → not done. Skips while the worship graph is still
  /// loading (the next tap retries) or when the item was hidden/removed by
  /// the user (toggleWorship would otherwise fail on a missing id).
  void _syncWorship() {
    final eval = ref.read(evaluationProvider);
    if (eval is! AsyncData) return;
    final items = eval.value!.worshipItems;
    final index = items.indexWhere((w) => w.id == widget.worshipId);
    if (index < 0) return;
    final allDone = _checked.length == widget.steps.length;
    if (allDone != items[index].done) {
      ref.read(evaluationProvider.notifier).toggleWorship(widget.worshipId);
    }
  }

  Future<void> _toggle(int index) async {
    setState(() {
      if (_checked.contains(index)) {
        _checked.remove(index);
      } else {
        _checked.add(index);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _checked.join(','));
    _syncWorship();
  }

  Future<void> _reset() async {
    setState(() => _checked.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    // Removing a step un-registers the worship item for today too.
    _syncWorship();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the worship graph so it is loaded (and stays in sync) when the
    // user completes the checklist — same pattern as the calendar screen.
    // The watched value also drives the registration chip below, so the UI
    // can never claim a registration that isn't real.
    final itemDone = ref
            .watch(evaluationProvider)
            .value
            ?.worshipItems
            .firstWhere(
              (w) => w.id == widget.worshipId,
              orElse: () => WorshipItem(
                  id: widget.worshipId,
                  label: widget.worshipLabel,
                  icon: widget.worshipIcon),
            )
            .done ??
        false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final accent = widget.accent;
    final allDone = !_loading && _checked.length == widget.steps.length;
    final progress =
        widget.steps.isEmpty ? 0.0 : _checked.length / widget.steps.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.title,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${_checked.length}/${widget.steps.length}',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w600,
                        color: accent)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _loading ? 0 : progress,
              minHeight: 6,
              backgroundColor: accent.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          if (itemDone) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 16, color: success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        allDone
                            ? '${widget.worshipLabel} کامل شد ✓ در طاعات امروز ثبت شد'
                            : '${widget.worshipLabel} امروز در طاعات ثبت شده است ✓',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w600,
                            color: success)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          ...widget.steps
              .asMap()
              .entries
              .map((e) => _buildStep(context, e.key, e.value, accent, isDark)),
          if (_checked.isNotEmpty)
            Center(
              child: TextButton.icon(
                onPressed: _reset,
                icon: Icon(Icons.refresh,
                    size: 14, color: t.textMuted),
                label: Text('بازنشانی امروز',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: t.textMuted)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context, int index, ChecklistStep step,
      Color accent, bool isDark) {
    final t = TimeThemeKit.of(context).palette;
    final checked = _checked.contains(index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _toggle(index),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: checked ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked
                      ? accent
                      : (t.outline),
                  width: checked ? 0 : 1.5,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(step.title,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 13),
                                fontWeight: step.isRukn
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: checked
                                    ? t.textMuted
                                    : t.textPrimary,
                                decoration: checked
                                    ? TextDecoration.lineThrough
                                    : null)),
                      ),
                      if (step.isRukn) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('رکن',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: AppTheme.scaledFontSize(context, 9),
                                  fontWeight: FontWeight.w700,
                                  color: accent)),
                        ),
                      ],
                    ],
                  ),
                  if (!checked) ...[
                    const SizedBox(height: 2),
                    Text(step.detail,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            color: t.textMuted,
                            height: 1.5)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
