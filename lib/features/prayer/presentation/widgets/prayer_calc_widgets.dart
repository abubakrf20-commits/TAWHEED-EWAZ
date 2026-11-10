import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/presentation/utils/prayer_calc_details.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// «خودکار» is the app default, so it leads the picker; the rest follow the
/// enum declaration order (the append-only persistence order).
final List<CalculationMethodOption> _methodPickerOrder = [
  CalculationMethodOption.auto,
  ...CalculationMethodOption.values
      .where((m) => m != CalculationMethodOption.auto),
];

/// Bottom sheet that lets the user pick the calculation method. Each option
/// shows its default Fajr/Isha angles so the choice is informed.
Future<void> showCalculationMethodPicker(
  BuildContext context, {
  required CalculationMethodOption selected,
  required ValueChanged<CalculationMethodOption> onSelected,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => ListView(
        controller: scrollController,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: TimeThemeKit.of(context).palette.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('انتخاب روش محاسبه',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 16),
                    fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'هر روش بر پایه زاویه‌های مشخصی از خورشید حساب می‌شود. زاویه فجر/عشاء هر روش در زیر آن آمده است.',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textMuted),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          ..._methodPickerOrder.map((opt) {
            final isSelected = opt == selected;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SettingRow(
                icon: Icons.calculate_outlined,
                title: opt.label,
                subtitle: opt.description,
                trailing: isSelected
                    ? Icon(Icons.check_circle,
                        color: TimeThemeKit.of(context).palette.primary,
                        size: 20)
                    : null,
                showChevron: !isSelected,
                onTap: () {
                  onSelected(opt);
                  Navigator.pop(context);
                },
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

/// Bottom sheet with every input that went into today's calculation —
/// location, method, angles, madhab, altitude and adjustments — for user
/// trust.
Future<void> showPrayerCalculationDetails(
  BuildContext context,
  WidgetRef ref,
) async {
  final service = ref.read(prayerTimeServiceProvider);
  final settings = ref.read(settingsProvider).value ?? const AppSettings();
  final pkg = await PackageInfo.fromPlatform();
  // The offset actually in effect for the device's zone today, so the sheet
  // shows exactly what the engine renders against.
  Duration? zoneOffset;
  try {
    tzdata.initializeTimeZones();
    zoneOffset =
        tz.TZDateTime.from(DateTime.now(), tz.getLocation(settings.timezone))
            .timeZoneOffset;
  } catch (e) {
    AppLogger.warning('PrayerCalcDetails', 'tz init failed for offset: $e');
    zoneOffset = null;
  }
  final rows = buildCalculationDetails(
    settings: settings,
    cityName: service.cityName,
    coordinates: service.coordinates,
    params: service.calculationParams,
    altitude: service.altitude,
    date: DateTime.now(),
    timezone: settings.timezone,
    timezoneOffset: zoneOffset,
    appVersion: '${pkg.version} (${pkg.buildNumber})',
  );
  if (!context.mounted) return;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => PrayerCalculationDetailsSheet(rows: rows),
  );
}

/// The details sheet content — public so it can be tested in isolation.
class PrayerCalculationDetailsSheet extends StatelessWidget {
  final List<CalcDetailRow> rows;

  const PrayerCalculationDetailsSheet({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => ListView(
        controller: scrollController,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: TimeThemeKit.of(context).palette.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Icon(Icons.science_outlined,
                    size: 20, color: TimeThemeKit.of(context).palette.primary),
                const SizedBox(width: 8),
                Text('جزئیات محاسبه اوقات شرعی',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'این مقادیر دقیقاً همان ورودی‌هایی است که اوقات امروز با آن‌ها محاسبه شده است.',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textMuted),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          ...rows.map((row) => _DetailRow(row: row)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final CalcDetailRow row;
  const _DetailRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(row.label,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: TimeThemeKit.of(context).palette.textMuted,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(row.value,
                textAlign: TextAlign.left,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: TimeThemeKit.of(context).palette.textPrimary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Labeled slider for the custom Fajr/Isha angles (0.5° steps), on the kit
/// slider row.
class PrayerAngleSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onSettled;
  final double min;
  final double max;
  final IconData icon;
  final Color accent;

  const PrayerAngleSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onSettled,
    this.min = 10,
    this.max = 21,
    this.icon = Icons.tune_outlined,
    this.accent = TopicHues.prayer,
  });

  @override
  Widget build(BuildContext context) {
    final display =
        value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
    return SettingsSliderRow(
      icon: icon,
      accent: accent,
      title: label,
      valueText: '$display°',
      value: value.clamp(min, max),
      min: min,
      max: max,
      divisions: ((max - min) * 2).round(),
      onChanged: onChanged,
      onSettled: onSettled,
    );
  }
}
