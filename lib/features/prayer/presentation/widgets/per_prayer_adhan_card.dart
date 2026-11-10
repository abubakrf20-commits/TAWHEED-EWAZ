import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/home/presentation/widgets/home_tokens.dart';
import 'package:tawheeed/features/prayer/services/prayer_azan_sound_store.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_flash.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart';

/// The per-prayer «اذان و اقامه هر نماز» card (Design A).
///
/// Five blocks on one settings card: each block owns its azan switch, its
/// voice chip and BOTH counters — the adhan-time shift and the adhan→iqamah
/// minutes — in one always-visible grid. An adhan-left-off prayer never dims
/// its counters: OFF dims only the adhan playback and the voice chip, and the
/// stored voice survives the toggle.
///
/// The control-grid layout degrades by measured width. A stepper whose ±
/// zones keep ≥44dp hit targets is ≥124px wide, so the three-column row
/// (voice chip 1.15 : shift 1 : iqamah 1) only fits wide screens; phones
/// render the approved two-row fallback (chip full-width above, the two
/// counters side by side) and very narrow widths stack all three controls.
/// The mode is decided per-layout inside the block, from the SAME width for
/// all five blocks, so the columns always align across the card.
class PerPrayerAdhanCard extends ConsumerStatefulWidget {
  const PerPrayerAdhanCard({
    super.key,
    required this.settings,
    required this.anchors,
    required this.flashKey,
  });

  final AppSettings settings;

  /// rowKey → GlobalKey owned by the page state; one per prayer block.
  final Map<String, GlobalKey> anchors;

  /// The rowKey currently flashing (see [SettingsHighlight]).
  final String? flashKey;

  static const rowKeys = <String>[
    'prayer.fajr',
    'prayer.dhuhr',
    'prayer.asr',
    'prayer.maghrib',
    'prayer.isha',
  ];

  static const _names = <String>['فجر', 'ظهر', 'عصر', 'مغرب', 'عشاء'];

  static const _icons = <IconData>[
    Icons.wb_twilight,
    Icons.light_mode,
    Icons.cloud,
    Icons.nightlight,
    Icons.dark_mode,
  ];

  /// Per-prayer identity accents — the home page's approved block colors
  /// (fajr == isha by the approved mockup; asr is the shared core token).
  static const _accents = <Color>[
    HomeColors.fajr,
    HomeColors.dhuhr,
    HomeColors.asr,
    HomeColors.maghrib,
    HomeColors.isha,
  ];

  @override
  ConsumerState<PerPrayerAdhanCard> createState() => _PerPrayerAdhanCardState();
}

class _PerPrayerAdhanCardState extends ConsumerState<PerPrayerAdhanCard> {
  /// Per-prayer voice overrides, loaded once at init. The card itself is the
  /// only writer while it is on screen, so local state can track every
  /// change synchronously; the store stays the source of truth for alarms.
  Map<PrayerSlot, String> _soundOverrides = const {};

  Settings get _notifier => ref.read(settingsProvider.notifier);

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  @override
  void didUpdateWidget(PerPrayerAdhanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Removing the picked adhan file also clears every «شخصی» override, so the
    // chip must not keep claiming one until the card is remounted.
    if (oldWidget.settings.customAzanPath != widget.settings.customAzanPath) {
      _loadSounds();
    }
  }

  Future<void> _loadSounds() async {
    try {
      final overrides = await PrayerAzanSoundStore().readOverrides();
      if (!mounted) return;
      setState(() => _soundOverrides = overrides);
    } catch (_) {
      // No prefs backing (fresh test isolate) — every prayer inherits the
      // shared voice, so leave the state empty.
    }
  }

  /// One shared value already validated the branch structure; these index
  /// doors keep the block widgets free of the ten field names.
  Future<void> setShiftAt(int i, int v) => switch (i) {
        0 => _notifier.setFajrOffset(v),
        1 => _notifier.setDhuhrOffset(v),
        2 => _notifier.setAsrOffset(v),
        3 => _notifier.setMaghribOffset(v),
        _ => _notifier.setIshaOffset(v),
      };

  Future<void> setIqamahAt(int i, int v) => switch (i) {
        0 => _notifier.setIqamahOffsetFajr(v),
        1 => _notifier.setIqamahOffsetDhuhr(v),
        2 => _notifier.setIqamahOffsetAsr(v),
        3 => _notifier.setIqamahOffsetMaghrib(v),
        _ => _notifier.setIqamahOffsetIsha(v),
      };

