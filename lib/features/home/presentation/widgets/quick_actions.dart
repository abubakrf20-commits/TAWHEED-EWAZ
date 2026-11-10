import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/presentation/more/more_duotone.dart';
import 'package:tawheeed/features/settings/presentation/more/more_registry.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';

/// Quick access shortcuts, back at the bottom of Home. The user picks the
/// tiles (persisted via [quickActionsProvider]); a long press removes one,
/// the «+» tile opens the picker.
///
/// Home shortcuts reuse the SAME fixed topic colors as the «بیشتر» tiles so a
/// section keeps one color everywhere (home, More, opened screen) and never
/// changes with the theme preset. Tab shortcuts are pinned to their fixed
/// default accents for the same reason. Each tile is the More page's Style-2
/// squircle replicated verbatim ([MoreDuotone] at [moreTileSize] of the
/// cell) — these are abbreviations of those tiles and must read as one.
/// Edge of one quick-access squircle inside a four-column [cellWidth] cell.
///
/// The More page keeps [moreTileSize] (0.8 · (cell − 10), capped at 72) because
/// its tiles are the page's content. On Home that same ratio left ~33 dp of air
/// between two neighbouring tiles on a 412 dp phone — the user (2026-11-07) read
/// that as «فاصلهٔ بین آیکون‌ها خیلی زیاد», so a shortcut now fills 92 % of its
/// cell and the only gap left is the 8 dp gutter. Shape, radius, duotone
/// recipe and glyph scale are unchanged; only the edge grows.
@visibleForTesting
double quickTileSize(double cellWidth) {
  final raw = 0.92 * cellWidth;
  return raw < 52 ? 52 : (raw > 88 ? 88 : raw);
}

class QuickActions extends ConsumerWidget {
  const QuickActions({super.key});

  /// Quick-action id → More registry id. Route tiles take icon, title,
  /// accent, glyph scale AND destination from [kMoreItems], so a section
  /// keeps one definition everywhere (home, More, opened screen). Tab
  /// shortcuts have no registry counterpart and stay local by design.
  /// Quick ids are also the persisted shape ([quickActionsProvider]) — they
  /// never change, even when they differ from the registry ids.
  @visibleForTesting
  static const Map<String, String> quickToMoreIds = {
    'qibla': 'qibla',
    'purification': 'purification',
    'prayer': 'prayer',
    'zakat': 'zakat',
    'hajj_umrah': 'hajj-umrah',
    'fasting': 'fasting',
    'khatm': 'khatm',
    'inheritance': 'inheritance',
    'hadith_books': 'hadith-books',
    'duas': 'duas',
    'ketabkhaneh': 'ketabkhaneh',
    'sciences': 'sciences',
    'study': 'study',
    'tasks': 'tasks',
    'expenses': 'expenses',
    'notes': 'worship-notes',
    'reminders': 'reminders',
    'period': 'period',
    'calculator': 'calculator',
    'pomodoro': 'pomodoro',
    'dangi': 'dangi',
  };

  static _ActionDef _routeTile(String moreId) {
    final item = kMoreItems.firstWhere((m) => m.id == moreId);
    return _ActionDef(
      item.icon,
      item.title,
      item.accent,
      _NavAction(item.destination),
      item.iconScale,
    );
  }

  static final Map<String, _ActionDef> _allActions = {
    // Route tiles resolve icon/title/accent/scale/route from the registry
    // through [quickToMoreIds] — the map above is the only mapping, so a
    // section can never exist in one and drift in the other.
    for (final entry in quickToMoreIds.entries)
      entry.key: _routeTile(entry.value),
    // ═══ تب‌ها (رنگ ثابت پیش‌فرض — بدون اثر از پریست تم) ═══
    'tasbih':
        _ActionDef(Icons.repeat, 'تسبیح', _kTabAzkarColor, _TabAction(2, 0)),
    'azkar': _ActionDef(
        Icons.wb_sunny_outlined, 'اذکار', _kTabAzkarColor, _TabAction(2, 1)),
    'quran':
        _ActionDef(Icons.auto_stories, 'قرآن', _kTabQuranColor, _TabAction(1)),
    'calendar': _ActionDef(
        Icons.calendar_month, 'تقویم', _kTabCalendarColor, _TabAction(3)),
    'evaluation': _ActionDef(Icons.assignment_outlined, 'ارزیابی',
        _kTabEvaluationColor, _TabAction(4)),
    'settings': _ActionDef(
        Icons.settings_outlined, 'تنظیمات', Colors.blueGrey, _TabAction(5)),
  };

