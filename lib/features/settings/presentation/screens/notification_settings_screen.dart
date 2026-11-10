import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/section_colors.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/models/day_time.dart';
import 'package:tawheeed/shared/services/friday_content.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/notification_settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_flash.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_section_hues.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:tawheeed/shared/widgets/async_screen.dart';

/// The single «اعلان‌ها و اذکار» section — every notification category in one
/// place: morning/evening adhkar, daily آیه/حدیث/دعا, Quran reminder, Islamic
/// occasions, Friday reminder, snooze duration and a master "cancel everything".
///
/// Every toggle goes through [NotificationSettings] so the change is persisted
/// and the scheduled notifications are reconciled immediately (the old inline
/// azkar section only saved the flag and took effect the next day).
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with SettingsHighlight<NotificationSettingsScreen> {
  late final Map<String, GlobalKey> _anchors = {
    'adhkar': GlobalKey(),
    'post_prayer': GlobalKey(),
    'daily': GlobalKey(),
    'quran': GlobalKey(),
    'events': GlobalKey(),
    'friday': GlobalKey(),
    'fasting': GlobalKey(),
    'misc': GlobalKey(),
  };

  @override
  Map<String, GlobalKey> get highlightAnchors => _anchors;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    bindSettingsHighlight();
  }

  @override
  void dispose() {
    disposeSettingsHighlight();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // One hue for the whole page: every header here belongs to «اعلان‌ها و
    // اذکار», so the accent matches the bar that opened this screen instead of
    // turning the eight sections into a rainbow.
    final sectionAccent = SettingsSectionHues.on(
        context, SettingsSectionHues.notifications);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SettingsAppBar(title: 'اعلان‌ها و اذکار'),
      // WHY the branch: this screen used to render
      // `ref.watch(...).value ?? const AppSettings()`, i.e. the FACTORY
      // DEFAULTS, while the Drift read was still in flight — and forever if it
      // failed. Every one of the eight live switches showed a value the user
      // had not chosen, and flipping one wrote from that default rather than
      // from what was stored. A pending read is a spinner; a failed read is a
      // panel that says so; only a read value is a switch.
      body: AsyncScreen<AppSettings>(
        asyncValue: ref.watch(notificationSettingsProvider),
        onRetry: () => ref.invalidate(notificationSettingsProvider),
        loading: const _NotificationSettingsSkeleton(),
        error: (context, error, stack, retry) =>
            _NotificationSettingsLoadFailure(error: error, onRetry: retry),
        data: (settings) => _buildBody(context, settings, sectionAccent),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, AppSettings settings, Color sectionAccent) {
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final adhkarEnabled =
        settings.morningAzkarNotification || settings.eveningAzkarNotification;
    // The events flag lives in SharedPreferences, not in `settings`. It is read
    // separately, so it can still be pending after the settings row landed —
    // the switch stays inert until its own read answers instead of claiming
    // «on» (its default) for a user who had turned it off.
    final eventsAsync = ref.watch(islamicEventsEnabledProvider);
    final eventsEnabled = eventsAsync.value ?? true;
    // Changing the key remounts the pref-backed cards so they re-read
    // SharedPreferences after «لغو همه» (initState is the source of truth).
    final cancelAllTick = ref.watch(cancelAllTickProvider);

    return ListView(
        // The route-driven highlight (see SettingsHighlight) walks the lazy
        // list down to the anchored row.
        controller: highlightScrollController,
        padding:
            const EdgeInsets.fromLTRB(DsSpacing.page, 4, DsSpacing.page, 32),
        children: [
          // Warns when Android denied exact alarms: every reminder silently
          // falls back to inexact mode and Doze can delay it by hours.
          const _ExactAlarmBanner(),
          const SettingsSaveFailureBanner(),
          // ── اذکار صبح و شب ────────────────────────────────────────────────
          SettingsFlashSection(
            rowKey: 'adhkar',
            flashKey: highlightFlashKey,
            child: SectionHeader(
              key: _anchors['adhkar'],
              title: 'اذکار صبح و شب',
              accent: sectionAccent,
            ),
          ),
          SettingsCard(children: [
            SwitchTile(
              title: 'یادآوری اذکار',
              subtitle: 'فعال یا غیرفعال کردن اذکار صبح و شب با هم',
              icon: Icons.brightness_5_outlined,
              value: adhkarEnabled,
              onChanged: notifier.toggleAdhkarNotifications,
            ),
            const SettingsDivider(),
            SwitchTile(
              title: 'اذکار صبح',
              icon: Icons.wb_sunny_outlined,
              value: settings.morningAzkarNotification,
              onChanged: notifier.setMorningAzkar,
            ),
            if (settings.morningAzkarNotification) ...[
              const SettingsDivider(),
              _AzkarTimeTile(
                morning: true,
                label: 'اذکار صبح',
                current: _toTimeOfDay(settings.morningAzkarTime),
                anchoredHint:
                    'پیش‌فرض: 45 دقیقه پس از اذان صبح. با «ساعت ثابت» زمان دلخواه بگذارید.',
              ),
            ],
            const SettingsDivider(),
            SwitchTile(
              title: 'اذکار شب',
              icon: Icons.nights_stay_outlined,
              value: settings.eveningAzkarNotification,
              onChanged: notifier.setEveningAzkar,
            ),
            if (settings.eveningAzkarNotification) ...[
              const SettingsDivider(),
              _AzkarTimeTile(
                morning: false,
                label: 'اذکار شب',
                current: _toTimeOfDay(settings.eveningAzkarTime),
                anchoredHint:
                    'پیش‌فرض: 1 ساعت پس از اذان عصر. با «ساعت ثابت» زمان دلخواه بگذارید.',
              ),
            ],
          ]),
          const SizedBox(height: 20),

          // ── اذکار بعد از نماز ─────────────────────────────────────────────
          SettingsFlashSection(
            rowKey: 'post_prayer',
            flashKey: highlightFlashKey,
            child: SectionHeader(
              key: _anchors['post_prayer'],
              title: 'اذکار بعد از نماز',
              accent: sectionAccent,
            ),
          ),
          _PostPrayerAzkarCard(key: ValueKey(cancelAllTick)),
          const SizedBox(height: 20),

          // ── یادآوری‌های روزانه ────────────────────────────────────────────
          SettingsFlashSection(
            rowKey: 'daily',
            flashKey: highlightFlashKey,
            child: SectionHeader(
              key: _anchors['daily'],
              title: 'یادآوری‌های روزانه',
              accent: sectionAccent,
            ),
          ),
          SettingsCard(children: [
            SwitchTile(
              title: 'آیه روز',
              subtitle: 'یک آیه همراه با ترجمه هر روز',
              icon: Icons.menu_book_outlined,
              value: settings.dailyVerse,
              onChanged: (v) async {
                await notifier.setDailyVerse(v);
                await notifier.rescheduleAll();
              },
            ),
            if (settings.dailyVerse) ...[
              const SettingsDivider(),
              TimePickerTile(
                time: _toTimeOfDay(settings.dailyVerseTime),
                label: 'زمان آیه روز',
                onPicked: (t) async {
                  await notifier.setDailyVerseTime(
                      DayTime(hour: t.hour, minute: t.minute));
                  await notifier.rescheduleAll();
                },
              ),
            ],
            const SettingsDivider(),
            SwitchTile(
              title: 'حدیث روز',
              subtitle: 'حدیثی از چهل حدیث هر روز',
              icon: Icons.auto_stories,
              value: settings.dailyHadith,
              onChanged: (v) async {
                await notifier.setDailyHadith(v);
                await notifier.rescheduleAll();
              },
            ),
            if (settings.dailyHadith) ...[
              const SettingsDivider(),
              TimePickerTile(
                time: _toTimeOfDay(settings.dailyHadithTime),
                label: 'زمان حدیث روز',
                onPicked: (t) async {
                  await notifier.setDailyHadithTime(
                      DayTime(hour: t.hour, minute: t.minute));
                  await notifier.rescheduleAll();
                },
              ),
            ],
            const SettingsDivider(),
            SwitchTile(
              title: 'دعای روز',
              subtitle: 'دعایی کوتاه همراه با ترجمه هر روز',
              icon: Icons.favorite_outline,
              value: settings.dailyDua,
              onChanged: (v) async {
                await notifier.setDailyDua(v);
                await notifier.rescheduleAll();
              },
            ),
            if (settings.dailyDua) ...[
              const SettingsDivider(),
              TimePickerTile(
                time: _toTimeOfDay(settings.dailyDuaTime),
                label: 'زمان دعای روز',
                onPicked: (t) async {
                  await notifier
                      .setDailyDuaTime(DayTime(hour: t.hour, minute: t.minute));
                  await notifier.rescheduleAll();
                },
              ),
            ],
          ]),
          const SizedBox(height: 20),

          // ── یادآوری قرآن ──────────────────────────────────────────────────
          SettingsFlashSection(
            rowKey: 'quran',
            flashKey: highlightFlashKey,
            child: SectionHeader(
              key: _anchors['quran'],
              title: 'یادآوری قرآن',
              accent: sectionAccent,
            ),
          ),
          SettingsCard(children: [
            SwitchTile(
              title: 'یادآوری تلاوت قرآن',
              subtitle: 'یادآوری روزانه خواندن قرآن',
              icon: Icons.menu_book_outlined,
              value: settings.quranReminder,
              onChanged: (v) async {
                await notifier.setQuranReminder(v);
                await notifier.rescheduleAll();
              },
            ),
            if (settings.quranReminder) ...[
              const SettingsDivider(),
              TimePickerTile(
                time: _toTimeOfDay(settings.quranReminderTime),
                label: 'زمان یادآوری قرآن',
                onPicked: (t) async {
                  await notifier.setQuranReminderTime(
                      DayTime(hour: t.hour, minute: t.minute));
                  await notifier.rescheduleAll();
                },
              ),
            ],
          ]),
          const SizedBox(height: 20),

          // ── مناسبت‌های اسلامی ─────────────────────────────────────────────
          SettingsFlashSection(
            rowKey: 'events',
            flashKey: highlightFlashKey,
            child: SectionHeader(
              key: _anchors['events'],
              title: 'مناسبت‌های اسلامی',
              accent: sectionAccent,
            ),
          ),
          SettingsCard(children: [
            SwitchTile(
              title: 'یادآوری مناسبت‌ها',
              subtitle: 'اعیاد و مناسبت‌های اسلامی چند روز پیش از فرارسیدن',
              icon: Icons.event_outlined,
              value: eventsEnabled,
              onChanged: eventsAsync.hasValue
                  ? notifier.toggleIslamicEventNotifications
                  : null,
            ),
          ]),
          const SizedBox(height: 20),

          // ── یادآوری روز جمعه ──────────────────────────────────────────────
          SettingsFlashSection(
            rowKey: 'friday',
            flashKey: highlightFlashKey,
            child: SectionHeader(
              key: _anchors['friday'],
              title: 'یادآوری روز جمعه',
              accent: sectionAccent,
            ),
          ),
          _FridayReminderCard(key: ValueKey(cancelAllTick)),
          const SizedBox(height: 20),
          _FridayKahfCard(key: ValueKey('friday_kahf_$cancelAllTick')),
          const SizedBox(height: 20),

          // ── یادآوری روزه‌های مستحب ─────────────────────────────────────────
          SettingsFlashSection(
            rowKey: 'fasting',
            flashKey: highlightFlashKey,
            child: SectionHeader(
              key: _anchors['fasting'],
              title: 'یادآوری روزه‌های مستحب',
              accent: sectionAccent,
            ),
          ),
          _FastingReminderCard(
            key: ValueKey('fasting_mon_thu_$cancelAllTick'),
            title: 'روزهٔ دوشنبه و پنجشنبه',
            subtitle: 'یادآوری هفتگی روزه‌های مستحب هفته',
            icon: Icons.event_repeat,
            enabledKey: NotificationService.fastingMonThuEnabledKey,
            hourKey: NotificationService.fastingMonThuHourKey,
            minuteKey: NotificationService.fastingMonThuMinuteKey,
            note: 'دوشنبه و پنجشنبه',
            save: ({required enabled, required hour, required minute}) => ref
                .read(notificationSettingsProvider.notifier)
                .setFastingMonThu(
                    enabled: enabled, hour: hour, minute: minute),
          ),
          const SizedBox(height: 20),
          _FastingReminderCard(
            key: ValueKey('fasting_bidh_$cancelAllTick'),
            title: 'روزهٔ ایام بیض',
            subtitle: 'روزهای ۱۳، ۱۴ و ۱۵ هر ماه قمری',
            icon: Icons.nightlight_round,
            enabledKey: NotificationService.fastingBidhEnabledKey,
            hourKey: NotificationService.fastingBidhHourKey,
            minuteKey: NotificationService.fastingBidhMinuteKey,
            note: 'هر ماه قمری',
            save: ({required enabled, required hour, required minute}) => ref
                .read(notificationSettingsProvider.notifier)
                .setFastingBidh(
                    enabled: enabled, hour: hour, minute: minute),
          ),
          const SizedBox(height: 20),

          // ── سایر ──────────────────────────────────────────────────────────
          SettingsFlashSection(
            rowKey: 'misc',
            flashKey: highlightFlashKey,
            child: SectionHeader(
              key: _anchors['misc'],
              title: 'سایر',
              accent: sectionAccent,
            ),
          ),
          SettingsCard(children: [
            const _SnoozeTile(),
            const SettingsDivider(),
            settingsRow(SettingRow(
              icon: Icons.notifications_off,
              title: 'لغو همه یادآوری‌ها',
              subtitle: 'خاموش کردن همه اعلان‌ها و اذان‌ها',
              showChevron: false,
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('لغو همه یادآوری‌ها'),
                    content: const Text(
                        'همه‌ی اعلان‌ها، اذان‌ها و یادآوری‌ها خاموش می‌شوند. ادامه می‌دهید؟'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('انصراف')),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('خاموش کردن همه'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                try {
                  await notifier.disableAllReminders();
                } finally {
                  // Pref-backed cards cache their toggles from initState —
                  // bump the tick so they remount and reload (now false).
                  ref.read(cancelAllTickProvider.notifier).bump();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('همه یادآوری‌ها لغو و خاموش شدند')));
                }
              },
            )),
          ]),
          const SizedBox(height: 40),
        ],
      );
  }

  static TimeOfDay _toTimeOfDay(DayTime t) =>
      TimeOfDay(hour: t.hour, minute: t.minute);
}

