import 'package:tawheeed/shared/utils/date_key.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/adhkar/presentation/widgets/azkar_list_widget.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/widgets/tasbih_counter_widget.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_daily_reset.dart';
import 'package:tawheeed/features/adhkar/adhkar.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart'
    show SwitchTile;
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/shared/services/click_sound_player.dart';
import 'package:tawheeed/shared/services/sound_registry.dart';
import 'package:tawheeed/shared/widgets/latin_time_picker.dart';

class AzkarTasbihTab extends ConsumerStatefulWidget {
  final int initialSubTab;
  const AzkarTasbihTab({super.key, this.initialSubTab = 0});

  @override
  ConsumerState<AzkarTasbihTab> createState() => _AzkarTasbihTabState();
}

class _AzkarTasbihTabState extends ConsumerState<AzkarTasbihTab>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  Timer? _resetTimer;
  String _lastSeenDate = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialSubTab.clamp(0, 1));
    _lastSeenDate = dateKeyOf(DateTime.now());
    WidgetsBinding.instance.addObserver(this);
    _scheduleResetCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resetTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A one-shot timer aimed at the boundary is only correct while the clock
    // and the timezone are. Coming back to the foreground is the one moment we
    // know both may have moved (the user changed the time, travelled, or the
    // OS suspended the timer), so re-aim rather than trust the old deadline.
    if (state == AppLifecycleState.resumed) _scheduleResetCheck();
  }

  /// Aims a single timer at the next daily-reset boundary.
  ///
  /// WHY not `Timer.periodic(1 min)`: that read SharedPreferences every sixty
  /// seconds — 1,440 reads a day — to detect one event that happens once, at a
  /// time the settings already tell us. The periodic version also kept polling
  /// while the tab sat hidden in the shell's `IndexedStack`.
  ///
  /// When the boundary arrives the counters are invalidated (the provider lives
  /// in an `IndexedStack`, so it is built once and never re-runs by itself) and
  /// the next boundary is scheduled. A prefs read failure returns null and
  /// schedules nothing — the resume hook retries, which is better than guessing
  /// a time and resetting someone's count early.
  Future<void> _scheduleResetCheck() async {
    _resetTimer?.cancel();
    final now = DateTime.now();
    final boundary = await tasbihNextResetBoundary(now);
    if (!mounted || boundary == null) return;
    // +1s of slack: firing exactly on the boundary can land a hair before it
    // (the timer's own scheduling), and `tasbihResetDecision` compares
    // `now.isBefore(deadline)`, so a millisecond early means a wasted round.
    final wait = boundary.difference(now) + const Duration(seconds: 1);
    _resetTimer = Timer(wait.isNegative ? Duration.zero : wait, _onResetBoundary);
  }

  Future<void> _onResetBoundary() async {
    if (!mounted) return;
    final today = dateKeyOf(DateTime.now());
    if (today != _lastSeenDate) {
      _lastSeenDate = today;
      ref.invalidate(tasbihProvider);
    } else if (await isTasbihDailyResetOverdue(DateTime.now())) {
      // The timer is cancelled in dispose, so `mounted` held when this tick
      // started — but the prefs read above is an await, and the tab can be
      // torn down during it. `ref` after that throws, so the guard belongs
      // here, after.
      if (!mounted) return;
      ref.invalidate(tasbihProvider);
    }
    // Aim at the next boundary whether or not this one did anything: a reset
    // that already ran today must still be followed by one tomorrow.
    if (mounted) await _scheduleResetCheck();
  }

  @override
  Widget build(BuildContext context) {
    // No AppBar and no fat TabBar: a 40dp page header plus the kit's compact
    // segmented control (user request, 2026-10-14 — the top of this tab used
    // to cost 56 (bar) + 56 (tab bar, 48 + 8 margin) = 112dp; this is 40+40).
    return SectionShell.fixed(
      title: 'اذکار و تسبیح',
      actions: [
        PageAction(
          icon: Icons.settings,
          tooltip: 'تنظیمات اذکار و تسبیح',
          onPressed: () => _showSettings(context),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(DsSpacing.page, 4, DsSpacing.page, 6),
            // The controller is the source of truth, so a swipe rebuilds the
            // strip as well as a tap.
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) => SegmentedTabs(
                tabs: const [
                  SegmentedTab(label: 'تسبیح'),
                  SegmentedTab(label: 'اذکار'),
                ],
                index: _tabController.index,
                onChanged: (i) => _tabController.animateTo(i),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const TasbihCounterWidget(),
                const AzkarListWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const _AzkarSettingsSheet(),
      // The sheet owns the reset hour/minute, which is exactly the boundary the
      // one-shot timer is aimed at. Closing the sheet is the one moment we know
      // it may have moved, so re-aim — otherwise a changed reset time would not
      // take effect until the next launch.
    ).whenComplete(() {
      if (mounted) _scheduleResetCheck();
    });
  }
}

class _AzkarSettingsSheet extends ConsumerStatefulWidget {
  const _AzkarSettingsSheet();

  @override
  ConsumerState<_AzkarSettingsSheet> createState() =>
      _AzkarSettingsSheetState();
}

class _AzkarSettingsSheetState extends ConsumerState<_AzkarSettingsSheet> {
  /// Short-lived preview player: lets the user hear the click (and the
  /// volume level) right here, instead of discovering silence on the counter.
  ClickSoundPlayer? _previewPlayer;

  @override
  void dispose() {
    unawaited(_previewPlayer?.dispose());
    super.dispose();
  }

  void _previewClick(double volume) {
    _previewPlayer ??= ClickSoundPlayer(SoundRegistry.tick.asset);
    unawaited(_previewPlayer!.play(volume));
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final settings = ref.watch(azkarSettingsProvider);
    final notifier = ref.read(azkarSettingsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: t.outline,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const SectionHeader(title: 'تنظیمات اذکار و تسبیح'),
            const SizedBox(height: 6),
            SwitchTile(
              icon: Icons.vibration_rounded,
              title: 'لرزش هنگام کلیک',
              subtitle: 'هپتیک بازخورد هنگام شمارش',
              value: settings.hapticEnabled,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                notifier.setHaptic(v);
              },
            ),
            SwitchTile(
              icon: Icons.volume_up_rounded,
              title: 'صدای کلیک',
              subtitle: 'پخش صدا هنگام شمارش',
              value: settings.soundEnabled,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                notifier.setSound(v);
                if (v) _previewClick(settings.tasbihVolume);
              },
            ),
            if (settings.soundEnabled) ...[
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 16, top: 4),
                child: SettingsSliderRow(
                  icon: Icons.volume_down_outlined,
                  accent: SectionHues.tasbih,
                  title: 'بلندی صدای کلیک',
                  valueText:
                      '${(settings.tasbihVolume * 100).round()}٪',
                  value: settings.tasbihVolume,
                  divisions: 20,
                  onChanged: notifier.setTasbihVolume,
                  onSettled: _previewClick,
                ),
              ),
            ],
            SwitchTile(
              icon: Icons.bolt_rounded,
              title: 'تسبیح سریع',
              subtitle:
                  'با نگه داشتن انگشت روی دایره، شمارش پشت‌سرهم انجام شود',
              value: settings.quickCount,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                notifier.setQuickCount(v);
              },
            ),
            if (settings.quickCount) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('سرعت شمارش',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            color: t.textMuted,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final speed in QuickCountSpeed.values) ...[
                          if (speed != QuickCountSpeed.values.first)
                            const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                notifier.setQuickSpeed(speed);
                              },
                              behavior: HitTestBehavior.opaque,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: speed == settings.quickSpeed
                                      ? SectionHues.tasbih
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: speed == settings.quickSpeed
                                        ? SectionHues.tasbih
                                        : t.outline.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    speed.label,
                                    style: TextStyle(
                                      fontSize: AppTheme.scaledFontSize(context, 13),
                                      fontWeight: speed == settings.quickSpeed
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: speed == settings.quickSpeed
                                          ? Colors.white
                                          : dsContentColor(
                                              context, SectionHues.tasbih),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
            SwitchTile(
              icon: Icons.restart_alt_rounded,
              title: 'ریست خودکار روزانه',
              subtitle:
                  'ریست اذکار هر روز ساعت ${settings.resetHour.toString().padLeft(2, '0')}:${settings.resetMinute.toString().padLeft(2, '0')}',
              value: settings.autoReset,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                notifier.setAutoReset(v);
              },
            ),
            if (settings.autoReset) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                      foregroundColor: SectionHues.tasbih),
                  onPressed: () async {
                    final picked = await showLatinTimePicker(
                      context,
                      initialTime: TimeOfDay(
                          hour: settings.resetHour,
                          minute: settings.resetMinute),
                      title: 'زمان ریست روزانه',
                    );
                    if (picked != null) {
                      notifier.setResetTime(picked.hour, picked.minute);
                    }
                  },
                  icon: const Icon(Icons.access_time),
                  label: Text(
                    '${settings.resetHour.toString().padLeft(2, '0')}:${settings.resetMinute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 26), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            SwitchTile(
              icon: Icons.autorenew_rounded,
              title: 'چرخش خودکار ذکر',
              subtitle:
                  'پس از تکمیل هدف، ذکر بعدی به‌طور خودکار انتخاب شود',
              value: settings.autoRotate,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                notifier.setAutoRotate(v);
              },
            ),
          ],
        ),
      ),
    );
  }

}
