import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/failure_view.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/fasting/data/fasting_content.dart';
import 'package:tawheeed/features/ramadan/data/ramadan_service.dart';
import 'package:tawheeed/features/ramadan/presentation/providers/ramadan_provider.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

class RamadanTrackerTab extends ConsumerStatefulWidget {
  const RamadanTrackerTab({super.key});

  @override
  ConsumerState<RamadanTrackerTab> createState() => _RamadanTrackerTabState();
}

class _RamadanTrackerTabState extends ConsumerState<RamadanTrackerTab> {
  Map<int, bool> _fastingDays = {};
  Map<int, bool> _taraweehDays = {};
  Map<int, bool> _nightPrayers = {};
  Set<int> _quranJuz = {};
  int _quranCompletions = 0;
  int _qadaOwed = 0;
  bool _loading = true;

  /// The tracker's own rows could not be read.
  ///
  /// WHY this exists: the read used to fail into an empty map, and an empty map
  /// renders as «۰/۳۰» — the page told a reader who had tracked twenty days that
  /// they had tracked none. A failed read is not a zero, so the counters and the
  /// day grid step aside and say what happened instead.
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        RamadanService.loadFastingDays(),
        RamadanService.loadTaraweehDays(),
        RamadanService.loadNightPrayers(),
        RamadanService.loadQuranJuzCompleted(),
        RamadanService.loadQuranCompletions(),
        RamadanService.loadQadaOwed(),
      ]);
      if (mounted) {
        setState(() {
          _fastingDays = results[0] as Map<int, bool>;
          _taraweehDays = results[1] as Map<int, bool>;
          _nightPrayers = results[2] as Map<int, bool>;
          _quranJuz = results[3] as Set<int>;
          _quranCompletions = results[4] as int;
          _qadaOwed = results[5] as int;
          _loading = false;
          _loadFailed = false;
        });
      }
    } catch (e) {
      AppLogger.warning('ramadan_tracker_tab', 'tracker load failed: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _retryLoad() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    await _loadData();
  }

  /// Applies a tracker edit in memory immediately and persists it; on a
  /// storage failure the previous value is restored.
  Future<void> _optimistic(
      {required void Function() apply,
      required Future<void> Function() persist,
      required void Function() rollback,
      required String tag}) async {
    setState(apply);
    try {
      await persist();
    } catch (e) {
      AppLogger.warning('ramadan_tracker_tab', '$tag failed: $e');
      if (mounted) setState(rollback);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ramadanState = ref.watch(ramadanProvider);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _buildHeader(context, ramadanState),
        const SizedBox(height: 16),
        if (ramadanState.isRamadan && ramadanState.nextMeal != null) ...[
          _CountdownCard(
            nextMeal: ramadanState.nextMeal!,
            onChanged: () => ref.invalidate(ramadanProvider),
          ),
          const SizedBox(height: 16),
        ],
        if (_loadFailed)
          _buildLoadFailure(context, isDark)
        else ...[
          _buildQuickStats(context, isDark),
          const SizedBox(height: 16),
          _buildFastingTracker(context, isDark),
          const SizedBox(height: 16),
          _buildQadaCounter(context, isDark),
          const SizedBox(height: 16),
          _buildWorshipTracker(context, isDark, ramadanState),
          const SizedBox(height: 16),
          _buildQuranTracker(context, isDark),
          const SizedBox(height: 16),
        ],
        _buildVirtuesSection(context, isDark),
        const SizedBox(height: 16),
        _buildSpecialWorshipsSection(context, isDark),
        const SizedBox(height: 16),
        _buildLaylatAlQadrSection(context, isDark),
        const SizedBox(height: 16),
        _buildItikafSection(context, isDark),
        const SizedBox(height: 16),
        _buildSuhoorIftarSection(context, isDark),
        const SizedBox(height: 16),
        if (!ramadanState.isRamadan)
          _buildDaysUntilRamadan(context, isDark, ramadanState),
        const SizedBox(height: 32),
      ],
    );
  }

  /// The tracker rows could not be read: say so and offer a retry.
  ///
  /// Rendering the page on empty maps instead would have said «۰/۳۰» — a claim
  /// about the reader's worship, not about the read. The guide below this panel
  /// is static content and stays available either way.
  Widget _buildLoadFailure(BuildContext context, bool isDark) {
    return FailureView(
      id: 'ramadan_tracker_load',
      title: 'وضعیت روزه‌ها خوانده نشد',
      detail: 'شمارنده‌ها و جدول روزها تا خواندن دوباره پنهان می‌مانند؛ '
          'عددهای صفر یعنی «هیچ روزی ثبت نشده»، و اینجا این را نمی‌دانیم. '
          'آنچه ثبت کرده‌اید پاک نشده است.',
      onRetry: _retryLoad,
    );
  }

  // ═══════════════════════════════════════════
  //  Header
  // ═══════════════════════════════════════════
  Widget _buildHeader(BuildContext context, RamadanState state) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: SawmData.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: SawmData.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.nightlight_round,
                size: 26, color: SawmData.accent),
          ),
          const SizedBox(height: 12),
          Text(
            state.isRamadan ? 'ماه مبارک رمضان' : 'ثبت عبادات روزه',
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 17),
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.isRamadan
                ? 'روز ${state.currentDay} از 30 — ${state.daysRemaining} روز باقی‌مانده'
                : 'ردیاب روزه، تراویح، قیام لیل و تلاوت قرآن',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 12),
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Countdown Card (Suhoor/Iftar)
  // ═══════════════════════════════════════════
  // ═══════════════════════════════════════════
  //  Quick Stats
  // ═══════════════════════════════════════════
  Widget _buildQuickStats(BuildContext context, bool isDark) {
    final fastedCount = _fastingDays.values.where((v) => v).length;
    final taraweehCount = _taraweehDays.values.where((v) => v).length;
    final nightCount = _nightPrayers.values.where((v) => v).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(isDark),
      child: Row(
        children: [
          _statItem(isDark, Icons.check_circle, 'روزه', '$fastedCount/30'),
          _statDivider(isDark),
          _statItem(isDark, Icons.mosque, 'تراویح', '$taraweehCount'),
          _statDivider(isDark),
          _statItem(isDark, Icons.nightlight, 'قیام لیل', '$nightCount'),
        ],
      ),
    );
  }

  Widget _statItem(bool isDark, IconData icon, String label, String value) {
    final t = TimeThemeKit.of(context).palette;
    return Expanded(
      child: Column(
        children: [
          Icon(icon,
              size: 20, color: isDark ? AppTheme.darkPrimary : SawmData.accent),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                  fontFamily: AppTheme.fontFamily)),
          Text(label,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: t.textSecondary,
                  fontFamily: AppTheme.fontFamily)),
        ],
      ),
    );
  }

  Widget _statDivider(bool isDark) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
        width: 1,
        height: 40,
        color: t.outline.withValues(alpha: isDark ? 0.3 : 0.5));
  }

  // ═══════════════════════════════════════════
  //  Fasting Tracker
  // ═══════════════════════════════════════════
  Widget _buildFastingTracker(BuildContext context, bool isDark) {
    final t = TimeThemeKit.of(context).palette;
    final fastedCount = _fastingDays.values.where((v) => v).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 20,
                      color: isDark ? AppTheme.darkPrimary : SawmData.accent),
                  const SizedBox(width: 8),
                  Text('ثبت روزه',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 16),
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                          fontFamily: AppTheme.fontFamily)),
                ],
              ),
              Text('$fastedCount/30 روز',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkPrimary : SawmData.accent,
                      fontFamily: AppTheme.fontFamily)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fastedCount / 30.0,
              minHeight: 6,
              backgroundColor: t.surfaceMuted,
              color: isDark ? AppTheme.darkPrimary : SawmData.accent,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(30, (i) {
              final day = i + 1;
              final fasted = _fastingDays[day] ?? false;
              return GestureDetector(
                onTap: () => _optimistic(
                  apply: () => _fastingDays[day] = !fasted,
                  rollback: () => _fastingDays[day] = fasted,
                  persist: () => RamadanService.toggleFastingDay(day, !fasted),
                  tag: 'toggleFastingDay',
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: fasted
                        ? (isDark ? AppTheme.darkPrimary : SawmData.accent)
                        : t.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: fasted
                          ? (isDark ? AppTheme.darkPrimary : SawmData.accent)
                          : t.outline.withValues(alpha: isDark ? 0.3 : 0.5),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w700,
                        color: fasted
                            ? Colors.white
                            : t.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Qada Counter
  // ═══════════════════════════════════════════
  Widget _buildQadaCounter(BuildContext context, bool isDark) {
    final t = TimeThemeKit.of(context).palette;
    final primary = isDark ? AppTheme.darkPrimary : SawmData.accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pending_actions_outlined, size: 20, color: primary),
              const SizedBox(width: 8),
              Text('روزه‌های قضا',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 16),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                      fontFamily: AppTheme.fontFamily)),
            ],
          ),
          const SizedBox(height: 6),
          Text('روزه‌هایی که از قضا مانده و باید ادا شوند.',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: t.textMuted,
                  fontFamily: AppTheme.fontFamily)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('باقی‌مانده: $_qadaOwed روز',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 15),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                        fontFamily: AppTheme.fontFamily)),
              ),
              _qadaButton(isDark, Icons.remove, 'اداشد', () {
                final prev = _qadaOwed;
                final next = (prev - 1).clamp(0, 0x7fffffff);
                _optimistic(
                  apply: () => _qadaOwed = next,
                  rollback: () => _qadaOwed = prev,
                  persist: () => RamadanService.setQadaOwed(next),
                  tag: 'setQadaOwed',
                );
              }),
              const SizedBox(width: 8),
              _qadaButton(isDark, Icons.add, 'افزودن', () {
                final prev = _qadaOwed;
                _optimistic(
                  apply: () => _qadaOwed = prev + 1,
                  rollback: () => _qadaOwed = prev,
                  persist: () => RamadanService.setQadaOwed(prev + 1),
                  tag: 'setQadaOwed',
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qadaButton(
      bool isDark, IconData icon, String label, VoidCallback onTap) {
    final primary = isDark ? AppTheme.darkPrimary : SawmData.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: primary),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: primary,
                    fontFamily: AppTheme.fontFamily)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Worship Tracker (Taraweeh + Night)
  // ═══════════════════════════════════════════
  Widget _buildWorshipTracker(
      BuildContext context, bool isDark, RamadanState state) {
    final t = TimeThemeKit.of(context).palette;
    if (!state.isRamadan) return const SizedBox.shrink();
    final currentDay = state.currentDay;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mosque,
                  size: 20,
                  color: isDark ? AppTheme.darkPrimary : SawmData.accent),
              const SizedBox(width: 8),
              Text('برنامه عبادی',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 16),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                      fontFamily: AppTheme.fontFamily)),
            ],
          ),
          const SizedBox(height: 12),
          _worshipToggle(
            isDark: isDark,
            icon: Icons.mosque_outlined,
            title: 'نماز تراویح',
            subtitle: '20 رکعت پس از عشاء',
            day: currentDay,
            checked: _taraweehDays[currentDay] ?? false,
            onToggle: (v) => _optimistic(
              apply: () => _taraweehDays[currentDay] = v,
              rollback: () => _taraweehDays[currentDay] = !v,
              persist: () => RamadanService.toggleTaraweehDay(currentDay, v),
              tag: 'toggleTaraweehDay',
            ),
          ),
          const SizedBox(height: 8),
          _worshipToggle(
            isDark: isDark,
            icon: Icons.nightlight_round,
            title: 'نماز شب (قیام لیل)',
            subtitle: 'نمازهای نفلی پس از نصف شب',
            day: currentDay,
            checked: _nightPrayers[currentDay] ?? false,
            onToggle: (v) => _optimistic(
              apply: () => _nightPrayers[currentDay] = v,
              rollback: () => _nightPrayers[currentDay] = !v,
              persist: () => RamadanService.toggleNightPrayer(currentDay, v),
              tag: 'toggleNightPrayer',
            ),
          ),
        ],
      ),
    );
  }

  Widget _worshipToggle({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required int day,
    required bool checked,
    required ValueChanged<bool> onToggle,
  }) {
    final t = TimeThemeKit.of(context).palette;
    return InkWell(
      onTap: () => onToggle(!checked),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: checked
              ? (isDark
                  ? AppTheme.darkPrimary.withValues(alpha: 0.15)
                  : SawmData.accent.withValues(alpha: 0.08))
              : t.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: checked
                ? (isDark ? AppTheme.darkPrimary : SawmData.accent)
                : t.outline.withValues(alpha: isDark ? 0.3 : 0.5),
            width: checked ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: checked
                    ? (isDark ? AppTheme.darkPrimary : SawmData.accent)
                    : t.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                          fontFamily: AppTheme.fontFamily)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          color: t.textSecondary,
                          fontFamily: AppTheme.fontFamily)),
                ],
              ),
            ),
            if (checked)
              Icon(Icons.check_circle,
                  size: 20,
                  color: isDark ? AppTheme.darkPrimary : SawmData.accent),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Quran Tracker
  // ═══════════════════════════════════════════
  Widget _buildQuranTracker(BuildContext context, bool isDark) {
    final t = TimeThemeKit.of(context).palette;
    final completedCount = _quranJuz.length;
    final allDone = completedCount >= 30;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book,
                      size: 20,
                      color: isDark ? AppTheme.darkPrimary : SawmData.accent),
                  const SizedBox(width: 8),
                  Text('تلاوت قرآن',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 16),
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                          fontFamily: AppTheme.fontFamily)),
                ],
              ),
              Text('$completedCount/30 جزء',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkPrimary : SawmData.accent,
                      fontFamily: AppTheme.fontFamily)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: completedCount / 30.0,
              minHeight: 6,
              backgroundColor: t.surfaceMuted,
              color: isDark ? AppTheme.darkPrimary : SawmData.accent,
            ),
          ),
          if (_quranCompletions > 0) ...[
            const SizedBox(height: 8),
            Text('تعداد ختم: $_quranCompletions',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkPrimary : SawmData.accent,
                    fontFamily: AppTheme.fontFamily)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(30, (i) {
              final juz = i + 1;
              final done = _quranJuz.contains(juz);
              return GestureDetector(
                onTap: () => _optimistic(
                  apply: () => done
                      ? _quranJuz.remove(juz)
                      : _quranJuz.add(juz),
                  rollback: () => done
                      ? _quranJuz.add(juz)
                      : _quranJuz.remove(juz),
                  persist: () => RamadanService.toggleQuranJuz(juz, !done),
                  tag: 'toggleQuranJuz',
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: done
                        ? (isDark ? AppTheme.darkPrimary : SawmData.accent)
                        : t.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: done
                          ? (isDark ? AppTheme.darkPrimary : SawmData.accent)
                          : t.outline.withValues(alpha: isDark ? 0.3 : 0.5),
                    ),
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text('$juz',
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w600,
                                color: t.textSecondary)),
                  ),
                ),
              );
            }),
          ),
          if (allDone) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final prevJuz = Set<int>.from(_quranJuz);
                final prevCount = _quranCompletions;
                setState(() {
                  _quranJuz = {};
                  _quranCompletions = prevCount + 1;
                });
                int? count;
                try {
                  count = await RamadanService.completeQuranRound();
                } catch (e) {
                  AppLogger.warning(
                      'ramadan_tracker_tab', 'completeQuranRound failed: $e');
                  if (mounted) {
                    setState(() {
                      _quranJuz = prevJuz;
                      _quranCompletions = prevCount;
                    });
                  }
                }
                if (count != null && context.mounted) {
                  setState(() => _quranCompletions = count!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('مبارک باشد! ختم قرآن شماره $count ثبت شد.'),
                      backgroundColor: SawmData.accent,
                    ),
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: SawmData.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.celebration,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text('شروع ختم جدید',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 14),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: AppTheme.fontFamily)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Virtues Section (from RamadanScreen)
  // ═══════════════════════════════════════════
  Widget _buildVirtuesSection(BuildContext context, bool isDark) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: 20,
                  color: isDark ? AppTheme.darkPrimary : SawmData.accent),
              const SizedBox(width: 8),
              Text('فضایل ماه رمضان',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 16),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                      fontFamily: AppTheme.fontFamily)),
            ],
          ),
          const SizedBox(height: 12),
          ...RamadanAzkar.ramadanVirtues.map((virtue) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle,
                        size: 6,
                        color: isDark ? AppTheme.darkPrimary : SawmData.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        textDirection: TextDirection.rtl,
                        text: TextSpan(
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              color: t.textPrimary,
                              fontFamily: AppTheme.fontFamily,
                              height: 1.6),
                          children: [
                            TextSpan(
                                text: '${virtue['title']}: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppTheme.darkPrimary
                                        : SawmData.accent)),
                            TextSpan(text: virtue['text']),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Special Worships Section
  // ═══════════════════════════════════════════
  Widget _buildSpecialWorshipsSection(BuildContext context, bool isDark) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('برنامه‌های عبادی ویژه',
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 16),
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
                fontFamily: AppTheme.fontFamily)),
        const SizedBox(height: 12),
        ...RamadanAzkar.specialWorships.map((worship) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: _cardDecoration(isDark),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((worship['icon'] ?? ''),
                      style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 19))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((worship['title'] ?? ''),
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 14),
                                fontWeight: FontWeight.w700,
                                color: t.textPrimary,
                                fontFamily: AppTheme.fontFamily)),
                        const SizedBox(height: 4),
                        Text((worship['text'] ?? ''),
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 12),
                                color: t.textSecondary,
                                fontFamily: AppTheme.fontFamily,
                                height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  Laylat Al Qadr Section
  // ═══════════════════════════════════════════
  Widget _buildLaylatAlQadrSection(BuildContext context, bool isDark) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1C3A) : const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('لیلة القدر',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkPrimary : SawmData.accent,
                  fontFamily: AppTheme.fontFamily)),
          const SizedBox(height: 4),
          Text('شب قدر بهتر از هزار ماه است',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: t.textSecondary,
                  fontFamily: AppTheme.fontFamily)),
          const SizedBox(height: 12),
          ...RamadanAzkar.laylatAlQadrVirtues.map((virtue) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle,
                        size: 6,
                        color: isDark ? AppTheme.darkPrimary : SawmData.accent),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(virtue,
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 13),
                                color: t.textPrimary,
                                fontFamily: AppTheme.fontFamily))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Itikaf Section
  // ═══════════════════════════════════════════
  Widget _buildItikafSection(BuildContext context, bool isDark) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.mosque,
                size: 20,
                color: isDark ? AppTheme.darkPrimary : SawmData.accent),
            const SizedBox(width: 8),
            Text('اعتکاف',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 16),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                    fontFamily: AppTheme.fontFamily)),
          ]),
          const SizedBox(height: 12),
          _itikafItem(isDark, 'فضیلت',
              'اعتکاف در 10 روز آخر رمضان مستحب مؤکد است و پاداش آن برابر با یک عمر عبادت است.'),
          const SizedBox(height: 6),
          _itikafItem(isDark, 'شرایط',
              'نیت اعتکاف، اقامت در مسجد، روزه بودن و پرهیز از مکروهات.'),
          const SizedBox(height: 6),
          _itikafItem(isDark, 'احکام',
              'ترک مکروهات اعتکاف مانند خرید و فروش، مسواک زدن با چوب تازه، بوییدن گل، حرف زدن بدون فایده و نگاه کردن به نامحرم.'),
        ],
      ),
    );
  }

  Widget _itikafItem(bool isDark, String title, String text) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.circle,
            size: 6, color: isDark ? AppTheme.darkPrimary : SawmData.accent),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            textDirection: TextDirection.rtl,
            text: TextSpan(
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  color: t.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                  height: 1.6),
              children: [
                TextSpan(
                    text: '$title: ',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? AppTheme.darkPrimary : SawmData.accent)),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  Days Until Ramadan
  // ═══════════════════════════════════════════
  Widget _buildDaysUntilRamadan(
      BuildContext context, bool isDark, RamadanState state) {
    final t = TimeThemeKit.of(context).palette;
    final days = state.daysUntilRamadan;
    if (days <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1C3A) : const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month,
              size: 28, color: isDark ? AppTheme.darkPrimary : SawmData.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('باقی‌مانده تا رمضان',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                        fontFamily: AppTheme.fontFamily)),
                const SizedBox(height: 2),
                Text('$days روز دیگر',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textSecondary,
                        fontFamily: AppTheme.fontFamily)),
              ],
            ),
          ),
          Text('$days',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 30),
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkPrimary : SawmData.accent,
                  fontFamily: AppTheme.fontFamily)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Iftar Duas
  // ═══════════════════════════════════════════
  Widget _buildSuhoorIftarSection(BuildContext context, bool isDark) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('دعای افطاری',
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 16),
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
                fontFamily: AppTheme.fontFamily)),
        const SizedBox(height: 12),
        _duaSubHeader(
            context, isDark, 'دعاهای افطاری', Icons.nightlight_outlined),
        const SizedBox(height: 8),
        ...RamadanAzkar.iftarDuas.asMap().entries.map((entry) =>
            _buildDuaItem(context, isDark, entry.value, entry.key + 1)),
      ],
    );
  }

  Widget _duaSubHeader(
      BuildContext context, bool isDark, String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? AppTheme.darkPrimary : SawmData.accent)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 18, color: isDark ? AppTheme.darkPrimary : SawmData.accent),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkPrimary : SawmData.accent,
                  fontFamily: AppTheme.fontFamily)),
        ],
      ),
    );
  }

  Widget _buildDuaItem(
      BuildContext context, bool isDark, RamadanDua dua, int number) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkPrimary : SawmData.accent)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                    child: Text('$number',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppTheme.darkPrimary
                                : SawmData.accent))),
              ),
              if (dua.source.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isDark
                            ? const Color(0xFF9A6B1E)
                            : AppTheme.goldPale)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(dua.source,
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 10),
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFFD4B05A)
                              : const Color(0xFF9A6B1E))),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(dua.arabic,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 17),
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFE8D5A0)
                      : const Color(0xFF4A148C),
                  fontFamily: AppTheme.fontFamily,
                  height: 2.2)),
          const SizedBox(height: 6),
          Text(dua.persian,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w400,
                  color: t.textSecondary,
                  fontFamily: AppTheme.fontFamily,
                  height: 1.8)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Helper
  // ═══════════════════════════════════════════
  BoxDecoration _cardDecoration(bool isDark) {
    final t = TimeThemeKit.of(context).palette;
    return BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: t.outline.withValues(alpha: isDark ? 0.3 : 0.5),
        width: 0.5,
      ),
    );
  }
}

