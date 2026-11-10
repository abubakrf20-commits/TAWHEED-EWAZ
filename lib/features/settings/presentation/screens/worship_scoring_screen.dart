import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_provider.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_section_hues.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «امتیازدهی عبادات» — the point values «ارزیابی و گزارش» counts.
///
/// This lived as six stepper rows inline on the settings page and read as a
/// wall of numbers between «صداهای برنامه» and «اعلان‌ها» (user report,
/// 2026-11-09: «خیلی شلوغ کرده، در یک تب قرار بده»). The rows moved here,
/// behind three tabs, so the settings page keeps one door and each tab shows
/// only its own handful. Nothing about the values changed: the labels, hints,
/// ranges and semantics are the ones the settings search and the tests
/// address, and every write still goes through `settingsProvider.patch`.
class WorshipScoringScreen extends ConsumerStatefulWidget {
  const WorshipScoringScreen({super.key, this.initialTab = 0});

  /// Tab labels, in display order; the settings search deep-links into them
  /// through `RouteNames.worshipScoringPrayer/Adhkar/Taaat`.
  static const List<String> tabLabels = ['نماز', 'اذکار', 'طاعات'];

  /// 0 نماز · 1 اذکار · 2 طاعات. Out-of-range values fall back to tab 0, so a
  /// stale link can never land on a blank page.
  final int initialTab;

  @override
  ConsumerState<WorshipScoringScreen> createState() =>
      _WorshipScoringScreenState();
}

class _WorshipScoringScreenState extends ConsumerState<WorshipScoringScreen> {
  static const int _minPoints = 1;
  static const int _maxPoints = 50;

  /// «ارزیابی و گزارش» is the page these numbers feed, so by default the
  /// screen starts on the tab that carries the five daily prayers.
  late int _tab =
      widget.initialTab >= 0 && widget.initialTab < 3 ? widget.initialTab : 0;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    final hue = SettingsSectionHues.on(context, SettingsSectionHues.scoring);

