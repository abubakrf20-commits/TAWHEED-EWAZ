import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/services/permission_service.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

class BatteryOptimizationScreen extends StatefulWidget {
  const BatteryOptimizationScreen({super.key});

  @override
  State<BatteryOptimizationScreen> createState() =>
      _BatteryOptimizationScreenState();
}

class _BatteryOptimizationScreenState extends State<BatteryOptimizationScreen>
    with WidgetsBindingObserver {
  /// Lowercase Build.MANUFACTURER from the native settings channel ('' when
  /// unavailable). Loaded once so the user's own brand guide sorts first
  /// (Audit 4.7). The previous implementation read a compile-time
  /// `String.fromEnvironment('deviceManufacturer')` const that is never
  /// defined — the sort silently ran with '' on every device.
  String _manufacturer = '';

  /// Null while the probe runs or when the channel cannot answer; the card
  /// must stay silent rather than claim the app is restricted (A-05).
  bool? _batteryIgnored;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadManufacturer();
    _loadBatteryStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The user changes the exemption in the system list, then comes back;
  /// refresh so the card never shows the pre-change state (A-05).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadBatteryStatus();
  }

  Future<void> _loadBatteryStatus() async {
    final ignored = await PermissionService().batteryOptimizationStatus();
    if (!mounted || ignored == _batteryIgnored) return;
    setState(() => _batteryIgnored = ignored);
  }

  Future<void> _loadManufacturer() async {
    final m = await PermissionService().deviceManufacturer();
    if (!mounted || m.isEmpty || m == _manufacturer) return;
    setState(() => _manufacturer = m);
  }

  static const _brands = [
    _BrandGuide(
      name: 'سامسونگ (Samsung)',
      matchKey: 'samsung',
      steps: [
        'Settings > Battery and device care > Battery > Background usage limits',
        'برنامه توحید را پیدا کنید و روی آن ضربه بزنید',
        'گزینه «Allow background activity» را فعال کنید',
        'برگردید به Settings > Apps > توحید > Battery',
        'گزینه «Unrestricted» را انتخاب کنید',
        'در Settings > Apps > توحید، مطمئن شوید «Allow autostart» فعال است',
      ],
    ),
    _BrandGuide(
      name: 'شیائومی (Xiaomi)',
      matchKey: 'xiaomi',
      steps: [
        'Settings > Apps > Manage apps > توحید > Autostart را فعال کنید',
        'Settings > Battery > Battery Saver > No restrictions را انتخاب کنید',
        'Settings > Apps > Manage apps > توحید > Other permissions > Show popup را فعال کنید',
        'در تسک‌منیجر، توحید را قفل کنید (دکمه قفل در منوی تسک‌منیجر)',
        'Settings > Notifications > App notifications > توحید > همه مجوزها را فعال کنید',
      ],
    ),
    _BrandGuide(
      name: 'هواوی (Huawei)',
      matchKey: 'huawei',
      steps: [
        'Settings > Battery > Launch > توحید > Manage manually را فعال کنید',
        'همه گزینه‌ها (Auto-launch, Secondary launch, Run in background) را فعال کنید',
        'Settings > Apps > Apps > توحید > Notifications > همه را فعال کنید',
        'Settings > Battery > App launch > توحید را روی «Manage manually» بگذارید و همه را فعال کنید',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'تنظیمات اعلان'),
      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(DsSpacing.page, 4, DsSpacing.page, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: t.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Icon(Icons.info_outline, color: t.primary, size: 32),
                const SizedBox(height: 8),
                Text(
                  'برای دریافت دقیق اعلان‌های اذان و یادآوری‌ها در پس‌زمینه، '
                  'باید مجوزهای زیر را فعال کنید. این مجوزها مخصوص گوشی‌های '
                  'سامسونگ، شیائومی و هواوی است.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      color: t.textPrimary),
                ),
              ],
            ),
          ),
          if (_batteryIgnored != null) ...[
            const SizedBox(height: 12),
            _batteryStatusCard(context, ignored: _batteryIgnored!),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.monitor_heart_outlined, size: 18),
              label: const Text('بررسی خودکار وضعیت گوشی'),
              onPressed: () => context.push(RouteNames.notificationDiagnostics),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'مراحل عمومی (همه گوشی‌ها):'),
          _stepChip(context,
              'Settings > Apps > توحید > Notifications > همه اعلان‌ها را فعال کنید'),
          _stepChip(context,
              'Settings > Apps > توحید > Permissions > Schedule exact alarms را فعال کنید'),
          _stepChip(context,
              'Settings > Apps > توحید > Set as System app (فقط شیائومی)'),
          _stepChip(context,
              'تنظیمات > باتری > بهینه‌سازی باتری > توحید > بدون محدودیت'),
          const SizedBox(height: 12),
          const SectionHeader(title: 'مراحل اختصاصی بر اساس برند گوشی:'),
          // Audit 4.7: the detected brand's guide is shown first.
          ..._sortedBrands(_manufacturer)
              .map((brand) => _BrandSection(brand: brand)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.battery_alert, size: 18),
              label: const Text('باز کردن تنظیمات باتری گوشی'),
              onPressed: _openBatterySettings,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// A-05: the exemption is what decides whether inexact reminders can slip
  /// through Doze. This states the measured state (and stays silent when the
  /// probe cannot answer) instead of guessing, and puts the system list one
  /// tap away. Adhan itself is scheduled with exactAllowWhileIdle, so it does
  /// not depend on this setting — the copy says so.
  Widget _batteryStatusCard(BuildContext context, {required bool ignored}) {
    final t = TimeThemeKit.of(context).palette;
    final accent = ignored ? AppTheme.success : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ignored ? Icons.check_circle_outline : Icons.battery_alert,
                  color: accent, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ignored
                          ? 'بهینه‌سازی باتری غیرفعال است'
                          : 'توحید در فهرست بهینه‌سازی باتری نیست',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ignored
                          ? 'اندروید اجرای پس‌زمینهٔ برنامه را محدود نمی‌کند؛ '
                              'اذان و یادآورها بدون تأخیر می‌رسند.'
                          : 'اندروید در حالت Doze ممکن است برخی یادآورها را با '
                              'تأخیر برساند. اذان‌ها با آلارم دقیق زمان‌بندی '
                              'می‌شوند و به این تنظیم وابسته نیستند، اما برای '
                              'اطمینان از رسیدن همهٔ یادآورها این گزینه را فعال کنید.',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        height: 1.7,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!ignored) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _openBatterySettings,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('باز کردن فهرست بهینه‌سازی باتری'),
                style: TextButton.styleFrom(foregroundColor: accent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openBatterySettings() {
    // Through PermissionService so channel failures are logged there instead
    // of escaping as an unhandled MissingPluginException (tests, early boot,
    // desktop targets without the Android handler).
    PermissionService().openBatteryOptimizationSettings();
  }

  /// Brands with the user's own manufacturer moved to the front (Audit 4.7).
  /// Stable: brands that do not match keep their declared order.
  static List<_BrandGuide> _sortedBrands(String manufacturer) {
    final sorted = List<_BrandGuide>.of(_brands);
    if (manufacturer.isEmpty) return sorted;
    final order = List<int>.generate(sorted.length, (i) => i);
    order.sort((a, b) {
      final ra = manufacturer.contains(sorted[a].matchKey) ? 0 : a + 1;
      final rb = manufacturer.contains(sorted[b].matchKey) ? 0 : b + 1;
      return ra.compareTo(rb);
    });
    return [for (final i in order) sorted[i]];
  }

  Widget _stepChip(BuildContext context, String text) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  color: t.textSecondary)),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      color: t.textPrimary))),
        ],
      ),
    );
  }
}

class _BrandGuide {
  final String name;

  /// Lowercase key matched against Build.MANUFACTURER (Audit 4.7).
  final String matchKey;
  final List<String> steps;
  const _BrandGuide({
    required this.name,
    required this.matchKey,
    required this.steps,
  });
}

class _BrandSection extends StatelessWidget {
  final _BrandGuide brand;
  const _BrandSection({required this.brand});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(brand.name,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    color: t.textPrimary)),
            const SizedBox(height: 8),
            ...List.generate(brand.steps.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 11),
                              color: t.primary,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(brand.steps[i],
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 12),
                                color: t.textPrimary))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
