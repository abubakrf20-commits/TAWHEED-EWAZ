import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/reminders/presentation/providers/reminder_provider.dart';
import 'package:tawheeed/features/reminders/data/models/reminder_model.dart';
import 'package:tawheeed/core/design_system/components/components.dart'
    show DsSpacing, SectionHeader, dsContentColor;
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/shared/widgets/latin_time_picker.dart';
import 'package:tawheeed/features/reminders/presentation/utils/reminder_colors.dart';
import 'package:tawheeed/shared/services/sound_choice.dart';
import 'package:tawheeed/shared/services/sound_preview_service.dart';
import 'package:tawheeed/shared/services/sound_registry.dart';
import 'package:tawheeed/shared/services/system_sound_catalog.dart';
import 'package:tawheeed/shared/widgets/sound_picker_sheet.dart';

class ReminderEditorScreen extends ConsumerStatefulWidget {
  final ReminderModel? reminder;
  const ReminderEditorScreen({super.key, this.reminder});

  @override
  ConsumerState<ReminderEditorScreen> createState() =>
      _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends ConsumerState<ReminderEditorScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _noteCtrl;
  late TimeOfDay _selectedTime;
  late List<bool> _selectedDays;
  late int _advanceMinutes;
  late String _soundName;
  late bool _isDateSpecific;
  DateTime? _specificDate;
  Set<String> _selectedPrayers = {};
  int _prayerOffsetMinutes = 0;

  // Canonical prayer palette (AppTheme.prayerNameColor) so the picker can
  // never drift from the rest of the app.
  static final _prayerOptions = [
    (
      'fajr',
      'اذان صبح',
      Icons.nightlight_round,
      AppTheme.prayerNameColor('fajr')
    ),
    ('dhuhr', 'اذان ظهر', Icons.light_mode, AppTheme.prayerNameColor('dhuhr')),
    (
      'asr',
      'اذان عصر',
      Icons.wb_sunny_rounded,
      AppTheme.prayerNameColor('asr')
    ),
    (
      'maghrib',
      'اذان مغرب',
      Icons.wb_twilight,
      AppTheme.prayerNameColor('maghrib')
    ),
    ('isha', 'اذان عشاء', Icons.dark_mode, AppTheme.prayerNameColor('isha')),
  ];

  bool get _isEditing => widget.reminder != null;

  /// اگر _soundName با «custom:» شروع شده باشد، مسیر فایل صوتی شخصی است.
  String? get _customSoundPath =>
      _soundName.startsWith('custom:') ? _soundName.substring(7) : null;

  /// برچسب نمایشی برای صدای انتخاب‌شده.
  String get _soundLabel {
    if (_soundName == 'default') return 'صدای پیش‌فرض سیستم';
    if (_soundName == 'silent') return 'بی صدا';
    final customPath = _customSoundPath;
    if (customPath != null) {
      final name = customPath.split(RegExp(r'[\\/]')).last;
      return 'فایل شخصی: $name';
    }
    if (_soundName == SoundChoice.appNotification) return 'صدای اعلان برنامه';
    final uri = SoundChoice.systemUri(_soundName);
    if (uri != null) {
      final title = SystemSoundCatalog.instance.titleOf(uri);
      final kind = SoundChoice.roughLabel(_soundName);
      return title == null ? kind : '$kind: $title';
    }
    return _soundName;
  }

  /// The play/stop target for the sound currently chosen, if it can be
  /// previewed at all (silent/default have nothing to play).
  SoundPreviewServiceCall? get _currentPreview {
    if (_soundName == SoundChoice.appNotification) {
      return SoundPreviewServiceCall(
        key: 'app:${SoundChoice.appNotification}',
        asset: SoundRegistry.reminder.asset,
      );
    }
    final customPath = _customSoundPath;
    if (customPath != null) {
      return SoundPreviewServiceCall(
          key: 'custom:$customPath', file: customPath);
    }
    final uri = SoundChoice.systemUri(_soundName);
    if (uri != null) {
      return SoundPreviewServiceCall(
        key: 'system:$uri',
        systemUri: uri,
        alarm: SoundChoice.isAlarm(_soundName),
      );
    }
    return null;
  }

  Future<void> _toggleCurrentPreview() async {
    final call = _currentPreview;
    if (call == null) return;
    await SoundPreviewService.instance.toggle(
      key: call.key,
      asset: call.asset,
      file: call.file,
      systemUri: call.systemUri,
      alarm: call.alarm,
    );
  }

