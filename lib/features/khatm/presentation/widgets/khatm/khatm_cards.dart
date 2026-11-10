import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/shared/widgets/latin_time_picker.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/features/khatm/presentation/widgets/khatm/khatm_common.dart';
import 'package:tawheeed/features/khatm/presentation/widgets/khatm/khatm_utils.dart';
import 'package:tawheeed/features/khatm/presentation/widgets/khatm/khatm_summary_card.dart';
import 'package:tawheeed/features/khatm/presentation/widgets/khatm/khatm_juz_grid.dart';

class ParticipantsCard extends StatelessWidget {
  final KhatmModel khatm;
  const ParticipantsCard({super.key, required this.khatm});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = TopicHues.khatm;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KhatmSectionHeader(
            icon: Icons.group,
            color: accent,
            title: 'شرکت‌کنندگان',
          ),
          const SizedBox(height: 14),
          ...khatm.participants.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: accent.withValues(alpha: 0.35)),
                      ),
                      child: Text(p.name.isNotEmpty ? p.name[0] : '?',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppTheme.scaledFontSize(context, 15),
                              color: dsContentColor(context, accent))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: TextStyle(
                                  color: t.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 14))),
                          const SizedBox(height: 2),
                          Text(
                              p.assignedJuzs.isNotEmpty
                                  ? 'جزء ${p.assignedJuzs.first}-${p.assignedJuzs.last}'
                                  : 'بدون سهم',
                              style: TextStyle(
                                  color: t.textMuted,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 11.5))),
                        ],
                      ),
                    ),
                    ParticipantProgress(p: p, khatm: khatm),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class ParticipantProgress extends StatelessWidget {
  final KhatmParticipant p;
  final KhatmModel khatm;
  const ParticipantProgress({super.key, required this.p, required this.khatm});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final total = p.assignedJuzs.length;
    if (total == 0) return const SizedBox.shrink();
    final done = p.assignedJuzs.where((j) => isJuzCompletedOf(khatm, j)).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: success.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$done از $total جزء',
        style: TextStyle(
          fontSize: AppTheme.scaledFontSize(context, 10.5),
          fontWeight: FontWeight.w700,
          color: dsContentColor(context, success),
        ),
      ),
    );
  }
}