  // Fixed default accents for the main tabs (matching AppTheme defaults) so
  // the shortcuts never repaint when the user switches accent presets.
  static const Color _kTabAzkarColor = Color(0xFF6D5A4A);
  static const Color _kTabQuranColor = Color(0xFFB8860B);
  static const Color _kTabCalendarColor = Color(0xFFE07B39);
  static const Color _kTabEvaluationColor = Color(0xFF8C7F72);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickActions = ref.watch(quickActionsProvider);
    final items = quickActions
        .map((id) => _allActions[id])
        .whereType<_ActionDef>()
        .toList();
    // Show a single "add" tile as an entry point when the grid is not full
    // (up to EIGHT saved tiles per the user's request); a long row of empty
    // add tiles would be confusing and wasted space.
    final t = TimeThemeKit.of(context).palette;
    if (items.length < 8) {
      items.add(_ActionDef(Icons.add, '', t.textMuted, _AddAction()));
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'دسترسی سریع'),
          const SizedBox(height: 6),
          // Wrap, not a fixed-aspect grid: each cell takes its intrinsic
          // height, so labels can never overflow at 320dp × large text.
          LayoutBuilder(
            builder: (context, constraints) {
              final cell = (constraints.maxWidth - 3 * 8) / 4;
              return Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < items.length; i++)
                    SizedBox(
                      width: cell,
                      child: _cell(context, ref, quickActions, items[i]),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// One shortcut cell — a long press removes a saved tile (never the «+»).
  Widget _cell(BuildContext context, WidgetRef ref, List<String> quickActions,
      _ActionDef def) {
    final existingIndex =
        quickActions.indexOf(QuickActions._allActions.keys.firstWhere(
      (k) => QuickActions._allActions[k]?.label == def.label,
      orElse: () => '',
    ));
    final isExisting = existingIndex >= 0;

    final tile = def.action.build(context, ref, def);
    if (!isExisting) return tile;

    void confirmDelete() => showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('حذف دسترسی'),
            content: Text('آیا از حذف «${def.label}» اطمینان دارید؟'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('لغو')),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final updated = List<String>.from(quickActions);
                  updated.removeAt(existingIndex);
                  await saveQuickActions(updated, ref);
                },
                child: const Text('حذف'),
              ),
            ],
          ),
        );

    // User request 2026-11-06: no visible «×» badge on the shortcut icons.
    // Removing a tile goes back to the original long press only; the tile
    // itself keeps its TalkBack label (P-03), and TalkBack's double-tap-and-
    // hold reaches the same confirmation dialog.
    return GestureDetector(onLongPress: confirmDelete, child: tile);
  }
}

class _ActionDef {
  final IconData icon;
  final String label;
  final Color color;
  final double iconScale;
  final _QuickAction action;
  const _ActionDef(this.icon, this.label, this.color, this.action,
      [this.iconScale = 1.0]);
}

abstract class _QuickAction {
  Widget build(BuildContext context, WidgetRef ref, _ActionDef def);
}

class _TabAction extends _QuickAction {
  final int tabIndex;
  final int? subTabIndex;
  _TabAction(this.tabIndex, [this.subTabIndex]);

  @override
  Widget build(BuildContext context, WidgetRef ref, _ActionDef def) {
    return _ActionItem(
        icon: def.icon,
        label: def.label,
        color: def.color,
        iconScale: def.iconScale,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(shellTabIndexProvider.notifier).setIndex(tabIndex);
          final sub = subTabIndex;
          if (sub != null) {
            ref.read(shellSubTabProvider.notifier).setIndex(sub);
          }
          // NOTE: no Navigator.pop here — a tab switch is not a sheet/dialog
          // dismiss. maybePop used to pop the shell route itself when tapped
          // from Home (back to splash / app exit).
        });
  }
}

class _NavAction extends _QuickAction {
  final String routeName;
  _NavAction(this.routeName);

  @override
  Widget build(BuildContext context, WidgetRef ref, _ActionDef def) {
    return _ActionItem(
        icon: def.icon,
        label: def.label,
        color: def.color,
        iconScale: def.iconScale,
        onTap: () {
          HapticFeedback.selectionClick();
          context.push(routeName);
        });
  }
}

class _AddAction extends _QuickAction {
  @override
  Widget build(BuildContext context, WidgetRef ref, _ActionDef def) {
    final t = TimeThemeKit.of(context).palette;
    return _ActionItem(
      icon: Icons.add,
      label: 'افزودن',
      color: t.textMuted,
      onTap: () => _showPicker(context, ref),
    );
  }

