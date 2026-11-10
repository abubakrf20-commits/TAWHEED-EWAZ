import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/constants/month_display.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_flash.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_section_hues.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_provider.dart';
import 'package:tawheeed/features/settings/presentation/search/settings_registry.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/azkar_settings_provider.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/sound_registry.dart';
import 'package:tawheeed/shared/services/click_sound_player.dart';
import 'package:tawheeed/shared/services/currency_store.dart';
import 'package:tawheeed/shared/services/sound_preview_service.dart';
import 'package:tawheeed/shared/widgets/currency_selector.dart';

/// Shared kit padding lives in settings_components.dart ([settingsRow]).
/// Shared kit card-with-dividers lives in settings_widgets.dart
/// ([settingsCard]).

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  String? _flashKey;
  Timer? _flashTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 150),
      () {
        if (mounted) setState(() => _query = value.trim());
      },
    );
  }

  /// The keyboard's «جستجو» key: apply the query now instead of waiting out
  /// the debounce, then drop the keyboard so the results are actually visible.
  void _onSearchSubmitted(String value) {
    _searchDebounce?.cancel();
    if (mounted) setState(() => _query = value.trim());
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _openEntry(SettingsSearchEntry entry) async {
    // The keyboard would otherwise stay up over the row we are about to reveal
    // (or over the page we are pushing), so the target could land off-screen.
    FocusManager.instance.primaryFocus?.unfocus();
    if (entry.route != null) {
      if (!mounted) return;
      // Forward-compatible highlight: redesigned pages scroll to rowKey.
      await context
          .push(entry.route!, extra: {'settingsHighlight': entry.rowKey});
      return;
    }
    final rowKey = entry.rowKey;
    if (rowKey == null) return;
    setState(() {
      _query = '';
      _searchController.clear();
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    final target = _settingsAnchors[rowKey]?.currentContext;
    if (target == null || !target.mounted) return;
    await Scrollable.ensureVisible(
      target,
      alignment: 0.05,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    if (!mounted) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    setState(() => _flashKey = rowKey);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _flashKey = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;

    const appBar = SettingsAppBar(title: 'تنظیمات');

    // Wait for the real row instead of rendering `const AppSettings()` first:
    // the fallback flashed default theme/accent/point values until the Drift
    // read completed.
    if (settings == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SettingsAppBar(title: 'تنظیمات'),
        body: Center(
            child: Padding(
          padding: EdgeInsets.all(48),
          child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5)),
        )),
      );
    }

    final searching = _query.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(DsSpacing.page, 4, DsSpacing.page, 32),
        children: [
          SettingsSearchField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onSubmitted: _onSearchSubmitted,
          ),
          const SizedBox(height: 8),
          // A write that failed and rolled back used to look like a switch
          // that simply refused to move.
          const SettingsSaveFailureBanner(),
          if (searching)
            _SettingsSearchResults(query: _query, onPick: _openEntry)
          else ...[
            SettingsFlashSection(
              rowKey: 'appearance',
              flashKey: _flashKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    key: _settingsAnchors['appearance'],
                    title: 'ظاهر برنامه',
                    accent: SettingsSectionHues.on(
                        context, SettingsSectionHues.appearance),
                    margin: const EdgeInsets.only(bottom: 8, right: 4),
                  ),
                  _ThemeRow(settings: settings),
                  const SizedBox(height: 8),
                  _ThemeKindChips(settings: settings),
                  const SizedBox(height: 8),
                  settingsCard([
                    _navTile(
                        context,
                        Icons.font_download_outlined,
                        'فونت و نمایش',
                        'انتخاب فونت، اندازه، نام ماه و متن عربی',
                        () => context.push(RouteNames.fontSettings)),
                    _navTile(
                        context,
                        Icons.nightlight_outlined,
                        'نمای قوس صفحهٔ اصلی',
                        'برچسب‌دار، آسمان یا قطعه‌ای',
                        () => context.push(RouteNames.arcStyle)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SettingsFlashSection(
              rowKey: 'hijri',
              flashKey: _flashKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    key: _settingsAnchors['hijri'],
                    title: 'نماز و اذان',
                    accent: SettingsSectionHues.on(
                        context, SettingsSectionHues.prayer),
                    margin: const EdgeInsets.only(bottom: 8, right: 4),
                  ),
                  settingsCard([
                    _navTile(
                        context,
                        Icons.settings_outlined,
                        'تنظیمات اذان و اقامه',
                        'صوت اذان، اذان نمازها، اوقات، اقامه، بی‌صدا، موقعیت',
                        () => context.push(RouteNames.prayerSettings)),
                    const _HijriOffsetRow(),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SettingsFlashSection(
              rowKey: 'sounds',
              flashKey: _flashKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    key: _settingsAnchors['sounds'],
                    title: 'صداهای برنامه',
                    description:
                        'سه گروه: تعاملی، هشدارها و اذان — هر صدا یک کارت',
                    accent: SettingsSectionHues.on(
                        context, SettingsSectionHues.sounds),
                    margin: const EdgeInsets.only(bottom: 8, right: 4),
                  ),
                  const _SoundSettingsSection(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SettingsFlashSection(
              rowKey: 'scoring',
              flashKey: _flashKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    key: _settingsAnchors['scoring'],
                    title: 'امتیازدهی عبادات',
                    accent: SettingsSectionHues.on(
                        context, SettingsSectionHues.scoring),
                    margin: const EdgeInsets.only(bottom: 8, right: 4),
                  ),
                  settingsCard([
                    _navTile(
                        context,
                        Icons.tune_rounded,
                        'تنظیم امتیازها',
                        _scoringSummary(settings),
                        () => context.push(RouteNames.worshipScoring)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: 'اعلان‌ها و اذکار',
              accent: SettingsSectionHues.on(
                  context, SettingsSectionHues.notifications),
              margin: const EdgeInsets.only(bottom: 8, right: 4),
            ),
            settingsCard([
              _navTile(
                  context,
                  Icons.notifications_active_outlined,
                  'تنظیمات اعلان‌ها و اذکار',
                  'اذکار صبح و شب، آیه و حدیث روز، قرآن، مناسبت‌ها و جمعه',
                  () => context.push(RouteNames.notificationSettings)),
              _navTile(
                  context,
                  Icons.health_and_safety_outlined,
                  'تشخیص تنظیمات گوشی',
                  'بررسی خودکار مجوز اعلان‌ها، هشدار دقیق و باتری',
                  () => context.push(RouteNames.notificationDiagnostics)),
              // Maintenance-only: shown in debug builds so a one-off cleanup is
              // reachable without exposing an internal tool to every user.
              if (kDebugMode)
                _navTile(
                    context,
                    Icons.photo_library_outlined,
                    'پیوست‌های اطلاعات من',
                    'اسکن و پاک‌سازی عکس‌های بی‌صاحب و ارجاع‌های شکسته',
                    () => context.push(RouteNames.attachmentDiagnostics)),
            ]),
            const SizedBox(height: 20),
            SectionHeader(
              title: 'ویجت‌ها',
              accent:
                  SettingsSectionHues.on(context, SettingsSectionHues.widgets),
              margin: const EdgeInsets.only(bottom: 8, right: 4),
            ),
            settingsCard([
              _navTile(
                  context,
                  Icons.widgets_outlined,
                  'تنظیم ویجت‌های صفحه اصلی',
                  'رنگ و شفافیت ویجت‌ها',
                  () => context.push(RouteNames.widgetSettings)),
            ]),
            const SizedBox(height: 20),
            SettingsFlashSection(
              rowKey: 'currency',
              flashKey: _flashKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    key: _settingsAnchors['currency'],
                    title: 'واحد پول',
                    accent: SettingsSectionHues.on(
                        context, SettingsSectionHues.currency),
                    margin: const EdgeInsets.only(bottom: 8, right: 4),
                  ),
                  const _CurrencySection(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: 'سایر',
              accent:
                  SettingsSectionHues.on(context, SettingsSectionHues.other),
              margin: const EdgeInsets.only(bottom: 8, right: 4),
            ),
            settingsCard([
              _navTile(
                  context,
                  Icons.storage_outlined,
                  'مدیریت فضا',
                  'حجم داده‌ها و پاک‌سازی دانلودهای قابل بازدانلود',
                  () => context.push(RouteNames.storageSettings)),
              _navTile(
                  context,
                  Icons.battery_alert,
                  'بهینه‌سازی باتری',
                  'جلوگیری از بسته شدن برنامه',
                  () => context.push(RouteNames.batteryOptimization)),
            ]),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }

  /// One line that tells the reader the current numbers without opening the
  /// page; the six steppers themselves live in the scoring page's tabs
  /// (moved there 2026-11-09, when six inline rows read as a wall of numbers).
  String _scoringSummary(AppSettings s) {
    final percent = (s.worshipMultiplier * 100).round();
    return 'فرض ${s.fardhPoint} · سنت ${s.sunnahPoint} · ضحی ${s.duhaPoint}'
        ' · اذکار ${s.adhkarPoint} · تسبیح ${s.tasbihPoint}'
        ' · طاعات ${NumberFormat.ltrIsolated('$percent٪')}';
  }

  Widget _navTile(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return settingsRow(
      SettingRow(icon: icon, title: title, subtitle: subtitle, onTap: onTap),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// THEME ROW (horizontal cards)
// ═══════════════════════════════════════════════════════════════

class _ThemeRow extends ConsumerWidget {
  final AppSettings settings;
  const _ThemeRow({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: SettingsSegmented<ThemeModeOption>(
        options: const [
          SettingsSegment(
              label: 'سیستم',
              icon: Icons.smartphone,
              value: ThemeModeOption.system),
          SettingsSegment(
              label: 'روشن',
              icon: Icons.light_mode,
              value: ThemeModeOption.light),
          SettingsSegment(
              label: 'تاریک',
              icon: Icons.dark_mode,
              value: ThemeModeOption.dark),
        ],
        value: settings.themeMode,
        onChanged: (v) => ref.read(settingsProvider.notifier).setThemeMode(v),
      ),
    );
  }
}

/// Hijri offset as a signed stepper row (−5…+5 days, unit روز).
/// Replaces the old slider + quick buttons: same range, same write, and the
/// value can never render bidi-reversed (formatSigned + LTR isolate).
class _HijriOffsetRow extends ConsumerWidget {
  const _HijriOffsetRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final offset = ref.watch(hijriOffsetProvider);
    return settingsRow(
      SettingRow(
        icon: Icons.calendar_month_outlined,
        color: t.accent,
        title: 'تاریخ هجری',
        subtitle: 'تطبیق با رویت هلال',
        showChevron: false,
        trailing: SettingsStepper(
          value: offset,
          min: -5,
          max: 5,
          signed: true,
          unit: 'روز',
          semanticLabel: 'تنظیم تاریخ هجری',
          onChanged: (v) =>
              ref.read(settingsProvider.notifier).setHijriOffset(v),
        ),
      ),
    );
  }
}

/// Horizontal theme chips (Design 1 §c): 84dp cards with two overlapping
/// color dots, name + one-word subtitle, gold check badge when selected.
/// The selected chip scrolls into view.
class _ThemeKindChips extends ConsumerStatefulWidget {
  final AppSettings settings;
  const _ThemeKindChips({required this.settings});

  static const _options = <(String value, String label, String subtitle)>[
    ('live', 'زنده', 'بر اساس وقت شرعی'),
    ('gold', 'طلایی', 'نماد برنامه'),
    ('dawn', 'سحر', 'بنفش'),
    ('day', 'روز', 'زمردی'),
    ('sunset', 'غروب', 'کهربایی'),
    ('night', 'شب', 'آبی'),
  ];

  @override
  ConsumerState<_ThemeKindChips> createState() => _ThemeKindChipsState();
}

class _ThemeKindChipsState extends ConsumerState<_ThemeKindChips> {
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _reveal(selectedValue()));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String selectedValue() => _ThemeKindChips._options
      .firstWhere(
        (o) =>
            themeKindFromStored(o.$1) ==
            themeKindFromStored(widget.settings.accentPreset),
        orElse: () => _ThemeKindChips._options[1],
      )
      .$1;

  void _reveal(String value) {
    final ctx = _keys[value]?.currentContext;
    if (ctx == null || !mounted) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = selectedValue();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.palette_outlined,
                size: 16, color: TimeThemeKit.of(context).palette.accent),
            const SizedBox(width: 8),
            Text('تم برنامه',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: TimeThemeKit.of(context).palette.textPrimary)),
          ]),
          const SizedBox(height: 10),
          SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in _ThemeKindChips._options) ...[
                  _chip(context, option, option.$1 == current),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    (String value, String label, String subtitle) option,
    bool selected,
  ) {
    final (value, label, subtitle) = option;
    final (swatchA, swatchB) =
        AppPalettes.previewSwatches(themeKindFromStored(value));
    final key = _keys.putIfAbsent(value, GlobalKey.new);
    // Selection chrome follows the CURRENT theme's accent — the old fixed
    // gold tint/border/badge painted a gold frame on a blue/teal page.
    final selAccent = TimeThemeKit.of(context).palette.accent;
    return Semantics(
      button: true,
      selected: selected,
      label: 'تم $label، $subtitle',
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(settingsProvider.notifier).setThemeKind(value);
          WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(value));
        },
        child: Stack(
          children: [
            Container(
              width: 84,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? selAccent.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? selAccent
                      : TimeThemeKit.of(context).palette.outline,
                  width: selected ? 1.5 : 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 42,
                    height: 26,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: swatchA,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: swatchB,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w500,
                      color: TimeThemeKit.of(context).palette.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 9.5),
                      color: TimeThemeKit.of(context).palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              PositionedDirectional(
                top: 4,
                end: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selAccent,
                  ),
                  child: Icon(Icons.check_rounded,
                      size: 10, color: dsContentColor(context, selAccent)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// «روش عرضه ماه» — Afghan users read the solar year under its Afghan month
/// names (حمل، ثور، …). Names only: the Shamsi arithmetic is identical, so the
/// choice reaches every calendar, report, share card and the native widget
/// through [DateConstants.persianMonths].
///
/// A block for the inside of the «فونت و نمایش» card, so it wears the same row
/// language as the font/switch tiles around it (14 dp sides, 18 dp icon tile,
/// 14/w600 title, 12 muted subtitle) instead of standing in its own card.
class _MonthDisplayRow extends StatelessWidget {
  const _MonthDisplayRow({super.key});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return ValueListenableBuilder<MonthDisplay>(
      valueListenable: monthDisplayNotifier,
      builder: (context, value, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconTile(
                  icon: Icons.calendar_view_month_outlined,
                  color: t.primary,
                  iconSize: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'روش عرضه ماه',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 2),
            Text(
              'نام ماه‌های شمسی: ایرانی یا افغانی',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            SettingsSegmented<MonthDisplay>(
              options: const [
                SettingsSegment(label: 'ایرانی', value: MonthDisplay.iranian),
                SettingsSegment(label: 'افغانی', value: MonthDisplay.afghan),
              ],
              value: value,
              onChanged: setMonthDisplay,
            ),
            const SizedBox(height: 10),
            Text(
              DateConstants.monthsFor(value).join('، '),
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                height: 1.6,
                color: t.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FONT & DISPLAY PAGE
// ═══════════════════════════════════════════════════════════════

/// Registry-driven search results, grouped by page. Replaces the old
/// 16-entry `_SettingsSearchDelegate` (deleted): full normalization,
/// AND-semantics, ranking, and every row in the inventory.
class _SettingsSearchResults extends StatelessWidget {
  const _SettingsSearchResults({required this.query, required this.onPick});

  final String query;
  final void Function(SettingsSearchEntry entry) onPick;

  /// Exhaustive switches, not maps: the compiler then guarantees every
  /// [SettingsSearchPage] has a header and an icon, so a new page can never
  /// show up in search results without them.
  static String _pageTitle(SettingsSearchPage page) => switch (page) {
        SettingsSearchPage.main => 'تنظیمات',
        SettingsSearchPage.prayer => 'نماز و اذان',
        SettingsSearchPage.notifications => 'اعلان‌ها و اذکار',
        SettingsSearchPage.widgets => 'ویجت‌ها',
        SettingsSearchPage.account => 'حساب و پشتیبان',
        SettingsSearchPage.font => 'فونت و نمایش',
        SettingsSearchPage.about => 'درباره برنامه',
      };

  static IconData _pageIcon(SettingsSearchPage page) => switch (page) {
        SettingsSearchPage.main => Icons.tune_outlined,
        SettingsSearchPage.prayer => Icons.mosque_outlined,
        SettingsSearchPage.notifications => Icons.notifications_outlined,
        SettingsSearchPage.widgets => Icons.widgets_outlined,
        SettingsSearchPage.account => Icons.account_circle_outlined,
        SettingsSearchPage.font => Icons.font_download_outlined,
        SettingsSearchPage.about => Icons.info_outline,
      };

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final results = searchSettings(query);
    if (results.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: t.textMuted),
            const SizedBox(height: 8),
            Text(
              'نتیجه‌ای یافت نشد',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'عبارت دیگری را امتحان کنید',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: t.textMuted,
              ),
            ),
          ],
        ),
      );
    }
    final pages = <SettingsSearchPage>[];
    for (final entry in results) {
      if (!pages.contains(entry.page)) pages.add(entry.page);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final page in pages) ...[
          SectionHeader(
            title: _pageTitle(page),
            // The group header carries the colour of the section the results
            // live in, so a hit is placed before it is read.
            accent: SettingsSectionHues.on(
                context, SettingsSectionHues.forPage(page)),
            margin: const EdgeInsets.only(bottom: 8, right: 4),
          ),
          settingsCard([
            for (final entry in results.where((e) => e.page == page))
              settingsRow(
                SettingRow(
                  icon: _pageIcon(page),
                  color: t.primary,
                  title: entry.title,
                  subtitle: entry.subtitle,
                  onTap: () => onPick(entry),
                ),
              ),
          ]),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// Anchors for in-page settings search results (a tap scrolls to the section).
final _settingsAnchors = <String, GlobalKey>{
  'appearance': GlobalKey(),
  'hijri': GlobalKey(),
  'sounds': GlobalKey(),
  'scoring': GlobalKey(),
  'currency': GlobalKey(),
};

/// Font + display settings page. Public (not private) so it is reachable
/// through the router (`/settings/font`) like every other settings page.
class FontDisplayPage extends ConsumerStatefulWidget {
  const FontDisplayPage({super.key});

  /// The row keys this page anchors, so the search registry can be checked
  /// against it (see `settings_registry_test.dart`) the same way the account
  /// hub's `AccountScreen.accountHighlightKeys` is.
  static const List<String> fontHighlightKeys = [
    'family',
    'size',
    'toggles',
    'monthDisplay',
  ];

  @override
  ConsumerState<FontDisplayPage> createState() => _FontDisplayPageState();
}

class _FontDisplayPageState extends ConsumerState<FontDisplayPage>
    with SettingsHighlight<FontDisplayPage> {
  late final Map<String, GlobalKey> _anchors = {
    for (final key in FontDisplayPage.fontHighlightKeys) key: GlobalKey(),
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
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SettingsAppBar(title: 'فونت و نمایش'),
        body: Center(
            child: Padding(
          padding: EdgeInsets.all(48),
          child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5)),
        )),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SettingsAppBar(title: 'فونت و نمایش'),
      body: ListView(
        // The route-driven highlight (see SettingsHighlight) walks the lazy
        // list down to the anchored row.
        controller: highlightScrollController,
        padding:
            const EdgeInsets.fromLTRB(DsSpacing.page, 4, DsSpacing.page, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              SettingsFlashSection(
                rowKey: 'family',
                flashKey: highlightFlashKey,
                child: SelectTile<FontFamilyOption>(
                  key: _anchors['family'],
                  title: 'فونت برنامه',
                  subtitle: switch (settings.fontFamily) {
                    FontFamilyOption.vazirmatn => 'Vazirmatn',
                    FontFamilyOption.amiri => 'Amiri',
                    FontFamilyOption.calibri => 'Calibri (Bold)',
                    FontFamilyOption.tktTika => 'TKT-Tika (تیکا)',
                    FontFamilyOption.harir => 'Harir (حریر)',
                    FontFamilyOption.parastoo => 'Parastoo (پرستو)',
                    FontFamilyOption.sakkalMajalla =>
                      'Sakkal Majalla (سکّال مجله)',
                    FontFamilyOption.sultanMedium =>
                      'Sultan Medium (سلطان میدیوم)',
                    FontFamilyOption.tabliq => 'Tabliq (تبلیغ)',
                  },
                  icon: Icons.font_download_outlined,
                  options: const [
                    FontFamilyOption.vazirmatn,
                    FontFamilyOption.amiri,
                    FontFamilyOption.calibri,
                    FontFamilyOption.tktTika,
                    FontFamilyOption.harir,
                    FontFamilyOption.parastoo,
                    FontFamilyOption.sakkalMajalla,
                    FontFamilyOption.sultanMedium,
                    FontFamilyOption.tabliq,
                  ],
                  labelBuilder: (v) => switch (v) {
                    FontFamilyOption.vazirmatn => 'Vazirmatn',
                    FontFamilyOption.amiri => 'Amiri',
                    FontFamilyOption.calibri => 'Calibri (Bold)',
                    FontFamilyOption.tktTika => 'TKT-Tika (تیکا)',
                    FontFamilyOption.harir => 'Harir (حریر)',
                    FontFamilyOption.parastoo => 'Parastoo (پرستو)',
                    FontFamilyOption.sakkalMajalla =>
                      'Sakkal Majalla (سکّال مجله)',
                    FontFamilyOption.sultanMedium =>
                      'Sultan Medium (سلطان میدیوم)',
                    FontFamilyOption.tabliq => 'Tabliq (تبلیغ)',
                  },
                  selected: settings.fontFamily,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setFontFamily(v),
                ),
              ),
              const SettingsDivider(),
              SettingsFlashSection(
                rowKey: 'size',
                flashKey: highlightFlashKey,
                child: settingsRow(
                  Padding(
                    key: _anchors['size'],
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: SettingsSliderRow(
                      icon: Icons.format_size_outlined,
                      accent: TimeThemeKit.of(context).palette.primary,
                      title: 'اندازه فونت',
                      // A stored size outside this window (older release, hand
                      // migrated row) would assert and kill the whole page.
                      value: settings.appFontSize.clamp(13.0, 26.0),
                      min: 13,
                      max: 26,
                      divisions: 13,
                      valueText: settings.appFontSize
                          .clamp(13.0, 26.0)
                          .toStringAsFixed(0),
                      onChanged: (v) =>
                          ref.read(settingsProvider.notifier).setFontScale(v),
                    ),
                  ),
                ),
              ),
              const SettingsDivider(),
              SettingsFlashSection(
                rowKey: 'toggles',
                flashKey: highlightFlashKey,
                child: SwitchTile(
                    key: _anchors['toggles'],
                    title: 'ساعت 12 ساعته',
                    subtitle: 'نمایش ساعت‌ها با قالب صبح/عصر',
                    icon: Icons.schedule_outlined,
                    value: settings.use12Hour,
                    onChanged: (v) =>
                        ref.read(settingsProvider.notifier).setUse12Hour(v)),
              ),
              const SettingsDivider(),
              SettingsFlashSection(
                rowKey: 'monthDisplay',
                flashKey: highlightFlashKey,
                child: _MonthDisplayRow(key: _anchors['monthDisplay']),
              ),
              const SettingsDivider(),
              SwitchTile(
                  title: 'نمایش متن عربی',
                  subtitle: 'در اذکار و دعاها',
                  icon: Icons.text_fields,
                  value: settings.showArabicText,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setShowArabicText(v)),
              const SettingsDivider(),
              SwitchTile(
                  title: 'نمایش دلیل (منبع روایت)',
                  subtitle: 'منبع هر ذکر و دعا',
                  icon: Icons.info_outline,
                  value: settings.showDaleel,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setShowDaleel(v)),
              const SettingsDivider(),
              SwitchTile(
                  title: 'فونت بزرگ‌تر عربی',
                  subtitle: 'در اذکار',
                  icon: Icons.format_size,
                  value: settings.largeArabicFont,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .setLargeArabicFont(v)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SOUNDS (صداهای برنامه) — per-sound in-app volume sliders
// ═══════════════════════════════════════════════════════════════

/// Volume controls for the in-app sounds, grouped by what each sound is FOR —
/// تعاملی، هشدارها، اذان — instead of three bare sliders in a row (user
/// request, 2026-11-09: «ارتقا بده و مرتبش کن»).
///
/// Two things were confusing rather than merely untidy, and both are fixed
/// here: the tasbih slider stayed live while `azkar_sound` was off, so a level
/// could be dragged for a sound that never played (the switch that owns that
/// flag now sits in the same card and the slider dims with it); and a level
/// could only be judged from memory (each group can now be heard — the real
/// click at the chosen level, the reminder tone at the alert level).
///
/// The adhan level is the same `azanVolume` the native alarm and the in-app
/// player read, so one slider governs both, and the card links to the page
/// that owns the voice itself (صوت اذان، اقامه، بی‌صدا).
class _SoundSettingsSection extends ConsumerStatefulWidget {
  const _SoundSettingsSection();

  @override
  ConsumerState<_SoundSettingsSection> createState() =>
      _SoundSettingsSectionState();
}

class _SoundSettingsSectionState extends ConsumerState<_SoundSettingsSection> {
  /// The adhan drag echoes locally so the thumb and the % chip follow the
  /// finger while the Drift write (+ the native reschedule it arms) fires
  /// once per drag through a trailing [DebouncedWriter] — not one
  /// read-modify-write per tick on weak phones.
  static const Duration _azanWriteDebounce = Duration(milliseconds: 350);
  double? _azanDrag;
  final DebouncedWriter _azanWriter =
      DebouncedWriter(delay: _azanWriteDebounce);

  /// The tasbih click, built on the first preview only: a reader who never asks
  /// to hear it pays for no AudioPool.
  ClickSoundPlayer? _tick;

  static const String _alertPreviewKey = SoundRegistry.reminderKey;

  @override
  void dispose() {
    unawaited(_azanWriter.flush());
    _azanWriter.dispose();
    final tick = _tick;
    _tick = null;
    if (tick != null) unawaited(tick.dispose());
    super.dispose();
  }

  void _playTick(double volume) {
    if (volume <= 0) return;
    final player = _tick ??= ClickSoundPlayer(SoundRegistry.tick.asset);
    unawaited(player.play(volume));
  }

  /// The reminder/pomodoro tone at the level the app will actually use.
  Future<void> _toggleAlertPreview      () => SoundPreviewService.instance.toggle(
        key: _alertPreviewKey,
        asset: SoundRegistry.reminder.asset,
      );

  /// «۰٪» reads as nothing happened; zero is a decision, so it says so.
  String _level(double value) {
    final pct = (value * 100).round();
    return pct == 0 ? 'بی‌صدا' : NumberFormat.ltrIsolated('$pct٪');
  }

  @override
  Widget build(BuildContext context) {
    final azkar = ref.watch(azkarSettingsProvider);
    final alertVolume = ref.watch(alertVolumeProvider);
    final azanVolume = ref.watch(azanVolumeProvider);
    final azanShown = _azanDrag ?? azanVolume;
    final soundOn = azkar.soundEnabled;
    final accent = TimeThemeKit.of(context).palette.accent;
    return Column(
      children: [
        _SoundGroup(
          icon: Icons.touch_app_outlined,
          accent: SectionHues.tasbih,
          title: 'تعاملی',
          description: 'کلیک شمردن تسبیح و شمارنده‌ها',
          children: [
            SwitchTile(
              icon: Icons.hearing_outlined,
              color: SectionHues.tasbih,
              title: 'کلیک تسبیح',
              subtitle: soundOn ? 'روشن' : 'خاموش',
              value: soundOn,
              onChanged: (v) =>
                  ref.read(azkarSettingsProvider.notifier).setSound(v),
            ),
            SettingsSliderRow(
              icon: Icons.graphic_eq_rounded,
              accent: SectionHues.tasbih,
              title: 'بلندی کلیک',
              valueText: _level(azkar.tasbihVolume),
              value: azkar.tasbihVolume,
              divisions: 20,
              onChanged: soundOn
                  ? (v) => ref
                      .read(azkarSettingsProvider.notifier)
                      .setTasbihVolume(v)
                  : null,
              onSettled: soundOn ? _playTick : null,
            ),
            settingsRow(
              SettingRow(
                icon: Icons.play_circle_outline_rounded,
                color: SectionHues.tasbih,
                title: 'شنیدن نمونه',
                subtitle: soundOn ? 'با همان بلندی' : 'صدا خاموش است',
                showChevron: false,
                onTap: soundOn ? () => _playTick(azkar.tasbihVolume) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SoundGroup(
          icon: Icons.notifications_active_outlined,
          accent: accent,
          title: 'هشدارها',
          description: 'پیش‌نمایش یادآورها و پایان پومودورو',
          children: [
            SettingsSliderRow(
              icon: Icons.volume_up_outlined,
              accent: accent,
              title: 'صدای هشدار',
              valueText: _level(alertVolume),
              value: alertVolume,
              divisions: 20,
              onChanged: (v) => ref.read(alertVolumeProvider.notifier).set(v),
            ),
            ListenableBuilder(
              listenable: SoundPreviewService.instance,
              builder: (context, _) {
                final playing =
                    SoundPreviewService.instance.isPlaying(_alertPreviewKey);
                return settingsRow(
                  SettingRow(
                    icon: playing
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline_rounded,
                    title: playing ? 'توقف نمونه' : 'شنیدن نمونه',
                    subtitle: 'همان تُنی که برای هشدارها پخش می‌شود',
                    showChevron: false,
                    onTap: _toggleAlertPreview,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SoundGroup(
          icon: Icons.campaign_outlined,
          accent: TopicHues.prayer,
          title: 'اذان',
          description: 'همان بلندی‌ای که هشدار بومی اذان هم می‌خواند',
          children: [
            SettingsSliderRow(
              icon: Icons.volume_up_outlined,
              accent: TopicHues.prayer,
              title: 'صدای اذان',
              valueText: _level(azanShown),
              value: azanShown,
              divisions: 20,
              onChanged: (v) {
                setState(() => _azanDrag = v);
                final notifier = ref.read(settingsProvider.notifier);
                _azanWriter.schedule(() => notifier.setAzanVolume(v));
              },
              onSettled: (_) async {
                await _azanWriter.flush();
                if (mounted) setState(() => _azanDrag = null);
              },
            ),
            settingsRow(
              SettingRow(
                icon: Icons.tune_rounded,
                color: TopicHues.prayer,
                title: 'صوت اذان و اقامه',
                subtitle: 'انتخاب صوت، پخش برای هر نماز و بی‌صدا کردن',
                onTap: () => context.push(RouteNames.prayerSettings),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One card of the sounds section: a titled header (icon + what this group is
/// for) above its own controls, so three sliders read as three answers rather
/// than one undifferentiated list.
class _SoundGroup extends StatelessWidget {
  const _SoundGroup({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
    required this.children,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: icon, color: accent, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CURRENCY (واحد پول)
// ═══════════════════════════════════════════════════════════════

/// یک ردیف «واحد پول» برای همهٔ بخش‌های مالی.
///
/// انبار یکی است ([CurrencyStore.shared]): زکات، زکات فطر، میراث، کفاره،
/// قلک، بدهی و مالی، دفتر هزینه‌ها و حساب مغازه همه با همین واحد نوشته و
/// خوانده می‌شوند. عوض کردن واحد عددهای **ثبت‌شده** را تبدیل نمی‌کند، فقط
/// واحدشان را عوض می‌کند — همین در توضیح دیالوگ گفته می‌شود.
class _CurrencySection extends StatefulWidget {
  const _CurrencySection();

  @override
  State<_CurrencySection> createState() => _CurrencySectionState();
}

class _CurrencySectionState extends State<_CurrencySection> {
  @override
  void initState() {
    super.initState();
    // تنظیمات می‌تواند اولین صفحه‌ای باشد که باز می‌شود، پس هیچ‌کدام از دو
    // انبار لزوماً خوانده نشده است؛ بدون این دو خط ردیف‌ها «تومان» پیش‌فرض را
    // نشان می‌دهند حتی وقتی کاربر واحد دیگری انتخاب کرده است.
    unawaited(CurrencyStore.calculators.load());
    unawaited(CurrencyStore.ledger.load());
  }

  Future<void> _pickCalculators(AppCurrency current) async {
    final picked = await _showCurrencyDialog(
      current: current,
      title: 'واحد بخش‌های مالی',
      accent: TopicHues.zakat,
      hint: 'زکات، زکات فطر، میراث، کفاره، قلک، بدهی و مالی و حساب مغازه با '
          'همین واحد نوشته و خوانده می‌شوند. عددهایی که ثبت شده‌اند تبدیل '
          'نمی‌شوند؛ فقط واحدشان عوض می‌شود. قیمت طلا و نقره هم برای هر واحد '
          'جداگانه ذخیره می‌شود.',
    );
    if (picked == null || picked == current) return;
    await CurrencyStore.calculators.save(picked);
  }

  Future<void> _pickLedger(AppCurrency current) async {
    final picked = await _showCurrencyDialog(
      current: current,
      title: 'واحد دفتر هزینه‌ها',
      accent: TopicHues.expenses,
      warn: true,
      hint: 'مبالغ ثبت‌شده تبدیل نمی‌شوند؛ فقط واحدشان عوض می‌شود. اگر '
          'عددها را از همان ابتدا به این واحد وارد کرده‌اید ادامه بدهید، '
          'وگرنه «انصراف» بزنید.',
    );
    if (picked == null || picked == current) return;
    await CurrencyStore.ledger.save(picked);
  }

  Future<AppCurrency?> _showCurrencyDialog({
    required AppCurrency current,
    required String title,
    required String hint,
    required Color accent,
    bool warn = false,
  }) {
    var selected = current;
    final muted = TimeThemeKit.of(context).palette.textMuted;
    return showDialog<AppCurrency>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CurrencySelector(
                  value: selected,
                  onChanged: (c) => setLocal(() => selected = c),
                  accent: accent,
                ),
                const SizedBox(height: 12),
                Text(
                  hint,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(ctx, 12),
                    height: 1.6,
                    color: warn
                        ? (Theme.of(ctx).brightness == Brightness.dark
                            ? AppTheme.darkWarning
                            : AppTheme.lightWarning)
                        : muted,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(selected),
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppCurrency>(
      valueListenable: CurrencyStore.calculators.notifier,
      builder: (context, calculators, _) => ValueListenableBuilder<AppCurrency>(
        valueListenable: CurrencyStore.ledger.notifier,
        builder: (context, ledger, __) => settingsCard([
          settingsRow(
            SettingRow(
              icon: Icons.payments_outlined,
              color: TopicHues.zakat,
              title: 'واحد حساب‌گرها',
              subtitle: 'زکات، فطر، میراث، کفاره، قلک، بدهی و مغازه — '
                  '${calculators.label}',
              onTap: () => _pickCalculators(calculators),
            ),
          ),
          settingsRow(
            SettingRow(
              icon: Icons.receipt_long_outlined,
              color: TopicHues.expenses,
              title: 'واحد دفتر هزینه‌ها',
              subtitle: 'برچسب مبالغ ثبت‌شده — ${ledger.label}',
              onTap: () => _pickLedger(ledger),
            ),
          ),
        ]),
      ),
    );
  }
}
