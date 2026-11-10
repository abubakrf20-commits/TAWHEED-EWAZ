import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/family_faith/data/family_faith_repository.dart';
import 'package:tawheeed/features/personal/family_faith/family_faith_providers.dart';
import 'package:tawheeed/features/personal/family_faith/family_faith_settings.dart';
import 'package:tawheeed/features/personal/family_faith/presentation/family_faith_style.dart';
import 'package:tawheeed/features/personal/family_faith/presentation/savings_sheets.dart';
import 'package:tawheeed/features/personal/family_faith/savings/savings_models.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_sheet_kit.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_widgets.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/currency_aware_state.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «قلک» — the goals list. Reached from its tile in «اطلاعات من».
class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key, this.nowOverride});

  /// Test seam for the ETA/monthly figures and the goldens.
  final DateTime? nowOverride;

  DateTime _now() => nowOverride ?? DateTime.now();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final async = ref.watch(savingsStoreProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: t.primary,
        iconTheme: IconThemeData(color: t.primary),
        title: Text(
          'قلک',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            color: t.primary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'بازگشت',
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'هدف تازه',
            icon: const Icon(Icons.add),
            onPressed: () => showGoalSheet(context),
          ),
          IconButton(
            tooltip: 'تنظیمات یادآوری',
            icon: const Icon(Icons.tune),
            onPressed: () => showSavingsReminderSettings(context, ref),
          ),
        ],
      ),
      // The unit is chosen in Settings; this page stays open in another tab and
      // must follow the store instead of keeping the unit it opened with.
      body: ValueListenableBuilder<AppCurrency>(
        valueListenable: CurrencyStore.calculators.notifier,
        builder: (context, _, __) => SafeArea(
          child: switch (async) {
            AsyncData(:final value) => _body(context, ref, value),
            AsyncError(:final error) => FailureView(
                id: 'savings_goals',
                title: 'خواندن هدف‌ها ممکن نشد',
                detail: 'هدف‌ها و مبلغ‌های کنارگذاشته‌شده پاک '
                    'نشده‌اند؛ فقط فهرستشان باز نشد.',
                onRetry: () => ref.invalidate(savingsStoreProvider),
                error: error,
                layout: FailureLayout.page,
              ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, SavingsSnapshot snapshot) {
    final now = _now();
    final goals = snapshot.active;
    if (snapshot.goals.isEmpty) {
      return CareEmptyState(
        accent: familySavingsColor,
        icon: Icons.savings_outlined,
        title: 'هنوز هدفی نساخته‌اید',
        body: 'برای یک سفر، یک خرید یا هر چیز دیگری هدف بگذارید و هر وقت '
            'خواستید مبلغی کنار بگذارید. برنامه فقط جمع و پیشرفت را نشان می‌دهد.',
        actionLabel: 'ساختن نخستین هدف',
        onAction: () => showGoalSheet(context),
      );
    }

    final unit = CurrencyStore.calculators.current.unit;
    var aggSaved = 0.0;
    var aggTarget = 0.0;
    var completed = 0;
    for (final goal in goals) {
      final p = savingsProgress(
        goal: goal,
        deposits: snapshot.depositsFor(goal.id),
        now: now,
      );
      aggSaved += p.saved;
      aggTarget += p.target;
      if (p.isComplete) completed++;
    }
    final aggFraction =
        aggTarget <= 0 ? 0.0 : (aggSaved / aggTarget).clamp(0.0, 1.0);

    final archivedGoals =
        snapshot.goals.where((g) => g.archived).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 32),
      children: [
        _SavingsHero(
          saved: aggSaved,
          target: aggTarget,
          fraction: aggFraction,
          activeCount: goals.length,
          completedCount: completed,
          unit: unit,
        ),
        const SizedBox(height: 10),
        for (final goal in goals) ...[
          _GoalCard(
            goal: goal,
            progress: savingsProgress(
              goal: goal,
              deposits: snapshot.depositsFor(goal.id),
              now: now,
            ),
            unit: unit,
            onTap: () => context.push('/personal-info/savings/${goal.id}'),
          ),
          const SizedBox(height: 8),
        ],
        if (archivedGoals.isNotEmpty) ...[
          const SizedBox(height: 4),
          _ArchivedSection(
            goals: archivedGoals,
            snapshot: snapshot,
            now: now,
            unit: unit,
            onOpen: (goal) => context.push('/personal-info/savings/${goal.id}'),
          ),
        ],
      ],
    );
  }
}