/// زمان اذکار صبح/شب با دو حالت: «مبتنی بر اذان» (پیش‌فرض: 45 دقیقه بعد از
/// اذان صبح و 1 ساعت بعد از اذان عصر) یا «ساعت ثابت» که کاربر انتخاب می‌کند.
/// حالت قبلاً فقط روشن می‌شد و هیچ راه برگشتی نداشت.
class _AzkarTimeTile extends ConsumerStatefulWidget {
  final bool morning;
  final String label;
  final TimeOfDay current;
  final String anchoredHint;

  const _AzkarTimeTile({
    required this.morning,
    required this.label,
    required this.current,
    required this.anchoredHint,
  });

  @override
  ConsumerState<_AzkarTimeTile> createState() => _AzkarTimeTileState();
}

class _AzkarTimeTileState extends ConsumerState<_AzkarTimeTile> {
  bool? _manual;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final manual = await ref
          .read(notificationServiceProvider)
          .isAzkarManual(morning: widget.morning);
      if (mounted) setState(() => _manual = manual);
    } catch (e) {
      // Mocked service in tests — fall back to the prayer-anchored default.
      AppLogger.warning('_AzkarTimeTileState', 'isAzkarManual unavailable: $e');
      if (mounted) setState(() => _manual = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Until the stored mode loads, show a quiet placeholder instead of the
    // prayer-anchored tab — flashing the wrong tab on slow disks (finding).
    if (_manual == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: SizedBox(
          height: 64,
          child: Center(
            child:
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }
    final manual = _manual!;
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('زمان ${widget.label}',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: t.textPrimary)),
          const SizedBox(height: 8),
          SegmentedTabs(
            tabs: const [
              SegmentedTab(label: 'مبتنی بر اذان'),
              SegmentedTab(label: 'ساعت ثابت'),
            ],
            index: manual ? 1 : 0,
            onChanged: (i) async {
              final value = i == 1;
              setState(() => _manual = value);
              final notifier = ref.read(notificationSettingsProvider.notifier);
              if (value) {
                await notifier.setAzkarTime(
                    DayTime(
                        hour: widget.current.hour,
                        minute: widget.current.minute),
                    morning: widget.morning);
              } else {
                await notifier.setAzkarPrayerAnchored(morning: widget.morning);
              }
            },
          ),
          if (manual)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TimePickerTile(
                time: widget.current,
                label: 'ساعت ${widget.label}',
                onPicked: (t) => ref
                    .read(notificationSettingsProvider.notifier)
                    .setAzkarTime(DayTime(hour: t.hour, minute: t.minute),
                        morning: widget.morning),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                widget.anchoredHint,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: t.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Snooze duration selector. The value is applied to the notification-service
/// singleton for use by the notification action buttons.
class _SnoozeTile extends ConsumerStatefulWidget {
  const _SnoozeTile();

  @override
  ConsumerState<_SnoozeTile> createState() => _SnoozeTileState();
}

class _SnoozeTileState extends ConsumerState<_SnoozeTile> {
  static const _options = [5, 10, 15];
  late int _minutes;

  @override
  void initState() {
    super.initState();
    // Read here, not in a field initializer: ref is only safe once the
    // element is mounted, and init keeps a single fresh read.
    _minutes = ref.read(notificationServiceProvider).snoozeMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('مدت به تعویق',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: t.textPrimary)),
          const SizedBox(height: 8),
          SegmentedTabs(
            tabs: const [
              SegmentedTab(label: '5 دقیقه'),
              SegmentedTab(label: '10 دقیقه'),
              SegmentedTab(label: '15 دقیقه'),
            ],
            index: _options.indexOf(_nearest(_minutes)),
            onChanged: (i) async {
              final value = _options[i];
              final prev = _minutes;
              setState(() => _minutes = value);
              try {
                await ref
                    .read(notificationSettingsProvider.notifier)
                    .setSnooze(Duration(minutes: value));
              } catch (e) {
                AppLogger.warning('_SnoozeTile', 'snooze persist failed: $e');
                if (!context.mounted) return;
                setState(() => _minutes = prev);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('ذخیره نشد؛ دوباره تلاش کنید')));
              }
            },
          ),
        ],
      ),
    );
  }

  static int _nearest(int minutes) {
    return _options
        .reduce((a, b) => (a - minutes).abs() <= (b - minutes).abs() ? a : b);
  }
}

