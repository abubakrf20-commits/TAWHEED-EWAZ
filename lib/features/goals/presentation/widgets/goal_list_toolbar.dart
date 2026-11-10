import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/goals/domain/goal_query.dart';
import 'package:tawheeed/features/goals/presentation/providers/goals_provider.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// Search field, filter chips and the sort menu that sit above the goal list.
///
/// Split out of the screen so the screen stays about loading and navigation,
/// and so the whole bar can be exercised by one widget test.
class GoalListToolbar extends ConsumerStatefulWidget {
  /// How many goals exist before any filter — used for «no results» wording
  /// that distinguishes "your search matched nothing" from "you have none".
  final int totalGoals;

  const GoalListToolbar({super.key, required this.totalGoals});

  @override
  ConsumerState<GoalListToolbar> createState() => _GoalListToolbarState();
}

class _GoalListToolbarState extends ConsumerState<GoalListToolbar> {
  late final TextEditingController _searchCtrl = TextEditingController(
      text: ref.read(goalListOptionsProvider).filter.query);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = TopicHues.goals;
    final options = ref.watch(goalListOptionsProvider);
    final filter = options.filter;

    // The field follows the provider rather than owning the text.
    //
    // `GoalListOptionsController.clear()` is reachable from outside this
    // widget — the "no matches" empty state calls it, and so does the reset
    // button below. When the controller was the only owner of the text, a
    // clear from either of those reset the list but left the old query sitting
    // in the field: the screen then showed every goal while the field claimed
    // a search was still active, and the next keystroke appended to a query
    // the user had just dismissed. Listening keeps one source of truth, so
    // every path that clears the list also clears the text.
    ref.listen(goalListOptionsProvider.select((o) => o.filter.query),
        (previous, next) {
      if (_searchCtrl.text == next) return;
      _searchCtrl.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                textDirection: TextDirection.rtl,
                onChanged: (v) =>
                    ref.read(goalListOptionsProvider.notifier).setQuery(v),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'جست‌وجو در اهداف…',
                  hintStyle: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: t.textMuted,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: filter.query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'پاک کردن جست‌وجو',
                          onPressed: () {
                            _searchCtrl.clear();
                            ref
                                .read(goalListOptionsProvider.notifier)
                                .setQuery('');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _sortButton(context, options.sort, accent),
            // "Clear all" lives in the fixed top row, not at the end of the
            // scrolling chip row. As a chip it was the furthest item from the
            // right edge, so on a narrow screen it was off-screen unless the
            // user happened to scroll sideways — a control you cannot see is
            // a control that does not exist. A reset is also not a filter
            // dimension, so it does not belong among the filters at all.
            //
            // The search field already clears its own text with its suffix ×,
            // so this only appears when a *chip* filter is actually set.
            if (_hasChipFilter(filter)) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.filter_alt_off, size: 18),
                color: accent,
                tooltip: 'پاک کردن فیلترها',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _searchCtrl.clear();
                  ref.read(goalListOptionsProvider.notifier).clear();
                },
              ),
            ],
          ],
        ),
        if (_hasAnyFilter(filter)) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final entry in kGoalCategories)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 6),
                    child: _chip(
                      context,
                      label: entry.$2,
                      selected: filter.category == entry.$1,
                      accent: accent,
                      onTap: () => ref
                          .read(goalListOptionsProvider.notifier)
                          .setCategory(
                              filter.category == entry.$1 ? null : entry.$1),
                    ),
                  ),
                // Priority 0 is the default, so there is no chip for it —
                // "any priority" already includes it.
                for (final p in const [(1, 'متوسط'), (2, 'زیاد')])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 6),
                    child: _chip(
                      context,
                      label: p.$2,
                      selected: filter.priority == p.$1,
                      accent: accent,
                      onTap: () => ref
                          .read(goalListOptionsProvider.notifier)
                          .setPriority(filter.priority == p.$1 ? null : p.$1),
                    ),
                  ),
                _chip(
                  context,
                  label: 'اتمام‌یافته‌ها',
                  selected: filter.hideCompleted,
                  accent: accent,
                  onTap: () => ref
                      .read(goalListOptionsProvider.notifier)
                      .setHideCompleted(!filter.hideCompleted),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  bool _hasAnyFilter(GoalFilter f) => !f.isEmpty;

  /// Whether a *chip* filter is set, ignoring the search text.
  ///
  /// The search field clears its own text through its suffix button, so a
  /// visible "clear" next to it would only appear to do nothing when the
  /// query is the only thing narrowing the list.
  bool _hasChipFilter(GoalFilter f) =>
      f.category != null || f.priority != null || f.hideCompleted;

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final t = TimeThemeKit.of(context).palette;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(context, 11),
        color: selected ? Colors.white : t.textPrimary,
      ),
      backgroundColor: t.card,
      selectedColor: accent,
      side: BorderSide(
        color: selected ? accent : accent.withValues(alpha: 0.25),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _sortButton(BuildContext context, GoalSort current, Color accent) {
    final t = TimeThemeKit.of(context).palette;
    return PopupMenuButton<GoalSort>(
      tooltip: 'ترتیب',
      initialValue: current,
      onSelected: (v) => ref.read(goalListOptionsProvider.notifier).setSort(v),
      color: t.card,
      itemBuilder: (context) => [
        for (final s in GoalSort.values)
          PopupMenuItem(value: s, child: Text(s.label)),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 18, color: accent),
            const SizedBox(width: 4),
            Text(
              NumberFormat.en(current.index + 1),
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