class TargetCard extends StatelessWidget {
  final KhatmModel khatm;
  const TargetCard({super.key, required this.khatm});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final dailyTarget = khatm.dailyTarget;
    final deadline = khatm.startDate.add(Duration(days: khatm.targetDays));
    final daysLeft = deadline.difference(DateTime.now()).inDays.clamp(0, 9999);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KhatmSectionHeader(
            icon: Icons.flag,
            color: warning,
            title: 'هدف روزانه',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: warning.withValues(alpha: 0.30)),
              ),
              child: Text(
                '$daysLeft روز مانده',
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w700,
                  color: dsContentColor(context, warning),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'برای اتمام به موقع، روزانه $dailyTarget صفحه بخوانید',
            style: TextStyle(
              color: t.textSecondary,
              fontSize: AppTheme.scaledFontSize(context, 12.5),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class CompletionCard extends ConsumerWidget {
  final DateTime? endDate;
  const CompletionCard({super.key, required this.endDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hijriOffset = ref.watch(hijriOffsetProvider);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E1A) : AppTheme.success,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
            ),
            child: const Icon(Icons.celebration, size: 34, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text('مبارک است!',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 22),
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text('ختم قرآن با موفقیت به پایان رسید',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: AppTheme.scaledFontSize(context, 14))),
          if (endDate != null) ...[
            const SizedBox(height: 4),
            Builder(builder: (context) {
              final hijri = HijriUtils.hijriFromGreg(
                endDate!.year,
                endDate!.month,
                endDate!.day,
                offset: hijriOffset,
              );
              const monthNames = [
                'محرم',
                'صفر',
                'ربیع‌الاول',
                'ربیع‌الثانی',
                'جمادی‌الاول',
                'جمادی‌الثانی',
                'رجب',
                'شعبان',
                'رمضان',
                'شوال',
                'ذی‌القعده',
                'ذی‌الحجه',
              ];
              return Text(
                'تاریخ اتمام: ${NumberFormat.normalizeDigits('${hijri.day}')} '
                '${monthNames[hijri.month - 1]} '
                '${NumberFormat.normalizeDigits('${hijri.year}')} هجری قمری',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: AppTheme.scaledFontSize(context, 12.5)),
              );
            }),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('604 صفحه',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('100٪ کامل',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class KhatmContent extends StatelessWidget {
  final KhatmModel khatm;
  const KhatmContent({super.key, required this.khatm});

  @override
  Widget build(BuildContext context) {
    final daysElapsed = DateTime.now().difference(khatm.startDate).inDays;
    final readPages = khatm.readPages;
    final avgPerDay = daysElapsed > 0 ? (readPages / daysElapsed) : 0.0;

    return ListView(
      // Extra bottom space so the «ثبت پیشرفت» FAB never covers the last
      // card (e.g. the daily-target number).
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 4, DsSpacing.page, 100),
      children: [
        KhatmSummaryCard(
          khatm: khatm,
          daysElapsed: daysElapsed,
          avgPerDay: avgPerDay,
        ),
        const SizedBox(height: 12),
        JuzGridWidget(khatm: khatm),
        const SizedBox(height: 12),
        if (khatm.isGroup && khatm.participants.isNotEmpty) ...[
          const SizedBox(height: 12),
          ParticipantsCard(khatm: khatm),
        ],
        if (!khatm.isCompleted) ...[
          const SizedBox(height: 12),
          KhatmReminderCard(dailyTarget: khatm.dailyTarget),
          const SizedBox(height: 12),
          TargetCard(khatm: khatm),
        ],
        if (khatm.isCompleted) ...[
          const SizedBox(height: 12),
          CompletionCard(endDate: khatm.endDate),
        ],
      ],
    );
  }
}

/// یادآوری روزانه خواندن صفحات ختم قرآن — با انتخاب ساعت دلخواه.
class KhatmReminderCard extends StatefulWidget {
  /// تعداد صفحات پیشنهادی امروز (برای متن اعلان).
  final int dailyTarget;
  const KhatmReminderCard({super.key, required this.dailyTarget});

  @override
  State<KhatmReminderCard> createState() => _KhatmReminderCardState();
}

class _KhatmReminderCardState extends State<KhatmReminderCard> {
  SharedPreferences? _prefs;
  bool _enabled = false;

  /// False until the stored prefs are read: an unread switch shows «خاموش» for
  /// every user, so it must not accept a tap that would write the inverse.
  bool _loaded = false;
  bool _busy = false;
  int _hour = NotificationService.defaultKhatmHour;
  int _minute = NotificationService.defaultKhatmMinute;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      if (!mounted) return;
      setState(() {
        _enabled = prefs.getBool(NotificationService.khatmEnabledKey) ?? false;
        _hour = prefs.getInt(NotificationService.khatmHourKey) ??
            NotificationService.defaultKhatmHour;
        _minute = prefs.getInt(NotificationService.khatmMinuteKey) ??
            NotificationService.defaultKhatmMinute;
        _loaded = true;
      });
    } catch (e) {
      AppLogger.warning('khatm_cards', 'reminder prefs read failed: $e');
      if (!mounted) return;
      // Never leave the card permanently inert after a failed read.
      setState(() => _loaded = true);
    }
  }

  /// Schedules/cancels first and only then persists the flag: the stored
  /// value must never claim a reminder the OS refused to book. A failure rolls
  /// the switch back and says so instead of leaving «روشن» on a dead reminder.
  Future<void> _setEnabled(bool value) async {
    final previous = _enabled;
    setState(() {
      _enabled = value;
      _busy = true;
    });
    try {
      if (value) {
        await NotificationService().scheduleKhatmReminder(
          time: TimeOfDay(hour: _hour, minute: _minute),
          dailyTarget: widget.dailyTarget,
        );
      } else {
        await NotificationService().cancelKhatmReminder();
      }
      await _prefs?.setBool(NotificationService.khatmEnabledKey, value);
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.success(
          context, value ? 'یادآوری روزانه فعال شد' : 'یادآوری روزانه غیرفعال شد');
    } catch (e) {
      AppLogger.warning('khatm_cards', 'khatm reminder toggle failed: $e');
      if (!mounted) return;
      setState(() {
        _enabled = previous;
        _busy = false;
      });
      AppSnackBar.error(
          context, 'تغییر یادآوری انجام نشد؛ دوباره تلاش کنید.');
    }
  }

  Future<void> _pickTime() async {
    final picked = await showLatinTimePicker(context,
        initialTime: TimeOfDay(hour: _hour, minute: _minute),
        title: 'ساعت یادآوری روزانه');
    // The card can be disposed while the picker sheet is open.
    if (picked == null || !mounted) return;
    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
    });
    await _prefs?.setInt(NotificationService.khatmHourKey, _hour);
    await _prefs?.setInt(NotificationService.khatmMinuteKey, _minute);
    if (_enabled) {
      await NotificationService().scheduleKhatmReminder(
        time: TimeOfDay(hour: _hour, minute: _minute),
        dailyTarget: widget.dailyTarget,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    const accent = TopicHues.khatm;
    final timeLabel =
        '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KhatmSectionHeader(
            icon: Icons.notifications_active,
            color: accent,
            title: 'یادآوری روزانه',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (_enabled ? success : accent).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color:
                        (_enabled ? success : accent).withValues(alpha: 0.30)),
              ),
              child: Text(
                _enabled ? 'روزانه $timeLabel' : 'خاموش',
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w700,
                  color: dsContentColor(context, _enabled ? success : accent),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'هر روز در ساعت مشخص، خواندن صفحات ختم را یادآوری کن تا از برنامه عقب نیفتی',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    height: 1.5,
                    color: t.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _enabled,
                // Inert until the stored value is known, and while a write is
                // in flight (a second tap would race the first).
                onChanged: _loaded && !_busy ? _setEnabled : null,
                activeThumbColor: success,
              ),
            ],
          ),
          if (_enabled) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: t.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.outline.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 18, color: dsContentColor(context, accent)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ساعت یادآوری',
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: t.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 15),
                        fontWeight: FontWeight.w800,
                        color: dsContentColor(context, accent),
                      ),
                    ),
                    Icon(Icons.chevron_left, size: 20, color: t.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
