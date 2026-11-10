import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/features/adhkar/tasbih/tasbih.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/azkar_settings_provider.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/design_system/glass_surface.dart';
import 'package:tawheeed/shared/widgets/async_screen.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';
import 'package:tawheeed/core/design_system/components/components.dart';

class AzkarListWidget extends ConsumerWidget {
  const AzkarListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasbihsAsync = ref.watch(tasbihProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final info = isDark ? AppTheme.darkInfo : AppTheme.lightInfo;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final onPrimary = dsOnAccent(context);
    // The tasbih section's fixed identity hue (2026 colored-pill language),
    // lifted toward white on dark surfaces to keep its contrast.
    final gold = isDark
        ? (Color.lerp(SectionHues.tasbih, Colors.white, 0.42) ??
            SectionHues.tasbih)
        : SectionHues.tasbih;

    return AsyncScreen<List<TasbihModel>>(
      asyncValue: tasbihsAsync,
      onRetry: () => ref.invalidate(tasbihProvider),
      data: (tasbihs) {
        final totalCount =
            tasbihs.fold<int>(0, (sum, t) => sum + t.currentCount);
        final totalTarget =
            tasbihs.fold<int>(0, (sum, t) => sum + t.targetCount);
        final autoReset = ref.watch(azkarSettingsProvider).autoReset;

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: 2 + tasbihs.length,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return GlassSurface(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.bar_chart,
                                  color: t.primary, size: 20),
                              const SizedBox(width: 8),
                              Text('آمار کل',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatCircle(
                                  label: autoReset ? 'امروز' : 'شمارنده کل',
                                  value: NumberFormat.formatPlain(
                                      totalCount.toDouble()),
                                  color: t.primary),
                              _StatCircle(
                                  label: 'هدف',
                                  value: NumberFormat.formatPlain(
                                      totalTarget.toDouble()),
                                  color: gold),
                              _StatCircle(
                                label: '% پیشرفت',
                                value: totalTarget > 0
                                    ? '${(totalCount * 100 / totalTarget).round()}%'
                                    : '0%',
                                color: info,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (totalTarget > 0)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value:
                                    (totalCount / totalTarget).clamp(0.0, 1.0),
                                minHeight: 12,
                                backgroundColor: t.divider,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    t.primary),
                              ),
                            ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('بازنشانی همه'),
                                    content: const Text(
                                        'آیا از بازنشانی شمارنده‌های همه‌ی اذکار اطمینان دارید؟'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('لغو')),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('بازنشانی'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && context.mounted) {
                                  await ref
                                      .read(tasbihProvider.notifier)
                                      .clearHistory();
                                }
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: Text('بازنشانی همه',
                                  style: TextStyle(
                                      fontSize: AppTheme.scaledFontSize(
                                          context, 12))),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (index == 1) return const SizedBox(height: 12);
                final zikr = tasbihs[index - 2];
                return _ZikrCard(
                  zikr: zikr,
                  ref: ref,
                  gold: gold,
                  onEditTarget: () => _showEditTargetDialog(context, ref, zikr),
                );
              },
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'add_azkar',
                tooltip: 'افزودن ذکر',
                onPressed: () => _showAddAzkarDialog(context, ref),
                backgroundColor: t.primary,
                child: Icon(Icons.add, color: onPrimary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditTargetDialog(
      BuildContext context, WidgetRef ref, TasbihModel zikr) {
    final ctrl = TextEditingController(text: zikr.targetCount.toString());
    bool hasError = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('تغییر تعداد هدف'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.rtl,
            autocorrect: false,
            inputFormatters: const [LatinGroupingFormatter(allowDecimal: false)],
            decoration: InputDecoration(
              labelText: 'تعداد جدید',
              errorText: hasError ? 'عدد معتبر وارد کنید' : null,
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
            FilledButton(
              onPressed: () {
                final text = _normalizeDigits(ctrl.text.trim());
                final target = int.tryParse(text);
                if (target != null && target > 0) {
                  ref
                      .read(tasbihProvider.notifier)
                      .updateTarget(zikr.id, target);
                  Navigator.pop(ctx);
                } else {
                  setDialogState(() => hasError = true);
                }
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    ).then((_) => ctrl.dispose());
  }

  void _showAddAzkarDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    final targetCtrl = TextEditingController(text: '100');
    bool textError = false;
    bool targetError = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('اذکار جدید'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  labelText: 'متن ذکر',
                  errorText: textError ? 'متن ذکر را وارد کنید' : null,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.rtl,
                autocorrect: false,
                inputFormatters: const [LatinGroupingFormatter(allowDecimal: false)],
                decoration: InputDecoration(
                  labelText: 'تعداد هدف',
                  errorText: targetError ? 'عدد معتبر وارد کنید' : null,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
            FilledButton(
              onPressed: () {
                final text = _normalizeDigits(targetCtrl.text.trim());
                final target = int.tryParse(text);
                if (ctrl.text.trim().isEmpty) {
                  setDialogState(() {
                    textError = true;
                    targetError = false;
                  });
                  return;
                }
                if (target == null || target <= 0) {
                  setDialogState(() {
                    targetError = true;
                    textError = false;
                  });
                  return;
                }
                ref
                    .read(tasbihProvider.notifier)
                    .startNew(text: ctrl.text.trim(), target: target);
                Navigator.pop(ctx);
              },
              child: const Text('افزودن'),
            ),
          ],
        ),
      ),
    ).then((_) {
      ctrl.dispose();
      targetCtrl.dispose();
    });
  }
}

class _StatCircle extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCircle(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final pal = TimeThemeKit.of(context).palette;
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 22),
                fontWeight: FontWeight.bold,
                color: dsContentColor(context, color))),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: pal.textMuted)),
      ],
    );
  }
}