/// Self-contained countdown card that ticks its own 1-second timer so the
/// surrounding list is not rebuilt every second. When the current meal's time
/// elapses, [onChanged] refreshes the parent provider for the next meal.
class _CountdownCard extends StatefulWidget {
  final ({String label, Duration remaining, bool isSuhoor}) nextMeal;
  final VoidCallback onChanged;

  const _CountdownCard({required this.nextMeal, required this.onChanged});

  @override
  State<_CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<_CountdownCard> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer(widget.nextMeal.remaining);
  }

  /// Cancels any running tick, seeds [_remaining] from [value] and starts a
  /// fresh 1-second countdown. Shared by init and update so the two paths
  /// cannot drift apart.
  void _startTimer(Duration value) {
    _timer?.cancel();
    _remaining = value;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining - const Duration(seconds: 1);
      });
      if (_remaining <= Duration.zero) {
        _timer?.cancel();
        widget.onChanged();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CountdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-seed when the meal identity changes, or when the parent hands back a
    // LATER target than we are counting to (e.g. the same-label meal recurs
    // the next day after the countdown hit zero) — otherwise the card would
    // stay frozen at 0:00 until the label differs.
    final movedForward = widget.nextMeal.remaining > _remaining;
    if (oldWidget.nextMeal.label != widget.nextMeal.label ||
        oldWidget.nextMeal.isSuhoor != widget.nextMeal.isSuhoor ||
        movedForward) {
      _startTimer(widget.nextMeal.remaining);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formatted {
    final d = _remaining;
    if (d.isNegative) return '--:--:--';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : SawmData.accent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            widget.nextMeal.label,
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 17),
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkTextPrimary : Colors.white,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatted,
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 48),
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkTextPrimary : Colors.white,
              fontFamily: AppTheme.fontFamily,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.nextMeal.isSuhoor ? 'تا اذان صبح' : 'تا اذان مغرب',
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 14),
              color: isDark ? AppTheme.darkTextSecondary : Colors.white70,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
