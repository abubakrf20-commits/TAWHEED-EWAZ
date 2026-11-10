import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart'
    show SettingsDivider;
import 'package:tawheeed/core/services/permission_service.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_provider.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';

/// Live diagnostic page for the phone settings that decide whether
/// notifications arrive on time and prayer times are accurate:
///
///   1. اعلان‌ها (notifications permission, Android 13+)
///   2. هشدار دقیق (SCHEDULE_EXACT_ALARM, Android 12+)
///   3. بهینه‌سازی باتری (Doze exemption)
///   4. مزاحم نشو (DND policy access — optional but needed for sound while DND)
///   5. موقعیت مکانی (location permission for prayer time calculation)
///   6. موقعیت‌یاب فعال (GPS/network location enabled)
///
/// Each check is re-run whenever the app returns to the foreground, so after
/// the user toggles something in the system settings page and comes back the
/// page already reflects the new state. Every failing item has a «رفع»
/// button that opens the exact system screen needed.
class NotificationDiagnosticsScreen extends ConsumerStatefulWidget {
  const NotificationDiagnosticsScreen({super.key});

  @override
  ConsumerState<NotificationDiagnosticsScreen> createState() =>
      _NotificationDiagnosticsScreenState();
}

/// Result of one diagnostic check.
class _CheckResult {
  final bool ok;
  final bool optional; // true → failure is a warning, not a blocker
  const _CheckResult(this.ok, {this.optional = false});
}