  Future<void> setEnabledAt(int i, bool v) => switch (i) {
        0 => _notifier.setAzanEnabledForFajr(v),
        1 => _notifier.setAzanEnabledForDhuhr(v),
        2 => _notifier.setAzanEnabledForAsr(v),
        3 => _notifier.setAzanEnabledForMaghrib(v),
        _ => _notifier.setAzanEnabledForIsha(v),
      };

  String _soundKeyFor(int i) => PrayerAzanSoundStore.effectiveFor(
      PrayerSlot.values[i], _soundOverrides, widget.settings.azanSound);

  Future<void> applySoundAt(int i, String key) async {
    final slot = PrayerSlot.values[i];
    setState(() => _soundOverrides = {..._soundOverrides, slot: key});
    await _notifier.setAzanSoundFor(slot, key);
  }

  Future<void> applySoundToAll(String key) async {
    setState(() => _soundOverrides = {
          for (final slot in PrayerSlot.values) slot: key,
        });
    for (final slot in PrayerSlot.values) {
      await _notifier.setAzanSoundFor(slot, key);
    }
  }

  Future<void> applyUniformIqamah(int v) =>
      _notifier.setIqamahOffsetsUniform(v);

  Future<void> resetSection() => _notifier.resetPrayerAdhanSection();

  /// Restores everything the three bulk actions can move: ten model values
  /// and the five voice overrides (absent → clear, back to the shared voice).
  Future<void> _restoreSnapshot(PrayerAdhanSnapshot snap) async {
    final shifts = [
      snap.fajrShift,
      snap.dhuhrShift,
      snap.asrShift,
      snap.maghribShift,
      snap.ishaShift
    ];
    final iqamahs = [
      snap.fajrIqamah,
      snap.dhuhrIqamah,
      snap.asrIqamah,
      snap.maghribIqamah,
      snap.ishaIqamah,
    ];
    for (var i = 0; i < 5; i++) {
      await setShiftAt(i, shifts[i]);
      await setIqamahAt(i, iqamahs[i]);
      final slot = PrayerSlot.values[i];
      final previous = snap.sounds[slot];
      if (previous == null) {
        await _notifier.clearAzanSoundFor(slot);
      } else {
        await _notifier.setAzanSoundFor(slot, previous);
      }
    }
    await _loadSounds();
  }

  PrayerAdhanSnapshot snapshotOf(AppSettings s) => PrayerAdhanSnapshot(
        fajrShift: s.fajrOffset,
        dhuhrShift: s.dhuhrOffset,
        asrShift: s.asrOffset,
        maghribShift: s.maghribOffset,
        ishaShift: s.ishaOffset,
        fajrIqamah: s.iqamahOffsetFajr,
        dhuhrIqamah: s.iqamahOffsetDhuhr,
        asrIqamah: s.iqamahOffsetAsr,
        maghribIqamah: s.iqamahOffsetMaghrib,
        ishaIqamah: s.iqamahOffsetIsha,
        sounds: {..._soundOverrides},
      );

