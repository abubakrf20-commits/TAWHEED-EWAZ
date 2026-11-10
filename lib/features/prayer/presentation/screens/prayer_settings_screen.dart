import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/presentation/widgets/prayer_calc_widgets.dart';
import 'package:tawheeed/features/prayer/presentation/widgets/per_prayer_adhan_card.dart';
import 'package:tawheeed/features/prayer/presentation/widgets/city_picker_sheet.dart';
import 'package:tawheeed/shared/models/day_time.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/services/sound_preview_service.dart';
import 'package:tawheeed/features/prayer/services/prayer_azan_sound_store.dart';
import 'package:tawheeed/features/prayer/services/silent_mode_service.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_flash.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_section_hues.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:tawheeed/features/settings/presentation/widgets/silent_after_iqamah_tile.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/latin_time_picker.dart';

class PrayerSettingsScreen extends ConsumerStatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  ConsumerState<PrayerSettingsScreen> createState() =>
      _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends ConsumerState<PrayerSettingsScreen>
    with SettingsHighlight<PrayerSettingsScreen> {
  static const MethodChannel _azanChannel = MethodChannel('com.tawheeed/azan');

  late final Map<String, GlobalKey> _anchors = {
    'adhan_sound': GlobalKey(),
    'calc': GlobalKey(),
    'location': GlobalKey(),
    'prayer.fajr': GlobalKey(),
    'prayer.dhuhr': GlobalKey(),
    'prayer.asr': GlobalKey(),
    'prayer.maghrib': GlobalKey(),
    'prayer.isha': GlobalKey(),
    'prayer.adhanBulk': GlobalKey(),
    'prayer_notif': GlobalKey(),
    'global_shift': GlobalKey(),
    'friday': GlobalKey(),
    'silent': GlobalKey(),
  };

  @override
  Map<String, GlobalKey> get highlightAnchors => _anchors;

  /// Angle drags echo locally (thumb + value follow the finger) while the
  /// Drift write fires once per drag through a trailing [DebouncedWriter].
  /// One writer PER slider: a shared writer lets the second schedule REPLACE
  /// the first's pending write and silently drop it.
  static const Duration _dragWriteDebounce = Duration(milliseconds: 350);
  double? _fajrAngleDrag;
  double? _ishaAngleDrag;
  final DebouncedWriter _fajrAngleWriter =
      DebouncedWriter(delay: _dragWriteDebounce);
  final DebouncedWriter _ishaAngleWriter =
      DebouncedWriter(delay: _dragWriteDebounce);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    bindSettingsHighlight();
  }

  @override
  void initState() {
    super.initState();
    SoundPreviewService.instance.addListener(_onPreviewChanged);
  }

  void _onPreviewChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SoundPreviewService.instance.removeListener(_onPreviewChanged);
    SoundPreviewService.instance.stop();
    unawaited(_fajrAngleWriter.flush());
    _fajrAngleWriter.dispose();
    unawaited(_ishaAngleWriter.flush());
    _ishaAngleWriter.dispose();
    disposeSettingsHighlight();
    super.dispose();
  }

  /// Applies a city chosen by name from the bundled offline tables, which
  /// cover Iranian towns and world cities alike. Turning «موقعیت خودکار» off
  /// is deliberate: a typed city is a fixed point, so GPS must not overwrite
  /// it on the next refresh — the same contract the map picker follows.
  /// Recalculation is automatic (prayerRelevantSettingsProvider watches the
  /// manual coordinates), so nothing else has to be nudged here.
  Future<void> _pickCity(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final place = await CityPickerSheet.show(
      context,
      initialQuery: ref.read(settingsProvider).value?.city ?? '',
    );
    if (place == null) return;
    final notifier = ref.read(settingsProvider.notifier);
    // One write, one emission: the four setters below are pure saves, so a
    // single patch is equivalent and avoids 4 repo writes per pick.
    // A picked city renders on ITS clock: the city's IANA zone is written so
    // a Sydney picked from a Tehran device shows Sydney times, not Tehran
    // clock-shifted ones. _reconcileTimezone leaves manual mode alone.
    await notifier.patch((s) => s.copyWith(
          useLocation: false,
          manualLat: place.lat,
          manualLng: place.lng,
          hasLocation: true,
          city: place.name,
          timezone: (place.tzId != null && place.tzId!.isNotEmpty)
              ? place.tzId!
              : s.timezone,
        ));
    messenger.showSnackBar(
        SnackBar(content: Text('«${place.name}» به‌عنوان موقعیت انتخاب شد')));
  }

  /// Picks an audio file through the native SAF picker and copies it into
  /// the app-private custom_azans/ dir (file_picker 3.x silently returned
  /// null paths on modern Android, which is why this used to "not work").
  Future<void> _pickCustomAzanFile(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path =
          await _azanChannel.invokeMethod<String>('pickAndCopyAzanFile');
      if (path == null) {
        messenger
            .showSnackBar(const SnackBar(content: Text('فایلی انتخاب نشد')));
        return;
      }
      if (!File(path).existsSync()) {
        messenger
            .showSnackBar(const SnackBar(content: Text('کپی فایل ناموفق بود')));
        return;
      }
      await ref.read(settingsProvider.notifier).setCustomAzanPath(path);
      messenger.showSnackBar(
          const SnackBar(content: Text('فایل اذان با موفقیت ذخیره شد')));
    } catch (e) {
      AppLogger.warning('prayer_settings_screen', 'error: $e');
      messenger.showSnackBar(
          const SnackBar(content: Text('انتخاب فایل اذان ممکن نشد؛ دوباره تلاش کنید.')));
    }
  }

  /// Removes the picked adhan file and every per-prayer «شخصی» override that
  /// pointed at it, so nothing keeps a path to a file that no longer exists.
  /// The shared azanSound stays 'custom': the row that re-picks a file is
  /// gated on it, and clearing it would strand the user with no way back in.
  Future<void> _removeCustomAzanFile(
      BuildContext context, WidgetRef ref, String path) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(settingsProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف فایل اذان'),
        content: const Text(
            'فایل انتخاب‌شده حذف می‌شود و اذان به صدای پیش‌فرض برنامه برمی‌گردد.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('انصراف')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      // Best-effort: a file that is already gone (or a legacy foreign path)
      // must not block clearing the setting that points at it.
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
      await notifier.setCustomAzanPath(null);
      final overrides = await PrayerAzanSoundStore().readOverrides();
      for (final entry in overrides.entries) {
        if (entry.value == 'custom') {
          await notifier.clearAzanSoundFor(entry.key);
        }
      }
      messenger.showSnackBar(const SnackBar(content: Text('فایل اذان حذف شد')));
    } catch (e) {
      AppLogger.warning('prayer_settings_screen', 'remove custom azan: $e');
      messenger
          .showSnackBar(const SnackBar(content: Text('حذف فایل اذان ممکن نشد')));
    }
  }

  /// Plays/stops the chosen adhan voice through the shared preview player.
  /// The old path used a fire-and-forget player with no stop control, so a long
  /// adhan could only be silenced with a volume key.
  Future<void> _toggleAzanPreview(AppSettings settings) async {
    final service = SoundPreviewService.instance;
    final key = 'azan:${settings.azanSound}';
    if (service.isPlaying(key)) {
      await service.stop();
      return;
    }
    String? path;
    if (settings.azanSound == 'custom') {
      path = settings.customAzanPath;
    } else {
      try {
        path = await _azanChannel.invokeMethod<String>(
            'bundledAzanPath', {'sound': settings.azanSound});
      } catch (e) {
        AppLogger.warning('prayer_settings', 'bundled adhan path failed: $e');
      }
    }
    if (!mounted) return;
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('فایل صوتی اذان در دسترس نیست؛ دوباره انتخاب کنید')));
      return;
    }
    final wasPlaying = service.isPlaying(key);
    final ok = await service.toggle(key: key, file: path);
    if (!ok && !wasPlaying && mounted && !service.isPlaying(key)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پخش صدای اذان ممکن نشد')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SettingsAppBar(title: 'تنظیمات نماز و اذان'),
      body: Consumer(
        builder: (context, ref, _) {
          final settings =
              ref.watch(settingsProvider).value ?? const AppSettings();
          // One hue for the page: every header here is «نماز و اذان», so the
          // accent matches the bar that opened this screen.
          final sectionAccent = SettingsSectionHues.on(
              context, SettingsSectionHues.prayer);
          return ListView(
            // The route-driven highlight (see SettingsHighlight) walks the
            // lazy list down to the anchored row.
            controller: highlightScrollController,
            padding: const EdgeInsets.fromLTRB(
                DsSpacing.page, 4, DsSpacing.page, 24),
            children: [
              SettingsFlashSection(
                rowKey: 'adhan_sound',
                flashKey: highlightFlashKey,
                child: SectionHeader(
                  key: _anchors['adhan_sound'],
                  title: 'صوت اذان',
                  accent: sectionAccent,
                ),
              ),
              SettingsCard(children: [
                SelectTile<String>(
                  title: 'صوت اذان',
                  subtitle: _azanLabel(settings.azanSound),
                  icon: Icons.music_note_outlined,
                  options: ['kamel', 'takbir', 'takbirShort', 'custom'],
                  labelBuilder: _azanLabel,
                  selected: settings.azanSound,
                  onChanged: (v) async {
                    await ref.read(settingsProvider.notifier).setAzanSound(v);
                    // The await above can outlive the route; using `context`
                    // unguarded after it threw once the screen was popped
                    // mid-save (analyzer: use_build_context_synchronously).
                    if (!context.mounted) return;
                    if (v == 'custom' &&
                        ref.read(settingsProvider).value?.customAzanPath ==
                            null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('حالا فایل اذان شخصی را انتخاب کنید')));
                    }
                  },
                ),
                const SettingsDivider(),
                settingsRow(SettingRow(
                  icon: Icons.play_circle_outline,
                  showChevron: false,
                  title: SoundPreviewService.instance
                          .isPlaying('azan:${settings.azanSound}')
                      ? 'توقف صدای اذان'
                      : 'پخش صدای اذان (تست)',
                  subtitle: SoundPreviewService.instance
                          .isPlaying('azan:${settings.azanSound}')
                      ? 'برای قطع صدا دوباره بزنید'
                      : null,
                  trailing: Icon(
                    SoundPreviewService.instance
                            .isPlaying('azan:${settings.azanSound}')
                        ? Icons.stop_circle_rounded
                        : Icons.play_circle_outline_rounded,
                    size: 22,
                    color: sectionAccent,
                  ),
                  onTap: () => _toggleAzanPreview(settings),
                )),
                const SettingsDivider(),
                settingsRow(SettingRow(
                  icon: Icons.notification_add_outlined,
                  showChevron: false,
                  title: 'تست اعلان اذان',
                  subtitle: 'زمان‌بندی اعلان واقعی اذان برای یک دقیقه بعد',
                  onTap: () async {
                    await NotificationService().scheduleTestAdhan(
                      azanSound: settings.azanSound,
                      customAzanPath: settings.customAzanPath,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'اعلان تستی اذان برای یک دقیقه دیگر زمان‌بندی شد')));
                    }
                  },
                )),
                if (settings.azanSound == 'custom')
                  Builder(builder: (context) {
                    final path = settings.customAzanPath;
                    final hasPath = path != null && path.isNotEmpty;
                    // "Missing" also covers a legacy path from before the
                    // app-private copy (e.g. a content:// URI or an
                    // /sdcard/… file): the native resolver only honours a
                    // direct child of filesDir/custom_azans, so such a file
                    // can never sound at prayer time even though it exists.
                    // The mosque alarm is not silent in that case —
                    // NativePrayerAlarmService.bakeAlarmSound falls back to the
                    // bundled kamel adhan — so the copy promises that, not
                    // silence.
                    final fileMissing = !_usableCustomAzanPath(path);
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final error =
                        isDark ? AppTheme.darkError : AppTheme.lightError;
                    // The filename rides the subtitle: SettingRow's trailing is
                    // an unbounded Row child, so a long filename there squeezed
                    // the title to a few pixels on a 320dp phone.
                    return settingsRow(SettingRow(
                      icon: Icons.folder_open,
                      showChevron: false,
                      title: 'انتخاب فایل اذان',
                      subtitle: fileMissing
                          ? (hasPath
                              ? 'فایل انتخاب‌شده در دسترس نیست — تا انتخاب دوباره، اذان پیش‌فرض پخش می‌شود'
                              : 'فایلی انتخاب نشده — تا انتخاب دوباره، اذان پیش‌فرض پخش می‌شود')
                          : (path ?? '').split(RegExp(r'[\\/]')).last,
                      // Available for any recorded path, usable or not, or a
                      // stale one could never be cleared.
                      trailing: hasPath
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              iconSize: 20,
                              color: error,
                              tooltip: 'حذف فایل اذان',
                              onPressed: () =>
                                  _removeCustomAzanFile(context, ref, path),
                            )
                          : null,
                      onTap: () => _pickCustomAzanFile(context, ref),
                    ));
                  }),
              ]),
              const SizedBox(height: 20),
              SettingsFlashSection(
                rowKey: 'calc',
                flashKey: highlightFlashKey,
                child: SectionHeader(
                  key: _anchors['calc'],
                  title: 'روش محاسباتی',
                  accent: sectionAccent,
                ),
              ),
              SettingsCard(children: [
                settingsRow(SettingRow(
                  icon: Icons.calculate_outlined,
                  title: 'روش محاسبه',
                  subtitle:
                      '${settings.calculationMethod.label} — ${settings.calculationMethod.description}',
                  onTap: () => showCalculationMethodPicker(
                    context,
                    selected: settings.calculationMethod,
                    onSelected: (v) =>
                        ref.read(settingsProvider.notifier).setCalcMethod(v),
                  ),
                )),
                const SettingsDivider(),
                SelectTile<AsrMethod>(
                  title: 'مذهب عصر',
                  subtitle: settings.asrMethod.label,
                  icon: Icons.access_time,
                  options: AsrMethod.values,
                  labelBuilder: (v) => v.label,
                  selected: settings.asrMethod,
                  onChanged: (v) async =>
                      ref.read(settingsProvider.notifier).setAsrMethod(v),
                ),
                const SettingsDivider(),
                SelectTile<HighLatitudeRuleOption>(
                  title: 'قانون عرض بالا',
                  subtitle:
                      '${settings.highLatitudeRule.label} — برای شهرهای دور از استوا',
                  icon: Icons.nights_stay_outlined,
                  options: HighLatitudeRuleOption.values,
                  labelBuilder: (v) => v.label,
                  selected: settings.highLatitudeRule,
                  onChanged: (v) async => ref
                      .read(settingsProvider.notifier)
                      .setHighLatitudeRule(v),
                ),
                if (settings.calculationMethod ==
                    CalculationMethodOption.custom) ...[
                  const SettingsDivider(),
                  settingsRow(PrayerAngleSlider(
                    label: 'زاویه فجر',
                    icon: Icons.wb_twilight_outlined,
                    accent: PrayerHues.fajr,
                    value: _fajrAngleDrag ?? settings.customFajrAngle,
                    onChanged: (v) {
                      setState(() => _fajrAngleDrag = v);
                      final notifier = ref.read(settingsProvider.notifier);
                      _fajrAngleWriter
                          .schedule(() => notifier.setCustomFajrAngle(v));
                    },
                    onSettled: (_) async {
                      await _fajrAngleWriter.flush();
                      if (mounted) setState(() => _fajrAngleDrag = null);
                    },
                  )),
                  const SettingsDivider(),
                  settingsRow(PrayerAngleSlider(
                    label: 'زاویه عشاء',
                    icon: Icons.nights_stay_outlined,
                    accent: PrayerHues.isha,
                    value: _ishaAngleDrag ?? settings.customIshaAngle,
                    onChanged: (v) {
                      setState(() => _ishaAngleDrag = v);
                      final notifier = ref.read(settingsProvider.notifier);
                      _ishaAngleWriter
                          .schedule(() => notifier.setCustomIshaAngle(v));
                    },
                    onSettled: (_) async {
                      await _ishaAngleWriter.flush();
                      if (mounted) setState(() => _ishaAngleDrag = null);
                    },
                  )),
                ],
                const SettingsDivider(),
                SwitchTile(
                  title: 'اصلاح ارتفاع مکان',
                  subtitle:
                      'تصحیح افق برای طلوع و مغرب بر اساس ارتفاع از سطح دریا',
                  icon: Icons.terrain_outlined,
                  value: settings.elevationCorrection,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .setElevationCorrection(v),
                ),
                const SettingsDivider(),
                settingsRow(SettingRow(
                  icon: Icons.science_outlined,
                  title: 'جزئیات محاسبه',
                  subtitle: 'نمایش ورودی‌های محاسبه امروز برای اطمینان از صحت',
                  onTap: () => showPrayerCalculationDetails(context, ref),
                )),
              ]),
              const SizedBox(height: 20),
              SettingsFlashSection(
                rowKey: 'location',
                flashKey: highlightFlashKey,
                child: SectionHeader(
                  key: _anchors['location'],
                  title: 'موقعیت مکانی',
                  accent: sectionAccent,
                ),
              ),
              SettingsCard(children: [
                SwitchTile(
                  title: 'موقعیت خودکار',
                  subtitle: settings.useLocation
                      ? 'استفاده از GPS گوشی'
                      : 'ورود دستی مختصات',
                  icon: settings.useLocation ? Icons.gps_fixed : Icons.pin_drop,
                  value: settings.useLocation,
                  onChanged: (v) async =>
                      ref.read(settingsProvider.notifier).setUseLocation(v),
                ),
                if (!settings.useLocation) ...[
                  const SettingsDivider(),
                  settingsRow(SettingRow(
                    icon: Icons.search,
                    title: 'جست‌وجوی شهر',
                    subtitle:
                        'نام شهر را بنویسید؛ فهرست همراه سراسر جهان را می‌شناسد',
                    onTap: () => _pickCity(context, ref),
                  )),
                  const SettingsDivider(),
                  settingsRow(SettingRow(
                    icon: Icons.map_outlined,
                    title: 'انتخاب از روی نقشه',
                    subtitle: 'روی نقشه ضربه بزنید تا موقعیت را انتخاب کنید',
                    onTap: () => context.push(RouteNames.mapPicker),
                  )),
                  const SettingsDivider(),
                  _LatLngTile(
                    label: 'عرض جغرافیایی',
                    value: settings.manualLat,
                    icon: Icons.arrow_upward,
                    onChanged: (v) => ref
                        .read(settingsProvider.notifier)
                        .setManualCoords(v, settings.manualLng ?? 0),
                  ),
                  const SettingsDivider(),
                  _LatLngTile(
                    label: 'طول جغرافیایی',
                    value: settings.manualLng,
                    icon: Icons.arrow_forward,
                    min: -180,
                    max: 180,
                    onChanged: (v) => ref
                        .read(settingsProvider.notifier)
                        .setManualCoords(settings.manualLat ?? 0, v),
                  ),
                ],
              ]),
              const SizedBox(height: 20),
              SectionHeader(
                title: 'اذان و اقامه هر نماز',
                accent: sectionAccent,
                description:
                    'برای هر نماز، صدا، زمان اذان و فاصله اذان تا اقامه را جداگانه تنظیم کنید',
              ),
              PerPrayerAdhanCard(
                settings: settings,
                anchors: _anchors,
                flashKey: highlightFlashKey,
              ),
              const SizedBox(height: 20),
              SettingsFlashSection(
                rowKey: 'prayer_notif',
                flashKey: highlightFlashKey,
                child: SectionHeader(
                  key: _anchors['prayer_notif'],
                  title: 'اعلان نماز',
                  accent: sectionAccent,
                ),
              ),
              SettingsCard(children: [
                SwitchTile(
                  title: 'یادآوری اوقات نماز',
                  icon: Icons.notifications,
                  value: settings.prayerNotifications,
                  onChanged: (v) async {
                    await ref
                        .read(settingsProvider.notifier)
                        .setPrayerNotifications(v);
                    if (!context.mounted) return;
                    await _rescheduleNotifications(context, ref);
                  },
                ),
                if (settings.prayerNotifications) ...[
                  const SettingsDivider(),
                  _NotifMinutesTile(settings: settings),
                ],
              ]),
              const SizedBox(height: 20),
              SettingsFlashSection(
                rowKey: 'global_shift',
                flashKey: highlightFlashKey,
                child: SectionHeader(
                  key: _anchors['global_shift'],
                  title: 'جابجایی کلی',
                  accent: sectionAccent,
                  description:
                      'همه اوقات نماز را یکجا جلو یا عقب ببرید (برای رفع اختلاف یک ساعته تابستانی)',
                ),
              ),
              SettingsCard(children: [
                settingsRow(SettingRow(
                  icon: Icons.schedule,
                  title: 'همه اوقات',
                  showChevron: false,
                  trailing: SettingsStepper(
                    value: settings.globalPrayerOffset,
                    min: -60,
                    max: 60,
                    signed: true,
                    semanticLabel: 'جابجایی کلی همه اوقات',
                    onChanged: (v) => ref
                        .read(settingsProvider.notifier)
                        .setGlobalPrayerOffset(v),
                  ),
                )),
                const SettingsDivider(),
                settingsRow(SettingRow(
                  icon: Icons.wb_twilight_outlined,
                  title: 'طلوع آفتاب',
                  subtitle: 'فقط وقت طلوع، جدا از جابجایی کلی',
                  showChevron: false,
                  trailing: SettingsStepper(
                    value: settings.sunriseOffset,
                    min: -60,
                    max: 60,
                    signed: true,
                    semanticLabel: 'جابجایی طلوع آفتاب',
                    onChanged: (v) => ref
                        .read(settingsProvider.notifier)
                        .setSunriseOffset(v),
                  ),
                )),
              ]),
              const SizedBox(height: 20),
              SettingsFlashSection(
                rowKey: 'friday',
                flashKey: highlightFlashKey,
                child: SectionHeader(
                  key: _anchors['friday'],
                  title: 'وقت نماز جمعه',
                  accent: sectionAccent,
                ),
              ),
              _FridayPrayerTimeCard(settings: settings),
              const SizedBox(height: 20),
              SettingsFlashSection(
                rowKey: 'silent',
                flashKey: highlightFlashKey,
                child: SectionHeader(
                  key: _anchors['silent'],
                  title: 'بی‌صدا قبل از اقامه',
                  accent: sectionAccent,
                ),
              ),
              const _SilentModeNotice(),
              SettingsCard(children: [
                SwitchTile(
                  title: 'بی‌صدا قبل از اقامه',
                  subtitle: 'خاموش کردن صدای گوشی چند دقیقه قبل از اقامهٔ نماز',
                  icon: Icons.volume_off_outlined,
                  value: settings.silentBeforeIqamah,
                  onChanged: (v) async {
                    await ref
                        .read(settingsProvider.notifier)
                        .setSilentBeforeIqamah(v);
                    if (v && context.mounted) {
                      await _warnDndIfNeeded(context);
                    }
                  },
                ),
                if (settings.silentBeforeIqamah) ...[
                  const SettingsDivider(),
                  settingsRow(SettingRow(
                    icon: Icons.timer_outlined,
                    title: 'مدت زمان (دقیقه)',
                    showChevron: false,
                    trailing: SettingsStepper(
                      value: settings.silentBeforeIqamahMinutes,
                      min: 1,
                      max: 60,
                      onChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .setSilentBeforeIqamahMinutes(v),
                    ),
                  )),
                  const SettingsDivider(),
                  const SilentAfterIqamahTile(),
                ],
                const SettingsDivider(),
                SwitchTile(
                  title: 'بی‌صدا در وقت نماز',
                  subtitle: 'خاموش ماندن گوشی در مدت نماز',
                  icon: Icons.do_not_disturb_on,
                  value: settings.silentDuringPrayer,
                  onChanged: (v) async {
                    await ref
                        .read(settingsProvider.notifier)
                        .setSilentDuringPrayer(v);
                    if (v && context.mounted) {
                      await _warnDndIfNeeded(context);
                    }
                  },
                ),
                if (settings.silentDuringPrayer) ...[
                  const SettingsDivider(),
                  settingsRow(SettingRow(
                    icon: Icons.timer_outlined,
                    title: 'مدت زمان (دقیقه)',
                    showChevron: false,
                    trailing: SettingsStepper(
                      value: settings.silentDuration,
                      min: 1,
                      max: 60,
                      onChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .setSilentDuration(v),
                    ),
                  )),
                ],
              ]),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  String _azanLabel(String key) => prayerAzanLabel(key);

  /// True when [path] is a custom azan file the native alarm can actually
  /// play: it must exist AND sit directly inside the app-private
  /// `custom_azans/` dir (the native resolver rejects anything else, so a
  /// legacy foreign path would only ever play the bundled default).
  bool _usableCustomAzanPath(String? path) {
    if (path == null || path.isEmpty) return false;
    if (!File(path).existsSync()) return false;
    final segs = path.split(RegExp(r'[\\/]'));
    return segs.length >= 2 && segs[segs.length - 2] == 'custom_azans';
  }

  Future<void> _rescheduleNotifications(
      BuildContext context, WidgetRef ref) async {
    final service = ref.read(prayerTimeServiceProvider);
    final s = ref.read(settingsProvider).value ?? const AppSettings();
    if (service.prayerTimes != null) {
      await ref
          .read(dailyNotificationSchedulerProvider)
          .forceReschedule(prayerService: service, settings: s);
    }
  }

  /// Warns when DND access is missing after enabling either silent mode, with
  /// a shortcut to the system screen. Shared by both silent switches so the
  /// copy cannot diverge.
  static Future<void> _warnDndIfNeeded(BuildContext context) async {
    if (!context.mounted) return;
    final granted = await SilentModeService().isDndAccessGranted();
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'برای بی‌صدا شدن کامل گوشی، دسترسی «عدم مزاحمت» لازم است (در پایین راهنمایی شده).'),
          action: SnackBarAction(
            label: 'باز کردن',
            onPressed: () => SilentModeService().openDndSettings(),
          ),
        ),
      );
    }
  }
}