class _NotificationDiagnosticsScreenState
    extends ConsumerState<NotificationDiagnosticsScreen>
    with WidgetsBindingObserver {
  final _permissionService = PermissionService();

  _CheckResult? _notifications;
  _CheckResult? _exactAlarm;
  _CheckResult? _battery;
  _CheckResult? _dnd;
  _CheckResult? _location;
  _CheckResult? _gps;
  List<NativeReminderInfo> _armed = const [];
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runChecks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have granted/fixed something in the system settings and
    // just returned — refresh immediately so the page never shows stale state.
    if (state != AppLifecycleState.resumed) return;
    if (mounted) _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() => _checking = true);
    final results = await Future.wait([
      _permissionService.isNotificationGranted(),
      _permissionService.isExactAlarmGranted(),
      _permissionService.isBatteryOptimizationIgnored(),
      _permissionService.isDndAccessGranted(),
      _permissionService.isLocationGranted(),
      _permissionService.isGpsEnabled(),
    ]);
    // What is actually armed on the OS alarm clock — the single most useful
    // thing to see when "the azan didn't fire": a missing entry means the
    // schedule never landed, not that the phone misbehaved.
    final armed = await NotificationService().armedReminders();
    if (!mounted) return;
    setState(() {
      _notifications = _CheckResult(results[0]);
      _exactAlarm = _CheckResult(results[1]);
      _battery = _CheckResult(results[2]);
      _dnd = _CheckResult(results[3], optional: true);
      _location = _CheckResult(results[4], optional: true);
      _gps = _CheckResult(results[5], optional: true);
      _armed = armed;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SettingsAppBar(
        title: 'تشخیص تنظیمات گوشی',
        trailing: IconButton(
          tooltip: 'بررسی دوباره',
          icon: const Icon(Icons.refresh),
          onPressed: _checking ? null : _runChecks,
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(DsSpacing.page, 4, DsSpacing.page, 32),
        children: [
          _SummaryCard(
            checking: _checking,
            notifications: _notifications,
            exactAlarm: _exactAlarm,
            battery: _battery,
            dnd: _dnd,
            location: _location,
            gps: _gps,
          ),
          const SizedBox(height: 20),
          if (_checking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _CheckRow(
              icon: Icons.notifications_active_outlined,
              title: 'اعلان‌ها',
              subtitle: 'مجوز نمایش اعلان‌ها (اندروید 13+)',
              result: _notifications,
              actionLabel: 'فعال‌سازی',
              onFix: _permissionService.requestNotificationPermission,
            ),
            _CheckRow(
              icon: Icons.alarm_on_outlined,
              title: 'هشدار دقیق',
              subtitle: 'زمان‌بندی دقیق اذان و یادآوری‌ها (اندروید 12+)',
              result: _exactAlarm,
              actionLabel: 'رفع',
              // Explicit user tap: bypass the 24h auto-prompt cooldown.
              onFix: () async {
                await _permissionService.ensureExactAlarmPermission(
                    force: true);
              },
            ),
            _CheckRow(
              icon: Icons.battery_charging_full_outlined,
              title: 'بهینه‌سازی باتری',
              subtitle: 'جلوگیری از به‌تعویق‌افتادن اعلان‌ها در پس‌زمینه',
              result: _battery,
              actionLabel: 'رفع',
              onFix: _permissionService.openBatteryOptimizationSettings,
            ),
            _CheckRow(
              icon: Icons.do_not_disturb_on_outlined,
              title: 'رژیم مزاحم نشو (اختیاری)',
              subtitle: 'برای پخش صدای اذان وقتی حالت مزاحم نشو فعال است',
              result: _dnd,
              actionLabel: 'فعال‌سازی',
              onFix: _permissionService.openDndSettings,
            ),
            _CheckRow(
              icon: Icons.location_on_outlined,
              title: 'دسترسی موقعیت مکانی',
              subtitle:
                  'مجوز دسترسی به موقعیت برای تعیین دقیق شهر و اوقات شرعی',
              result: _location,
              actionLabel: 'اجازه دسترسی',
              onFix: _permissionService.requestLocationPermission,
            ),
            _CheckRow(
              icon: Icons.location_searching_outlined,
              title: 'موقعیت‌یاب فعال',
              subtitle: 'GPS و شبکه برای تعیین موقعیت فعال باشند',
              result: _gps,
              actionLabel: 'فعال‌سازی',
              onFix: _permissionService.openLocationSettings,
            ),
            const SizedBox(height: 16),
            _ArmedRemindersCard(reminders: _armed),
            const SizedBox(height: 20),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: settingsRow(SettingRow(
                icon: Icons.lightbulb_outline,
                color: warning,
                title: 'هنوز اعلان دقیق نیست؟',
                subtitle:
                    'سامسونگ، شیائومی و هواوی گزینه‌های باتری اضافه‌ای دارند که مانع اجرای دقیق اعلان‌ها می‌شود.',
                onTap: () => context.push(RouteNames.batteryOptimization),
              )),
            ),
            const SizedBox(height: 20),
            const SettingsDivider(),
            const SizedBox(height: 20),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.power_off_outlined, color: warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('نکتهٔ مهم درباره «توقف اجباری»',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                // On-scale (12.5 snaps to 12): identical pixels.
                                fontSize:
                                    AppTheme.scaledFontSize(context, 12),
                                fontWeight: FontWeight.w700,
                                color: t.textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                          'کشیدن «توقف اجباری» (Force stop) برنامه در اندروید همهٔ هشدارهایش — حتی اذان — را لغو می‌کند. برای تست، برنامه را فقط ببندید و در پس‌زمینه نگه دارید. در شیائومی/هیپراو‌اس «اجازه خودراه‌اندازی» و «بدون محدودیت باتری» را هم فعال کنید.',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 11.5),
                              height: 1.5,
                              color: t.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Test/share rows need settled state — hidden behind the spinner
          // instead of inviting taps pre-state.
          if (!_checking) ...[
            const SizedBox(height: 20),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: settingsRow(SettingRow(
                icon: Icons.notification_add_outlined,
              title: 'تست اعلان اذان',
              subtitle:
                  'زمان‌بندی اعلان واقعی اذان برای یک دقیقه بعد — بررسی کل زنجیرهٔ اعلان',
              showChevron: false,
              onTap: () async {
                // Same parameters as the prayer page's copy: testing the
                // default sound here while the user picked another was P1.
                AppSettings sound = const AppSettings();
                try {
                  sound = ref.read(settingsProvider).value ??
                      const AppSettings();
                } catch (e) {
                  AppLogger.warning('NotificationDiagnostics',
                      'settings read failed, testing default sound: $e');
                }
                await ref.read(notificationServiceProvider).scheduleTestAdhan(
                      azanSound: sound.azanSound,
                      customAzanPath: sound.customAzanPath,
                    );
                if (context.mounted) {
                  AppSnackBar.show(context,
                      'اعلان تستی اذان برای یک دقیقه دیگر زمان‌بندی شد');
                }
              },
            )),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: settingsRow(SettingRow(
              icon: Icons.bug_report_outlined,
              title: 'اشتراک گزارش رویدادها',
              // Audit P-10: a broken log file used to look exactly like an
              // empty one. Surface the write-failure counter right here.
              subtitle: AppLogger.failedWrites == 0
                  ? 'فایل لاگ دستگاه را برای عیب\u200cیابی ارسال کنید (رایگان/شماره\u200cها پیش از ارسال حذف می\u200cشوند)'
                  : 'هشدار: ${AppLogger.failedWrites} نوشتن لاگ ناموفق بوده است؛ گزارش ممکن است ناقص باشد',
              showChevron: false,
              onTap: () async {
                await AppLogger.flush();
                final path = await AppLogger.logFilePath();
                if (!context.mounted) return;
                if (path == null) {
                  AppSnackBar.show(context, 'گزارشی برای ارسال وجود ندارد');
                  return;
                }
                // U6-P2-3/U6-04: the log leaves the device through the share
                // sheet, so the user confirms it first — the subtitle
                // promises scrubbing, and this dialog is where the promise
                // is stated before anything is sent. Cancelling aborts the
                // share entirely.
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(
                      'ارسال گزارش رویدادها؟',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(dialogContext, 16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    content: Text(
                      'متن گزارش پیش از ذخیره پاک\u200cسازی می\u200cشود و شامل '
                      'هیچ دادهٔ شخصی نیست. با تأیید، یک فایل از دستگاه شما '
                      'خارج می\u200cشود.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(dialogContext, 13),
                        height: 1.6,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('لغو'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('ارسال'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                try {
                  await SharePlus.instance
                      .share(ShareParams(files: [XFile(path)]));
                } catch (e) {
                  AppLogger.error('notif_share', e);
                  if (context.mounted) {
                    AppSnackBar.show(context, 'ارسال گزارش ناموفق بود');
                  }
                }
              },
            )),
          ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final bool checking;
  final _CheckResult? notifications;
  final _CheckResult? exactAlarm;
  final _CheckResult? battery;
  final _CheckResult? dnd;
  final _CheckResult? location;
  final _CheckResult? gps;

  const _SummaryCard({
    required this.checking,
    required this.notifications,
    required this.exactAlarm,
    required this.battery,
    required this.dnd,
    required this.location,
    required this.gps,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final results = [notifications, exactAlarm, battery, dnd, location, gps]
        .whereType<_CheckResult>();
    // DND is an optional check — a muted-do-not-disturb "failure" must not
    // turn the whole summary red.
    final blocking = results.where((r) => !r.ok && !r.optional).length;
    final optionalIssues = results.where((r) => !r.ok && r.optional).length;

    late final Color color;
    late final IconData icon;
    late final String title;
    late final String subtitle;
    if (checking) {
      color = isDark ? AppTheme.darkInfo : AppTheme.lightInfo;
      icon = Icons.sync;
      title = 'در حال بررسی وضعیت…';
      subtitle = 'چند لحظه صبر کنید';
    } else if (blocking == 0 && optionalIssues == 0) {
      color = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
      icon = Icons.verified_outlined;
      title = 'همه‌چیز مرتب است';
      subtitle = 'تنظیمات گوشی برای اعلان‌ها و موقعیت‌یابی آماده است';
    } else if (blocking == 0) {
      // Only an optional check (DND) failed — amber, not red.
      color = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
      icon = Icons.warning_amber_rounded;
      title = '$optionalIssues مورد اختیاری برای بررسی است';
      subtitle = 'تنظیمات ضروری سالم است؛ این مورد فقط اختیاری است';
    } else {
      color = isDark ? AppTheme.darkError : AppTheme.lightError;
      icon = Icons.error_outline;
      title = '$blocking مورد نیاز به بررسی دارد';
      subtitle = 'با لمس هر مورد، صفحهٔ تنظیمات مربوطه باز می‌شود';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(icon, color: dsContentColor(context, color), size: 36),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: t.textMuted)),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final _CheckResult? result;
  final String actionLabel;
  final Future<void> Function() onFix;

  const _CheckRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.result,
    required this.actionLabel,
    required this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = result?.ok ?? false;
    final optional = result?.optional ?? false;
    final color = ok
        ? (isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess)
        : (optional
            ? (isDark ? AppTheme.darkWarning : AppTheme.lightWarning)
            : (isDark ? AppTheme.darkError : AppTheme.lightError));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(ok ? Icons.check_rounded : icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          // On-scale (13.5 snaps to 13): identical pixels.
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          height: 1.4,
                          color: t.textMuted)),
                ],
              ),
            ),
            if (!ok) ...[
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      // Await the fix first, then re-check once: the old
                      // fire-and-forget + blind 600 ms timer raced the grant.
                      // The resume observer covers system-screen returns.
                      await onFix();
                      await Future.delayed(const Duration(milliseconds: 600));
                      if (context.mounted) _refresh(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Text(actionLabel,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _refresh(BuildContext context) {
    final state =
        context.findAncestorStateOfType<_NotificationDiagnosticsScreenState>();
    state?._runChecks();
  }
}

/// Read-only list of what is currently armed on the OS alarm clock
/// ([NotificationService.armedReminders]). This is the difference between
/// "the phone swallowed a notification" and "the reminder was never scheduled"
/// — the first thing a reliability report needs to show.
class _ArmedRemindersCard extends StatelessWidget {
  final List<NativeReminderInfo> reminders;
  const _ArmedRemindersCard({required this.reminders});

  static const int _maxRows = 10;

  static String _formatIn(int minutes) {
    if (minutes <= 0) return 'اکنون';
    if (minutes < 60) return '$minutes دقیقه بعد';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h < 24) {
      return m == 0 ? '$h ساعت بعد' : '$h ساعت و $m دقیقه بعد';
    }
    final d = h ~/ 24;
    final hr = h % 24;
    return hr == 0 ? '$d روز بعد' : '$d روز و $hr ساعت بعد';
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final info = isDark ? AppTheme.darkInfo : AppTheme.lightInfo;
    final shown = reminders.take(_maxRows).toList();

    Widget label(String text, {double? size, FontWeight? weight, Color? color}) =>
        Text(text,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(
                    context, size ?? 12.5),
                fontWeight: weight,
                color: color ?? t.textPrimary));

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          settingsRow(Row(
            children: [
              Icon(Icons.schedule_outlined, size: 18, color: info),
              const SizedBox(width: 8),
              Expanded(
                child: label('هشدارهای زمان‌بندی‌شده',
                    size: 13.5, weight: FontWeight.w700),
              ),
              label('${reminders.length}', color: info, weight: FontWeight.w700),
            ],
          )),
          const SizedBox(height: 4),
          if (reminders.isEmpty)
            settingsRow(label(
              'هیچ هشداری در ساعت زنگولۀ سیستم فعال نیست. یادآوری‌ها پس از '
              'محاسبۀ اوقات یا فعال‌کردنشان اینجا فهرست می‌شوند.',
              size: 11.5,
              color: t.textMuted,
            ))
          else
            for (final r in shown)
              settingsRow(Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label(
                            r.title.isNotEmpty
                                ? r.title
                                : (r.channelId.isNotEmpty
                                    ? r.channelId
                                    : 'هشدار #${r.id}'),
                            size: 12.5),
                        const SizedBox(height: 1),
                        label('${_formatIn(r.fireInMinutes)} • شناسه ${r.id}',
                            size: 11, color: t.textMuted),
                      ],
                    ),
                  ),
                  if (r.repeatDaily)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: info.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: label('هر روز',
                          size: 10.5, color: info, weight: FontWeight.w700),
                    ),
                ],
              )),
          if (reminders.length > _maxRows)
            settingsRow(label('+${reminders.length - _maxRows} مورد دیگر',
                size: 11, color: t.textMuted)),
        ],
      ),
    );
  }
}