  static const _advanceOptions = [0, 5, 10, 15, 30, 60];
  static const _advanceLabels = ['بدون', '5', '10', '15', '30', '60'];
  static const _shortDayNames = ['شن', 'یک', 'دو', 'سه', 'چهار', 'پنج', 'جم'];
  static const _soundOptions = [
    ('default', 'صدای پیش‌فرض سیستم', Icons.volume_up_outlined),
    ('silent', 'بی صدا', Icons.volume_off_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.reminder?.title ?? '');
    _noteCtrl = TextEditingController(text: widget.reminder?.note ?? '');
    _selectedTime = TimeOfDay(
      hour: widget.reminder?.hour ?? 8,
      minute: widget.reminder?.minute ?? 0,
    );
    _selectedDays = widget.reminder != null
        ? List.generate(7, (i) => widget.reminder!.daysOfWeek.contains(i))
        : List<bool>.filled(7, true);
    _advanceMinutes = widget.reminder?.advanceMinutes ?? 0;
    _soundName = widget.reminder?.soundName ?? 'default';
    _isDateSpecific = widget.reminder?.specificDate != null;
    _specificDate = widget.reminder?.specificDate;
    final ref = widget.reminder?.prayerRef;
    _selectedPrayers = ref != null
        ? ref.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet()
        : {};
    _prayerOffsetMinutes = widget.reminder?.prayerOffsetMinutes ?? 0;
    // A saved phone tone needs the catalog to show its real title, and the
    // preview icon needs to repaint when playback starts/stops.
    SoundPreviewService.instance.addListener(_onPreviewChanged);
    if (SoundChoice.isSystem(_soundName)) {
      SystemSoundCatalog.instance.load().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onPreviewChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _showSoundPicker(BuildContext context) async {
    final chosen = await showSoundPickerSheet(
      context,
      current: _soundName,
      pickFile: _pickCustomSoundFile,
      title: 'انتخاب صدای یادآور',
    );
    if (!mounted || chosen == null || chosen == _soundName) return;
    await SoundPreviewService.instance.stop();
    if (!mounted) return;
    setState(() => _soundName = chosen);
  }

  static const _azanChannel = MethodChannel('com.tawheeed/azan');

  /// SAF picker that copies the chosen file into filesDir/custom_sounds/
  /// (file_picker 3.x returns null path on Android 13+ without permission).
  /// The picker sheet calls this; the returned path is wrapped as
  /// `custom:<path>` there, so nothing here previews or navigates.
  Future<String?> _pickCustomSoundFile() async {
    try {
      final savePath =
          await _azanChannel.invokeMethod<String>('pickAndCopyReminderSound');
      if (savePath == null || savePath.isEmpty) return null;
      if (!File(savePath).existsSync()) {
        if (mounted) AppSnackBar.error(context, 'کپی فایل ناموفق بود');
        return null;
      }
      // فایل صوتی قبلی (اگه شخصی بوده) پاک کن
      final oldPath = _customSoundPath;
      if (oldPath != null && oldPath != savePath) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) await oldFile.delete();
      }
      return savePath;
    } on PlatformException catch (e) {
      AppLogger.warning('reminder_editor_screen', 'error: $e');
      if (mounted) {
        AppSnackBar.error(
            context, 'انتخاب فایل صوتی ممکن نشد؛ دوباره تلاش کنید.');
      }
      return null;
    } catch (e) {
      AppLogger.warning('reminder_editor_screen', 'error: $e');
      if (mounted) {
        AppSnackBar.error(
            context, 'انتخاب فایل صوتی ممکن نشد؛ دوباره تلاش کنید.');
      }
      return null;
    }
  }

