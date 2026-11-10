import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/features/hajj_umrah/data/hajj_content.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';

/// A finished trip, kept so the next one starts from zero instead of showing
/// last year's ticks as if the rites were already done.
class HajjTripRecord {
  const HajjTripRecord({
    required this.startedOn,
    required this.done,
    required this.total,
  });

  /// ISO `yyyy-MM-dd` of the first tick of that trip.
  final String startedOn;
  final int done;
  final int total;

  Map<String, dynamic> toJson() =>
      {'startedOn': startedOn, 'done': done, 'total': total};

  static HajjTripRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final startedOn = raw['startedOn'];
    if (startedOn is! String) return null;
    return HajjTripRecord(
      startedOn: startedOn,
      done: raw['done'] is int ? raw['done'] as int : 0,
      total: raw['total'] is int ? raw['total'] as int : 0,
    );
  }
}

/// Renders an ordered list of [RitualStepData] as a step-by-step guide with a
/// persisted completion toggle per step and an overall progress bar.
///
/// [storageKey] namespaces progress in SharedPreferences so the umrah and hajj
/// guides keep independent state.
class RitualStepsView extends StatefulWidget {
  final String storageKey;
  final List<RitualStepData> steps;
  final Color accentColor;
  final String progressLabel;

  /// Step number to mark «امروز» — the pilgrimage-day banner's answer. Null
  /// outside the five days of hajj.
  final int? highlightStep;

  const RitualStepsView({
    super.key,
    required this.storageKey,
    required this.steps,
    required this.accentColor,
    this.progressLabel = 'پیشرفت',
    this.highlightStep,
  });

  @override
  State<RitualStepsView> createState() => _RitualStepsViewState();
}

class _RitualStepsViewState extends State<RitualStepsView> {
  Set<int> _done = {};
  bool _loading = true;

  /// ISO date of the first tick of the current trip, null before it starts.
  String? _tripStart;

  /// The trip that «سفر جدید» closed, if any.
  HajjTripRecord? _lastTrip;