/// Aggregate «قلک» header: total saved across every active goal, an overall
/// ring, and the active / completed counts — a single glance at the whole kitty.
class _SavingsHero extends StatelessWidget {
  const _SavingsHero({
    required this.saved,
    required this.target,
    required this.fraction,
    required this.activeCount,
    required this.completedCount,
    required this.unit,
  });

  final double saved;
  final double target;
  final double fraction;
  final int activeCount;
  final int completedCount;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [familySavingsColor, Color(0xFF2E7D32)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: familySavingsColor.withValues(alpha: .25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.savings_outlined,
                  size: 18, color: Colors.white.withValues(alpha: .9)),
              const SizedBox(width: 6),
              Text(
                'قلک',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: .95),
                ),
              ),
              const Spacer(),
              Text(
                'مجموع پس‌انداز',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: Colors.white.withValues(alpha: .9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeroRing(fraction: fraction),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      NumberFormat.formatMoney(saved, unit),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 19),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'از ${NumberFormat.formatMoney(target, unit)}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: Colors.white.withValues(alpha: .82),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _HeroChip(label: '$activeCount هدف فعال'),
                        if (completedCount > 0)
                          _HeroChip(label: '$completedCount تکمیل‌شده'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 10),
            color: Colors.white,
          ),
        ),
      );
}

/// Collapsible list of archived goals, so a finished or retired target leaves
/// the main list but stays reachable (and restorable) instead of being deleted.
class _ArchivedSection extends StatelessWidget {
  const _ArchivedSection({
    required this.goals,
    required this.snapshot,
    required this.now,
    required this.unit,
    required this.onOpen,
  });

  final List<SavingsGoal> goals;
  final SavingsSnapshot snapshot;
  final DateTime now;
  final String unit;
  final ValueChanged<SavingsGoal> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        visualDensity: VisualDensity.compact,
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Icon(Icons.archive_outlined, size: 18, color: t.textMuted),
        title: Text(
          'هدف‌های بایگانی‌شده (${goals.length})',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11),
            color: t.textSecondary,
          ),
        ),
        children: [
          for (final goal in goals) ...[
            _GoalCard(
              goal: goal,
              progress: savingsProgress(
                goal: goal,
                deposits: snapshot.depositsFor(goal.id),
                now: now,
              ),
              unit: unit,
              onTap: () => onOpen(goal),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.progress,
    required this.unit,
    required this.onTap,
  });

  final SavingsGoal goal;
  final SavingsProgress progress;
  final String unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          _PiggyJar(
            fraction: progress.fraction,
            accent: savingsAccentFor(goal.accentKey),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        goal.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      savingsIconFor(goal.iconKey),
                      size: 14,
                      color: dsContentColor(context, savingsAccentFor(goal.accentKey)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${NumberFormat.formatMoney(progress.saved, unit)} از '
                  '${NumberFormat.formatMoney(progress.target, unit)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: t.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _EtaChip(
                    progress: progress,
                    accent: savingsAccentFor(goal.accentKey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EtaChip extends StatelessWidget {
  const _EtaChip({required this.progress, required this.accent});

  final SavingsProgress progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final label = progress.isComplete
        ? 'تکمیل شد ✓'
        : progress.etaDays != null
            ? 'با همین روند حدود ${_daysLabel(progress.etaDays!)}'
            : progress.monthsToDeadline != null
                ? 'تا تاریخ هدف: ${progress.monthsToDeadline} ماه'
                : 'در حال جمع‌آوری';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 10),
          fontWeight: FontWeight.w600,
          color: dsContentColor(context, accent),
        ),
      ),
    );
  }

  static String _daysLabel(int days) {
    if (days <= 45) return '$days روز';
    final months = (days / 30).round();
    return '$months ماه';
  }
}

/// «قلک شیشهای» — the goal's progress as a real jar that fills with coins.
///
/// The fill is animated from zero on first paint and from the previous level
/// on every deposit, which is the «coins dropping in» moment. Reduce-motion
/// turns the animation into a single static frame.
class _PiggyJar extends StatelessWidget {
  const _PiggyJar({
    required this.fraction,
    required this.accent,
    this.size = 52,
  });