class _ZikrCard extends StatelessWidget {
  final TasbihModel zikr;
  final WidgetRef ref;
  final Color gold;
  final VoidCallback onEditTarget;

  const _ZikrCard(
      {required this.zikr,
      required this.ref,
      required this.gold,
      required this.onEditTarget});

  @override
  Widget build(BuildContext context) {
    final pal = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final pct =
        zikr.targetCount > 0 ? zikr.currentCount / zikr.targetCount : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassSurface(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      zikr.targetDhikr,
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(
                            context, zikr.targetCount > 100 ? 17 : 20),
                        fontWeight: FontWeight.w600,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'حذف ذکر',
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('حذف ذکر'),
                          content: Text(
                              'آیا از حذف «${zikr.targetDhikr}» اطمینان دارید؟'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('لغو')),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: danger),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('حذف'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await ref.read(tasbihProvider.notifier).delete(zikr.id);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        ref.read(tasbihProvider.notifier).increment(zikr.id),
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('بازنشانی'),
                          content: const Text(
                              'آیا از بازنشانی شمارنده اطمینان دارید؟'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('لغو')),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                ref
                                    .read(tasbihProvider.notifier)
                                    .reset(zikr.id);
                              },
                              child: const Text('بازنشانی'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: pal.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${NumberFormat.formatPlain(zikr.currentCount.toDouble())}/${NumberFormat.formatPlain(zikr.targetCount.toDouble())}',
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 18),
                          fontWeight: FontWeight.bold,
                          color: pal.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onEditTarget,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? pal.surfaceMuted : pal.outline,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.edit,
                          size: 18,
                          color: isDark ? pal.textMuted : pal.textSecondary),
                    ),
                  ),
                  const Spacer(),
                  Text('${(pct * 100).round()}%',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: pal.textMuted)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: pal.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(pct >= 1.0
                            ? success
                            : pal.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Folds typed digits AND drops the grouping the entry formatter inserts,
/// so the `int.tryParse` at each dialog's save reads a real number.
String _normalizeDigits(String s) =>
    NumberFormat.normalizeDigits(s).replaceAll(',', '');