  String get _stepsKey => 'hajj_steps_${widget.storageKey}';
  String get _startKey => 'hajj_trip_start_${widget.storageKey}';
  String get _archiveKey => 'hajj_trip_archive_${widget.storageKey}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_stepsKey);
      if (saved != null && saved.isNotEmpty) {
        _done = saved
            .split(',')
            .map((e) => int.tryParse(e) ?? -1)
            .where((e) => e >= 0)
            .toSet();
      }
      _tripStart = prefs.getString(_startKey);
      _lastTrip = HajjTripRecord.fromJson(
          jsonDecode(prefs.getString(_archiveKey) ?? 'null'));
    } catch (e) {
      AppLogger.warning('ritual_steps', 'progress read failed: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(int step) async {
    final startingTrip = _tripStart == null && !_done.contains(step);
    final wasDone = _done.contains(step);
    final now = DateTime.now();
    final iso = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    setState(() {
      if (wasDone) {
        _done.remove(step);
      } else {
        _done.add(step);
      }
      if (startingTrip) _tripStart = iso;
    });
    if (!await _persist()) {
      if (!mounted) return;
      // Undo the optimistic tick: a rite shown as done that is not recorded is
      // the one state this guide must never display — it is the whole reason
      // [_newTrip] archives the previous trip instead of clearing it silently.
      setState(() {
        if (wasDone) {
          _done.add(step);
        } else {
          _done.remove(step);
        }
        if (startingTrip) _tripStart = null;
      });
      AppSnackBar.error(
        context,
        wasDone
            ? 'تیک برداشته نشد و این مرحله هنوز انجام‌شده است.'
            : 'تیک ثبت نشد و این مرحله انجام‌شده ثبت نمی‌شود.',
        onRetry: () => _toggle(step),
      );
      return;
    }
    if (startingTrip) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_startKey, iso);
      } catch (e) {
        AppLogger.warning('ritual_steps', 'trip start write failed: $e');
      }
    }
  }

  /// Closes the current trip and starts a new one.
  ///
  /// WHY a confirmation: this used to be a one-tap «بازنشانی پیشرفت» that
  /// wiped the ticks with no trace, and nothing ever cleared them at all — so
  /// a year later the guide still showed last year's completed rites as done.
  /// The closed trip is archived and shown as «سفر قبلی» so the reset is not
  /// a silent data loss.
  Future<void> _newTrip() async {
    final doneCount =
        widget.steps.where((s) => _done.contains(s.step)).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = TimeThemeKit.of(ctx).palette;
        return AlertDialog(
          backgroundColor: t.card,
          title: Text(
            'سفر جدید',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(ctx, 15),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          content: Text(
            doneCount == 0
                ? 'پیشرفت فعلی پاک می‌شود و شمارش مناسک از ابتدا آغاز می‌شود.'
                : 'پیشرفت این سفر ($doneCount از ${widget.steps.length}) بایگانی '
                    'می‌شود و برای سفر بعدی، همهٔ مراحل از ابتدا شمارش می‌شوند.',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(ctx, 12.5),
              height: 1.7,
              color: t.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('انصراف',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(ctx, 12.5),
                    color: t.textMuted,
                  )),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('شروع سفر جدید',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(ctx, 12.5),
                    fontWeight: FontWeight.w700,
                    color: widget.accentColor,
                  )),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final archived = _tripStart == null
        ? _lastTrip
        : HajjTripRecord(
            startedOn: _tripStart!,
            done: doneCount,
            total: widget.steps.length,
          );
    setState(() {
      _done.clear();
      _tripStart = null;
      _lastTrip = archived;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_stepsKey);
      await prefs.remove(_startKey);
      if (archived != null) {
        await prefs.setString(_archiveKey, jsonEncode(archived.toJson()));
      }
    } catch (e) {
      AppLogger.warning('ritual_steps', 'trip archive failed: $e');
    }
  }

  /// A failed write used to be silent: the tick stayed on screen and vanished
  /// on the next open with no trace anywhere.
  /// Returns whether the write landed.
  ///
  /// It used to swallow the error and return nothing, so [_toggle] drew a tick
  /// it could not stand behind: the rite looked done, and the next open showed
  /// it undone. A caller that paints optimistic state has to know.
  Future<bool> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_stepsKey, _done.join(','));
      return true;
    } catch (e) {
      AppLogger.warning('ritual_steps', 'progress write failed: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.steps.length;
    // Progress counts by step number so reordering never shifts completion.
    final doneCount = widget.steps.where((s) => _done.contains(s.step)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProgressBar(context, doneCount, total),
        const SizedBox(height: 12),
        // The steps render even while the saved ticks are still loading — the
        // guide is the content the user came for, and hiding it behind a
        // `SizedBox.shrink()` made the whole tab pop in after a blank frame.
        // The toggles stay inert until the read lands so a tap in that window
        // cannot be overwritten by the arriving state.
        for (var i = 0; i < widget.steps.length; i++)
          _StepCard(
            step: widget.steps[i],
            isLast: i == widget.steps.length - 1,
            done: _done.contains(widget.steps[i].step),
            highlight: widget.highlightStep == widget.steps[i].step,
            accentColor: widget.accentColor,
            onToggle:
                _loading ? null : () => _toggle(widget.steps[i].step),
          ),
        if (!_loading) _buildTripLine(context, doneCount),
      ],
    );
  }

  /// The trip footer: when this trip started, what the last one left behind,
  /// and the one control that closes it. Shown even with zero ticks, because
  /// «سفر جدید» is also how a traveller starts over after an accidental tap.
  Widget _buildTripLine(BuildContext context, int doneCount) {
    final t = TimeThemeKit.of(context).palette;
    final last = _lastTrip;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        children: [
          if (_tripStart != null)
            Text(
              'سفر جاری از ${jalaliDayMonth(_tripStart!)}',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: t.textMuted,
              ),
            ),
          if (last != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'سفر قبلی: ${last.done} از ${last.total}'
                ' · از ${jalaliDayMonth(last.startedOn)}',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: t.textMuted.withValues(alpha: 0.8),
                ),
              ),
            ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _newTrip,
            icon: Icon(Icons.luggage,
                size: 15, color: t.textMuted),
            label: Text(
              'سفر جدید',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11.5),
                color: t.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, int done, int total) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final fraction = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: t.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 16, color: widget.accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.progressLabel}: $done از $total',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
              if (total > 0 && done == total)
                Text('تکمیل شد ✓',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w700,
                      color: success,
                    )),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: widget.accentColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final RitualStepData step;
  final bool isLast;
  final bool done;

  /// This is the rite of the day the banner announced — the card is ringed in
  /// the accent and carries an «امروز» chip so the traveller's eye lands on it
  /// without scrolling to find a number.
  final bool highlight;
  final Color accentColor;

  /// null while the saved ticks are still loading — the row renders, the tick
  /// does not accept a tap that the arriving state would then overwrite.
  final VoidCallback? onToggle;

  const _StepCard({
    required this.step,
    required this.isLast,
    required this.done,
    required this.highlight,
    required this.accentColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: done ? accentColor : accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: accentColor.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Center(
                child: Text(
                  '${step.step}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 15),
                    fontWeight: FontWeight.w800,
                    color: done ? Colors.white : accentColor,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                  width: 2,
                  height: 20,
                  color: accentColor.withValues(alpha: 0.15)),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: highlight
                  ? accentColor.withValues(alpha: 0.06)
                  : t.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: highlight
                      ? accentColor.withValues(alpha: 0.55)
                      : t.outline,
                  width: highlight ? 1.4 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            step.title,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 14),
                              fontWeight: FontWeight.w700,
                              color: t.textPrimary,
                            ),
                          ),
                          if (highlight) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  'امروز',
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 10),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (step.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            SelectableText(
                              step.subtitle,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 12),
                                color: accentColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onToggle,
                      visualDensity: VisualDensity.compact,
                      tooltip: done ? 'لغو انجام' : 'انجام شد',
                      icon: Icon(
                        done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 24,
                        color:
                            done ? accentColor : t.textMuted,
                      ),
                    ),
                  ],
                ),
                if (step.arabic.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _ArabicDua(arabic: step.arabic, accentColor: accentColor),
                ],
                const SizedBox(height: 8),
                Container(height: 1, color: accentColor.withValues(alpha: 0.1)),
                const SizedBox(height: 8),
                SelectableText(
                  step.description,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: t.textSecondary,
                    height: 1.6,
                  ),
                ),
                if (step.tip.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _TipBox(tip: step.tip, accentColor: accentColor),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ArabicDua extends StatelessWidget {
  final String arabic;
  final Color accentColor;
  const _ArabicDua({required this.arabic, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.record_voice_over_outlined,
                  size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text('ذِکر و دعا',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            arabic,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 15),
              height: 1.9,
              color: t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  final String tip;
  final Color accentColor;
  const _TipBox({required this.tip, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final info = isDark ? AppTheme.darkInfo : AppTheme.lightInfo;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 16, color: info),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              tip,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