  @override
  void dispose() {
    SoundPreviewService.instance.removeListener(_onPreviewChanged);
    SoundPreviewService.instance.stop();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final reminder = widget.reminder;
    if (reminder == null) return;
    final notifier = ref.read(reminderProvider.notifier);
    // Capture the messenger before popping: the editor unmounts on delete,
    // and `ScaffoldMessenger.of(context)`/`ref` throw afterwards.
    final messenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف یادآور'),
        content: Text('«${reminder.title}» حذف شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لغو')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor:
                    isDark ? AppTheme.darkError : AppTheme.lightError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await notifier.deleteReminder(reminder.id);
    if (mounted) Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('یادآور حذف شد'),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        action: SnackBarAction(
          label: 'بازگردانی',
          onPressed: notifier.undoLastDelete,
        ),
      ));
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      AppSnackBar.error(context, 'عنوان یادآور را وارد کنید');
      return;
    }

    if (_isDateSpecific && _specificDate == null) {
      AppSnackBar.error(
          context, 'برای یادآوری «تاریخ مشخص»، ابتدا تاریخ را انتخاب کنید');
      return;
    }

    final isPrayerMode = _selectedPrayers.isNotEmpty;
    final days = isPrayerMode || _isDateSpecific ? <int>[] : <int>[];
    if (!isPrayerMode && !_isDateSpecific) {
      for (int i = 0; i < 7; i++) {
        if (_selectedDays[i]) days.add(i);
      }
      if (days.isEmpty) {
        AppSnackBar.error(context, 'حداقل یک روز را انتخاب کنید');
        return;
      }
    }

    final notifier = ref.read(reminderProvider.notifier);

    if (_isEditing) {
      // Build a fresh model instead of mutating widget.reminder: that
      // instance is the one held in the provider's state list, so a cascade
      // edit changed the visible list before saving — and a failed save left
      // the card showing values that were never persisted. copyWith cannot
      // stand in either: `field ?? this.field` has no way to clear
      // specificDate/prayerRef when the user switches modes.
      final old = widget.reminder!;
      notifier.updateReminder(ReminderModel(
        id: old.id,
        title: title,
        note: _noteCtrl.text.trim(),
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        daysOfWeek: days,
        isEnabled: old.isEnabled,
        createdAt: old.createdAt,
        advanceMinutes: _advanceMinutes,
        useSound: _soundName != 'silent',
        soundName: _soundName,
        specificDate: _isDateSpecific ? _specificDate : null,
        prayerRef: _selectedPrayers.isEmpty ? null : _selectedPrayers.join(','),
        prayerOffsetMinutes: _prayerOffsetMinutes,
      ));
    } else {
      notifier.addReminder(
        title: title,
        note: _noteCtrl.text.trim(),
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        daysOfWeek: days,
        advanceMinutes: _advanceMinutes,
        useSound: _soundName != 'silent',
        soundName: _soundName,
        specificDate: _isDateSpecific ? _specificDate : null,
        prayerRef: _selectedPrayers.isEmpty ? null : _selectedPrayers.join(','),
        prayerOffsetMinutes: _prayerOffsetMinutes,
      );
    }
    AppSnackBar.success(context, 'یادآور ذخیره شد');
    Navigator.pop(context);
  }

  /// The shared Jalali picker — this screen used to hand-roll its own
  /// calendar dialog, which drifted from every other date field in the app
  /// (no quick month/year jump, no «امروز», unbounded year list).
  Future<void> _showShamsiDatePicker(
      BuildContext context, Color gold, bool isDark) async {
    final picked = await ShamsiDatePicker.show(
      context,
      initialDate: _specificDate,
      // A date-specific reminder is almost always near; +5 keeps the year
      // dropdown honest without offering a century of choices.
      maxYearOffset: 5,
    );
    if (picked != null && mounted) {
      setState(() => _specificDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    const gold = ReminderColors.accent;
    final goldStrong = dsContentColor(context, gold);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: t.primary,
        iconTheme: IconThemeData(color: t.primary),
        title: Text(_isEditing ? 'ویرایش یادآور' : 'یادآور جدید',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                color: t.primary)),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
              color: danger,
              tooltip: 'حذف یادآور',
            ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
            tooltip: 'ذخیره',
          ),
        ],
      ),
      body: ListView(
        // The system-bar inset is added to the page's own bottom padding, so
        // the last row scrolls above the 3-button bar and nothing is added
        // where there is no bar (inset zero).
        padding: EdgeInsets.fromLTRB(
          DsSpacing.page,
          DsSpacing.page,
          DsSpacing.page,
          DsSpacing.page + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const SectionHeader(title: 'اطلاعات اصلی', margin: EdgeInsets.zero),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'عنوان یادآور (مثلاً: داروی صبحگاه)',
              hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily, color: t.textMuted),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14),
              color: t.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'توضیحات (اختیاری)',
              hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily, color: t.textMuted),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            maxLines: 2,
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'زمان‌بندی', margin: EdgeInsets.zero),
          const SizedBox(height: 8),
          _selectedPrayers.isNotEmpty
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wb_sunny, color: gold, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'زمان بر اساس ${_selectedPrayers.length} اذان',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          color: goldStrong,
                        ),
                      ),
                    ],
                  ),
                )
              : GestureDetector(
                  onTap: () async {
                    final picked = await showLatinTimePicker(
                      context,
                      initialTime: _selectedTime,
                      title: 'ساعت یادآوری',
                    );
                    if (!mounted) return;
                    if (picked != null) setState(() => _selectedTime = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: t.outline),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: gold, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          'ساعت یادآوری',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 14),
                            color: t.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 20),
                            fontWeight: FontWeight.w700,
                            color: goldStrong,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_left, color: t.textMuted),
                      ],
                    ),
                  ),
                ),
          const SizedBox(height: 12),
          Text(
            'یادآوری چند دقیقه زودتر؟',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_advanceOptions.length, (i) {
              final isSelected = _advanceMinutes == _advanceOptions[i];
              return GestureDetector(
                onTap: () =>
                    setState(() => _advanceMinutes = _advanceOptions[i]),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? gold.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          isSelected ? gold.withValues(alpha: 0.4) : t.outline,
                    ),
                  ),
                  child: Text(
                    '${_advanceLabels[i]} دقیقه',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? goldStrong : t.textMuted,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'نوع یادآوری', margin: EdgeInsets.zero),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isDateSpecific = false;
                    _specificDate = null;
                    _selectedPrayers = {};
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: !_isDateSpecific
                          ? gold.withValues(alpha: 0.10)
                          : t.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !_isDateSpecific
                            ? gold.withValues(alpha: 0.3)
                            : t.outline,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.repeat,
                            size: 18,
                            color: !_isDateSpecific ? gold : t.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          'تکرار هفتگی',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w600,
                            color: !_isDateSpecific ? goldStrong : t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isDateSpecific = true;
                    _selectedPrayers = {};
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isDateSpecific
                          ? gold.withValues(alpha: 0.10)
                          : t.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isDateSpecific
                            ? gold.withValues(alpha: 0.3)
                            : t.outline,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today,
                            size: 18,
                            color: _isDateSpecific ? gold : t.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          'تاریخ مشخص',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w600,
                            color: _isDateSpecific ? goldStrong : t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    if (_selectedPrayers.isEmpty) {
                      _selectedPrayers = {'fajr'};
                    } else {
                      _selectedPrayers = {};
                    }
                    _specificDate = null;
                    _isDateSpecific = false;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedPrayers.isNotEmpty
                          ? gold.withValues(alpha: 0.10)
                          : t.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedPrayers.isNotEmpty
                            ? gold.withValues(alpha: 0.3)
                            : t.outline,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wb_sunny,
                            size: 18,
                            color: _selectedPrayers.isNotEmpty
                                ? gold
                                : t.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          'زمان اذان',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w600,
                            color: _selectedPrayers.isNotEmpty
                                ? goldStrong
                                : t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedPrayers.isNotEmpty) ...[
            const SectionHeader(title: 'اذان‌ها', margin: EdgeInsets.zero),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                final allSelected =
                    _selectedPrayers.length == _prayerOptions.length;
                setState(() {
                  if (allSelected) {
                    _selectedPrayers = {};
                  } else {
                    _selectedPrayers = _prayerOptions.map((p) => p.$1).toSet();
                  }
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedPrayers.length == _prayerOptions.length
                      ? gold.withValues(alpha: 0.10)
                      : t.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedPrayers.length == _prayerOptions.length
                        ? gold.withValues(alpha: 0.3)
                        : t.outline,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedPrayers.length == _prayerOptions.length
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: _selectedPrayers.length == _prayerOptions.length
                          ? gold
                          : t.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'همه اذان‌ها',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w600,
                        color: _selectedPrayers.length == _prayerOptions.length
                            ? goldStrong
                            : t.textPrimary,
                      ),
                    ),
                    if (_selectedPrayers.length == _prayerOptions.length)
                      const Spacer()
                    else ...[
                      const Spacer(),
                      Text(
                        '${_selectedPrayers.length} انتخاب',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          color: t.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _prayerOptions.map((p) {
                final (key, label, icon, color) = p;
                final isSelected = _selectedPrayers.contains(key);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selectedPrayers.remove(key);
                    } else {
                      _selectedPrayers.add(key);
                    }
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.12)
                          : t.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? color.withValues(alpha: 0.4)
                            : t.outline,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 16, color: isSelected ? color : t.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? dsContentColor(context, color)
                                : t.textMuted,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.check_circle, size: 16, color: color),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'تنظیم زمان نسبت به اذان',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final offset in [-15, -10, -5, 0, 5, 10, 15, 30])
                  GestureDetector(
                    onTap: () => setState(() => _prayerOffsetMinutes = offset),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _prayerOffsetMinutes == offset
                            ? gold.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _prayerOffsetMinutes == offset
                              ? gold.withValues(alpha: 0.4)
                              : t.outline,
                        ),
                      ),
                      child: Text(
                        offset == 0
                            ? 'همزمان'
                            : '${offset > 0 ? '+' : ''}$offset',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          fontWeight: _prayerOffsetMinutes == offset
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _prayerOffsetMinutes == offset
                              ? goldStrong
                              : t.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ] else if (_isDateSpecific) ...[
            const SectionHeader(title: 'تاریخ', margin: EdgeInsets.zero),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showShamsiDatePicker(context, gold, isDark),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: t.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: gold, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      'تاریخ',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        color: t.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _specificDate != null
                          ? jalaliYmdPadded(_specificDate!)
                          : 'انتخاب کنید',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w700,
                        color: _specificDate != null ? goldStrong : t.textMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_left, color: t.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const SectionHeader(title: 'روزهای تکرار', margin: EdgeInsets.zero),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                final allSelected = _selectedDays.every((d) => d);
                setState(() {
                  for (int i = 0; i < 7; i++) {
                    _selectedDays[i] = !allSelected;
                  }
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedDays.every((d) => d)
                      ? gold.withValues(alpha: 0.10)
                      : t.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedDays.every((d) => d)
                        ? gold.withValues(alpha: 0.3)
                        : t.outline,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedDays.every((d) => d)
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 20,
                      color: _selectedDays.every((d) => d) ? gold : t.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'هر روز',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w600,
                        color: _selectedDays.every((d) => d)
                            ? goldStrong
                            : t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(7, (i) {
                final isSelected = _selectedDays[i];
                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedDays[i] = !_selectedDays[i]),
                    child: Container(
                      margin: EdgeInsets.only(left: i < 6 ? 6 : 0),
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? gold.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? gold.withValues(alpha: 0.4)
                              : t.outline,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _shortDayNames[i],
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? goldStrong : t.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
          const SizedBox(height: 24),
          const SectionHeader(title: 'اعلان و صدا', margin: EdgeInsets.zero),
          const SizedBox(height: 8),
          ...List.generate(_soundOptions.length, (i) {
            final (key, label, icon) = _soundOptions[i];
            final isSelected = _soundName == key;
            return GestureDetector(
              onTap: () => setState(() => _soundName = key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color:
                      isSelected ? gold.withValues(alpha: 0.08) : t.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? gold.withValues(alpha: 0.4) : t.outline,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        size: 20, color: isSelected ? gold : t.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? t.textPrimary : t.textMuted,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, size: 20, color: gold),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showSoundPicker(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: (_soundName != 'default' && _soundName != 'silent'
                    ? gold.withValues(alpha: 0.08)
                    : t.surfaceAlt),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _soundName != 'default' && _soundName != 'silent'
                      ? gold.withValues(alpha: 0.4)
                      : t.outline,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.music_note_outlined,
                      size: 20,
                      color: _soundName != 'default' && _soundName != 'silent'
                          ? gold
                          : t.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _soundLabel,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w600,
                        color: _soundName != 'default' && _soundName != 'silent'
                            ? t.textPrimary
                            : t.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_currentPreview case final preview?)
                    IconButton(
                      tooltip:
                          SoundPreviewService.instance.isPlaying(preview.key)
                              ? 'توقف صدا'
                              : 'پخش نمونه',
                      visualDensity: VisualDensity.compact,
                      onPressed: _toggleCurrentPreview,
                      icon: Icon(
                        SoundPreviewService.instance.isPlaying(preview.key)
                            ? Icons.stop_circle_rounded
                            : Icons.play_circle_outline_rounded,
                        size: 22,
                        color: gold,
                      ),
                    ),
                  Icon(Icons.chevron_left, size: 20, color: t.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
