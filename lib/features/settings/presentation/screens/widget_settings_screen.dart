import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/features/adhkar/tasbih/tasbih.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/presentation/widgets/prayer_widget_preview.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/widgets/tasbih_widget_preview.dart';
import 'package:tawheeed/features/home/services/widget_sync_provider.dart';
import 'package:tawheeed/features/home/services/widget_bridge.dart';
import 'package:tawheeed/features/home/domain/entities/widget_snapshot.dart';
import 'package:tawheeed/shared/services/widget_sync_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/features/settings/presentation/widgets/widget_palettes.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_flash.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:tawheeed/features/settings/presentation/widgets/widget_design_tokens.dart';
import 'package:tawheeed/shared/models/day_time.dart';

/// Shared kit card-with-dividers lives in settings_widgets.dart
/// ([settingsCard]).

class WidgetSettingsScreen extends ConsumerStatefulWidget {
  const WidgetSettingsScreen({super.key});

  @override
  ConsumerState<WidgetSettingsScreen> createState() =>
      _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends ConsumerState<WidgetSettingsScreen>
    with SettingsHighlight<WidgetSettingsScreen> {
  static const int _tabPrayer = 0;

  /// The native per-widget key suffix for each tab, in tab order.
  static const List<String> _tabTargets = ['prayer', 'tasbih'];

  List<WidgetPalette> _palettes = const [];
  bool _loaded = false;

  // One independent selection per widget, indexed by tab.
  List<String> _selectedPaletteId =
      List.filled(2, WidgetPalettes.defaultPaletteId);
  List<int> _selectedStep = const [0, 0];
  List<String> _savedPaletteId =
      List.filled(2, WidgetPalettes.defaultPaletteId);
  List<int> _savedStep = const [0, 0];
  int _activeTab = _tabPrayer;

  // ── The per-widget options ──
  //
  // These live on the SCREEN, not inside the options card, for two reasons:
  //
  //  1. The preview is drawn by this screen, and it has to react to them. The
  //     card used to own the state, so the preview could not see a toggle and
  //     the page showed a card that ignored the options above it.
  //  2. One writer. The card used to move its own thumb and the screen knew
  //     nothing, so a value written from anywhere else never reached either.
  bool? _showProgress;
  bool? _showGregorian;
  bool? _faDigits;
  bool? _autoAdvance;

  /// «چیدمان ویجت اوقات نماز» — the new second layout. `horizontal` is the
  /// shipped five-box card; `vertical` is the five-row one.
  String _layout = WidgetSnapshot.prayerLayoutHorizontal;

  /// True while a toggle is being written + pushed. ONE flag for the card:
  /// every switch disables together so a second tap cannot race the first.
  bool _optionsBusy = false;

  /// Search-landing anchors: the palette card and the opacity card — the two
  /// rows the settings search can deep-link to on this page.
  final Map<String, GlobalKey> _anchors = {
    'colors': GlobalKey(),
    'sliders': GlobalKey(),
  };

  @override
  Map<String, GlobalKey> get highlightAnchors => _anchors;

  bool get _hasUnsavedChanges {
    for (var i = 0; i < _tabTargets.length; i++) {
      if (_selectedPaletteId[i] != _savedPaletteId[i] ||
          _selectedStep[i] != _savedStep[i]) {
        return true;
      }
    }
    return false;
  }

  /// Set the instant the user confirms «خروج بدون ذخیره».
  ///
  /// This is not a convenience: it is what makes leaving possible at all. The
  /// page is a page-based (GoRouter) route, and for those `Navigator.pop`
  /// delegates to the delegate's `onPopPage`. Popping from inside
  /// `onPopInvokedWithResult` while `canPop` is still false therefore never
  /// completes — the page stayed on screen no matter what the user tapped,
  /// which is exactly the «گیر کرده» report. Flipping this first makes
  /// `canPop` true, so the pop that follows is a real one.
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

  /// The native side owns the selection. Before the first widget render has
  /// persisted a migrated palette there, mirror its legacy migration for
  /// display so the page opens on what the widget will actually show. Each
  /// widget resolves independently — the same ladder the native resolver
  /// walks: its own per-widget keys, then the shared keys both widgets
  /// carried before the split, then the legacy colour prefs.
  Future<void> _load() async {
    final palettes = await WidgetPalettes.load();
    final theme = await ref.read(widgetSyncProvider).getWidgetTheme();
    final maxStep = WidgetPalettes.opacitySteps(palettes).length - 1;
    final ids = <String>[];
    final steps = <int>[];
    for (final target in _tabTargets) {
      final (id, step) = await _resolveSelection(palettes, theme, target);
      ids.add(id);
      steps.add(step.clamp(0, maxStep));
    }
    final options = await _readOptions();
    if (!mounted) return;
    setState(() {
      _palettes = palettes;
      _selectedPaletteId = ids;
      _savedPaletteId = List.of(ids);
      _selectedStep = steps;
      _savedStep = List.of(steps);
      _showProgress = options.$1;
      _showGregorian = options.$2;
      _faDigits = options.$3;
      _autoAdvance = options.$4;
      _layout = options.$5;
      _loaded = true;
    });
  }

  /// The stored option values, with the same defaults the native renderer
  /// applies when a key is missing — so the page opens showing what the widget
  /// is actually drawing, never a guess.
  Future<(bool, bool, bool, bool, String)> _readOptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (
        prefs.getBool('widget_show_progress') ?? true,
        prefs.getBool('widget_show_gregorian') ?? true,
        prefs.getBool('widget_fa_digits') ?? false,
        prefs.getBool('tasbih_auto_advance') ?? false,
        prefs.getString('widget_prayer_layout') ==
                WidgetSnapshot.prayerLayoutVertical
            ? WidgetSnapshot.prayerLayoutVertical
            : WidgetSnapshot.prayerLayoutHorizontal,
      );
    } on MissingPluginException {
      return (true, true, false, false, WidgetSnapshot.prayerLayoutHorizontal);
    }
  }

  /// Writes one option, moves the UI first, and pushes a snapshot so a placed
  /// widget repaints within a second.
  ///
  /// The old card wrote the pref but never updated its own state, so the thumb
  /// never moved; and it set a `_busy` flag it never cleared, which disabled
  /// every switch on the card for the rest of the session — the user's «گزینه
  /// ها قفل هستند». Both are fixed here: the value is set optimistically,
  /// rolled back on failure, and `_optionsBusy` is always released.
  Future<void> _writeOption(String key, bool value) async {
    if (_optionsBusy) return;
    final previous = _optionValue(key);
    setState(() {
      _optionsBusy = true;
      _setOptionValue(key, value);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
      await ref.read(widgetSyncServiceProvider).syncWidgetsNow(ref);
    } catch (e) {
      // Never leave the card claiming a state the widget does not have.
      if (mounted) setState(() => _setOptionValue(key, previous ?? !value));
      AppLogger.warning('WidgetSettings', 'option $key failed: $e');
      if (mounted) {
        AppSnackBar.error(context, 'ذخیره نشد؛ دوباره تلاش کنید.');
      }
    } finally {
      if (mounted) setState(() => _optionsBusy = false);
    }
  }

  /// The layout option. Written immediately like the toggles — the preview
  /// above repaints the moment it changes, which is the point of the option.
  Future<void> _writeLayout(String value) async {
    if (_optionsBusy || value == _layout) return;
    final previous = _layout;
    setState(() {
      _optionsBusy = true;
      _layout = value;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('widget_prayer_layout', value);
      await ref.read(widgetSyncServiceProvider).syncWidgetsNow(ref);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) setState(() => _layout = previous);
      AppLogger.warning('WidgetSettings', 'layout write failed: $e');
      if (mounted) {
        AppSnackBar.error(context, 'ذخیره نشد؛ دوباره تلاش کنید.');
      }
    } finally {
      if (mounted) setState(() => _optionsBusy = false);
    }
  }

  bool? _optionValue(String key) {
    if (key == 'widget_show_progress') return _showProgress;
    if (key == 'widget_show_gregorian') return _showGregorian;
    if (key == 'widget_fa_digits') return _faDigits;
    if (key == 'tasbih_auto_advance') return _autoAdvance;
    return null;
  }

  void _setOptionValue(String key, bool value) {
    if (key == 'widget_show_progress') {
      _showProgress = value;
    } else if (key == 'widget_show_gregorian') {
      _showGregorian = value;
    } else if (key == 'widget_fa_digits') {
      _faDigits = value;
    } else if (key == 'tasbih_auto_advance') {
      _autoAdvance = value;
    }
  }

  /// Per-widget stored map → shared keys (the pre-split selection) → the
  /// legacy exact-colour prefs → defaults.
  Future<(String, int)> _resolveSelection(
    List<WidgetPalette> palettes,
    Map<String, dynamic> theme,
    String target,
  ) async {
    final perWidget = theme[target];
    final storedId =
        perWidget is Map ? perWidget['paletteId'] as String? : null;
    final storedStep = perWidget is Map
        ? ((perWidget['opacityStep'] as num?)?.toInt() ?? -1)
        : -1;
    if (storedId != null && storedStep >= 0) {
      return (storedId, storedStep);
    }
    final sharedId = theme['paletteId'] as String?;
    final sharedStep = (theme['opacityStep'] as num?)?.toInt() ?? -1;
    if (sharedId != null && sharedStep >= 0) {
      return (sharedId, sharedStep);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return WidgetPalettes.legacySelection(
        palettes,
        prefs.getString(WidgetTokens.keyBgColor),
        prefs.getDouble(WidgetTokens.keyOpacity) ?? -1.0,
      );
    } on MissingPluginException {
      return (WidgetPalettes.defaultPaletteId, 0);
    }
  }

  /// The palette the widget currently paints with: the selected preset, or
  /// for «خودکار» the one bound to the current prayer-time phase (same
  /// boundaries the native resolver uses — the app's own times).
  WidgetPalette get _displayPalette {
    final id = _selectedPaletteId[_activeTab];
    if (id == 'auto') {
      return WidgetPalettes.forPhase(_palettes, _phaseForNow());
    }
    return WidgetPalettes.byId(_palettes, id);
  }

  WidgetPhase _phaseForNow() {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    int? m(DayTime? t) => t == null ? null : t.hour * 60 + t.minute;
    final prayer = ref.read(prayerTimesProvider).value;
    final fajr = m(prayer?.fajr.time);
    final sunrise = m(prayer?.shorouq.time);
    final dhuhr = m(prayer?.duhr.time);
    final asr = m(prayer?.asr.time);
    final maghrib = m(prayer?.maghrib.time);
    final isha = m(prayer?.isha.time);
    bool inRange(int? start, int? end) =>
        start != null && end != null && minutes >= start && minutes < end;
    if (isha == null || fajr == null || minutes >= isha || minutes < fajr) {
      return WidgetPhase.night;
    }
    if (inRange(fajr, sunrise)) return WidgetPhase.dawn;
    if (inRange(sunrise, dhuhr)) return WidgetPhase.morning;
    if (inRange(dhuhr, asr)) return WidgetPhase.afternoon;
    if (inRange(asr, maghrib)) return WidgetPhase.sunset;
    if (inRange(maghrib, isha)) return WidgetPhase.evening;
    return WidgetPhase.night;
  }

  double get _opacity {
    final steps = WidgetPalettes.opacitySteps(_palettes);
    return _selectedStep[_activeTab] < steps.length
        ? steps[_selectedStep[_activeTab]]
        : steps.first;
  }

  Future<void> _applyTheme() async {
    final ws = ref.read(widgetSyncProvider);
    final changed = <String>[];
    for (var i = 0; i < _tabTargets.length; i++) {
      if (_selectedPaletteId[i] == _savedPaletteId[i] &&
          _selectedStep[i] == _savedStep[i]) {
        continue;
      }
      changed.add(_tabTargets[i]);
      await ws.setWidgetTheme(
        paletteId: _selectedPaletteId[i],
        opacityStep: _selectedStep[i],
        widget: _tabTargets[i],
      );
    }
    // The bridge logs and returns on a platform-channel failure, so its
    // completion is not proof the widget changed. Read the native state back:
    // claiming «ذخیره شد» over a widget that still paints the old palette is
    // the one lie this page must not tell.
    final persisted = await _persistedTargets(changed);
    if (!mounted) return;
    if (!persisted) {
      AppSnackBar.error(
          context, 'ذخیره نشد؛ ویجت تغییر نکرد. دوباره تلاش کنید.');
      return;
    }
    // A style save also refreshes the data snapshot, otherwise the widgets
    // keep stale times/dates under the new skin until the next sync.
    ref.read(widgetSyncServiceProvider).syncWidgetsNow(ref);
    setState(() {
      _savedPaletteId = List.of(_selectedPaletteId);
      _savedStep = List.of(_selectedStep);
    });
    HapticFeedback.lightImpact();
    if (mounted) {
      AppSnackBar.success(context, 'استایل ویجت ذخیره شد');
    }
  }

  /// True when the native store reports, for every target in [targets], the
  /// palette and opacity step this page just asked for. A target with no
  /// stored map yet counts as a failure: the write did not land.
  Future<bool> _persistedTargets(List<String> targets) async {
    if (targets.isEmpty) return true;
    final theme = await ref.read(widgetSyncProvider).getWidgetTheme();
    for (final target in targets) {
      final index = _tabTargets.indexOf(target);
      final entry = theme[target];
      if (entry is! Map) return false;
      if (entry['paletteId'] != _selectedPaletteId[index]) return false;
      if ((entry['opacityStep'] as num?)?.toInt() != _selectedStep[index]) {
        return false;
      }
    }
    return true;
  }

  /// Guard against losing edits: confirm before popping with unsaved changes.
  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تغییرات ذخیره نشده',
            style: TextStyle(fontFamily: AppTheme.fontFamily)),
        content: Text(
            'استایل ویجت را تغییر داده‌اید اما ذخیره نشده است. خروج بدون ذخیره؟',
            style: TextStyle(fontFamily: AppTheme.fontFamily)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('ماندن',
                style: TextStyle(fontFamily: AppTheme.fontFamily)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('خروج بدون ذخیره',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final display = _displayPalette;
    final effectiveBg =
        WidgetPalettes.composite(display.bgColor, _opacity, const Color(0xFF808080));
    final contrast =
        WidgetPalettes.contrastRatio(effectiveBg, display.textColor);
    return PopScope(
      canPop: _allowPop || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!context.mounted) return;
        final discard = await _confirmDiscard();
        if (!discard || !context.mounted) return;
        // Open the gate first, then walk through it — see [_allowPop].
        setState(() => _allowPop = true);
        Navigator.of(context).pop(result);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SettingsAppBar(
          title: 'ویجت‌ها',
          // If this page is ever the ROOT route (a build that launches straight
          // into it), there is nothing to pop and the user is stranded: the
          // in-app arrow does nothing and the system back drops them out of the
          // app. Land them on the shell instead — never on a dead end.
          onBack: () {
            final navigator = Navigator.of(context);
            if (!navigator.canPop()) {
              // Nothing beneath: land on the shell, never on a dead end.
              context.go(RouteNames.shell);
              return;
            }
            // maybePop, not pop: it is the path that runs the unsaved-changes
            // guard below. A bare pop would silently throw the edits away.
            navigator.maybePop();
          },
          trailing: TextButton.icon(
            onPressed: _hasUnsavedChanges ? _applyTheme : null,
            icon: Icon(Icons.check,
                size: 18,
                color: _hasUnsavedChanges ? null : t.textMuted),
            label: Text('ذخیره',
                style: TextStyle(fontFamily: AppTheme.fontFamily)),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.page, vertical: 8),
              child: SegmentedTabs(
                tabs: const [
                  SegmentedTab(
                      label: 'اوقات نماز', icon: Icons.nightlight_round),
                  SegmentedTab(label: 'تسبیح', icon: Icons.lens_blur),
                ],
                index: _activeTab,
                onChanged: (i) => setState(() => _activeTab = i),
              ),
            ),
            Expanded(
              child: ListView(
                controller: highlightScrollController,
                padding: const EdgeInsets.fromLTRB(
                    DsSpacing.page, 0, DsSpacing.page, 24),
                children: [
                  _buildPreviewStage(display),
                  const SizedBox(height: 12),
                  const SettingsSaveFailureBanner(),
                  if (contrast < 3.0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: warning.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: warning.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 18, color: warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'در این شفافیت، خوانایی متن روی پس‌زمینه کم است',
                              style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 12),
                                fontFamily: AppTheme.fontFamily,
                                color: warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SettingsFlashSection(
                    rowKey: 'colors',
                    flashKey: highlightFlashKey,
                    child: KeyedSubtree(
                      key: _anchors['colors'],
                      child: _PaletteCard(
                        title: _activeTab == _tabPrayer
                            ? 'پالت رنگ — اوقات نماز'
                            : 'پالت رنگ — تسبیح',
                        palettes: _palettes,
                        selectedId: _selectedPaletteId[_activeTab],
                        loaded: _loaded,
                        onSelect: (id) =>
                            setState(() => _selectedPaletteId[_activeTab] = id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsFlashSection(
                    rowKey: 'sliders',
                    flashKey: highlightFlashKey,
                    child: KeyedSubtree(
                      key: _anchors['sliders'],
                      child: _OpacityCard(
                        title: _activeTab == _tabPrayer
                            ? 'شفافیت پس‌زمینه — اوقات نماز'
                            : 'شفافیت پس‌زمینه — تسبیح',
                        steps: WidgetPalettes.opacitySteps(_palettes),
                        selectedStep: _selectedStep[_activeTab],
                        onSelect: (s) =>
                            setState(() => _selectedStep[_activeTab] = s),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsFlashSection(
                    rowKey: 'options',
                    flashKey: highlightFlashKey,
                    child: KeyedSubtree(
                      key: _anchors['options'],
                      child: _WidgetOptionsCard(
                        isTasbih: _activeTab == 1,
                        layout: _layout,
                        showProgress: _showProgress,
                        showGregorian: _showGregorian,
                        faDigits: _faDigits,
                        autoAdvance: _autoAdvance,
                        busy: _optionsBusy,
                        onToggle: _writeOption,
                        onLayout: _writeLayout,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  settingsCard([
                    settingsRow(SettingRow(
                      icon: Icons.sync,
                      title: 'همگام‌سازی دستی',
                      subtitle: 'ارسال داده‌های فعلی به ویجت‌ها',
                      showChevron: false,
                      trailing: TextButton(
                          onPressed: () => _manualSync(context),
                          child: Text('همگام‌سازی',
                              style:
                                  TextStyle(fontFamily: AppTheme.fontFamily))),
                    )),
                    if (_activeTab == 1)
                      settingsRow(SettingRow(
                        icon: Icons.add_box_outlined,
                        title: 'افزودن ویجت تسبیح',
                        subtitle: 'ویجت تسبیح را به صفحه اصلی اضافه کنید',
                        showChevron: false,
                        trailing: _pinWidgetButton(context, 'tasbih', 'افزودن'),
                      ))
                    else ...[
                      settingsRow(SettingRow(
                        icon: Icons.view_column_outlined,
                        title: 'افزودن ویجت افقی اوقات نماز',
                        subtitle:
                            'ویجت اوقات نماز به چیدمان افقی (پنج خانه کنار هم)',
                        showChevron: false,
                        trailing: _pinWidgetButton(context, 'prayer', 'افزودن'),
                      )),
                      settingsRow(SettingRow(
                        icon: Icons.view_stream_outlined,
                        title: 'افزودن ویجت عمودی اوقات نماز',
                        subtitle:
                            'ویجت اوقات نماز به چیدمان عمودی (پنج ردیف) — ویجتی مستقل از ویجت افقی',
                        showChevron: false,
                        trailing:
                            _pinWidgetButton(context, 'prayer_vertical', 'افزودن'),
                      )),
                    ],
                    settingsRow(SettingRow(
                      icon: Icons.help_outline,
                      title: 'نحوه اضافه کردن ویجت',
                      subtitle: 'صفحه اصلی را لمس کنید و نگه دارید',
                      onTap: () => _showHelp(context),
                    )),
                  ]),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The live preview as the FIRST child of the page's scroll view, so it
  /// travels with the controls instead of being pinned above them.
  ///
  /// It used to sit in a `Flexible` box clamped to 260–320 dp outside the
  /// list, with a nested `SingleChildScrollView` to survive a short screen.
  /// That pinned it while everything else scrolled («صفحه که اسکرول می‌کنم
  /// پیش‌نمایش‌ها هم اسکرول بشوند»), and the clamp was guesswork: both
  /// previews are a fixed [WidgetTokens.widgetMediumWidth] × height, so the
  /// stage is exactly that plus a small margin and no inner scroll is needed.
  ///
  /// The height follows the LAYOUT: the five-row card needs the room its rows
  /// are priced for (`PrayerVerticalBudget` puts the full tier — header, clock,
  /// date, five rows, countdown — at ~263 dp on a 320 dp-wide cell), so the
  /// vertical preview is drawn at [verticalPreviewHeight] and the horizontal
  /// one keeps the home screen's medium cell. Both are drawn 1:1; the stage
  /// never scales the card up.
  ///
  /// The backdrop stays: it wears the selected gradient at the selected
  /// opacity, which is what the widget itself is drawn on. At 55% the preview
  /// is translucent, so this surface is what the user is really choosing
  /// against.
  Widget _buildPreviewStage(WidgetPalette display) {
    return Container(
      height: _previewHeight + 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            display.bgColor.withValues(alpha: _opacity),
            display.bgEndColor.withValues(alpha: _opacity),
          ],
        ),
        borderRadius: BorderRadius.circular(WidgetTokens.widgetRadius),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      // scaleDown, never up: the preview stays 1:1 with the home-screen widget
      // wherever it fits, and shrinks instead of overflowing on a narrow
      // phone. The 320 dp widget needs 320 + the page gutters.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: _buildPreview(display),
      ),
    );
  }

  /// The vertical card's preview box: the first height at which its FULL tier
  /// fits at the preview's 320 dp width, with a little air — see
  /// `PrayerVerticalBudget.metrics`. A shorter box would draw the compact
  /// tier, which is truthful for a 4×2 placement but is not the design the
  /// option is offering.
  static const double verticalPreviewHeight = 272;

  double get _previewHeight => _activeTab == _tabPrayer &&
          _layout == WidgetSnapshot.prayerLayoutVertical
      ? verticalPreviewHeight
      : WidgetTokens.widgetMediumHeight;

  /// Builds a live preview that mirrors the actual home-screen widget for the
  /// selected type. Tab 0 = prayer + clock + calendar + remaining time.
  /// Tab 1 = tasbih counter.
  Widget _buildPreview(WidgetPalette display) {
    switch (_activeTab) {
      case 0:
        return _buildPrayerPreview(display);
      default:
        return _buildTasbihPreview(display);
    }
  }

  Widget _buildPrayerPreview(WidgetPalette display) {
    return SizedBox(
      width: WidgetTokens.widgetMediumWidth,
      height: _previewHeight,
      child: PrayerWidgetPreview(
        bgColor: display.bgColor,
        textColor: display.textColor,
        accentColor: display.accentColor,
        light: display.light,
        opacity: _opacity,
        settings: ref.read(settingsProvider).value,
        // The three options and the layout are handed to the preview so the
        // card above the controls shows what the widget will show — the
        // reason the page exists. They were previously owned inside the
        // options card, which is why toggling one changed nothing up here.
        layout: _layout,
        showProgress: _showProgress ?? true,
        showGregorian: _showGregorian ?? true,
        faDigits: _faDigits ?? false,
      ),
    );
  }

  Widget _buildTasbihPreview(WidgetPalette display) {
    // Watch — the preview updates live as the user taps the counter.
    // Prefer the zikr actually in progress; fall back to the first one.
    final tasbihList = ref.watch(tasbihProvider).value ?? [];
    TasbihModel? inProgress;
    for (final t in tasbihList) {
      if (t.currentCount > 0) {
        inProgress = t;
        break;
      }
    }
    final current =
        inProgress ?? (tasbihList.isNotEmpty ? tasbihList.first : null);
    final text = current?.targetDhikr ?? 'لا إله إلا الله';
    final count = current?.currentCount ?? 0;
    final target = current?.targetCount ?? 100;
    final zikrIndex = current == null
        ? 0
        : tasbihList.indexWhere((t) => t.id == current.id).clamp(0, 999);
    // The native widget sums its per-zikr counters for the «امروز N» line —
    // mirror that here so the preview teaches the real reading.
    final todayCount = tasbihList.fold<int>(0, (sum, t) => sum + t.currentCount);

    return TasbihWidgetPreview(
      dhikr: text,
      count: count,
      target: target,
      zikrIndex: zikrIndex,
      zikrCount: tasbihList.length,
      todayCount: todayCount,
      bgColor: display.bgColor,
      bgEndColor: display.bgEndColor,
      textColor: display.textColor,
      accentColor: display.accentColor,
      light: display.light,
      opacity: _opacity,
    );
  }

  /// Audit 8.21-1: the manual sync delegates to the background engine's full
  /// snapshot builder (khatm fields, per-zikr tasbih lists, native
  /// self-refresh calc params). The inline builder this replaces produced a
  /// POORER snapshot and overwrote the rich background data with it,
  /// clearing the widget's self-refresh inputs until the next bg sync.
  Future<void> _manualSync(BuildContext context) async {
    await ref.read(widgetSyncServiceProvider).syncWidgetsNow(ref);
    if (context.mounted) {
      AppSnackBar.success(context, 'ویجت‌ها همگام‌سازی شدند');
    }
  }

  /// Pins a prayer widget of the requested orientation to the home screen.
  ///
  /// `prayer` is the horizontal provider (which follows the «چیدمان» segmented
  /// control above); `prayer_vertical` is the dedicated vertical provider that
  /// always draws the five-row card. Both can live on the home screen at the
  /// same time.
  Widget _pinWidgetButton(BuildContext context, String widgetType, String label) {
    return TextButton(
      onPressed: () async {
        final bridge = WidgetBridge();
        final success = await bridge.requestPinWidget(widgetType: widgetType);
        if (context.mounted) {
          if (success) {
            AppSnackBar.success(context, 'ویجت با موفقیت اضافه شد');
          } else {
            AppSnackBar.error(context, 'امکان اضافه کردن ویجت وجود ندارد');
          }
        }
      },
      child: Text(label, style: TextStyle(fontFamily: AppTheme.fontFamily)),
    );
  }

  void _showHelp(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: t.textMuted,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('نحوه اضافه کردن ویجت',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 18),
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontFamily,
                    color: t.textPrimary)),
            const SizedBox(height: 12),
            _helpStep(context, 1, 'صفحه اصلی گوشی را لمس کنید و نگه دارید'),
            _helpStep(context, 2, 'گزینه ویجت‌ها را انتخاب کنید'),
            _helpStep(context, 3,
                'توحید را پیدا کرده و ویجت مورد نظر را انتخاب کنید'),
            _helpStep(context, 4, 'ویجت را روی صفحه قرار دهید'),
            const SizedBox(height: 8),
            Text(
                'پس از تغییر پالت یا شفافیت، دکمه ذخیره را بزنید تا به ویجت‌ها اعمال شود.',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: t.textMuted,
                    fontFamily: AppTheme.fontFamily)),
          ],
        ),
      ),
    );
  }

  Widget _helpStep(BuildContext context, int num, String text) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                  color: t.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: Center(
                  child: Text('$num',
                      style: TextStyle(
                          color: t.primary,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          fontWeight: FontWeight.bold,
                          fontFamily: AppTheme.fontFamily)))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontFamily: AppTheme.fontFamily))),
        ],
      ),
    );
  }
}