  /// The bulk-undo snackbar. Its FIRST statement is the context's own
  /// mounted check, so a bulk closure may hand it the build context across
  /// its awaits (the same shape `_warnDndIfNeeded` uses on the page).
  void _showUndo(
    BuildContext context,
    String done,
    PrayerAdhanSnapshot snapshot,
  ) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(done),
          action: SnackBarAction(
            label: 'واگرد',
            onPressed: () => unawaited(_restoreSnapshot(snapshot)),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final enableds = [
      s.azanEnabledForFajr,
      s.azanEnabledForDhuhr,
      s.azanEnabledForAsr,
      s.azanEnabledForMaghrib,
      s.azanEnabledForIsha,
    ];

    return SettingsCard(
      children: [
        SettingsFlashSection(
          rowKey: 'prayer.adhanBulk',
          flashKey: widget.flashKey,
          child: Padding(
            key: widget.anchors['prayer.adhanBulk'],
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
            child: _BulkActionsRow(
              // The snapshot is captured from the PRE-ACTION settings
              // BEFORE the write — capturing it after the await would
              // restore the just-applied values back onto themselves.
              onSoundAll: (key) => unawaited(() async {
                final snap = snapshotOf(s);
                await applySoundToAll(key);
                if (!context.mounted) return;
                _showUndo(context, 'صدای همه نمازها تغییر کرد', snap);
              }()),
              onUniformIqamah: (v) => unawaited(() async {
                final snap = snapshotOf(s);
                await applyUniformIqamah(v);
                if (!context.mounted) return;
                _showUndo(context, 'فاصله اقامه یکسان شد', snap);
              }()),
              onReset: () => unawaited(() async {
                final snap = snapshotOf(s);
                await resetSection();
                if (!context.mounted) return;
                _showUndo(context, 'بخش اذان و اقامه بازنشانی شد', snap);
              }()),
            ),
          ),
        ),
        for (var i = 0; i < 5; i++) ...[
          const SettingsDivider(),
          SettingsFlashSection(
            rowKey: PerPrayerAdhanCard.rowKeys[i],
            flashKey: widget.flashKey,
            child: Padding(
              key: widget.anchors[PerPrayerAdhanCard.rowKeys[i]],
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _PrayerBlock(
                name: PerPrayerAdhanCard._names[i],
                icon: PerPrayerAdhanCard._icons[i],
                accent: PerPrayerAdhanCard._accents[i],
                enabled: enableds[i],
                soundKey: _soundKeyFor(i),
                shift: [
                  s.fajrOffset,
                  s.dhuhrOffset,
                  s.asrOffset,
                  s.maghribOffset,
                  s.ishaOffset,
                ][i],
                iqamah: [
                  s.iqamahOffsetFajr,
                  s.iqamahOffsetDhuhr,
                  s.iqamahOffsetAsr,
                  s.iqamahOffsetMaghrib,
                  s.iqamahOffsetIsha,
                ][i],
                onToggle: (v) => unawaited(setEnabledAt(i, v)),
                onSound: (key) => unawaited(applySoundAt(i, key)),
                onShift: (v) => unawaited(setShiftAt(i, v)),
                onIqamah: (v) => unawaited(setIqamahAt(i, v)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The pre-action state of the whole section, for the bulk actions' undo.
class PrayerAdhanSnapshot {
  const PrayerAdhanSnapshot({
    required this.fajrShift,
    required this.dhuhrShift,
    required this.asrShift,
    required this.maghribShift,
    required this.ishaShift,
    required this.fajrIqamah,
    required this.dhuhrIqamah,
    required this.asrIqamah,
    required this.maghribIqamah,
    required this.ishaIqamah,
    required this.sounds,
  });

  final int fajrShift, dhuhrShift, asrShift, maghribShift, ishaShift;
  final int fajrIqamah, dhuhrIqamah, asrIqamah, maghribIqamah, ishaIqamah;
  final Map<PrayerSlot, String> sounds;
}

/// One prayer block: header (duotone tile + name + live caption + switch) and
/// the always-active control grid under it.
class _PrayerBlock extends StatelessWidget {
  const _PrayerBlock({
    required this.name,
    required this.icon,
    required this.accent,
    required this.enabled,
    required this.soundKey,
    required this.shift,
    required this.iqamah,
    required this.onToggle,
    required this.onSound,
    required this.onShift,
    required this.onIqamah,
  });

  final String name;
  final IconData icon;
  final Color accent;
  final bool enabled;

  /// The EFFECTIVE voice of this prayer (own override or the shared one).
  final String soundKey;
  final int shift;
  final int iqamah;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onSound;
  final ValueChanged<int> onShift;
  final ValueChanged<int> onIqamah;

  static const int _shiftMin = -70;
  static const int _shiftMax = 70;
  static const int _iqamahMax = 70;

  /// The stepper pills keep 44dp ± zones → ≥124px; the voice chip needs ~78px.
  /// One shared minimum table per block keeps every mode on this list.
  static const double _chipMinWidth = 78;
  static const double _stepperMinWidth = 124;
  static const double _gap = 6;

  static const String _shiftCaption = 'جابجایی اذان (دقیقه)';
  static const String _iqamahCaption = 'تا اقامه (دقیقه)';

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    // The a/c rule: an OFF adhan dims ONLY the voice chip. The name and the
    // tile keep their identity ink; the status line below (accent when ON /
    // muted «اذان خاموش …» when OFF) is the state's own voice.

    return Column(
      key: ValueKey('adhan-block-$name'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              DuotoneIconTile(accent: accent, icon: icon, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w500,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    // The caption alone shrinks (FittedBox) — the row can
                    // never overflow, even at 320dp / scale 1.3.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        enabled
                            ? 'پخش اذان فعال'
                            : 'اذان خاموش · زمان و اقامه همچنان اعمال می‌شود',
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w400,
                          color: enabled
                              ? accent
                              : p.textMuted.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SettingsSwitch(
                value: enabled,
                semanticLabel: 'پخش اذان $name',
                onChanged: onToggle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final unit = (w - 2 * _gap) / 3.15;
                if (unit >= _stepperMinWidth && unit * 1.15 >= _chipMinWidth) {
                  return _grid3(context, p);
                }
                if ((w - _gap) / 2 >= _stepperMinWidth) {
                  return _grid2(context, p);
                }
                return _stacked(context, p);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _caption(BuildContext context, Color muted, String text) => Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 10),
          fontWeight: FontWeight.w400,
          color: muted,
        ),
      );

  /// Column cell with an optional centered caption above the control.
  Widget _cell(
    BuildContext context,
    String? caption,
    Widget control,
    Color muted,
  ) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (caption != null) ...[
            _caption(context, muted, caption),
            const SizedBox(height: 4),
          ],
          control,
        ],
      );

  Widget _voiceChip(BuildContext context) => _SoundChip(
        key: ValueKey('adhan-voice-$name'),
        accent: accent,
        enabled: enabled,
        soundKey: soundKey,
        prayerName: name,
        onSelected: onSound,
      );

  Widget _stepper(BuildContext context, bool isShift) {
    return SettingsStepper(
      key: ValueKey(isShift ? 'adhan-shift-$name' : 'adhan-iqama-$name'),
      value: isShift ? shift : iqamah,
      min: isShift ? _shiftMin : 0,
      max: isShift ? _shiftMax : _iqamahMax,
      signed: isShift,
      color: accent,
      height: 36,
      radius: 18,
      borderWidth: 1,
      glyphSize: 18,
      valueFontSize: 13.5,
      fillColor: TimeThemeKit.of(context).palette.card,
      borderColor: accent.withValues(alpha: 0.20),
      expand: true,
      semanticLabel: isShift ? 'جابجایی اذان $name' : 'فاصله اقامه $name',
      onChanged: isShift ? onShift : onIqamah,
    );
  }

  /// Wide screens: the three columns (voice chip 1.15 flex, then the two
  /// counters), captions above the counters, aligned across all five blocks.
  Widget _grid3(BuildContext context, AppPalette p) {
    return Row(
      children: [
        Expanded(
          flex: 115,
          child: _voiceChip(context),
        ),
        const SizedBox(width: _gap),
        Expanded(
          flex: 100,
          child: _cell(
              context, _shiftCaption, _stepper(context, true), p.textMuted),
        ),
        const SizedBox(width: _gap),
        Expanded(
          flex: 100,
          child: _cell(
              context, _iqamahCaption, _stepper(context, false), p.textMuted),
        ),
      ],
    );
  }

  /// Phones: the voice chip owns a full-width row and the two counters share
  /// the second row — every counter stays ≥ its 124px pill.
  Widget _grid2(BuildContext context, AppPalette p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _voiceChip(context),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _cell(
                  context, _shiftCaption, _stepper(context, true), p.textMuted),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: _cell(context, _iqamahCaption, _stepper(context, false),
                  p.textMuted),
            ),
          ],
        ),
      ],
    );
  }

  /// Very narrow screens: every control gets its own captioned row.
  Widget _stacked(BuildContext context, AppPalette p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _voiceChip(context),
        const SizedBox(height: 8),
        _cell(context, _shiftCaption, _stepper(context, true), p.textMuted),
        const SizedBox(height: 8),
        _cell(context, _iqamahCaption, _stepper(context, false), p.textMuted),
      ],
    );
  }
}

/// Time-palette alias for the private helpers, keeping the signatures short.
// (removed — AppPalette is used directly)

/// The voice selector behind one prayer — the same kamel/takbir/custom
/// options the global «صوت اذان» row offers, written to the per-prayer
/// override. When the prayer's adhan playback is off the chip renders in
/// muted flat colors and stops taking hits (Semantics enabled: false); the
/// stored voice is preserved untouched.
class _SoundChip extends StatelessWidget {
  const _SoundChip({
    super.key,
    required this.accent,
    required this.enabled,
    required this.soundKey,
    required this.prayerName,
    required this.onSelected,
  });