/// Amber banner shown when Android denied exact alarms: every reminder
/// silently falls back to inexact mode and Doze can delay it by hours.
/// Hidden otherwise.
class _ExactAlarmBanner extends StatefulWidget {
  const _ExactAlarmBanner();

  @override
  State<_ExactAlarmBanner> createState() => _ExactAlarmBannerState();
}

class _ExactAlarmBannerState extends State<_ExactAlarmBanner> {
  bool? _exact;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      await NotificationService().refreshScheduleMode();
      if (mounted) {
        setState(() => _exact = NotificationService().scheduleMode ==
            AndroidScheduleMode.exactAllowWhileIdle);
      }
    } catch (e) {
      AppLogger.warning('NotificationSettings', 'init step failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_exact ?? true) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WarningCard(
        icon: Icons.alarm_off_outlined,
        text:
            'یادآوری‌ها ممکن است با تأخیر بیایند — مجوز «هشدار دقیق» داده نشده؛ اندروید اعلان‌ها را عقب می‌اندازد.',
        actionLabel: 'رفع مشکل',
        onAction: () => context.push(RouteNames.notificationDiagnostics),
      ),
    );
  }
}

/// Delay selector for the «اذکار بعد از نماز» reminders (minutes after each
/// prayer's iqamah). Stored in SharedPreferences (not [AppSettings]) so it
/// needs no Drift schema migration — same pattern as the Friday/khatm prefs.
class _PostPrayerAzkarCard extends ConsumerStatefulWidget {
  const _PostPrayerAzkarCard({super.key});