/// The palette picker: one gradient chip per preset plus the «خودکار» chip,
/// each labelled with its Persian name from widget_palettes.json.
class _PaletteCard extends StatelessWidget {
  final String title;
  final List<WidgetPalette> palettes;
  final String selectedId;
  final bool loaded;
  final ValueChanged<String> onSelect;

  const _PaletteCard({
    required this.title,
    required this.palettes,
    required this.selectedId,
    required this.loaded,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final presets = palettes.where((p) => !p.auto).toList(growable: false);
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.outline.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.bold,
                  color: t.textMuted,
                  fontFamily: AppTheme.fontFamily)),
          const SizedBox(height: 10),
          if (!loaded)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                _AutoChip(selected: selectedId == 'auto', onTap: () => onSelect('auto')),
                for (final p in presets)
                  _PaletteChip(
                    palette: p,
                    selected: selectedId == p.id,
                    onTap: () => onSelect(p.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// «خودکار»: the palette follows the prayer-time phase, so its swatch shows
/// a slice of every palette it may resolve to.
class _AutoChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _AutoChip({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ChipShell(
      selected: selected,
      onTap: onTap,
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          // True palette backgrounds (assets/widget_palettes.json), so the
          // swatch previews what «خودکار» may resolve to — never accents.
          gradient: const LinearGradient(
            colors: [
              Color(0xFF004F9E),
              Color(0xFF1B4332),
              Color(0xFF4C1D95),
              Color(0xFF7C2D12),
              Color(0xFF3B2316),
            ],
          ),
        ),
        child: Center(
          child: Text('خودکار',
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 10),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: AppTheme.fontFamily,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              )),
        ),
      ),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  final WidgetPalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteChip({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ChipShell(
      selected: selected,
      onTap: onTap,
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [palette.bgColor, palette.bgEndColor],
          ),
        ),
        child: Center(
          child: Text(palette.name,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 10),
                fontWeight: FontWeight.bold,
                color: palette.textColor,
                fontFamily: AppTheme.fontFamily,
              )),
        ),
      ),
    );
  }
}