    return Scaffold(
      appBar: const SectionAppBar(title: 'امتیازدهی عبادات'),
      body: settings == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  DsSpacing.page, 12, DsSpacing.page, 32),
              children: [
                SectionHeader(
                  title: 'امتیاز هر عبادت',
                  accent: hue,
                  description: 'همین عددها در «ارزیابی و گزارش» شمرده می‌شوند؛ '
                      'هر عدد را با کم و زیاد کردن تغییر دهید.',
                  margin: const EdgeInsets.only(bottom: 10, right: 4),
                ),
                SegmentedTabs(
                  tabs: const [
                    SegmentedTab(label: 'نماز'),
                    SegmentedTab(label: 'اذکار'),
                    SegmentedTab(label: 'طاعات'),
                  ],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: 12),
                _tabBody(settings),
                const SizedBox(height: 14),
                _Explainer(hue: hue, tab: _tab),
                const SizedBox(height: 10),
                settingsRow(
                  SettingRow(
                    icon: Icons.insights_outlined,
                    color: hue,
                    title: 'دیدن گزارش با این امتیازها',
                    subtitle:
                        'همین عددها در ارزیابی روز، هفته و ماه شمرده می‌شوند',
                    onTap: () => _openReport(context),
                  ),
                ),
              ],
            ),
    );
  }

  /// The index of «ارزیابی و گزارش» in the shell's bottom bar.
  ///
  /// It is a shell tab, not a route (`route_names.dart` explains why pushing a
  /// path for it 404s), so this door closes the settings stack and selects the
  /// tab instead of navigating to a path that does not exist.
  static const int _evaluationTab = 4;

  void _openReport(BuildContext context) {
    ref.read(shellTabIndexProvider.notifier).setIndex(_evaluationTab);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _tabBody(AppSettings settings) {
    final notifier = ref.read(settingsProvider.notifier);
    switch (_tab) {
      case 1:
        return settingsCard([
          _pointRow(
            context,
            Icons.wb_twilight_outlined,
            'اذکار صبح و شام',
            'هر دور اذکار صبح یا شام تکمیل‌شده',
            child: SettingsStepper(
              value: settings.adhkarPoint,
              min: _minPoints,
              max: _maxPoints,
              semanticLabel: 'اذکار صبح و شام',
              onChanged: (v) =>
                  notifier.patch((s) => s.copyWith(adhkarPoint: v)),
            ),
          ),
          _pointRow(
            context,
            Icons.water_drop_outlined,
            'تسبیح',
            'انجام تسبیح (هر روز)',
            child: SettingsStepper(
              value: settings.tasbihPoint,
              min: _minPoints,
              max: _maxPoints,
              semanticLabel: 'تسبیح',
              onChanged: (v) =>
                  notifier.patch((s) => s.copyWith(tasbihPoint: v)),
            ),
          ),
        ]);
      case 2:
        final multiplier = (settings.worshipMultiplier * 100).round();
        return settingsCard([
          _pointRow(
            context,
            Icons.favorite_outline,
            'طاعات (قرآن، صدقه و…)',
            'ضریب امتیاز چک‌لیست طاعات',
            child: SettingsStepper(
              value: multiplier,
              min: 25,
              max: 300,
              step: 25,
              valueLabel: NumberFormat.ltrIsolated('$multiplier٪'),
              semanticLabel: 'ضریب امتیاز طاعات',
              onChanged: (v) =>
                  notifier.patch((s) => s.copyWith(worshipMultiplier: v / 100)),
            ),
          ),
        ]);
      default:
        return settingsCard([
          _pointRow(
            context,
            Icons.check_circle_outline,
            'هر نماز واجب (فرض)',
            'فرض یا قضای انجام‌شده',
            child: SettingsStepper(
              value: settings.fardhPoint,
              min: _minPoints,
              max: _maxPoints,
              semanticLabel: 'هر نماز واجب',
              onChanged: (v) =>
                  notifier.patch((s) => s.copyWith(fardhPoint: v)),
            ),
          ),
          _pointRow(
            context,
            Icons.star_outline,
            'هر سنت و وتر',
            'رواتب و وتر انجام‌شده',
            child: SettingsStepper(
              value: settings.sunnahPoint,
              min: _minPoints,
              max: _maxPoints,
              semanticLabel: 'هر سنت و وتر',
              onChanged: (v) =>
                  notifier.patch((s) => s.copyWith(sunnahPoint: v)),
            ),
          ),
          _pointRow(
            context,
            Icons.wb_sunny_outlined,
            'نماز ضحی',
            'نماز چاشت انجام‌شده',
            child: SettingsStepper(
              value: settings.duhaPoint,
              min: _minPoints,
              max: _maxPoints,
              semanticLabel: 'نماز ضحی',
              onChanged: (v) => notifier.patch((s) => s.copyWith(duhaPoint: v)),
            ),
          ),
        ]);
    }
  }

  Widget _pointRow(
    BuildContext context,
    IconData icon,
    String label,
    String hint, {
    required Widget child,
  }) {
    final t = TimeThemeKit.of(context).palette;
    return settingsRow(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            IconTile(icon: icon, color: t.accent, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary)),
                  const SizedBox(height: 2),
                  Text(hint,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          color: t.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// One short paragraph per tab: what the number on screen actually buys, so a
/// point value is never a bare integer the reader has to reverse-engineer.
class _Explainer extends StatelessWidget {
  const _Explainer({required this.hue, required this.tab});

  final Color hue;
  final int tab;

  @override
  Widget build(BuildContext context) {
    final text = switch (tab) {
      1 => 'اذکار هر روز یک‌بار شمرده می‌شوند: با تکمیل دور صبح یا شام، '
          'امتیاز اذکار، و با انجام تسبیح، امتیاز تسبیح به گزارش روز اضافه می‌شود.',
      2 => 'ضریب طاعات فقط امتیاز چک‌لیست طاعات (قرآن، صدقه، دعا و…) را '
          'کم یا زیاد می‌کند؛ نماز و اذکار ضریب جدا دارند.',
      _ => 'هر نماز واجب، هر سنت و وتر و نماز ضحی که در همان روز ثبت شود '
          'به همین عدد شمرده می‌شود؛ قضا هم در ردیف فرض حساب می‌شود.',
    };
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hue.withValues(alpha: 0.22), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 17, color: hue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11.5),
                height: 1.7,
                color: t.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
