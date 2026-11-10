import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';
import 'package:tawheeed/shared/utils/tag_palette.dart';
import 'package:tawheeed/features/tasks/presentation/providers/task_provider.dart';
import 'package:tawheeed/features/tasks/domain/entities/task_model.dart';

import 'package:tawheeed/features/tasks/presentation/widgets/tasks/tasks_common.dart';
import 'package:tawheeed/features/tasks/presentation/widgets/tasks/tasks_virtues.dart';
import 'package:tawheeed/features/tasks/presentation/widgets/tasks/tasks_summary.dart';
import 'package:tawheeed/features/tasks/presentation/widgets/tasks/tasks_filters.dart';
import 'package:tawheeed/features/tasks/presentation/widgets/tasks/tasks_tile.dart';
import 'package:tawheeed/features/tasks/presentation/widgets/tasks/tasks_dialog.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  TaskFilter _filter = TaskFilter.all;
  bool _showCompleted = true;
  bool _showArchived = false;

  /// Active tag filter (null = all tags).
  String? _selectedTag;

  /// Group the list by tag instead of the pending/completed sections.
  bool _groupByTag = false;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskListProvider);
    final loadStatus = ref.watch(tasksLoadedProvider);

    final filtered = _applyTagFilter(_applyFilter(tasks));

    final pending = filtered.where((t) => !t.isCompleted).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    bool isOverdue(TaskModel t) {
      final d = t.dueDate;
      return d != null && DateTime(d.year, d.month, d.day).isBefore(todayStart);
    }

    // Tasks whose deadline silently passed: shown in their own red section
    // above the ordinary pending list, oldest deadline first.
    final overduePending = pending.where(isOverdue).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final upcomingPending = pending.where((t) => !isOverdue(t)).toList();
    final completed = filtered.where((t) => t.isCompleted).toList()
      ..sort((a, b) {
        final ca = a.completedAt ?? a.updatedAt ?? a.createdAt;
        final cb = b.completedAt ?? b.updatedAt ?? b.createdAt;
        return cb.compareTo(ca);
      });
    // Auto-archive: done jobs older than a month leave the main lists for
    // the «بایگانی» section below (restoring one un-completes it).
    final archived = completed.where(isTaskArchived).toList();
    final recentCompleted = completed.where((t) => !isTaskArchived(t)).toList();

    final totalAll = tasks.length;
    final doneAll = tasks.where((t) => t.isCompleted).length;
    final progress = totalAll == 0 ? 0.0 : (doneAll / totalAll);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'مدیریت کارها',
        actions: [
          if (doneAll > 0)
            IconButton(
              icon: const Icon(Icons.cleaning_services_outlined),
              tooltip: 'حذف کارهای انجام شده',
              onPressed: () => _confirmClearCompleted(context, ref),
            ),
        ],
      ),
      body: loadStatus == TasksLoadStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : loadStatus == TasksLoadStatus.failed
          ? _buildLoadFailure(context, ref)
          : tasks.isEmpty
              ? TasksVirtuesScreen(
                  onStart: () => _showTaskDialog(context),
                )
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: TasksSummary(
                        tasks: tasks,
                        progress: progress,
                        pendingCount: pending.length,
                        doneCount: doneAll,
                      ),
                    ),
                    SliverToBoxAdapter(child: _buildFilterRow(tasks)),
                    if (filtered.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppEmptyState(
                          icon: _filter == TaskFilter.all
                              ? Icons.task_alt
                              : Icons.search_off,
                          message: _filter == TaskFilter.all
                              ? 'هنوز کاری ثبت نشده'
                              : 'موردی یافت نشد',
                          accent: tasksAccent,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(
                            _groupByTag
                                ? _buildTagGroupChildren(filtered)
                                : [
                                    if (overduePending.isNotEmpty) ...[
                                      SectionLabel(
                                        title: 'تأخیر خورده',
                                        count: overduePending.length,
                                        accent:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                      const SizedBox(height: 8),
                                      ...overduePending
                                          .map((t) => TaskTile(taskId: t.id)),
                                      const SizedBox(height: 16),
                                    ],
                                    if (upcomingPending.isNotEmpty) ...[
                                      SectionLabel(
                                          title: 'در انتظار',
                                          count: upcomingPending.length,
                                          accent: tasksAccent),
                                      const SizedBox(height: 8),
                                      ...upcomingPending
                                          .map((t) => TaskTile(taskId: t.id)),
                                      const SizedBox(height: 16),
                                    ],
                                    if (recentCompleted.isNotEmpty) ...[
                                      CollapsibleHeader(
                                        title: 'انجام شده',
                                        count: recentCompleted.length,
                                        expanded: _showCompleted,
                                        onToggle: () => setState(() =>
                                            _showCompleted = !_showCompleted),
                                      ),
                                      const SizedBox(height: 8),
                                      if (_showCompleted)
                                        ...recentCompleted
                                            .map((t) => TaskTile(taskId: t.id)),
                                      const SizedBox(height: 16),
                                    ],
                                    if (archived.isNotEmpty) ...[
                                      CollapsibleHeader(
                                        title: 'بایگانی',
                                        count: archived.length,
                                        expanded: _showArchived,
                                        onToggle: () => setState(() =>
                                            _showArchived = !_showArchived),
                                      ),
                                      const SizedBox(height: 8),
                                      if (_showArchived)
                                        ...archived
                                            .map((t) => TaskTile(taskId: t.id)),
                                    ],
                                  ],
                          ),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: InsetFab(
        inset: MediaQuery.paddingOf(context).bottom,
        child: FloatingActionButton.extended(
          onPressed: () => _showTaskDialog(context),
          backgroundColor: tasksAccent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label:
              Text('کار جدید', style: TextStyle(fontFamily: AppTheme.fontFamily)),
        ),
      ),
    );
  }

  /// Applies the active tag filter on top of the main filter.
  List<TaskModel> _applyTagFilter(List<TaskModel> tasks) {
    final tag = _selectedTag;
    if (tag == null) return tasks;
    return tasks.where((t) => t.tags.contains(tag)).toList();
  }

  List<TaskModel> _applyFilter(List<TaskModel> tasks) {
    switch (_filter) {
      case TaskFilter.all:
        return tasks;
      case TaskFilter.today:
        final now = DateTime.now();
        return tasks.where((t) {
          if (t.dueDate == null) return false;
          return t.dueDate!.day == now.day &&
              t.dueDate!.month == now.month &&
              t.dueDate!.year == now.year;
        }).toList();
      case TaskFilter.thisWeek:
        final now = DateTime.now();
        // Iranian week starts Saturday
        final daysSinceSat = (now.weekday + 1) % 7;
        final weekStart = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: daysSinceSat));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return tasks.where((t) {
          if (t.dueDate == null) return false;
          return !t.dueDate!.isBefore(weekStart) &&
              !t.dueDate!.isAfter(weekEnd);
        }).toList();
      case TaskFilter.highPriority:
        return tasks.where((t) => t.priority >= 2 && !t.isCompleted).toList();
      case TaskFilter.completed:
        return tasks.where((t) => t.isCompleted).toList();
    }
  }

  Widget _buildFilterRow(List<TaskModel> tasks) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              TaskFilterChip(
                  label: 'همه',
                  filter: TaskFilter.all,
                  icon: Icons.grid_view_rounded,
                  current: _filter,
                  onChanged: (f) => setState(() => _filter = f)),
              const SizedBox(width: 8),
              TaskFilterChip(
                  label: 'امروز',
                  filter: TaskFilter.today,
                  icon: Icons.today,
                  current: _filter,
                  onChanged: (f) => setState(() => _filter = f)),
              const SizedBox(width: 8),
              TaskFilterChip(
                  label: 'این هفته',
                  filter: TaskFilter.thisWeek,
                  icon: Icons.date_range,
                  current: _filter,
                  onChanged: (f) => setState(() => _filter = f)),
              const SizedBox(width: 8),
              TaskFilterChip(
                  label: 'مهم',
                  filter: TaskFilter.highPriority,
                  icon: Icons.flag,
                  current: _filter,
                  onChanged: (f) => setState(() => _filter = f)),
              const SizedBox(width: 8),
              TaskFilterChip(
                  label: 'انجام شده',
                  filter: TaskFilter.completed,
                  icon: Icons.check_circle,
                  current: _filter,
                  onChanged: (f) => setState(() => _filter = f)),
            ],
          ),
        ),
        _buildTagRow(tasks),
      ],
    );
  }

  /// Tag filter chips + the group-by-tag toggle. Hidden when no task has tags.
  Widget _buildTagRow(List<TaskModel> allTasks) {
    final tags = allTasks.expand((t) => t.tags).toSet().toList()
      ..sort((a, b) => a.compareTo(b));
    if (tags.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          TagFilterChip(
            key: const ValueKey('tag_chip_all'),
            label: 'همه برچسب‌ها',
            selected: _selectedTag == null,
            color: tasksAccent,
            onTap: () => setState(() => _selectedTag = null),
          ),
          for (final tag in tags) ...[
            const SizedBox(width: 8),
            TagFilterChip(
              key: ValueKey('tag_chip_$tag'),
              label: tag,
              selected: _selectedTag == tag,
              color: _tagColor(tag),
              onTap: () => setState(() {
                _selectedTag = _selectedTag == tag ? null : tag;
              }),
            ),
          ],
          const SizedBox(width: 12),
          GroupByTagChip(
            key: const ValueKey('group_by_tag_toggle'),
            active: _groupByTag,
            onTap: () => setState(() => _groupByTag = !_groupByTag),
          ),
        ],
      ),
    );
  }

  /// Groups the filtered tasks under their tags (a multi-tag task appears in
  /// every group it belongs to; untagged tasks go under «بدون برچسب»).
  List<Widget> _buildTagGroupChildren(List<TaskModel> tasks) {
    final groups = _groupByTagList(tasks);
    return [
      for (final g in groups) ...[
        SectionLabel(
            title: g.tag, count: g.tasks.length, accent: _tagColor(g.tag)),
        const SizedBox(height: 8),
        ...g.tasks.map((t) => TaskTile(taskId: t.id)),
        const SizedBox(height: 16),
      ],
    ];
  }

  List<({String tag, List<TaskModel> tasks})> _groupByTagList(
      List<TaskModel> tasks) {
    final order = <String>[];
    final map = <String, List<TaskModel>>{};
    void add(String tag, TaskModel t) {
      final list = map[tag];
      if (list != null) {
        list.add(t);
      } else {
        map[tag] = <TaskModel>[t];
        order.add(tag);
      }
    }

    for (final t in tasks) {
      if (t.tags.isEmpty) {
        add('بدون برچسب', t);
      } else {
        for (final tag in t.tags) {
          add(tag, t);
        }
      }
    }
    return [
      for (final tag in order)
        (
          tag: tag,
          tasks: (map[tag] ?? <TaskModel>[])
            ..sort((a, b) {
              final status =
                  (a.isCompleted ? 1 : 0).compareTo(b.isCompleted ? 1 : 0);
              if (status != 0) return status;
              return b.priority.compareTo(a.priority);
            }),
        ),
    ];
  }

  /// Deterministic color per tag for the chips and group headers.
  ///
  /// Uses the shared FNV-1a helper — `tag.hashCode` is randomized per Dart
  /// isolate, which reshuffled every tag color on each app launch.
  static const List<Color> _tagPalette = <Color>[
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFFFFA726),
    Color(0xFF66BB6A),
    Color(0xFFEC407A),
    Color(0xFF29B6F6),
    Color(0xFFFF7043),
    Color(0xFF8D6E63),
  ];

  Color _tagColor(String tag) => stablePaletteColor(tag, _tagPalette);

  void _showTaskDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TaskDialog(),
    );
  }

  void _confirmClearCompleted(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(taskListProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأیید حذف'),
        content: const Text('آیا از حذف همه کارهای انجام شده اطمینان دارید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await notifier.clearCompleted();
              if (!context.mounted) return;
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: const Text('کارهای انجام‌شده حذف شدند'),
                  duration: const Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'بازگردانی',
                    onPressed: notifier.undoClearCompleted,
                  ),
                ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف همه'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// EMPTY STATE — virtues screen (khatm pattern)
// ══════════════════════════════════════════════════════════════

/// The read failed — which is not the same statement as "you have no tasks".
///
/// The old `loaded` flag went true either way, so this screen offered the
/// first-task onboarding to a reader whose tasks had simply not been read.
Widget _buildLoadFailure(BuildContext context, WidgetRef ref) {
  return FailureView(
    id: 'tasks_load',
    title: 'کارها باز نشدند',
    detail: 'کارهای شما پاک نشده‌اند؛ فقط خواندنشان ناموفق بود.',
    onRetry: () => ref.read(taskListProvider.notifier).reload(),
    layout: FailureLayout.page,
  );
}