  @override
  ConsumerState<_PostPrayerAzkarCard> createState() =>
      _PostPrayerAzkarCardState();
}

class _PostPrayerAzkarCardState extends ConsumerState<_PostPrayerAzkarCard> {
  static const _options = [5, 10, 15, 20, 30, 45, 60];
  int _minutes = NotificationService.defaultPostPrayerDelay;
  bool _enabled = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = ref.read(notificationServiceProvider);
      final v = await service.postPrayerDelayMinutes();
      final enabled = await service.postPrayerEnabled();
      if (!mounted) return;
      setState(() {
        _minutes = v;
        _enabled = enabled;
        _loaded = true;
      });
    } catch (e) {
      // Unavailable (e.g. mocked service in tests) — keep the defaults.
      AppLogger.warning(
          '_PostPrayerDelayTile', 'delay/enabled read failed: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

  int _nearest(int minutes) {
    var best = _options.first;
    for (final o in _options) {
      if ((o - minutes).abs() < (best - minutes).abs()) best = o;
    }
    return best;
  }

  /// Optimistic flip with a rollback: the switch must not stay «روشن» when the
  /// write failed, or the next page open silently disagrees with it.
  Future<void> _setEnabled(bool v) async {
    final prev = _enabled;
    setState(() => _enabled = v);
    try {
      await ref
          .read(notificationSettingsProvider.notifier)
          .setPostPrayerEnabled(v);
    } catch (e) {
      AppLogger.warning('_PostPrayerAzkarCard', 'enabled persist failed: $e');
      if (!mounted) return;
      setState(() => _enabled = prev);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ذخیره نشد؛ دوباره تلاش کنید')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return SettingsCard(children: [
      SwitchTile(
        title: 'اذکار بعد از نماز',
        subtitle: 'یادآوری ذکر پس از اقامهٔ هر نماز (5 نوبت در روز)',
        icon: Icons.notifications_active_outlined,
        value: _enabled,
        onChanged: _loaded ? _setEnabled : null,
      ),
      const SettingsDivider(),
      // The delay only means anything while the reminder itself is on —
      // same pattern as the prayer page's conditional duration rows.
      if (_enabled) ...[
        SelectTile<int>(
          title: 'فاصله از اقامه',
          subtitle: '${_nearest(_minutes)} دقیقه',
          icon: Icons.timer_outlined,
          options: _options,
          labelBuilder: (o) => '$o دقیقه',
          selected: _nearest(_minutes),
          onChanged: _loaded
              ? (v) async {
                  final prev = _minutes;
                  setState(() => _minutes = v);
                  try {
                    await ref
                        .read(notificationSettingsProvider.notifier)
                        .setPostPrayerDelay(v);
                  } catch (e) {
                    AppLogger.warning(
                        '_PostPrayerAzkarCard', 'delay persist failed: $e');
                    if (!context.mounted) return;
                    setState(() => _minutes = prev);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('ذخیره نشد؛ دوباره تلاش کنید')));
                  }
                }
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Text(
            'مستقل از «یادآوری اوقات نماز» است؛ حتی با خاموش بودن آن هم می‌رسد.',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: t.textMuted),
          ),
        ),
      ],
    ]);
  }
}