/// Display label for an azan-voice key; shared by the «صوت اذان» row and the
/// per-prayer voice chips below (both edit the same global voice).
String prayerAzanLabel(String key) {
  switch (key) {
    case 'kamel':
      return 'الغامدی - کامل';
    case 'takbir':
      return 'الغامدی - تکبیر';
    case 'takbirShort':
      return 'تکبیر کوتاه';
    case 'custom':
      return 'فایل شخصی از گوشی';
    default:
      return key;
  }
}


/// انتخاب وقت نماز جمعه.
///
/// وقت محاسبه‌شدهٔ ظهر به‌عنوان پیش‌فرض نشان داده می‌شود و تا وقتی کاربر
/// چیزی انتخاب نکرده باشد همان زمان مبناست. با زدن «بازگشت به ظهر» مقدار
/// ذخیره‌شده پاک می‌شود و برنامه دوباره زمان‌بندی می‌شود.
class _FridayPrayerTimeCard extends ConsumerWidget {
  const _FridayPrayerTimeCard({required this.settings});

  final AppSettings settings;

  String _formatHhMm(DayTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// وقت نماز عوض شده ⇒ اعلان‌های اذان/اقامه دوباره زمان‌بندی می‌شوند.
  Future<void> _reschedule(WidgetRef ref) async {
    final service = ref.read(prayerTimeServiceProvider);
    final s = ref.read(settingsProvider).value ?? const AppSettings();
    if (service.prayerTimes == null) return;
    await ref
        .read(dailyNotificationSchedulerProvider)
        .forceReschedule(prayerService: service, settings: s);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dhuhr = ref.watch(prayerTimeServiceProvider).dhuhr;
    final custom = settings.fridayPrayerTime;
    // تا وقتی کاربر_override نکرده، وقتِ محاسبه‌شدهٔ ظهر مبناست.
    final effective = custom ??
        (dhuhr == null
            ? null
            : DayTime(hour: dhuhr.hour, minute: dhuhr.minute));
    final sub = custom == null
        ? 'پیش‌فرض: وقت ظهر (${effective == null ? '—' : _formatHhMm(effective)})'
        : 'ساعت ${_formatHhMm(custom)}';

    return SettingsCard(children: [
      settingsRow(SettingRow(
        icon: Icons.wb_twilight,
        title: 'وقت نماز جمعه',
        subtitle: sub,
        onTap: () async {
          final initial = effective == null
              ? const TimeOfDay(hour: 12, minute: 0)
              : TimeOfDay(hour: effective.hour, minute: effective.minute);
          final picked = await showLatinTimePicker(
            context,
            initialTime: initial,
            title: 'وقت نماز جمعه',
          );
          if (picked == null) return;
          await ref.read(settingsProvider.notifier).setFridayPrayerTime(
                DayTime(hour: picked.hour, minute: picked.minute),
              );
          await _reschedule(ref);
        },
      )),
      if (custom != null) ...[
        const SettingsDivider(),
        settingsRow(SettingRow(
          icon: Icons.restart_alt,
          title: 'بازگشت به وقت ظهر',
          subtitle: 'حذف ساعت دلخواه و استفاده از وقت محاسبه‌شدهٔ ظهر',
          showChevron: false,
          onTap: () async {
            await ref.read(settingsProvider.notifier).setFridayPrayerTime(null);
            await _reschedule(ref);
          },
        )),
      ],
    ]);
  }
}

class _NotifMinutesTile extends ConsumerWidget {
  final AppSettings settings;

