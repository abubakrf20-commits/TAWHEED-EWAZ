import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/kids/data/kids_dao.dart';
import 'package:tawheeed/features/personal2/kids/domain/kid_logic.dart';
import 'package:tawheeed/features/personal2/kids/presentation/providers/kids_providers.dart';
import 'package:tawheeed/features/personal2/shared/parent_lock.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

/// «حالت کودک» — the screen the child uses.
///
/// Design rules from the brief that shape every decision here:
///  • gentle, never shaming: a missed day reads «مانده» (left), not a red X;
///  • no public comparison between siblings;
///  • tap marks done with a short haptic + scale animation (<= 250 ms) and the
///    animation is skipped when the platform asks to reduce motion;
///  • leaving needs the parent PIN when one is configured;
///  • nothing initialises before the first frame — the providers are watched in
///    build, and the wake lock is acquired after the first frame.
class ChildModeScreen extends ConsumerStatefulWidget {
  const ChildModeScreen({super.key, required this.kidId});

  final String kidId;

  @override
  ConsumerState<ChildModeScreen> createState() => _ChildModeScreenState();
}

class _ChildModeScreenState extends ConsumerState<ChildModeScreen> {
  /// The habit whose celebration is animating (null = none).
  String? _celebrating;
  Timer? _undoTimer;
  String? _undoLogId;
  bool _keepAwake = false;