  final double fraction;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final target = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: target),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 720),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _JarPainter(
                fill: value,
                accent: accent,
                glass: t.surfaceAlt,
                outline: t.outline,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: size * .10),
              child: Text(
                '${(value * 100).round()}٪',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize:
                      AppTheme.scaledFontSize(context, size <= 60 ? 10 : 20),
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JarPainter extends CustomPainter {
  const _JarPainter({
    required this.fill,
    required this.accent,
    required this.glass,
    required this.outline,
  });

  final double fill;
  final Color accent;
  final Color glass;
  final Color outline;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final bodyTop = h * .17;
    final bodyBottom = h * .96;
    final body = RRect.fromLTRBR(
      w * .10,
      bodyTop,
      w * .90,
      bodyBottom,
      Radius.circular(w * .19),
    );

    canvas.drawRRect(body, Paint()..color = glass);
    final level = bodyBottom - (bodyBottom - bodyTop) * fill;

    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(
      Rect.fromLTRB(0, level, w, bodyBottom),
      Paint()..color = accent.withValues(alpha: .26),
    );
    canvas.drawOval(
      Rect.fromLTRB(-w * .1, level - h * .022, w * 1.1, level + h * .022),
      Paint()..color = accent.withValues(alpha: .34),
    );

    // Coins only appear below the liquid line — the jar visibly fills.
    const spots = <Offset>[
      Offset(.28, .55),
      Offset(.52, .68),
      Offset(.73, .58),
      Offset(.37, .84),
      Offset(.64, .90),
      Offset(.80, .78),
      Offset(.20, .76),
    ];
    final coinR = w * .055;
    for (final spot in spots) {
      final cy = bodyTop + (bodyBottom - bodyTop) * spot.dy;
      if (cy < level + coinR) continue;
      final c = Offset(w * spot.dx, cy);
      canvas.drawCircle(
          c, coinR, Paint()..color = accent.withValues(alpha: .70));
      canvas.drawCircle(
          c, coinR * .55, Paint()..color = accent.withValues(alpha: .30));
    }
    canvas.restore();

    // Glass shine + rim.
    canvas.drawRRect(
      RRect.fromLTRBR(
        w * .16,
        bodyTop + h * .06,
        w * .23,
        bodyBottom - h * .14,
        Radius.circular(w * .04),
      ),
      Paint()..color = Colors.white.withValues(alpha: .26),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Lid with a coin slot.
    final lidH = h * .10;
    canvas.drawRRect(
      RRect.fromLTRBR(
        w * .24,
        h * .03,
        w * .76,
        h * .03 + lidH,
        Radius.circular(lidH * .45),
      ),
      Paint()..color = accent.withValues(alpha: .88),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        w * .41,
        h * .058,
        w * .59,
        h * .058 + h * .018,
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white.withValues(alpha: .80),
    );
  }

  @override
  bool shouldRepaint(covariant _JarPainter old) =>
      old.fill != fill || old.accent != accent || old.glass != glass;
}

/// Four tiny milestone stamps — the small «celebration» for every quarter of
/// the goal, always visible instead of a one-shot confetti that a user misses.
class _MilestoneStrip extends StatelessWidget {
  const _MilestoneStrip({required this.fraction, required this.accent});

  final double fraction;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const steps = [25, 50, 75, 100];
    return Row(
      children: [
        for (final step in steps) ...[
          if (step != 25) const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: fraction * 100 >= step
                    ? accent.withValues(alpha: .16)
                    : t.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: fraction * 100 >= step
                      ? accent.withValues(alpha: .45)
                      : t.outline,
                  width: .6,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    fraction * 100 >= step
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 11,
                    color: fraction * 100 >= step
                        ? dsContentColor(context, accent)
                        : t.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    NumberFormat.ltrIsolated('$step%'),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w700,
                      color: fraction * 100 >= step
                          ? dsContentColor(context, accent)
                          : t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Running-balance sparkline over the deposit history.
class _BalanceTrendCard extends StatelessWidget {
  const _BalanceTrendCard({required this.values, required this.accent});

  final List<double> values;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'روند موجودی',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              fontWeight: FontWeight.w700,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: CustomPaint(
              painter: _TrendPainter(values: values, color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final span = max - min < 0.0001 ? 1.0 : max - min;
    final dx = size.width / (values.length - 1);
    Offset at(int i) => Offset(
          i * dx,
          size.height - 6 - ((values[i] - min) / span) * (size.height - 12),
        );
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..color = color.withValues(alpha: .14)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final last = at(values.length - 1);
    canvas.drawCircle(last, 6, Paint()..color = color.withValues(alpha: .20));
    canvas.drawCircle(last, 3.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values.length != values.length || old.color != color;
}

/// One goal in full: ring, figures, deposit history and the quick actions.
class SavingsGoalScreen extends ConsumerStatefulWidget {
  const SavingsGoalScreen({super.key, required this.goalId, this.nowOverride});

  final String goalId;
  final DateTime? nowOverride;

  @override
  ConsumerState<SavingsGoalScreen> createState() => _SavingsGoalScreenState();
}

class _SavingsGoalScreenState extends ConsumerState<SavingsGoalScreen>
    with CurrencyAwareState<SavingsGoalScreen> {
  List<double> _presets = SavingsPresetStore.defaults;

  DateTime get _now => widget.nowOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final presets = await SavingsPresetStore.load();
    if (!mounted) return;
    setState(() => _presets = presets);
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final async = ref.watch(savingsStoreProvider);
    final unit = CurrencyStore.calculators.current.unit;

    SavingsGoal? goal;
    final snap = async.value;
    if (snap != null) {
      for (final candidate in snap.goals) {
        if (candidate.id == widget.goalId) {
          goal = candidate;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: t.primary,
        iconTheme: IconThemeData(color: t.primary),
        title: Text(
          goal?.archived == true ? 'هدف بایگانی‌شده' : 'جزئیات هدف',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            color: t.primary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'بازگشت',
          onPressed: () => context.pop(),
        ),
        actions: [
          if (goal != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'بیشتر',
              onSelected: (value) async {
                if (value == 'archive' || value == 'unarchive') {
                  final navigator = Navigator.of(context);
                  await ref.read(savingsStoreProvider.notifier).updateGoal(
                        goal!.copyWith(archived: value == 'archive'),
                      );
                  if (!mounted) return;
                  navigator.pop();
                } else if (value == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('حذف هدف'),
                      content: Text(
                        'هدف «${goal!.title}» و تمام واریزهای آن برای همیشه حذف '
                        'می‌شوند. این کار قابل بازگشت نیست.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text('انصراف'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: const Text('حذف'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref
                        .read(savingsStoreProvider.notifier)
                        .deleteGoal(goal!.id);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: goal!.archived ? 'unarchive' : 'archive',
                  child: Text(goal.archived ? 'خروج از بایگانی' : 'بایگانی هدف'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('حذف هدف'),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: switch (async) {
          AsyncData(:final value) => _body(context, value, unit),
          AsyncError() => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'خواندن قلک ممکن نشد؛ دوباره تلاش کنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => ref.invalidate(savingsStoreProvider),
                      child: const Text('تلاش دوباره'),
                    ),
                  ],
                ),
              ),
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _body(BuildContext context, SavingsSnapshot snapshot, String unit) {
    final t = TimeThemeKit.of(context).palette;
    SavingsGoal? goal;
    for (final candidate in snapshot.goals) {
      if (candidate.id == widget.goalId) goal = candidate;
    }
    if (goal == null) {
      return Center(
        child: Text(
          'این هدف پیدا نشد (شاید حذف شده باشد).',
          style: TextStyle(fontFamily: AppTheme.fontFamily, color: t.textMuted),
        ),
      );
    }
    final deposits = snapshot.depositsFor(goal.id);
    final progress =
        savingsProgress(goal: goal, deposits: deposits, now: _now);

    // Running balance after each entry, oldest first, so the history can show
    // how much of the kitty each deposit/withdrawal left behind.
    final balanceById = <String, double>{};
    {
      var running = 0.0;
      final ascending = [...deposits]..sort((a, b) => a.date.compareTo(b.date));
      for (final d in ascending) {
        running += d.amount;
        balanceById[d.id] = running;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 32),
      children: [
        AppCard(
          child: Column(
            children: [
              _PiggyJar(
                fraction: progress.fraction,
                accent: savingsAccentFor(goal.accentKey),
                size: 132,
              ),
              const SizedBox(height: 8),
              _MilestoneStrip(
                fraction: progress.fraction,
                accent: savingsAccentFor(goal.accentKey),
              ),
              const SizedBox(height: 10),
              Text(
                goal.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${NumberFormat.formatMoney(progress.saved, unit)} از '
                '${NumberFormat.formatMoney(progress.target, unit)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: t.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                progress.isComplete
                    ? 'هدف تکمیل شده است.'
                    : 'باقی‌مانده: ${NumberFormat.formatMoney(progress.remaining, unit)}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: t.textMuted,
                ),
              ),
              if (goal.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    goal.note,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10.5),
                      height: 1.6,
                      color: t.textSecondary,
                    ),
                  ),
                ),
              ],
              if (progress.perMonthNeeded != null) ...[
                const SizedBox(height: 6),
                _EtaChip(progress: progress, accent: savingsAccentFor(goal.accentKey)),
                const SizedBox(height: 4),
                Text(
                  'برای رسیدن تا تاریخ هدف '
                  '(${progress.monthsToDeadline} ماه دیگر) حدود '
                  '${NumberFormat.formatMoney(progress.perMonthNeeded!, unit)} '
                  'در ماه لازم است.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10.5),
                    height: 1.5,
                    color: t.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: familySavingsColor,
                  foregroundColor: dsOnAccent(context),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                onPressed: () => _deposit(goal!, progress, deposits),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('واریز'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: deposits.isEmpty
                    ? null
                    : () => showDepositSheet(context, goal!, withdraw: true),
                // Withdrawal is destructive: red text and a red-tinted border
                // so it cannot be mistaken for the neutral outline beside it.
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: .55),
                  ),
                ),
                icon: const Icon(Icons.remove, size: 17),
                label: const Text('برداشت'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                'تاریخچهٔ واریز',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _editPresets(unit),
              icon: const Icon(Icons.tune, size: 15),
              label: const Text('میان‌برها'),
            ),
          ],
        ),
        if (deposits.length >= 2) ...[
          _BalanceTrendCard(
            values: [
              for (final d in ([...deposits]
                ..sort((a, b) => a.date.compareTo(b.date))))
                balanceById[d.id] ?? 0,
            ],
            accent: savingsAccentFor(goal.accentKey),
          ),
          const SizedBox(height: 8),
        ],
        if (deposits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'هنوز واریزی ثبت نشده است.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: t.textMuted,
              ),
            ),
          )
        else
          for (final deposit in deposits) ...[
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    deposit.isWithdrawal
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 16,
                    color: deposit.isWithdrawal ? t.textMuted : familySavingsColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          careJalaliLong(deposit.date),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11.5),
                            color: t.textPrimary,
                          ),
                        ),
                        if (deposit.note.isNotEmpty)
                          Text(
                            deposit.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 10),
                              color: t.textMuted,
                            ),
                          ),
                        Text(
                          'موجودی: ${NumberFormat.formatMoney(balanceById[deposit.id] ?? 0, unit)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 9),
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    NumberFormat.formatMoney(deposit.amount, unit),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11.5),
                      fontWeight: FontWeight.w700,
                      color: deposit.isWithdrawal
                          ? t.textMuted
                          : dsContentColor(context, familySavingsColor),
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 17,
                    tooltip: 'بیشتر',
                    onSelected: (value) async {
                      if (value == 'delete') {
                        await ref
                            .read(savingsStoreProvider.notifier)
                            .deleteDeposit(deposit.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('حذف این واریز')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
      ],
    );
  }

  Future<void> _deposit(
    SavingsGoal goal,
    SavingsProgress before,
    List<Deposit> deposits,
  ) async {
    await showDepositSheet(context, goal, presets: _presets);
    if (!mounted) return;
    final snapshot = ref.read(savingsStoreProvider).value;
    if (snapshot == null) return;
    final after = savingsProgress(
      goal: goal,
      deposits: snapshot.depositsFor(goal.id),
      now: _now,
    );
    final milestone = crossedMilestone(before.fraction, after.fraction);
    if (milestone != null) _celebrate(milestone);
  }

  /// One gentle celebration per milestone: a scaling check, ≤ 250 ms, and
  /// nothing at all when the system asks for reduced motion.
  void _celebrate(int milestone) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final t = TimeThemeKit.of(dialogContext).palette;
        final card = Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 46, color: familySavingsColor),
              const SizedBox(height: 10),
              Text(
                '$milestone٪ هدف',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(dialogContext, 15),
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'یک قدم دیگر نزدیک شدید.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(dialogContext, 11),
                  color: t.textMuted,
                ),
              ),
            ],
          ),
        );
        return GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Container(
            color: Colors.black.withValues(alpha: .25),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(40),
            child: reduceMotion
                ? card
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: .85, end: 1),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: card,
                  ),
          ),
        );
      },
    );
  }

  Future<void> _editPresets(String unit) async {
    final controllers = [
      for (final value in _presets)
        TextEditingController(text: NumberFormat.formatPlain(value)),
    ];
    // The app's one sheet contract (handle, corner radius, insets) instead of
    // a raw AlertDialog, so this editor matches every other editor here.
    final result = await showCareSheet<List<double>>(
      context,
      accent: familySavingsColor,
      child: Column(
        children: [
          const CareSheetTitle(
            title: 'میان‌برهای واریز',
            subtitle:
                'دکمه‌های میان‌بر روی شیت واریز با این مبالغ پر می‌شوند.',
          ),
          for (final controller in controllers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'مبلغ ($unit)',
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('انصراف'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop([
                    for (final controller in controllers)
                      NumberFormat.parse(controller.text),
                  ]),
                  child: const Text('ذخیره'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    for (final controller in controllers) {
      controller.dispose();
    }
    if (result == null) return;
    final cleaned = [
      for (final value in result)
        if (value > 0) value,
    ];
    final next = cleaned.isEmpty ? SavingsPresetStore.defaults : cleaned;
    await SavingsPresetStore.save(next);
    if (!mounted) return;
    setState(() => _presets = next);
  }
}

/// «تنظیمات یادآوری» برای قلک: فعال/غیرفعال، ساعت و یادآوری ماهانه.
Future<void> showSavingsReminderSettings(
  BuildContext context,
  WidgetRef ref,
) async {
  final settings = await SavingsReminderStore.load();
  if (!context.mounted) return;

  var enabled = settings.enabled;
  var hour = settings.hour;
  var remindMonthly = settings.remindMonthly;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TimeThemeKit.of(context).palette.elevated,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final t = TimeThemeKit.of(sheetContext).palette;
        final accent = familySavingsColor;

        Future<void> save() async {
          final next = SavingsReminderSettings(
            enabled: enabled,
            hour: hour,
            remindMonthly: remindMonthly,
          );
          await SavingsReminderStore.save(next);
          final data = ref.read(savingsStoreProvider).value;
          if (data != null) {
            unawaited(
              ref.read(savingsRemindersProvider).sync(data).catchError(
                    (Object e, StackTrace s) =>
                        AppLogger.warning('SavingsReminder', 're-sync failed: $e'),
                  ),
            );
          }
          if (!sheetContext.mounted) return;
          Navigator.of(sheetContext).pop();
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: AppCard(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SheetHandle(),
                    Text(
                      'تنظیمات یادآوری قلک',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CareSwitchRow(
                      label: 'یادآوری واریز فعال باشد',
                      value: enabled,
                      accent: accent,
                      onChanged: (v) => setSheetState(() => enabled = v),
                    ),
                    const SizedBox(height: 12),
                    CareSwitchRow(
                      label: 'یادآوری ماهانه',
                      value: remindMonthly,
                      accent: accent,
                      onChanged: (v) => setSheetState(() => remindMonthly = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ساعت یادآوری',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              color: t.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 70,
                          child: TextField(
                            controller: TextEditingController(
                              text: hour.toString().padLeft(2, '0'),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              color: t.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                            onChanged: (v) {
                              final h = int.tryParse(v);
                              if (h != null && h >= 0 && h <= 23) {
                                setSheetState(() => hour = h);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    CareSheetSubmit(
                      label: 'ذخیره تنظیمات',
                      accent: accent,
                      onPressed: save,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}


/// The overview hero keeps a ring: a glass jar would fight the solid green
/// header, while the goal list and detail page both use [_PiggyJar].
class _HeroRing extends StatelessWidget {
  const _HeroRing({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    const size = 78.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              strokeWidth: 6,
              backgroundColor: Colors.white.withValues(alpha: .24),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          Text(
            '${(fraction * 100).round()}٪',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14),
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