  const _NotifMinutesTile({required this.settings});

  /// Re-runs the daily scheduler so the new pre-adhan minutes take effect
  /// immediately (the adhan notifications themselves are untouched).
  static Future<void> _reschedulePrayerNotifs(
      BuildContext context, WidgetRef ref) async {
    final service = ref.read(prayerTimeServiceProvider);
    final s = ref.read(settingsProvider).value ?? const AppSettings();
    if (service.prayerTimes != null) {
      await ref
          .read(dailyNotificationSchedulerProvider)
          .forceReschedule(prayerService: service, settings: s);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return settingsRow(SettingRow(
      icon: Icons.timer_outlined,
      title: 'یادآوری قبل از اذان (دقیقه)',
      showChevron: false,
      trailing: SettingsStepper(
        value: settings.prayerNotifMinutes,
        max: 30,
        onChanged: (v) async {
          await ref.read(settingsProvider.notifier).setPrayerNotifMinutes(v);
          if (context.mounted) {
            await _reschedulePrayerNotifs(context, ref);
          }
        },
      ),
    ));
  }
}

class _SilentModeNotice extends StatefulWidget {
  const _SilentModeNotice();

  @override
  State<_SilentModeNotice> createState() => _SilentModeNoticeState();
}

class _LatLngTile extends StatefulWidget {
  final String label;
  final double? value;
  final IconData icon;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _LatLngTile({
    required this.label,
    required this.value,
    required this.icon,
    this.min = -90,
    this.max = 90,
    required this.onChanged,
  });