  @override
  void initState() {
    super.initState();
    // After the first frame: nothing about this screen may delay the first
    // paint or the tap that got here.
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyWakelock());
  }

  Future<void> _applyWakelock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool(kidKeepAwakePrefKey) ?? false;
      if (!mounted) return;
      _keepAwake = value;
      if (value) await WakelockPlus.enable();
    } catch (e) {
      // A refused wake lock is cosmetic; the screen still works.
    }
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    if (_keepAwake) {
      unawaited(WakelockPlus.disable().catchError((_) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(kidDayProvider(widget.kidId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        // The brief: system back/exit requires the PIN when the parent lock is
        // on. `canPop: false` plus an explicit check is the only way to see the
        // back gesture before the route is gone.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          await _exitChildMode();
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: day.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => FailureView(
                id: 'child_mode_load',
                title: 'دفتر این فرزند باز نشد',
                detail: 'کارها و ستاره‌های ثبت‌شده پاک نشده‌اند؛ فقط '
                    'خواندنشان ناموفق بود.',
                onRetry: () => ref.invalidate(kidDayProvider(widget.kidId)),
                layout: FailureLayout.page,
                error: e,
              ),
              data: (state) => state == null
                  ? const AppEmptyState(
                      icon: Icons.person_off_outlined,
                      message: 'این فرزند پیدا نشد',
                      subtitle: 'ممکن است از دفتر کودک حذف شده باشد.',
                    )
                  : _body(context, state),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exitChildMode() async {
    final allowed = await ParentLock.requirePin(
      context,
      reason: 'برای خروج از حالت کودک رمز والدین را وارد کنید',
    );
    if (!allowed || !mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/personal-tools/kids');
    }
  }

  Widget _body(BuildContext context, KidDayState state) {
    final t = TimeThemeKit.of(context).palette;
    final color = KidColors.of(state.kid.colorKey);
    final total = state.scheduled.length + state.prayersScheduled;
    final done = state.habitsDone + state.prayersDone;
    final nextReward = _nextReward(state);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        _header(context, state, color),
        const SizedBox(height: 14),
        if (state.prayersScheduled > 0) ...[
          Text(
            'نمازهای امروز',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _prayerRow(context, state, color),
          const SizedBox(height: 16),
        ],
        Text(
          'کارهای خوب امروز',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: t.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (state.scheduled.isEmpty)
          AppCard(
            child: Text(
              'برای امروز کاری برنامه‌ریزی نشده. یک روز خوب داشته باشی!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                color: t.textSecondary,
              ),
            ),
          )
        else
          _habitGrid(context, state, color),
        const SizedBox(height: 16),
        _starJar(context, state, color, nextReward),
        const SizedBox(height: 10),
        if (_undoLogId != null) _undoBar(context, color),
        if (total > 0 && done == total)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'امروز همهٔ کارها انجام شد. آفرین!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
      ],
    );
  }

  RewardRecord? _nextReward(KidDayState state) {
    // The nearest affordable-soon reward: the cheapest one not yet affordable.
    final affordable = state.spendable;
    RewardRecord? candidate;
    for (final r in state.rewards) {
      if (r.costStars <= affordable) continue;
      if (candidate == null || r.costStars < candidate.costStars) candidate = r;
    }
    return candidate ?? state.rewards.firstOrNull;
  }

  Widget _header(BuildContext context, KidDayState state, Color color) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        // Initial avatar — the brief forbids photos of children outright.
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            state.kid.name.characters.first,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'سلام ${state.kid.name}',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 17),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Personal2Colors.kidsStars.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.star_rounded,
                  size: 16, color: Personal2Colors.kidsStars),
              const SizedBox(width: 4),
              Text(
                '${state.spendable}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'خروج',
          icon: const Icon(Icons.lock_outline, size: 20),
          onPressed: _exitChildMode,
        ),
      ],
    );
  }

  /// The five prayer chips, one timer, no per-second work.
  ///
  /// Times come from the app's own schedule (`prayerTimesProvider`); this
  /// screen never calculates a prayer time. If the times have not loaded the
  /// chips are simply absent — never guessed.
  Widget _prayerRow(BuildContext context, KidDayState state, Color color) {
    final times = ref.watch(prayerTimesProvider).value;
    if (times == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final day = times.date;
    DateTime at(dynamic time) =>
        DateTime(day.year, day.month, day.day, time.hour, time.minute);

    final windows = DayPrayerWindows.from(
      fajr: at(times.fajr.time),
      sunrise: at(times.shorouq.time),
      dhuhr: at(times.duhr.time),
      asr: at(times.asr.time),
      maghrib: at(times.maghrib.time),
      isha: at(times.isha.time),
    );

    // "Day over" is judged against the kids day, not the calendar day: with a
    // dayStart of 03:00, 01:30 still belongs to yesterday and its prayers are
    // still markable.
    final calendarDayKey = kidDayKey(now, dayStartMinutes: state.settings.dayStartMinutes);
    final dayOver = calendarDayKey != state.dayKey;

    final enabled = [
      for (final p in KidPrayer.values)
        if (state.prayerConfig.enabled.contains(p)) p,
    ];

    return Row(
      children: [
        for (var i = 0; i < enabled.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _prayerChip(
              context,
              state,
              enabled[i],
              windows.windowsFor(enabled[i]),
              now,
              dayOver,
              color,
            ),
          ),
        ],
      ],
    );
  }

  Widget _prayerChip(
    BuildContext context,
    KidDayState state,
    KidPrayer prayer,
    PrayerWindows windows,
    DateTime now,
    bool dayOver,
    Color color,
  ) {
    final t = TimeThemeKit.of(context).palette;
    final log = state.logForPrayer(prayer);
    final chipState = prayerChipState(
      prayer: prayer,
      windows: windows,
      now: now,
      logged: log?.status,
      dayOver: dayOver,
      lateAllowed: state.prayerConfig.lateAllowed,
    );

    final (fill, ink, icon) = switch (chipState) {
      PrayerChipState.done => (
          color.withValues(alpha: .18),
          color,
          Icons.check_rounded
        ),
      PrayerChipState.now => (
          color.withValues(alpha: .10),
          color,
          Icons.circle_outlined
        ),
      PrayerChipState.lateAvailable => (
          DsStatus.warning(context).withValues(alpha: .14),
          DsStatus.warning(context),
          Icons.schedule_rounded
        ),
      PrayerChipState.locked => (
          t.surfaceMuted,
          t.textMuted,
          Icons.lock_outline
        ),
      PrayerChipState.missed => (
          t.surfaceMuted,
          t.textMuted,
          Icons.remove_rounded
        ),
    };

    final markable = canMarkPrayer(chipState);

    return Semantics(
      label: 'نماز ${prayer.titleFa}',
      value: switch (chipState) {
        PrayerChipState.done => 'انجام شد',
        PrayerChipState.now => 'وقت آن است',
        PrayerChipState.lateAvailable => 'قضا',
        PrayerChipState.locked => 'هنوز نشده',
        PrayerChipState.missed => 'انجام نشد',
      },
      button: markable,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: markable
            ? () => _markPrayer(state, prayer, chipState)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: chipState == PrayerChipState.now
                  ? color.withValues(alpha: .55)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: ink),
              const SizedBox(height: 4),
              Text(
                prayer.titleFa,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _habitGrid(BuildContext context, KidDayState state, Color color) {
    // Two columns, one row at a time: the brief's 2-column grid of large tiles.
    final habits = state.scheduled;
    // Inside a ListView: shrink-wrap and a bounded height so the grid lays out
    // lazily but never asserts on an unbounded height.
    //
    // The tile is an icon, up to two title lines and a status line, so its
    // height cannot follow the column width alone: at 320 dp with 1.3× text a
    // width-derived box is ~34 px short and the tile clips its status row. The
    // row height is therefore the larger of the design's width ratio and a
    // text-scaled floor.
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - 8) / 2;
        final extent = math.max(cellWidth / 1.32, 112 * textScale);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: extent,
          ),
          itemCount: habits.length,
          itemBuilder: (context, i) =>
              _habitTile(context, state, habits[i], color),
        );
      },
    );
  }

  Widget _habitTile(BuildContext context, KidDayState state, HabitSpec habit, Color color) {
    final t = TimeThemeKit.of(context).palette;
    final log = state.logForHabit(habit.id);
    final done = log?.status == KidLogStatus.approved;
    final pending = log?.status == KidLogStatus.pending;
    final celebrating = _celebrating == habit.id;

    return Semantics(
      label: habit.title,
      value: done
          ? 'انجام شد'
          : pending
              ? 'منتظر تأیید والدین'
              : 'انجام نشده',
      button: log == null,
      child: AnimatedScale(
        // 200 ms, well inside the brief's 250 ms cap, and the platform's
        // reduce-motion preference skips it entirely.
        scale: celebrating ? 1.04 : 1.0,
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 200),
        child: AppCard(
          borderColor: done ? color.withValues(alpha: .45) : null,
          onTap: log == null ? () => _markHabit(state, habit) : null,
          onLongPress: log != null ? () => _undo(state, log) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DuotoneIconTile(
                accent: color,
                icon: KidIcons.of(habit.iconKey),
                size: 52,
              ),
              const Spacer(),
              Text(
                habit.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  if (done) ...[
                    Icon(Icons.check_circle_rounded, size: 13, color: color),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'انجام شد · +${habit.stars}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                          color: color,
                        ),
                      ),
                    ),
                  ] else if (pending) ...[
                    Icon(Icons.hourglass_bottom_rounded,
                        size: 13, color: DsStatus.warning(context)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'منتظر تأیید والدین',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                          color: DsStatus.warning(context),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Icon(Icons.star_rounded,
                        size: 13, color: Personal2Colors.kidsStars),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '+${habit.stars} ستاره',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                          color: t.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _starJar(
    BuildContext context,
    KidDayState state,
    Color color,
    RewardRecord? reward,
  ) {
    final t = TimeThemeKit.of(context).palette;
    if (reward == null) {
      return AppCard(
        child: Text(
          'جایزه‌ای تعریف نشده. از والدین بخواه برایت جایزه بگذارند.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            color: t.textSecondary,
          ),
        ),
      );
    }
    final remaining = (reward.costStars - state.spendable).clamp(0, 9999);
    final progress = rewardProgress(
      cost: reward.costStars,
      available: state.spendable,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded,
                  size: 18, color: Personal2Colors.kidsStars),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  remaining == 0
                      ? 'ستاره‌های «${reward.title}» کامل شد!'
                      : 'تا «${reward.title}» فقط $remaining ستاره مانده',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(color: t.outline.withValues(alpha: .3)),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Personal2Colors.kidsStars,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _undoBar(BuildContext context, Color color) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'ثبت شد',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: t.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: _performUndo,
            child: const Text('بازگرداندن'),
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────

  Future<void> _markHabit(KidDayState state, HabitSpec habit) async {
    final dao = ref.read(kidsDaoProvider);
    HapticFeedback.lightImpact();
    setState(() => _celebrating = habit.id);
    final result = await dao.markLog(
      kidId: state.kid.id,
      dayKey: state.dayKey,
      date: DateTime.now(),
      habitId: habit.id,
      stars: habitStars(habit.stars),
      late: false,
      requiresApproval: habit.requiresApproval,
    );
    if (mounted) {
      setState(() => _celebrating = null);
    }
    if (!result.ok) {
      // Already logged (a double tap or two devices): nothing to do, and no
      // error dialog for a child to read.
      ref.invalidate(kidDayProvider(widget.kidId));
      return;
    }
    // Arm the 10 s undo window. The log id is not returned by markLog, so the
    // row is re-read rather than guessed; the timer is deliberately short.
    ref.invalidate(kidDayProvider(widget.kidId));
    final refreshed = await ref.read(kidDayProvider(widget.kidId).future);
    final log = refreshed?.logForHabit(habit.id);
    if (log != null && mounted) {
      _startUndoWindow(log.id);
    }
  }

  Future<void> _markPrayer(
    KidDayState state,
    KidPrayer prayer,
    PrayerChipState chipState,
  ) async {
    final dao = ref.read(kidsDaoProvider);
    final late = chipState == PrayerChipState.lateAvailable;
    final stars = prayerStars(
      base: state.prayerConfig.starsPerPrayer,
      late: late,
      lateFactor: state.prayerConfig.lateFactor,
    );
    HapticFeedback.lightImpact();
    final result = await dao.markLog(
      kidId: state.kid.id,
      dayKey: state.dayKey,
      date: DateTime.now(),
      prayerKey: prayer.key,
      stars: stars,
      late: late,
      requiresApproval: state.prayerConfig.requiresApproval,
    );
    ref.invalidate(kidDayProvider(widget.kidId));
    if (!result.ok) return;
    final refreshed = await ref.read(kidDayProvider(widget.kidId).future);
    final log = refreshed?.logForPrayer(prayer);
    if (log != null && mounted) _startUndoWindow(log.id);
  }

  void _startUndoWindow(String logId) {
    _undoTimer?.cancel();
    setState(() => _undoLogId = logId);
    _undoTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _undoLogId = null);
    });
  }

  Future<void> _undo(KidDayState state, KidLogRecord log) async {
    _undoTimer?.cancel();
    setState(() => _undoLogId = null);
    await ref.read(kidsDaoProvider).undoLog(log.id);
    ref.invalidate(kidDayProvider(widget.kidId));
  }

  Future<void> _performUndo() async {
    final id = _undoLogId;
    if (id == null) return;
    _undoTimer?.cancel();
    setState(() => _undoLogId = null);
    await ref.read(kidsDaoProvider).undoLog(id);
    ref.invalidate(kidDayProvider(widget.kidId));
  }
}