class _ChipShell extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _ChipShell({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  // Selection chrome follows the CURRENT theme's accent, not
                  // a fixed gold ring (same rule as the settings page chips).
                  color: selected
                      ? t.accent
                      : t.outline.withValues(alpha: 0.4),
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: child,
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

/// The fixed opacity steps from widget_palettes.json (100/85/70/55 %).
class _OpacityCard extends StatelessWidget {
  final String title;
  final List<double> steps;
  final int selectedStep;
  final ValueChanged<int> onSelect;

  const _OpacityCard({
    required this.title,
    required this.steps,
    required this.selectedStep,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.outline.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.bold,
                  color: t.textMuted,
                  fontFamily: AppTheme.fontFamily)),
          const SizedBox(height: 10),
          SegmentedTabs(
            tabs: [
              for (final s in steps)
                SegmentedTab(label: '${(s * 100).round()}%'),
            ],
            index: selectedStep < steps.length ? selectedStep : 0,
            onChanged: onSelect,
          ),
        ],
      ),
    );
  }
}

/// The per-widget options (2026-11): for the prayer card — the layout
/// (horizontal / vertical), the progress bar, the Persian digits and the
/// Gregorian date line; for the tasbih card — what happens when the count
/// reaches the goal («ادامه شمارش» is the default for everyone, «رفتن به ذکر
/// بعدی» restores the old behavior).
///
/// The card is STATELESS and every value arrives from the screen, which hands
/// the same values to the preview above it. That is the fix for «گزینه‌های
/// جدید … قفل هستند»: the switches used to own their state, so a tap moved
/// nothing the page could see, and a single `_busy` flag that was never
/// cleared left every switch disabled for the rest of the session. Here a tap
/// calls [_WidgetSettingsScreenState._writeOption], which moves the value
/// optimistically, writes the SAME key the native side reads
/// (`tasbih_auto_advance`, `widget_show_progress`, `widget_show_gregorian`,
/// `widget_fa_digits`) or [_WidgetSettingsScreenState._writeLayout]
/// (`widget_prayer_layout`), and pushes the snapshot so a placed widget
/// repaints within a second.
class _WidgetOptionsCard extends StatelessWidget {
  const _WidgetOptionsCard({
    required this.isTasbih,
    required this.layout,
    required this.showProgress,
    required this.showGregorian,
    required this.faDigits,
    required this.autoAdvance,
    required this.busy,
    required this.onToggle,
    required this.onLayout,
  });