  final Color accent;
  final bool enabled;
  final String soundKey;
  final String prayerName;
  final ValueChanged<String> onSelected;

  static const _options = <String>['kamel', 'takbir', 'takbirShort', 'custom'];

  static String shortLabel(String key) => switch (key) {
        'kamel' => 'کامل',
        'takbir' => 'تکبیر',
        'takbirShort' => 'تکبیر کوتاه',
        'custom' => 'شخصی',
        _ => key,
      };

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    final fill = enabled
        ? accent.withValues(alpha: 0.08)
        : p.textMuted.withValues(alpha: 0.10);
    final border = enabled
        ? accent.withValues(alpha: 0.19)
        : p.textMuted.withValues(alpha: 0.12);
    final ink = enabled ? _chipInk(context, accent) : p.textMuted;

    return Semantics(
      label: enabled
          ? 'انتخاب صدای اذان $prayerName'
          : 'انتخاب صدای اذان $prayerName — غیرفعال',
      button: true,
      enabled: enabled,
      child: PopupMenuButton<String>(
        tooltip: 'صدای اذان $prayerName',
        enabled: enabled,
        initialValue: soundKey,
        onSelected: onSelected,
        color: p.card,
        itemBuilder: (context) => [
          for (final o in _options)
            CheckedPopupMenuItem(
              value: o,
              checked: o == soundKey,
              child: Text(
                shortLabel(o),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                ),
              ),
            ),
        ],
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_note_rounded, size: 15, color: ink),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  shortLabel(soundKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11.5),
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}

/// The chip ink of a colored accent — dark-mixed on light palettes, on dark
/// ones the kit's readable-accent lift, so a deep accent never fails 3:1.
Color _chipInk(BuildContext context, Color accent) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    return Color.lerp(accent, Colors.white, 0.35) ?? accent;
  }
  return Color.lerp(accent, Colors.black, 0.35) ?? accent;
}

