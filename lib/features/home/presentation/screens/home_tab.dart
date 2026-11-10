import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/app/state/pending_prayer.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/glass_surface.dart';
import 'package:tawheeed/core/services/permission_service.dart';
import 'package:tawheeed/core/theme/app_colors.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/home/presentation/widgets/actions_timeline_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/daily_summary_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/friday_adab_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/hero_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/period_hayz_banner.dart';
import 'package:tawheeed/features/home/presentation/widgets/prayer_times_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/quick_actions.dart';
import 'package:tawheeed/features/home/presentation/widgets/rawatib_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/worship_today_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/reminders_card.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/search/search.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

class HomeTab extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToAzkarTimeline;
  const HomeTab({super.key, this.onNavigateToAzkarTimeline});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> with WidgetsBindingObserver {
  bool _showBatteryBanner = false;

  /// Audit P-08: on Android 14+ SCHEDULE_EXACT_ALARM is denied by default
  /// and the native adhan arm fails silently. Home used to warn only about
  /// Doze, so the one permission that actually silences the adhan was
  /// invisible.
  bool _showAlarmBanner = false;

  /// Prayer row to highlight after a notification tap. Served from
  /// [pendingPrayerProvider] (works whether Home is freshly built or already
  /// open) and consumed immediately so later rebuilds don't re-highlight.
  String? _prayerHighlight;
  ValueNotifier<String?>? _pendingPrayer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBatteryBanner();
    _checkAlarmBanner();
    _pendingPrayer = ref.read(pendingPrayerProvider);
    _prayerHighlight = _pendingPrayer?.value;
    _pendingPrayer?.value = null;
    _pendingPrayer?.addListener(_onPendingPrayer);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The warning points at a system settings page, so the user may have fixed
    // it while the app was away — re-check instead of nagging all session.
    if (state == AppLifecycleState.resumed) {
      // Both warnings point at system settings, so a returning user may have
      // fixed them while the app was away — never nag on stale state.
      _checkBatteryBanner();
      _checkAlarmBanner();
    }
  }

  void _onPendingPrayer() {
    final name = _pendingPrayer?.value;
    if (name == null || !mounted) return;
    _pendingPrayer?.value = null;
    setState(() => _prayerHighlight = name);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingPrayer?.removeListener(_onPendingPrayer);
    super.dispose();
  }

  /// Shows the Doze warning only when it can still help: a device that is
  /// already exempt, and a user who turned every reminder off, both have
  /// nothing left to do on that screen. The banner used to be shown to
  /// everyone, so Home looked permanently broken.
  Future<void> _checkBatteryBanner() async {
    var show = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool('battery_banner_dismissed') ?? false;
      if (!dismissed) {
        final settings = await ref.read(settingsProvider.future);
        show = settings.anyNotificationEnabled &&
            !await PermissionService().isBatteryOptimizationIgnored();
      }
    } catch (e) {
      AppLogger.warning('HomeTab', 'Battery banner check failed: $e');
    }
    // Assigned even on the failure path: a re-check that finds the exemption
    // granted has to clear a banner that is already on screen.
    if (mounted) setState(() => _showBatteryBanner = show);
  }

  Future<void> _dismissBatteryBanner() async {
    setState(() => _showBatteryBanner = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('battery_banner_dismissed', true);
    } catch (e) {
      AppLogger.warning('HomeTab', 'Battery banner dismiss failed: $e');
    }
  }

  /// Audit P-08 — only warn when a reminder is actually enabled AND one of
  /// the two grants is missing. `ExactAlarmHelper.canScheduleExactAlarms`
  /// returns true below Android 12, so older devices never get a false alarm.
  Future<void> _checkAlarmBanner() async {
    var show = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool('alarm_banner_dismissed') ?? false;
      if (!dismissed) {
        final settings = await ref.read(settingsProvider.future);
        if (settings.anyAzanEnabled || settings.anyNotificationEnabled) {
          final permission = PermissionService();
          final notifications = await permission.isNotificationGranted();
          final exact = await permission.isExactAlarmGranted();
          show = !notifications || !exact;
        }
      }
    } catch (e) {
      AppLogger.warning('HomeTab', 'Alarm banner check failed: $e');
    }
    if (mounted) setState(() => _showAlarmBanner = show);
  }

  Future<void> _dismissAlarmBanner() async {
    setState(() => _showAlarmBanner = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('alarm_banner_dismissed', true);
    } catch (e) {
      AppLogger.warning('HomeTab', 'Alarm banner dismiss failed: $e');
    }
  }

  /// One tap takes the user straight to the OS grant flows, then re-checks
  /// so the banner disappears the moment both permissions are in place.
  Future<void> _fixAlarmPermissions() async {
    final permission = PermissionService();
    await permission.ensureExactAlarmPermission(force: true);
    await permission.requestNotificationPermission();
    await _checkAlarmBanner();
  }

  @override
  Widget build(BuildContext context) {
    final lite = ref.watch(liteModeProvider).value ?? false;

    return SectionShell.list(
      title: 'خانه',
      headerPadding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
      actions: [
        PageAction(
          icon: Icons.search,
          tooltip: 'جستجو در همه بخش‌ها',
          onPressed: () => openGlobalSearch(context, ref),
        ),
      ],
      // One path for a user-requested refresh: it forces a fresh fix and
      // publishes through the provider, so the hero and the card are
      // guaranteed to re-render. Poking the repository directly used to
      // leave the provider's state untouched when the location failed.
      onRefresh: () =>
          ref.read(prayerTimesProvider.notifier).reload(forceRefresh: true),
      children: [
        // The hero sits in the same padded rhythm as the cards below —
        // side/top margins, fully rounded like a box.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: HeroCard(lite: lite),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_showBatteryBanner) ...[
                _batteryBanner(context),
                const SizedBox(height: 8),
              ],
              if (_showAlarmBanner) ...[
                _alarmBanner(context),
                const SizedBox(height: 8),
              ],
              // «ادامهٔ مطالعه» removed from Home per user request 2026-11-06.
              // The page carries no section headings and no rules between
              // groups (user request 2026-11-07): «تقسیم‌بندی‌ها را حذف کن».
              // The three bands that used to name امروز / عبادت / یادآوری are
              // gone; the extra 4 px of air between groups stays, because that
              // is what still separates them without drawing a line.
              PrayerTimesCard(highlightKey: _prayerHighlight),
              const SizedBox(height: 8),
              const RawatibCard(),
              const SizedBox(height: 8),
              ActionsTimelineCard(
                  onNavigateToAzkar: widget.onNavigateToAzkarTimeline),
              const SizedBox(height: 12),
              const DailySummaryCard(),
              const SizedBox(height: 8),
              const WorshipTodayCard(),
              const SizedBox(height: 12),
              const RemindersCard(),
              const SizedBox(height: 8),
              // فقط جمعه‌ها رندر می‌شود؛ بقیهٔ روزها خودش صفر می‌ماند.
              const FridayAdabCard(),
              const SizedBox(height: 8),
              const QuickActions(),
              // The hayz note is its own block at the bottom of the page
              // (user request 2026-10-23), and it says the tracker's rule,
              // not the banner's generic one. It sizes itself to zero on a
              // day outside a period, so nothing else moves; its own
              // top padding is the gap, hence no SizedBox above it.
              ValueListenableBuilder<DateTime>(
                valueListenable: ref.watch(clockTickerProvider).minute,
                builder: (context, tick, _) => PeriodHayzBanner(
                  trackerNote:
                      'در ایام حیض نماز ساقط است؛ ثبت آن اختیاری است و ثبت‌نکردنش «فوت» شمرده نمی‌شود',
                  now: tick,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _batteryBanner(BuildContext context) {
    return GlassSurface(
      radius: AppTheme.radiusMedium,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      borderGold: false,
      borderColor: AppColors.warning(context).withValues(alpha: 0.25),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.warning(context).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.battery_alert,
                size: 16, color: AppColors.warning(context)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push(RouteNames.batteryOptimization),
              child: Text(
                'برای دریافت اعلان‌ها در پس‌زمینه، تنظیمات باتری را بررسی کنید',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: AppColors.warning(context)),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'بستن اعلان باتری',
            child: GestureDetector(
              onTap: _dismissBatteryBanner,
              child: Icon(Icons.close,
                  size: 16,
                  color: AppColors.warning(context).withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }

  /// Audit P-08 — the missing-grant warning. Same shape as the Doze banner
  /// so Home keeps one visual language for "something is off".
  Widget _alarmBanner(BuildContext context) {
    final warning = AppColors.warning(context);
    return GlassSurface(
      radius: AppTheme.radiusMedium,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      borderGold: false,
      borderColor: warning.withValues(alpha: 0.25),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.alarm_off, size: 16, color: warning),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              button: true,
              label: 'رفع مجوز اعلان و آلارم دقیق',
              onTap: () => unawaited(_fixAlarmPermissions()),
              child: ExcludeSemantics(
                child: GestureDetector(
                  onTap: () => unawaited(_fixAlarmPermissions()),
                  child: Text(
                    'مجوز اعلان یا آلارم دقیق داده نشده است؛ اذان ممکن است بیصدا بماند. برای رفع لمس کنید',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: warning),
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'بستن اعلان مجوزها',
            child: GestureDetector(
              onTap: _dismissAlarmBanner,
              child: Icon(Icons.close,
                  size: 16, color: warning.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}

