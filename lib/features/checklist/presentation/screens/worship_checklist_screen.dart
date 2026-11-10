import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart';
import 'package:tawheeed/features/checklist/presentation/widgets/worship_list_widget.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// Daily worship checklist with a visual hero header.
///
/// Shows today's progress as an animated ring, the earned score, the current
/// streak and a motivational line, followed by the checklist itself. The
/// «راهنمای طهارت» / «ارزیابی و گزارش» shortcut rows were removed
/// (2026-10-13 user request).
class WorshipChecklistScreen extends ConsumerWidget {
  const WorshipChecklistScreen({super.key});

  /// Opens the template sheet: tapping a pack appends its items to the
  /// checklist (items already present by label are skipped).
  void _showTemplates(
      BuildContext context, WidgetRef ref, List<WorshipItem> current) {
    final existingLabels = current.map((i) => i.label).toSet();
    final t = TimeThemeKit.of(context).palette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('افزودن الگوی چک‌لیست',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 16),
                      fontWeight: FontWeight.w800,
                      color: t.textPrimary,
                    )),
                const SizedBox(height: 4),
                Text(
                  'یک مجموعهٔ آماده را به طاعات روزانه اضافه کنید؛ موارد تکراری کنار گذاشته می‌شوند.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: t.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                for (final pack in checklistTemplates) ...[
                  _TemplatePackTile(
                    pack: pack,
                    onTap: () {
                      final service = ref.read(evaluationProvider.notifier);
                      for (final item in pack.items) {
                        if (existingLabels.contains(item.label)) continue;
                        service.addCustomWorshipItem(
                            item.label, item.icon, item.points);
                      }
                      Navigator.of(sheetCtx).pop();
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(evaluationProvider).value;
    final items = state?.worshipItems ?? const <WorshipItem>[];
    final done = items.where((i) => i.done).length;
    final total = items.length;
    // maxScore includes prayer points (فرض/رواتب/ضحی) so the ring stays
    // consistent with the score, which now counts prayers as well.
    final maxScore = ref.read(evaluationProvider.notifier).dailyMaxScore;
    final score = state?.dailyScore ?? 0;
    final streak = state?.currentStreak ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'طاعات روزانه',
        actions: [
          IconButton(
            tooltip: 'الگوهای چک‌لیست',
            icon: const Icon(Icons.playlist_add),
            onPressed: () => _showTemplates(context, ref, items),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            _HeroHeader(
              done: done,
              total: total,
              score: score,
              maxScore: maxScore,
              streak: streak,
            ),
            const SizedBox(height: 20),
            const _SectionLabel(),
            const SizedBox(height: 12),
            const WorshipListWidget(),
            // The «راهنمای طهارت» / «ارزیابی و گزارش» shortcut rows were
            // deleted (2026-10-13 user request) — purification lives in More
            // and the ارزیابی tab is one tab away on the bottom nav.
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero header
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final int done;
  final int total;
  final int score;
  final int maxScore;
  final int streak;

  const _HeroHeader({
    required this.done,
    required this.total,
    required this.score,
    required this.maxScore,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fraction = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final complete = total > 0 && done >= total;

    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final heroColor = isDark
        ? const Color(0xFF3A2B1C)
        : const Color(0xFF5E4338);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: heroColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        child: Stack(
          children: [
            Positioned(
              top: -16,
              right: -12,
              child: Icon(
                Icons.spa_outlined,
                size: 120,
                color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.09),
              ),
            ),
            Positioned(
              bottom: -32,
              left: -18,
              child: Icon(
                Icons.star_rounded,
                size: 150,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
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
                            Text(
                              'طاعات روزانه',
                              style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 20),
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'پیشرفت امروز خود را ثبت کن',
                              style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 13),
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (streak > 0) _StreakChip(streak: streak),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _ProgressRing(
                        fraction: fraction,
                        done: done,
                        total: total,
                        complete: complete,
                        successColor: success,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'امتیاز امروز',
                              style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 12),
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Audit P-02: one reading instead of two adjacent
                            // `Row` children. A bare "/ $maxScore" in an RTL
                            // paragraph is read as "140 / 60" by anything
                            // that scans left-to-right, and TalkBack saw two
                            // separate nodes with no relationship. The app's
                            // canonical «X از Y» phrasing is direction-proof,
                            // and each number stays LTR-isolated.
                            Semantics(
                              container: true,
                              label: 'امتیاز امروز $score از $maxScore',
                              child: ExcludeSemantics(
                                child: Text.rich(
                                  TextSpan(children: [
                                    TextSpan(
                                      text: NumberFormat.ltrIsolated('$score'),
                                      style: TextStyle(
                                        fontSize: AppTheme.scaledFontSize(
                                            context, 34),
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          ' از ${NumberFormat.ltrIsolated('$maxScore')}',
                                      style: TextStyle(
                                        fontSize: AppTheme.scaledFontSize(
                                            context, 16),
                                        fontWeight: FontWeight.w600,
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ]),
                                  textDirection: TextDirection.rtl,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _message(fraction),
                              style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.92),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _message(double fraction) {
    if (fraction >= 1) return 'آفرین! همهٔ طاعات امروز انجام شد';
    if (fraction >= 0.5) return 'نیمهٔ راه پشت سر است، ادامه بده';
    if (fraction > 0) return 'قدم‌های کوچک، رسیدن به قله';
    return 'با یک طاعت کوچک، روزت را شروع کن';
  }
}

class _StreakChip extends StatelessWidget {
  final int streak;
  const _StreakChip({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department,
              size: 16, color: Colors.amberAccent),
          const SizedBox(width: 4),
          Text(
            'زنجیره: $streak',
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 12),
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double fraction;
  final int done;
  final int total;
  final bool complete;
  final Color successColor;

  const _ProgressRing({
    required this.fraction,
    required this.done,
    required this.total,
    required this.complete,
    required this.successColor,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: 86,
          height: 86,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(86),
                painter: _RingPainter(
                    fraction: value,
                    complete: complete,
                    successColor: successColor),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).round()}%',
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 18),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    NumberFormat.fraction(done, total),
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final bool complete;
  final Color successColor;

  const _RingPainter({
    required this.fraction,
    required this.complete,
    required this.successColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawCircle(center, radius, track);

    final f = fraction.clamp(0.0, 1.0);
    if (f > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = complete ? successColor : Colors.white;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * f,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.complete != complete;
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label & report card
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: t.tertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'چک‌لیست طاعات',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 15),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CHECKLIST TEMPLATES — ready-made packs (وضو / نماز / روزه / اذکار)
// ══════════════════════════════════════════════════════════════
class ChecklistTemplateItem {
  final String label;
  final IconData icon;
  final int points;
  const ChecklistTemplateItem(this.label, this.icon, this.points);
}

class ChecklistTemplatePack {
  final String name;
  final IconData icon;
  final List<ChecklistTemplateItem> items;
  const ChecklistTemplatePack(this.name, this.icon, this.items);
}

const checklistTemplates = <ChecklistTemplatePack>[
  ChecklistTemplatePack('وضو و طهارت', Icons.water_drop, [
    ChecklistTemplateItem('وضو با بسم‌الله و نیت', Icons.water_drop, 5),
    ChecklistTemplateItem('مسواک هنگام وضو', Icons.clean_hands, 5),
    ChecklistTemplateItem('دو رکعت بعد از وضو', Icons.self_improvement, 5),
  ]),
  ChecklistTemplatePack('نماز', Icons.mosque, [
    ChecklistTemplateItem('نماز اول وقت', Icons.mosque, 5),
    ChecklistTemplateItem('نماز جماعت', Icons.people, 5),
    ChecklistTemplateItem('نماز ضحی', Icons.wb_sunny, 5),
    ChecklistTemplateItem('نماز شب (تهجد)', Icons.nightlight, 5),
  ]),
  ChecklistTemplatePack('روزه', Icons.restaurant, [
    ChecklistTemplateItem('روزه دوشنبه/پنجشنبه', Icons.restaurant, 5),
    ChecklistTemplateItem('روزه ایام البیض', Icons.nightlight, 5),
    ChecklistTemplateItem('روزه عرفه', Icons.wb_sunny, 5),
    ChecklistTemplateItem('افطاری دادن', Icons.volunteer_activism, 5),
  ]),
  ChecklistTemplatePack('اذکار و قرآن', Icons.menu_book, [
    ChecklistTemplateItem('اذکار صبح', Icons.wb_sunny, 5),
    ChecklistTemplateItem('اذکار شب', Icons.nightlight, 5),
    ChecklistTemplateItem('ورد قرآن روزانه', Icons.menu_book, 5),
    ChecklistTemplateItem('صدقه هرچند اندک', Icons.favorite, 5),
  ]),
];

class _TemplatePackTile extends StatelessWidget {
  final ChecklistTemplatePack pack;
  final VoidCallback onTap;
  const _TemplatePackTile({required this.pack, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: t.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.outline),
          ),
          child: Row(
            children: [
              Icon(pack.icon, size: 22, color: TopicHues.worshipChecklist),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.name,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pack.items.length} طاعت',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline,
                  size: 20, color: TopicHues.worshipChecklist),
            ],
          ),
        ),
      ),
    );
  }
}