  @override
  State<_LatLngTile> createState() => _LatLngTileState();
}

class _LatLngTileState extends State<_LatLngTile> {
  late TextEditingController _controller;
  late FocusNode _focus;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value?.toStringAsFixed(4) ?? '',
    );
    // Tapping away used to discard the input silently; commit on focus loss.
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _submit();
  }

  /// Empty input is refused (the last good value is restored) — persisting
  /// a bare 0 would silently move the user to the Gulf of Guinea.
  /// Persian/Arabic digits and separators are folded before parsing.
  void _submit() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _error = 'مقداری وارد نشده است';
        _controller.text = widget.value?.toStringAsFixed(4) ?? '';
      });
      return;
    }
    final folded = NumberFormat.normalizeDigits(raw)
        .replaceAll('٬', '')
        .replaceAll(',', '')
        .replaceAll('٫', '.');
    final parsed = double.tryParse(folded);
    if (parsed != null && parsed >= widget.min && parsed <= widget.max) {
      setState(() => _error = null);
      widget.onChanged(parsed);
    } else {
      setState(() => _error =
          'مقدار باید بین ${widget.min} و ${widget.max} باشد');
    }
  }

  @override
  void didUpdateWidget(_LatLngTile old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && !_focus.hasFocus) {
      _controller.text = widget.value?.toStringAsFixed(4) ?? '';
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          IconTile(icon: widget.icon, color: p.primary, iconSize: 18),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              widget.label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w500,
                color: p.textPrimary,
              ),
            ),
          ),
          const Spacer(),
          // The visible label is a sibling Text, so the field carries the
          // name for TalkBack itself.
          Semantics(
            label: widget.label,
            child: SizedBox(
              width: 140,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  errorText: _error,
                  errorStyle: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 10),
                  ),
                ),
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 13)),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SilentModeNoticeState extends State<_SilentModeNotice> {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final granted = await SilentModeService().isDndAccessGranted();
    if (mounted) setState(() => _granted = granted);
  }

  /// Opens the system DnD-access screen, then re-checks on return so the card
  /// flips to the granted state without the user having to leave the page.
  Future<void> _open() async {
    await SilentModeService().openDndSettings();
    if (mounted) await _check();
  }

  @override
  Widget build(BuildContext context) {
    if (_granted ?? false) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: WarningCard(
          text: 'دسترسی بی‌صدا کردن خودکار داده شده است.',
          icon: Icons.check_circle_outline,
          accent: SettingsTokens.switchOn,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WarningCard(
        text:
            'برای بی‌صدا کردن خودکار گوشی هنگام اقامه، دسترسی «عدم مزاحمت» (Do Not Disturb) لازم است.',
        actionLabel: 'باز کردن تنظیمات دسترسی',
        onAction: _open,
      ),
    );
  }
}
