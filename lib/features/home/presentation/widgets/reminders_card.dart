import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/features/adhkar/duas/data/hesn_db_service.dart';
import 'package:tawheeed/features/books/presentation/providers/reading_stats_provider.dart';
import 'package:tawheeed/features/home/domain/daily_dua_selector.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/features/home/presentation/widgets/home_tokens.dart';
import 'package:tawheeed/features/khatm/presentation/providers/khatm_provider.dart';
import 'package:tawheeed/features/prayer/domain/home_day_model.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/date_key.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// One row of the reminders card.
class _ReminderDef {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  /// Measurable progress (quran pages, khatm percent) folded into the
  /// subtitle as «… · label»; null = plain row.
  final String? progressLabel;
  const _ReminderDef({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
    this.progressLabel,
  });
}

/// ═══════════════════════════════════════════════════════════════
/// RemindersCard — the redesigned home's «یادآوری‌های امروز» (8/9).
///
/// A compact behavioural port of the old QuickReminders: same data
/// sources (per-day done-ids in SharedPreferences, the daily dua from
/// HesnDbService, reading stats and the active khatm for the progress
/// lines), same conditional set (Mon/Thu fasts, tomorrow's fast, ایام
/// البیض, duha inside the domain [duhaWindow], qiyam at night, the
/// post-prayer adhkar slots), same toggle/persist/hide-after-a-minute
/// mechanics and the same minute-tick date rollover. Presentation
/// changes: ~50dp rows on the shared duotone tile, a 21dp toggle circle
/// as the only affordance (the arrow icon is gone), progress folded
/// into the subtitle, and [SectionHeader] with the n/total chip.
/// ═══════════════════════════════════════════════════════════════
class RemindersCard extends ConsumerStatefulWidget {
  const RemindersCard({super.key, this.nowOverride});

  /// Clock seam: "now" a widget test cannot otherwise pin.
  @visibleForTesting
  final DateTime? nowOverride;

  @override
  ConsumerState<RemindersCard> createState() => _RemindersCardState();
}

class _RemindersCardState extends ConsumerState<RemindersCard> {
  SharedPreferences? _prefs;
  final Set<String> _doneIds = {};
  final Set<String> _completedIds = {};
  final Set<String> _hidingIds = {};
  bool _initDone = false;

  /// The read that decides which rows are ticked failed.
  ///
  /// Before this flag existed the catch logged and set `_initDone`, so the card
  /// rendered with an empty `_doneIds` — every reminder looked untouched, and
  /// the user's morning ticks read as «you have done nothing today». Logging a
  /// failure is not the same as surviving it.
  bool _initFailed = false;
  final Map<String, Timer> _hideTimers = {};
  Timer? _dateCheckTimer;
  String _currentDateKey = '';
  HesnItem? _dailyDua;