/// The «صدا برای همه» / «اقامه یکسان» / «بازنشانی» chip strip. The two pickers
/// open real menus; they never touch the five ON/OFF toggles.
class _BulkActionsRow extends StatelessWidget {
  const _BulkActionsRow({
    required this.onSoundAll,
    required this.onUniformIqamah,
    required this.onReset,
  });

  final ValueChanged<String> onSoundAll;
  final ValueChanged<int> onUniformIqamah;
  final VoidCallback onReset;

  static const _soundOptions = <String>[
    'kamel',
    'takbir',
    'takbirShort',
    'custom'
  ];
  static const _uniformChoices = <int>[10, 15, 20, 25, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;

    Widget chipVisual(String label, IconData icon) => Container(
          height: 32,
          alignment: AlignmentDirectional.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.outline, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppPalette.heroGold),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11.5),
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );

    return Row(
      children: [
        Expanded(
          child: PopupMenuButton<Object>(
            tooltip: 'صدای اذان همه نمازها',
            color: p.card,
            onSelected: (v) => onSoundAll(v as String),
            itemBuilder: (context) => [
              for (final o in _soundOptions)
                PopupMenuItem(
                  value: o,
                  child: Text(
                    _SoundChip.shortLabel(o),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                    ),
                  ),
                ),
            ],
            child: chipVisual('صدا برای همه', Icons.graphic_eq_rounded),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: PopupMenuButton<Object>(
            tooltip: 'فاصله اقامه یکسان',
            color: p.card,
            onSelected: (v) => onUniformIqamah(v as int),
            itemBuilder: (context) => [
              for (final v in _uniformChoices)
                PopupMenuItem(
                  value: v,
                  height: 40,
                  child: Text(
                    '$v دقیقه',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                    ),
                  ),
                ),
            ],
            child: chipVisual('اقامه یکسان', Icons.timer_rounded),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            onTap: onReset,
            child: chipVisual('بازنشانی', Icons.restart_alt_rounded),
          ),
        ),
      ],
    );
  }
}
