import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/services/silent_mode_service.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';

/// Lets the user keep the device silent for a few minutes AFTER the iqamah
/// (in addition to the «before iqamah» window). Default 0 = unmute exactly at
/// the iqamah. Stored in SharedPreferences so no Drift schema change is needed.
class SilentAfterIqamahTile extends ConsumerStatefulWidget {
  const SilentAfterIqamahTile({super.key});

  @override
  ConsumerState<SilentAfterIqamahTile> createState() =>
      _SilentAfterIqamahTileState();
}

class _SilentAfterIqamahTileState extends ConsumerState<SilentAfterIqamahTile> {
  int? _minutes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await SilentModeService.instance.afterIqamahMinutes();
    if (mounted) setState(() => _minutes = value);
  }

  Future<void> _set(int value) async {
    // Audit 8.21-4: clamp to the service's 0..120 range. The old UI-side 60
    // silently capped an already-persisted 90-minute value back to 60 on the
    // next tap, even though the service stores up to 120.
    final clamped = value.clamp(0, 120).toInt();
    setState(() => _minutes = clamped);
    await SilentModeService.instance.setAfterIqamahMinutes(clamped);
    await _reschedule();
  }

  Future<void> _reschedule() async {
    try {
      final service = ref.read(prayerTimeServiceProvider);
      final s = ref.read(settingsProvider).value ?? const AppSettings();
      if (service.prayerTimes != null) {
        await ref
            .read(dailyNotificationSchedulerProvider)
            .forceReschedule(prayerService: service, settings: s);
      }
    } catch (e) {
      // Best-effort; the change still applies on the next app launch.
      AppLogger.warning('SilentAfterIqamah', 'channel tweak failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _minutes;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: SettingRow(
        icon: Icons.timer_outlined,
        title: 'ماندن بی‌صدا بعد از اقامه (دقیقه)',
        subtitle: minutes == null
            ? null
            : minutes == 0
                ? 'باز شدن صدا دقیقاً هنگام اقامه'
                : 'باز شدن صدا $minutes دقیقه بعد از اقامه',
        showChevron: false,
        trailing: SettingsStepper(
          value: minutes ?? 0,
          max: 120,
          unit: 'دقیقه',
          semanticLabel: 'ماندن بی‌صدا بعد از اقامه',
          onChanged: minutes == null ? null : _set,
        ),
      ),
    );
  }
}