  @override
  void initState() {
    super.initState();
    _currentDateKey = dateKeyOf(DateTime.now());
    _initPrefs();
    _dateCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final newKey = dateKeyOf(DateTime.now());
      if (newKey != _currentDateKey && mounted) {
        _currentDateKey = newKey;
        setState(() {
          _doneIds.clear();
          _completedIds.clear();
          _hidingIds.clear();
        });
        _prefs?.setStringList('home_reminders_$newKey', []);
      }
    });
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final today = dateKeyOf(DateTime.now());
      final saved = _prefs?.getStringList('home_reminders_$today') ?? [];
      _doneIds.addAll(saved);
      // Seed the completed set too: the old widget only filled it on
      // toggle, so rows restored from prefs rendered in NEITHER list and
      // silently vanished after a restart while the chip kept counting them.
      _completedIds.addAll(saved);
      try {
        final items = await HesnDbService().getAllItems();
        // Pinned-now consistency: tests/goldens drive everything else off
        // nowOverride, so the dua selection follows it too. The pref keys
        // above stay on the real clock (they persist across real days and
        // the date-roll timer owns them).
        // Pin the selection to the instant the card renders from: the
        // override when a test/golden supplies one, else the shared minute
        // ticker (which seeds itself with the real clock at app start). The
        // real wall clock made the daily-dua row — and every home golden
        // containing this card — drift with the calendar date.
        final pinnedNow =
            widget.nowOverride ?? ref.read(clockTickerProvider).minute.value;
        _dailyDua = DailyDuaSelector.select(items, pinnedNow);
      } catch (e) {
        AppLogger.warning('Reminders: dua load failed', e.toString());
      }
      if (mounted) {
        setState(() {
          _initDone = true;
        });
      }
    } catch (e) {
      AppLogger.warning('Reminders: init failed', e.toString());
      if (mounted) {
        setState(() {
          _initDone = true;
          _initFailed = true;
        });
      }
    }
  }

  /// Retry after a failed init: clear the partial state, then read again.
  void _retryInit() {
    setState(() {
      _initFailed = false;
      _initDone = false;
      _doneIds.clear();
      _completedIds.clear();
      _dailyDua = null;
    });
    _initPrefs();
  }

  Future<void> _toggle(String id) async {
    final wasDone = _doneIds.contains(id);
    setState(() {
      if (wasDone) {
        _doneIds.remove(id);
        _completedIds.remove(id);
        _hideTimers[id]?.cancel();
        _hideTimers.remove(id);
      } else {
        _doneIds.add(id);
        _completedIds.add(id);
        _hideTimers[id] = Timer(const Duration(minutes: 1), () {
          if (mounted) {
            setState(() {
              _hidingIds.add(id);
              _completedIds.remove(id);
            });
          }
        });
      }
    });
    try {
      await _prefs?.setStringList(
          'home_reminders_${dateKeyOf(DateTime.now())}', _doneIds.toList());
    } catch (e) {
      // The tick was drawn before the write proved itself. Leaving it there
      // meant the reader's morning ticks looked recorded and were gone on the
      // next open — the same lie the cards were fixed for, one step later. Put
      // the tick back where it was and say so.
      AppLogger.warning('Reminders: failed to save toggle', e.toString());
      if (!mounted) return;
      _hideTimers[id]?.cancel();
      _hideTimers.remove(id);
      setState(() {
        if (wasDone) {
          _doneIds.add(id);
          _completedIds.add(id);
        } else {
          _doneIds.remove(id);
          _completedIds.remove(id);
          _hidingIds.remove(id);
        }
      });
      AppSnackBar.error(
        context,
        wasDone
            ? 'تیک برداشته نشد و هنوز ثبت‌شده است.'
            : 'تیک ثبت نشد و برنگشت.',
        onRetry: () => _toggle(id),
      );
    }
  }

  @override
  void dispose() {
    _dateCheckTimer?.cancel();
    for (final t in _hideTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  String _prayerName(String key) {
    switch (key) {
      case 'after_fajr':
        return 'فجر';
      case 'after_dhuhr':
        return 'ظهر';
      case 'after_asr':
        return 'عصر';
      case 'after_maghrib':
        return 'مغرب';
      case 'after_isha':
        return 'عشاء';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initDone) {
      final t = TimeThemeKit.of(context).palette;
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'یادآوری‌های امروز'),
            Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: t.textMuted.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      );
    }

    // The ticks could not be read: say so instead of drawing every row as
    // untouched. The card keeps its header so the page does not lose a block
    // and shift everything under it.
    if (_initFailed) {
      return AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: SectionHeader(title: 'یادآوری‌های امروز'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: FailureView(
                id: 'home_reminders_load',
                title: 'یادآوری‌های امروز باز نشد',
                detail: 'تیک‌های امروز پاک نشده‌اند؛ فقط خواندنشان ناموفق بود.',
                layout: FailureLayout.inline,
                onRetry: _retryInit,
              ),
            ),
          ],
        ),
      );
    }

    final settings = ref.watch(settingsProvider).value;
    final hijriOffset = ref.watch(hijriOffsetProvider);
    final times = ref.watch(prayerTimesProvider);
    final readingStats = ref.watch(readingStatsProvider).value;
    final khatm = ref.watch(khatmProvider).value;

    // One derivation closure for both the rebuild key and the builder —
    // the key must never disagree with what renders (phase-2 minute-tick
    // contract: a tick whose key is unchanged repaints nothing).
    List<_ReminderDef> remindersAt(DateTime now) {
      final weekday = now.weekday;
      final schedule =
          times.value == null ? null : PrayerSchedule.fromToday(times.value!);
      // Before today's fajr the shar'i day is yesterday's cycle — the
      // post-isha slot must key off the night's prayers, not tomorrow's.
      final preFajr = schedule != null && now.isBefore(schedule.today.fajr);
      final day = schedule == null
          ? null
          : (preFajr ? schedule.yesterday : schedule.today);

      final todayPages = readingStats?[dateKeyOf(now)] ?? 0;

      final reminders = <_ReminderDef>[];

      void addRem(String id, IconData icon, String title, String subtitle,
          Color color,
          {VoidCallback? onTap, String? progressLabel}) {
        reminders.add(_ReminderDef(
          id: id,
          icon: icon,
          title: title,
          subtitle:
              progressLabel == null ? subtitle : '$subtitle · $progressLabel',
          color: color,
          onTap: onTap,
          progressLabel: progressLabel,
        ));
      }

      void goSub(int sub) {
        ref.read(shellTabIndexProvider.notifier).setIndex(2);
        ref.read(shellSubTabProvider.notifier).setIndex(sub);
      }

      if (weekday == DateTime.monday || weekday == DateTime.thursday) {
        addRem(
            'fasting',
            Icons.free_breakfast,
            'روزه امروز',
            weekday == DateTime.monday
                ? 'روزه دوشنبه مستحب است'
                : 'روزه پنجشنبه مستحب است',
            HomeColors.khatm);
      }

      final tomorrowWeekday = (weekday % 7) + 1;
      if (tomorrowWeekday == DateTime.monday ||
          tomorrowWeekday == DateTime.thursday) {
        addRem(
            'fasting_tomorrow',
            Icons.free_breakfast,
            'روزه فردا',
            tomorrowWeekday == DateTime.monday
                ? 'فردا دوشنبه است — روزه مستحب است'
                : 'فردا پنجشنبه است — روزه مستحب است',
            HomeColors.khatm);
      }

      if (HijriUtils.isAyamAlBidh(now, offset: hijriOffset)) {
        addRem('bidh', Icons.nightlight_round, 'ایام البیض',
            'روزه 13، 14 و 15 هر ماه قمری مستحب است', HomeColors.khatm);
      }

      if (day != null) {
        final duha = duhaWindow(day);
        if (!now.isBefore(duha.start) && now.isBefore(duha.end)) {
          addRem('dhuha', Icons.wb_sunny_outlined, 'نماز ضحی',
              'نماز 2 رکعتی در وسط روز مستحب است', HomeColors.sunrise,
              onTap: () => context.push(RouteNames.worshipChecklist));
        }
      }

      if (now.hour >= 20 || now.hour < 5) {
        addRem('qiyam', Icons.brightness_3, 'قیام (نماز شب)',
            '2 رکعت نماز شب در این ساعات مستحب است', HomeColors.isha,
            onTap: () => context.push(RouteNames.worshipChecklist));
      }

      if (day != null) {
        // Same slots as notification_service: iqamah offset + 10 min
        // after the adhan, window −5/+30.
        const postDelay = 10;
        final postPrayerSlots = <String, DateTime>{
          'after_fajr': day.fajr.add(Duration(
              minutes: (settings?.iqamahOffsetFajr ?? 30) + postDelay)),
          'after_dhuhr': day.dhuhr.add(Duration(
              minutes: (settings?.iqamahOffsetDhuhr ?? 25) + postDelay)),
          'after_asr': day.asr.add(Duration(
              minutes: (settings?.iqamahOffsetAsr ?? 25) + postDelay)),
          'after_maghrib': day.maghrib.add(Duration(
              minutes: (settings?.iqamahOffsetMaghrib ?? 7) + postDelay)),
          'after_isha': day.isha.add(Duration(
              minutes: (settings?.iqamahOffsetIsha ?? 25) + postDelay)),
        };
        for (final entry in postPrayerSlots.entries) {
          final start = entry.value.subtract(const Duration(minutes: 5));
          final end = entry.value.add(const Duration(minutes: 30));
          if (now.isAfter(start) && now.isBefore(end)) {
            addRem(
                'post_${entry.key}',
                Icons.done_outline,
                'اذکار بعد از نماز',
                'اذکار ماثور بعد از ${_prayerName(entry.key)} را بخوانید',
                HomeColors.done,
                onTap: () => goSub(1));
          }
        }
      }

      if (_dailyDua != null) {
        final dua = _dailyDua!;
        addRem(
          'daily_dua',
          Icons.volunteer_activism_outlined,
          'دعای روز',
          dua.lead.isNotEmpty ? dua.lead : 'یک دعا از بخش دعاها بخوانید',
          HomeColors.dua,
          onTap: () => context.push(RouteNames.duas),
        );
      }

      addRem('quran', Icons.auto_stories, 'تلاوت قرآن',
          'هر روز حداقل 1 صفحه بخوانید', HomeColors.tilawa,
          onTap: () => ref.read(shellTabIndexProvider.notifier).setIndex(1),
          progressLabel: '$todayPages از 1 صفحه');
      if (khatm != null) {
        addRem('khatm', Icons.menu_book, 'ختم قرآن',
            'پیشرفت خود را بررسی کنید', HomeColors.khatm,
            onTap: () => context.push(RouteNames.khatm),
            progressLabel: '${(khatm.progress * 100).round()}٪ از ختم فعلی');
      } else {
        addRem('khatm', Icons.menu_book, 'ختم قرآن',
            'پیشرفت خود را بررسی کنید', HomeColors.khatm,
            onTap: () => context.push(RouteNames.khatm));
      }

      return reminders;
    }

    return QuantizedRebuild<String>(
      listenable: ref.watch(clockTickerProvider).minute,
      keyOf: (tick) {
        final now = widget.nowOverride ?? tick;
        final reminders = remindersAt(now);
        return '${dateKeyOf(now)}|'
            '${reminders.where((r) => !_hidingIds.contains(r.id)).map((r) => r.id).join(',')}';
      },
      builder: (context, tick) {
        final now = widget.nowOverride ?? tick;
        final reminders = remindersAt(now);
        final visible =
            reminders.where((r) => !_hidingIds.contains(r.id)).toList();
        if (visible.isEmpty) return const SizedBox.shrink();

        final pending = visible.where((r) => !_doneIds.contains(r.id)).toList();
        final completed =
            visible.where((r) => _completedIds.contains(r.id)).toList();
        final allDone = pending.isEmpty && completed.isNotEmpty;
        final doneCount =
            reminders.where((r) => _doneIds.contains(r.id)).length;

        return AppCard(
          padding: EdgeInsets.zero,
          borderColor: allDone ? HomeColors.done.withValues(alpha: 0.35) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: SectionHeader(
                  title: 'یادآوری‌های امروز',
                  count: NumberFormat.ltrIsolated(
                      '$doneCount/${reminders.length}'),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, allDone ? 2 : 12),
                child: Column(
                  children: [
                    for (final r in pending)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _row(context, r),
                      ),
                    for (final r in completed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _row(context, r, completed: true),
                      ),
                  ],
                ),
              ),
              if (allDone)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.celebration,
                          size: 16, color: HomeColors.done),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'آفرین! همه\u200cی یادآوری‌های امروز انجام شد',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w600,
                            color: HomeColors.done,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, _ReminderDef r, {bool completed = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = completed ? HomeColors.done : r.color;
    final titleColor = completed
        ? HomeColors.done
        : (isDark ? r.color : mix(r.color, Colors.black, 0.45));
    final subtitleColor = completed
        ? HomeColors.done.withValues(alpha: 0.7)
        : TimeThemeKit.of(context).palette.textMuted;
    final done = _doneIds.contains(r.id);
    return Container(
      height: 50,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 6, 0),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        children: [
          DuotoneIconTile(accent: r.color, icon: r.icon, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: r.onTap ?? () => _toggle(r.id),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12.5),
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                      color: titleColor,
                      decoration: completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    r.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10.5),
                      height: 1.25,
                      color: subtitleColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Semantics(
            button: true,
            label: done ? 'لغو انجام' : 'انجام شد',
            child: GestureDetector(
              key: ValueKey('reminder_circle_${r.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                _toggle(r.id);
              },
              child: SizedBox(
                width: 48,
                height: 50,
                child: Center(
                  child: done
                      ? Container(
                          width: 21,
                          height: 21,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: HomeColors.done,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        )
                      : Container(
                          width: 21,
                          height: 21,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: r.color.withValues(alpha: 0.6),
                              width: 1.6,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