  final bool isTasbih;
  final String layout;
  final bool? showProgress;
  final bool? showGregorian;
  final bool? faDigits;
  final bool? autoAdvance;
  final bool busy;
  final Future<void> Function(String key, bool value) onToggle;
  final Future<void> Function(String value) onLayout;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final loaded = showProgress != null &&
        showGregorian != null &&
        faDigits != null &&
        autoAdvance != null;
    if (!loaded) {
      return const AppCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    final vertical = layout == WidgetSnapshot.prayerLayoutVertical;
    return AppCard(
      child: Column(
        children: [
          if (!isTasbih) ...[
            SettingRow(
              icon: vertical
                  ? Icons.view_stream_outlined
                  : Icons.view_column_outlined,
              title: 'چیدمان ویجت',
              subtitle: vertical
                  ? 'نمازها به‌صورت عمودی، هر نماز در یک ردیف'
                  : 'نمازها در یک ردیف کنار هم (طرح فعلی)',
              showChevron: false,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: SegmentedTabs(
                tabs: const [
                  SegmentedTab(label: 'افقی', icon: Icons.view_column_outlined),
                  SegmentedTab(label: 'عمودی', icon: Icons.view_stream_outlined),
                ],
                index: vertical ? 1 : 0,
                onChanged: busy
                    ? (_) {}
                    : (i) => onLayout(i == 1
                        ? WidgetSnapshot.prayerLayoutVertical
                        : WidgetSnapshot.prayerLayoutHorizontal),
              ),
            ),
            if (vertical)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14, color: t.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'این چیدمان روی ویجت افقیِ اضافه‌شده اعمال می‌شود. ویجت عمودی یک '
                        'ویجت مستقل است: آن را از دکمهٔ «افزودن ویجت عمودی» پین کنید — '
                        'می‌توانید ویجت افقی و عمودی را هم‌زمان داشته باشید.',
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          fontFamily: AppTheme.fontFamily,
                          color: t.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            settingsRow(SettingRow(
              icon: Icons.horizontal_rule_rounded,
              title: 'نمایش نوار پیشرفت',
              subtitle: 'نوار میزان گذشتهٔ روز تا اذان بعدی',
              showChevron: false,
              trailing: SettingsSwitch(
                value: showProgress!,
                onChanged:
                    busy ? null : (v) => onToggle('widget_show_progress', v),
              ),
            )),
            settingsRow(SettingRow(
              icon: Icons.looks_one_rounded,
              title: 'ارقام فارسی ساعت ویجت',
              subtitle: 'ساعت ویجت با ارقام ۰-۹ (پیش‌فرض: لاتین)',
              showChevron: false,
              trailing: SettingsSwitch(
                value: faDigits!,
                onChanged: busy ? null : (v) => onToggle('widget_fa_digits', v),
              ),
            )),
            settingsRow(SettingRow(
              icon: Icons.calendar_today_rounded,
              title: 'نمایش تاریخ میلادی',
              subtitle: 'نیمهٔ سوم خط تاریخ ویجت',
              showChevron: false,
              trailing: SettingsSwitch(
                value: showGregorian!,
                onChanged: busy
                    ? null
                    : (v) => onToggle('widget_show_gregorian', v),
              ),
            )),
          ] else
            settingsRow(SettingRow(
              icon: Icons.all_inclusive_rounded,
              title: 'بعد از رسیدن به هدف',
              subtitle: autoAdvance!
                  ? 'رفتن به ذکر بعدی (رفتار قدیمی)'
                  : 'ادامهٔ شمارش (پیش‌فرض)',
              showChevron: false,
              trailing: SettingsSwitch(
                value: autoAdvance!,
                onChanged: busy
                    ? null
                    : (v) => onToggle('tasbih_auto_advance', v),
              ),
            )),
        ],
      ),
    );
  }
}