  /// Audit B04 / P-03 — the picker is ALSO the accessible removal surface.
  ///
  /// The user (2026-11-06) rejected any visible badge on the shortcut icons,
  /// so long press is the only gesture on the tile itself. This sheet gives
  /// TalkBack / switch-access users a one-tap, fully labelled delete control
  /// instead, without putting a mark on the artwork. [Consumer] keeps both
  /// lists live after an add or remove — no sheet dismiss/reopen needed.
  void _showPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Consumer(
        builder: (sheetContext, sheetRef, _) {
          final currentList = sheetRef.watch(quickActionsProvider);
          final current = currentList.toSet();
          final available = QuickActions._allActions.keys
              .where((k) => !current.contains(k))
              .toList();
          final t = TimeThemeKit.of(sheetContext).palette;

          Future<void> remove(String id, String label) async {
            final confirmed = await showDialog<bool>(
              context: sheetContext,
              builder: (ctx) => AlertDialog(
                title: const Text('حذف دسترسی'),
                content: Text('آیا از حذف «$label» اطمینان دارید؟'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('لغو')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('حذف')),
                ],
              ),
            );
            if (confirmed != true) return;
            final updated = [...sheetRef.read(quickActionsProvider)]
              ..remove(id);
            await saveQuickActions(updated, sheetRef);
          }

          Widget sectionLabel(String text) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(text,
                    style: Theme.of(sheetContext)
                        .textTheme
                        .labelLarge
                        ?.copyWith(
                            fontWeight: FontWeight.bold, color: t.textMuted)),
              );

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: t.outline,
                          borderRadius: BorderRadius.circular(2))),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('دسترسی سریع',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                sectionLabel('دسترسیهای فعلی (حذف با آیکون سطل)'),
                for (final id in currentList)
                  Builder(builder: (context) {
                    final def = QuickActions._allActions[id];
                    if (def == null) return const SizedBox.shrink();
                    return ListTile(
                      dense: true,
                      leading: Icon(def.icon, color: def.color, size: 20),
                      title: Text(def.label,
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 13))),
                      trailing: Semantics(
                        container: true,
                        button: true,
                        label: 'حذف دسترسی ${def.label}',
                        child: ExcludeSemantics(
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: 'حذف ${def.label}',
                            onPressed: () => remove(id, def.label),
                          ),
                        ),
                      ),
                    );
                  }),
                const Divider(height: 1),
                sectionLabel('افزودن'),
                if (available.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('همه گزینهها اضافه شدهاند',
                        style: TextStyle(color: t.textMuted)),
                  )
                else ...[
                  for (final id in available)
                    Builder(builder: (context) {
                      final def = QuickActions._allActions[id];
                      if (def == null) return const SizedBox.shrink();
                      return ListTile(
                        leading: Icon(def.icon, color: def.color, size: 22),
                        title: Text(def.label,
                            style: TextStyle(
                                fontSize:
                                    AppTheme.scaledFontSize(context, 14))),
                        onTap: () async {
                          final updated = [
                            ...sheetRef.read(quickActionsProvider),
                            id
                          ];
                          await saveQuickActions(updated, sheetRef);
                        },
                      );
                    }),
                ],
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double iconScale;
  final VoidCallback onTap;
  const _ActionItem(
      {required this.icon,
      required this.label,
      required this.color,
      this.iconScale = 1.0,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Audit P-03: name every tile for TalkBack. The visual caption is a
    // single ellipsized Text; without this, the grid reads as six
    // unlabelled buttons.
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            // Vertical only: the LayoutBuilder below must see the FULL cell
            // width or moreTileSize() computes a smaller tile than intended.
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  // The cell width arrives from the Wrap's SizedBox; the tile
                  // edge is the SAME moreTileSize() the More grid uses.
                  final s = quickTileSize(constraints.maxWidth);
                  final d = MoreDuotone.of(color,
                      isDark: isDark, cardSurface: t.card);
                  return Container(
                    key: const ValueKey('quick-tile'),
                    width: s,
                    height: s,
                    // The 1dp accent hairline is drawn ON TOP of the clipped
                    // children so it stays a crisp edge (as in _Style2Tile).
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(s * .32),
                      border: Border.all(color: d.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(s * .32),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        children: [
                          Positioned.fill(child: ColoredBox(color: d.fill)),
                          Center(
                            child: Icon(
                              icon,
                              // Match the «بیشتر» page: the glyph is sized from
                              // the SAME moreTileSize() the More grid uses, so a
                              // quick-access icon reads at the same scale as its
                              // More counterpart (user request 2026-11-09). The
                              // tile itself still fills its cell — that keeps the
                              // tight inter-tile gap fixed on 2026-11-07.
                              size: moreTileSize(constraints.maxWidth) *
                                  .48 *
                                  iconScale,
                              color: d.glyph,
                            ),
                          ),
                          PositionedDirectional(
                            top: s * .12,
                            end: s * .12,
                            child: Container(
                              width: s * .10,
                              height: s * .10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: d.dot,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (label.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: dsContentColor(context, color),
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