/// Weekly Friday reminder toggle + time picker (اذکار و آداب جمعه، صلوات و دعا).
/// Backed by SharedPreferences and applied through [NotificationService].
class _FridayReminderCard extends ConsumerStatefulWidget {
  const _FridayReminderCard({super.key});

  @override
  ConsumerState<_FridayReminderCard> createState() =>
      _FridayReminderCardState();
}

class _FridayReminderCardState extends ConsumerState<_FridayReminderCard> {
  bool _enabled = true;
  bool _loaded = false;
  TimeOfDay _time = const TimeOfDay(
      hour: NotificationService.defaultFridayHour,
      minute: NotificationService.defaultFridayMinute);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(NotificationService.fridayEnabledKey) ?? true;
      final hour = prefs.getInt(NotificationService.fridayHourKey) ??
          NotificationService.defaultFridayHour;
      final minute = prefs.getInt(NotificationService.fridayMinuteKey) ??
          NotificationService.defaultFridayMinute;
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _time = TimeOfDay(hour: hour, minute: minute);
        _loaded = true;
      });
    } catch (e) {
      // No prefs on this device: keep the defaults, but stop showing a
      // spinner forever — the card is usable, it just has no stored state.
      AppLogger.warning('_FridayReminderCard', 'load failed: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _save({bool? enabled, TimeOfDay? time}) async {
    final prevEnabled = _enabled;
    final prevTime = _time;
    setState(() {
      if (enabled != null) _enabled = enabled;
      if (time != null) _time = time;
    });
    try {
      await ref.read(notificationSettingsProvider.notifier).setFridayReminder(
            enabled: _enabled,
            hour: _time.hour,
            minute: _time.minute,
          );
    } catch (e) {
      AppLogger.warning('_FridayReminderCard', 'save failed: $e');
      if (!mounted) return;
      setState(() {
        _enabled = prevEnabled;
        _time = prevTime;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ذخیره نشد؛ دوباره تلاش کنید')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(children: [
      SwitchTile(
        title: 'یادآوری روز جمعه',
        subtitle: 'اذکار و آداب جمعه، فضیلت صلوات و دعا',
        icon: Icons.wb_twilight,
        value: _enabled,
        // Inert until the stored value is read: a tap in that first frame
        // would save the default time over the user's own.
        onChanged: _loaded ? (v) => _save(enabled: v) : null,
      ),
      if (_enabled) ...[
        const SettingsDivider(),
        TimePickerTile(
          time: _time,
          label: 'زمان یادآوری',
          note: 'هر جمعه',
          onPicked: (t) => _save(time: t),
        ),
        const SettingsDivider(),
        const _FridayAdabBox(),
      ],
    ]);
  }
}

/// یادآوری مستقل «سوره کهف» — جمعه 6 صبح (جدا از یادآوری جمعهٔ 7 صبح).
class _FridayKahfCard extends ConsumerStatefulWidget {
  const _FridayKahfCard({super.key});

  @override
  ConsumerState<_FridayKahfCard> createState() => _FridayKahfCardState();
}

class _FridayKahfCardState extends ConsumerState<_FridayKahfCard> {
  bool _enabled = true;
  bool _loaded = false;
  TimeOfDay _time = const TimeOfDay(
      hour: NotificationService.defaultFridayKahfHour,
      minute: NotificationService.defaultFridayKahfMinute);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool(NotificationService.fridayKahfEnabledKey) ?? true;
      final hour = prefs.getInt(NotificationService.fridayKahfHourKey) ??
          NotificationService.defaultFridayKahfHour;
      final minute = prefs.getInt(NotificationService.fridayKahfMinuteKey) ??
          NotificationService.defaultFridayKahfMinute;
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _time = TimeOfDay(hour: hour, minute: minute);
        _loaded = true;
      });
    } catch (e) {
      AppLogger.warning('_FridayKahfCard', 'load failed: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _save({bool? enabled, TimeOfDay? time}) async {
    final prevEnabled = _enabled;
    final prevTime = _time;
    setState(() {
      if (enabled != null) _enabled = enabled;
      if (time != null) _time = time;
    });
    try {
      await ref
          .read(notificationSettingsProvider.notifier)
          .setFridayKahfReminder(
            enabled: _enabled,
            hour: _time.hour,
            minute: _time.minute,
          );
    } catch (e) {
      AppLogger.warning('_FridayKahfCard', 'save failed: $e');
      if (!mounted) return;
      setState(() {
        _enabled = prevEnabled;
        _time = prevTime;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ذخیره نشد؛ دوباره تلاش کنید')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(children: [
      SwitchTile(
        title: 'یادآوری سوره کهف',
        subtitle: 'تلاوت سوره کهف در روز جمعه',
        icon: Icons.auto_stories,
        value: _enabled,
        onChanged: _loaded ? (v) => _save(enabled: v) : null,
      ),
      if (_enabled) ...[
        const SettingsDivider(),
        TimePickerTile(
          time: _time,
          label: 'زمان یادآوری',
          note: 'هر جمعه',
          onPicked: (t) => _save(time: t),
        ),
      ],
    ]);
  }
}

/// کارت پیش‌فرض‌محور برای یادآوری روزه‌های مستحب. سوییچ و زمان هر کارت در
/// SharedPreferences نگه داشته می‌شود (نه در [AppSettings]) تا این یادآوری‌ها
/// بدون مهاجرت Drift کار کنند — همان الگوی کارت‌های جمعه.
class _FastingReminderCard extends ConsumerStatefulWidget {
  const _FastingReminderCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabledKey,
    required this.hourKey,
    required this.minuteKey,
    required this.note,
    required this.save,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String enabledKey;
  final String hourKey;
  final String minuteKey;
  final String note;
  final Future<void> Function(
      {required bool enabled,
      required int hour,
      required int minute}) save;

  @override
  ConsumerState<_FastingReminderCard> createState() =>
      _FastingReminderCardState();
}

class _FastingReminderCardState extends ConsumerState<_FastingReminderCard> {
  bool _enabled = true;
  bool _loaded = false;
  TimeOfDay _time = const TimeOfDay(
      hour: NotificationService.defaultFastingHour,
      minute: NotificationService.defaultFastingMinute);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(widget.enabledKey) ?? true;
      final hour = prefs.getInt(widget.hourKey) ??
          NotificationService.defaultFastingHour;
      final minute = prefs.getInt(widget.minuteKey) ??
          NotificationService.defaultFastingMinute;
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _time = TimeOfDay(hour: hour, minute: minute);
        _loaded = true;
      });
    } catch (e) {
      AppLogger.warning('_FastingReminderCard', 'load failed: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _save({bool? enabled, TimeOfDay? time}) async {
    final prevEnabled = _enabled;
    final prevTime = _time;
    setState(() {
      if (enabled != null) _enabled = enabled;
      if (time != null) _time = time;
    });
    try {
      await widget.save(
        enabled: _enabled,
        hour: _time.hour,
        minute: _time.minute,
      );
    } catch (e) {
      AppLogger.warning('_FastingReminderCard', 'save failed: $e');
      if (!mounted) return;
      setState(() {
        _enabled = prevEnabled;
        _time = prevTime;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ذخیره نشد؛ دوباره تلاش کنید')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(children: [
      SwitchTile(
        title: widget.title,
        subtitle: widget.subtitle,
        icon: widget.icon,
        value: _enabled,
        onChanged: _loaded ? (v) => _save(enabled: v) : null,
      ),
      if (_enabled) ...[
        const SettingsDivider(),
        TimePickerTile(
          time: _time,
          label: 'زمان یادآوری',
          note: widget.note,
          onPicked: (t) => _save(time: t),
        ),
      ],
    ]);
  }
}

/// Box showing the آداب و فضائل that are included in the Friday reminder —
/// متن از [FridayContent] می‌آید، همان منبع کارت صفحهٔ خانه و اعلان.
class _FridayAdabBox extends StatelessWidget {
  const _FridayAdabBox();

  @override
  Widget build(BuildContext context) {
    const accent = SectionColors.friday;
    final t = TimeThemeKit.of(context).palette;
    const headline = FridayContent.headline;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.menu_book, color: accent, size: 26),
              const SizedBox(width: 8),
              Text(
                FridayContent.title,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  // On-scale (12.5 snaps to 12): identical pixels, honest code.
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final adab in FridayContent.adabs.take(6))
            _AdabRow(
              icon: adab.icon,
              color: t.primary,
              text: adab.title,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote,
                    size: 14, color: dsContentColor(context, accent)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '«${headline.arabic}» — ${headline.translation} '
                    '(${headline.source})',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      // On-scale (10.5 snaps to 10): identical pixels.
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      height: 1.5,
                      color: t.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdabRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _AdabRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: dsContentColor(context, color)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: t.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder shown while the settings row is being read.
///
/// A spinner alone would let the page's shape jump; these inert rows hold the
/// layout and, crucially, contain no switches — nothing here can be tapped into
/// a value that has not been read yet.
class _NotificationSettingsSkeleton extends StatelessWidget {
  const _NotificationSettingsSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: widthFactor,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: t.textMuted.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 8, DsSpacing.page, 32),
      children: [
        for (var section = 0; section < 3; section++) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
            child: bar(0.35, 14),
          ),
          SettingsCard(children: [
            for (var row = 0; row < 3; row++) ...[
              if (row > 0) const SettingsDivider(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: t.textMuted.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: bar(0.7, 12)),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 22,
                      decoration: BoxDecoration(
                        color: t.textMuted.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ]),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// The settings row could not be read: say so, and offer a retry.
///
/// Rendering the page on factory defaults instead would have looked exactly
/// like a user who had turned everything off.
class _NotificationSettingsLoadFailure extends StatelessWidget {
  const _NotificationSettingsLoadFailure({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FailureView(
      id: 'notification_settings_load',
      title: 'تنظیمات اعلان‌ها باز نشد',
      detail: 'تنظیمات شما پاک نشده‌اند؛ فقط خواندنشان ناموفق بود. '
          'تا خواندن دوباره، هیچ کلیدی نمایش داده نمی‌شود تا با مقدار '
          'نادرست جابه‌جا نشود.',
      onRetry: onRetry,
      layout: FailureLayout.page,
      icon: Icons.notifications_off_outlined,
      error: error,
    );
  }
}
