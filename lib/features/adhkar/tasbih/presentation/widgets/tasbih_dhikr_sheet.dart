import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart';
import 'package:tawheeed/features/adhkar/tasbih/tasbih.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/date_key.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// One dhikr's own numbers, plus the two things the counter tab could not do:
/// rename it and read its per-dhikr history.
///
/// Renaming exists because `TasbihDao.rename` had no caller: the only way to
/// fix a typo was delete + recreate, which silently dropped
/// `totalLifetimeCount`. The history is read from the `tasbih_daily_<id>` rows
/// the tap path already writes, so no new storage or schema is involved.
///
/// Opened from a long-press on a dhikr chip. Pops with nothing: the caller
/// re-reads the provider afterwards, so a dismissal mid-rename still lands.
class TasbihDhikrSheet extends ConsumerStatefulWidget {
  const TasbihDhikrSheet({super.key, required this.tasbih});

  final TasbihModel tasbih;

  @override
  ConsumerState<TasbihDhikrSheet> createState() => _TasbihDhikrSheetState();
}

class _TasbihDhikrSheetState extends ConsumerState<TasbihDhikrSheet> {
  static const int _historyDays = 7;

  late String _name = widget.tasbih.targetDhikr;
  bool _loading = true;
  bool _failed = false;
  int _today = 0;
  int _week = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// One query for the whole window: the per-dhikr series is stored a day per
  /// row, so today's number and the week's total come from the same read.
  Future<void> _load() async {
    final now = DateTime.now();
    final end = dateKeyOf(now);
    final start =
        dateKeyOf(now.subtract(const Duration(days: _historyDays - 1)));
    try {
      final rows = await ref
          .read(dailyStatusDaoProvider)
          .getAllInDateRange('tasbih_daily_${widget.tasbih.id}', start, end);
      var today = 0;
      var week = 0;
      for (final row in rows) {
        week += row.value;
        if (row.date == end) today = row.value;
      }
      if (!mounted) return;
      setState(() {
        _today = today;
        _week = week;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // A failed read is not a zero: the cells print «—» and offer a retry,
      // so «هیچ نشمردهای» can never be mistaken for a broken query.
      setState(() {
        _failed = true;
        _loading = false;
      });
      AppLogger.warning('tasbih_dhikr_sheet', 'history read failed: $e');
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _load();
  }

  Future<void> _rename() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDhikrDialog(initial: _name),
    );
    if (result == null || !mounted) return;

    await ref.read(tasbihProvider.notifier).rename(widget.tasbih.id, result);
    // The notifier rolls an optimistic rename back on a failed write, so the
    // provider — not the text just typed — is what the title must follow.
    final live = ref.read(tasbihProvider).value ?? const <TasbihModel>[];
    final idx = live.indexWhere((t) => t.id == widget.tasbih.id);
    if (!mounted) return;
    if (idx < 0 || live[idx].targetDhikr != result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تغییر نام ذخیره نشد. دوباره تلاش کنید.')),
      );
      return;
    }
    setState(() => _name = result);
  }

  /// Plain arithmetic on the day's target — never a religious claim.
  String get _hint {
    final target = widget.tasbih.targetCount;
    if (target <= 0) return '';
    final remaining = target - _today;
    if (remaining <= 0) return 'هدف امروز این ذکر کامل شد.';
    return '${NumberFormat.formatPlain(remaining.toDouble())} ذکر تا رسیدن به هدف امروز مانده است.';
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final hue = dsContentColor(context, SectionHues.tasbih);
    final showNumbers = !_loading && !_failed;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _name,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 17),
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            if (_failed)
              _FailedHistory(onRetry: _retry)
            else
              Row(
                children: [
                  Expanded(
                    child: _StatCell(
                      label: 'امروز',
                      value: _today,
                      showValue: showNumbers,
                      hue: hue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCell(
                      label: '$_historyDays روز اخیر',
                      value: _week,
                      showValue: showNumbers,
                      hue: hue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCell(
                      label: 'کل',
                      value: widget.tasbih.totalLifetimeCount,
                      showValue: showNumbers,
                      hue: hue,
                    ),
                  ),
                ],
              ),
            if (showNumbers && _hint.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11.5),
                  fontWeight: FontWeight.w500,
                  color: t.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _rename,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('تغییر نام'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('بستن'),
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

/// Owns its own controller so the field cannot outlive it.
///
/// Disposing from the caller's `showDialog(...).then(...)` runs while the exit
/// transition is still rebuilding this subtree — the field then re-listens to a
/// disposed controller and throws. A StatefulWidget is unmounted with the
/// route, i.e. after that animation.
class _RenameDhikrDialog extends StatefulWidget {
  const _RenameDhikrDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDhikrDialog> createState() => _RenameDhikrDialogState();
}

class _RenameDhikrDialogState extends State<_RenameDhikrDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);
  bool _empty = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _empty = true);
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تغییر نام ذکر'),
      content: TextField(
        controller: _ctrl,
        textDirection: TextDirection.rtl,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: 'متن ذکر',
          border: const OutlineInputBorder(),
          errorText: _empty ? 'متن ذکر را وارد کنید' : null,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('لغو')),
        FilledButton(onPressed: _submit, child: const Text('ذخیره')),
      ],
    );
  }
}

/// One number with its own heading. The pair is a single spoken node — a bare
/// «۱۲» under TalkBack says nothing about what was counted.
class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.showValue,
    required this.hue,
  });

  final String label;
  final int value;
  final bool showValue;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final text = showValue ? NumberFormat.formatPlain(value.toDouble()) : '—';
    return Semantics(
      label: showValue ? '$label، $text' : '$label، نامعلوم',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 10),
                fontWeight: FontWeight.w600,
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                maxLines: 1,
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: showValue ? hue : t.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A failed history read, said out loud with a way back.
class _FailedHistory extends StatelessWidget {
  const _FailedHistory({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FailureView(
      id: 'tasbih_history',
      title: 'آمار این ذکر خوانده نشد',
      detail: 'شمارش‌های ثبت‌شده پاک نشده‌اند؛ فقط این آمار خوانده نشد.',
      onRetry: onRetry,
      layout: FailureLayout.inline,
    );
  }
}

/// Opens the sheet for [tasbih]. The caller re-reads the provider afterwards,
/// so a rename that lands while the sheet is dismissed is not lost.
Future<void> showTasbihDhikrSheet(
  BuildContext context, {
  required TasbihModel tasbih,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => TasbihDhikrSheet(tasbih: tasbih),
  );
}
