import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/home/presentation/utils/time_formatters.dart';
import 'package:tawheeed/features/tasks/presentation/widgets/tasks/tasks_common.dart';
import 'package:tawheeed/features/tasks/presentation/providers/task_provider.dart';
import 'package:tawheeed/features/tasks/presentation/providers/subtask_provider.dart';
import 'package:tawheeed/features/tasks/data/daos/task_aux_dao.dart';
import 'package:tawheeed/features/tasks/domain/entities/subtask.dart';
import 'package:tawheeed/features/tasks/domain/entities/task_model.dart';
import 'package:tawheeed/features/tasks/domain/task_recurrence.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';
import 'package:tawheeed/shared/widgets/latin_time_picker.dart';

class TaskDialog extends ConsumerStatefulWidget {
  final TaskModel? existingTask;
  const TaskDialog({super.key, this.existingTask});

  @override
  ConsumerState<TaskDialog> createState() => TaskDialogState();
}

class TaskDialogState extends ConsumerState<TaskDialog> {
  final _titleController = TextEditingController();
  final _tagController = TextEditingController();
  final _notesController = TextEditingController();
  final _subtaskController = TextEditingController();
  DateTime? _dueDate;
  int _priority = 0;
  List<String> _tags = [];

  /// Subtask drafts for a not-yet-saved task (persisted right after [addTask]
  /// returns the real id).
  final List<String> _draftSubtasks = [];

  /// Selected recurrence pattern (null = one-off). For the «هر N روز»
  /// pattern this stores `every_n_days:N` (see [TaskRecurrence.encodeEveryN]).
  String? _recurring;

  /// Interval picked for the «هر N روز» pattern.
  int _everyNDays = TaskRecurrence.defaultIntervalDays;

  /// Dart weekday (1=Monday..7=Sunday) picked for a weekly task, shown as
  /// Persian weekday chips. Selecting one anchors [_dueDate] on the coming
  /// day (e.g. «every Wednesday»).
  int? _weeklyWeekday;

  /// Due-date reminder toggle + time (default 08:00).
  bool _remindEnabled = false;
  TimeOfDay _remindTime = const TimeOfDay(hour: 8, minute: 0);

  static const _priorities = [
    {'value': 0, 'label': 'بدون اولویت', 'color': Color(0xFFBDBDBD)},
    {'value': 1, 'label': 'کم', 'color': Color(0xFFFDD835)},
    {'value': 2, 'label': 'متوسط', 'color': Color(0xFFFB8C00)},
    {'value': 3, 'label': 'زیاد', 'color': Color(0xFFE53935)},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingTask != null) {
      _titleController.text = widget.existingTask!.title;
      _notesController.text = widget.existingTask!.description ?? '';
      _dueDate = widget.existingTask!.dueDate;
      _priority = widget.existingTask!.priority;
      _tags = List.from(widget.existingTask!.tags);
      _recurring = widget.existingTask!.isRecurring
          ? widget.existingTask!.recurringType
          : null;
      _everyNDays = TaskRecurrence.intervalOf(_recurring);
      if (_recurring == TaskRecurrence.weekly && _dueDate != null) {
        _weeklyWeekday = _dueDate!.weekday;
      }
      _remindEnabled = widget.existingTask!.remindEnabled;
      final hm = widget.existingTask!.remindAt;
      if (hm != null) {
        final parts = hm.split(':');
        final h = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
        final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
        if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
          _remindTime = TimeOfDay(hour: h, minute: m);
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagController.dispose();
    _notesController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final t = tag.trim();
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() => _tags.add(t));
      _tagController.clear();
    }
  }

  void _pickWeeklyWeekday(int weekday) {
    setState(() {
      _weeklyWeekday = weekday;
      _dueDate = TaskRecurrence.nextWeekday(DateTime.now(), weekday);
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final notes = _notesController.text.trim();
    final remindEnabled = _remindEnabled && _dueDate != null;
    final remindAt = remindEnabled
        ? '${_remindTime.hour.toString().padLeft(2, '0')}:${_remindTime.minute.toString().padLeft(2, '0')}'
        : null;
    if (widget.existingTask == null) {
      final id = await ref.read(taskListProvider.notifier).addTask(
            title: title,
            description: notes.isEmpty ? null : notes,
            dueDate: _dueDate,
            isRecurring: _recurring != null,
            recurringType: _recurring,
            remindEnabled: remindEnabled,
            remindAt: remindAt,
            priority: _priority,
            tags: _tags,
          );
      if (id == null) {
        // The insert failed. The old code fell straight through to `pop()`, so
        // the sheet closed as if saved, no task existed, and the reader lost
        // everything they had typed. Keep the sheet and its drafts, and say so.
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('ذخیرهٔ کار ناموفق بود؛ دوباره تلاش کنید.'),
            duration: Duration(seconds: 3),
          ));
        return;
      }
      // Persist subtask drafts collected before the task existed.
      if (_draftSubtasks.isNotEmpty && mounted) {
        final dao = ref.read(taskAuxDaoProvider);
        final base = DateTime.now().millisecondsSinceEpoch;
        for (var i = 0; i < _draftSubtasks.length; i++) {
          await dao.upsertSubtask(Subtask(
            id: '${base}_$i',
            taskId: id,
            title: _draftSubtasks[i],
            position: i,
          ));
        }
      }
    } else {
      ref.read(taskListProvider.notifier).updateTask(
            widget.existingTask!.copyWith(
              title: title,
              description: notes.isEmpty ? null : notes,
              dueDate: _dueDate,
              isRecurring: _recurring != null,
              recurringType: _recurring,
              remindEnabled: remindEnabled,
              remindAt: remindAt,
              priority: _priority,
              tags: _tags,
            ),
          );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final task = widget.existingTask;
    if (task == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف کار'),
        content: Text('آیا از حذف «${task.title}» اطمینان دارید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // Capture the messenger AND the notifier before the sheet closes: the
      // snackbar (and its undo action) outlive this dialog, and using
      // `ref` after unmount throws.
      final messenger = ScaffoldMessenger.of(context);
      final notifier = ref.read(taskListProvider.notifier);
      notifier.deleteTask(task.id);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('کار حذف شد'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'بازگردانی',
            onPressed: notifier.undoLastDelete,
          ),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXLarge)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconChip(
                    icon: widget.existingTask == null
                        ? Icons.add_task
                        : Icons.edit_note,
                    color: tasksAccent,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.existingTask == null ? 'کار جدید' : 'ویرایش کار',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 17),
                      fontWeight: FontWeight.w800,
                      color: t.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان کار',
                  prefixIcon: const Icon(Icons.title, size: 20),
                  filled: true,
                  fillColor:
                      isDark ? t.surfaceAlt : Colors.white,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notesController,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'ملاحظات (اختیاری)',
                  hintText: 'توضیح یا نکته‌ای برای این کار…',
                  prefixIcon:
                      const Icon(Icons.sticky_note_2_outlined, size: 20),
                  filled: true,
                  fillColor:
                      isDark ? t.surfaceAlt : Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              _buildPriorityRow(),
              const SizedBox(height: 14),
              InkWell(
                onTap: () async {
                  final picked = await ShamsiDatePicker.show(context);
                  if (picked != null && mounted) {
                    setState(() {
                      _dueDate = picked;
                      // Keep the weekly chips in sync with a manual date.
                      if (_recurring == TaskRecurrence.weekly) {
                        _weeklyWeekday = picked.weekday;
                      }
                    });
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color:
                        isDark ? t.surfaceAlt : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, size: 20, color: tasksAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _dueDate != null
                              ? '${Jalali.fromDateTime(_dueDate!).day}/${Jalali.fromDateTime(_dueDate!).month}/${Jalali.fromDateTime(_dueDate!).year}'
                              : 'انتخاب تاریخ (اختیاری)',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            color: _dueDate != null
                                ? t.textPrimary
                                : t.textMuted,
                          ),
                        ),
                      ),
                      if (_dueDate != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          tooltip: 'پاک کردن تاریخ',
                          onPressed: () => setState(() {
                            _dueDate = null;
                            _weeklyWeekday = null;
                          }),
                        ),
                      Icon(Icons.chevron_left,
                          size: 20, color: t.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildRecurrenceRow(),
              const SizedBox(height: 14),
              _buildReminderRow(context),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        labelText: 'برچسب',
                        hintText: 'مثال: مهم',
                        prefixIcon: const Icon(Icons.label_outline, size: 20),
                        filled: true,
                        fillColor: isDark
                            ? t.surfaceAlt
                            : Colors.white,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: _addTag,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.add),
                    tooltip: 'افزودن برچسب',
                    onPressed: () => _addTag(_tagController.text.trim()),
                    style: IconButton.styleFrom(backgroundColor: tasksAccent),
                  ),
                ],
              ),
              if (_tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _tags.asMap().entries.map((entry) {
                      return Chip(
                        label: Text(entry.value,
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 12), fontFamily: AppTheme.fontFamily)),
                        deleteIcon: const Icon(Icons.close, size: 15),
                        onDeleted: () {
                          setState(() => _tags.removeAt(entry.key));
                        },
                        backgroundColor: tasksAccent.withValues(alpha: 0.10),
                        side: BorderSide(
                            color: tasksAccent.withValues(alpha: 0.3)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 20),
              _buildSubtaskSection(),
              if (widget.existingTask != null &&
                  widget.existingTask!.hasRecurrence)
                _buildHistoryLine(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.textSecondary,
                        side: BorderSide(color: t.outline),
                      ),
                      child: Text('انصراف',
                          style: TextStyle(fontFamily: AppTheme.fontFamily)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text('ذخیره',
                          style: TextStyle(fontFamily: AppTheme.fontFamily)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tasksAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.existingTask != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('حذف کار'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecurrenceRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.repeat, size: 20, color: tasksAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 6,
                children: [
                  _recurrenceChip('بدون تکرار', null),
                  _recurrenceChip('روزانه', TaskRecurrence.daily),
                  _recurrenceChip('هفتگی', TaskRecurrence.weekly),
                  _recurrenceChip('ماهانه', TaskRecurrence.monthly),
                  _recurrenceChip(
                      'هر $_everyNDays روز', TaskRecurrence.everyNDays),
                ],
              ),
            ),
          ],
        ),
        if (TaskRecurrence.baseOf(_recurring) == TaskRecurrence.everyNDays) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(width: 30),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Interval chips: 2..7 and 10/14/21/30 — covers the
                    // realistic «هر N روز» cadences without a text field.
                    for (final n in [2, 3, 4, 5, 6, 7, 10, 14, 21, 30])
                      _intervalChip(n),
                  ],
                ),
              ),
            ],
          ),
        ],
        if (_recurring == TaskRecurrence.weekly) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(width: 30),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Persian week order (Saturday first): Dart weekdays
                    // 6, 7, 1, 2, 3, 4, 5.
                    for (final wd in [6, 7, 1, 2, 3, 4, 5]) _weekdayChip(wd),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _weekdayChip(int weekday) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _weeklyWeekday == weekday;
    return InkWell(
      onTap: () => _pickWeeklyWeekday(weekday),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? tasksAccent.withValues(alpha: 0.16)
              : (isDark ? t.surfaceAlt : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? tasksAccent : t.outline,
          ),
        ),
        child: Text(
          TaskRecurrence.weekdayNamesFa[(weekday + 1) % 7],
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? tasksAccent : t.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _intervalChip(int n) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _everyNDays == n;
    return InkWell(
      onTap: () => setState(() {
        _everyNDays = n;
        if (TaskRecurrence.baseOf(_recurring) == TaskRecurrence.everyNDays) {
          _recurring = TaskRecurrence.encodeEveryN(n);
        }
      }),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? tasksAccent.withValues(alpha: 0.16)
              : (isDark ? t.surfaceAlt : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? tasksAccent : t.outline,
          ),
        ),
        child: Text(
          '$n',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? tasksAccent : t.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _recurrenceChip(String label, String? value) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected =
        TaskRecurrence.baseOf(_recurring) == TaskRecurrence.baseOf(value);
    return InkWell(
      onTap: () => setState(() => _recurring = value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? tasksAccent
              : (isDark ? t.surfaceAlt : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? tasksAccent : t.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : t.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildReminderRow(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final canRemind = _dueDate != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: canRemind && _remindEnabled
            ? tasksAccent.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            _remindEnabled && canRemind
                ? Icons.notifications_active
                : Icons.notifications_none,
            size: 20,
            color: _remindEnabled && canRemind
                ? tasksAccent
                : t.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: canRemind
                  ? () => setState(() => _remindEnabled = !_remindEnabled)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'یادآوری روز سررسید',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w600,
                      color: canRemind
                          ? t.textPrimary
                          : t.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    canRemind
                        ? 'روز قبل و روز سررسید اعلان دریافت می‌کنید'
                        : 'ابتدا یک تاریخ سررسید انتخاب کنید',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10.5),
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (canRemind && _remindEnabled)
            TextButton(
              onPressed: () async {
                final picked = await showLatinTimePicker(
                  context,
                  initialTime: _remindTime,
                  title: 'ساعت یادآوری',
                );
                if (picked != null && mounted) {
                  setState(() => _remindTime = picked);
                }
              },
              child: Text(
                TimeFormatters.formatTime(
                  '${_remindTime.hour.toString().padLeft(2, '0')}:'
                  '${_remindTime.minute.toString().padLeft(2, '0')}',
                  use12Hour: ref.watch(use12HourProvider),
                ),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w700,
                  color: tasksAccent,
                ),
              ),
            )
          else if (canRemind)
            Switch(
              value: _remindEnabled,
              activeTrackColor: tasksAccent,
              onChanged: (v) => setState(() => _remindEnabled = v),
            ),
        ],
      ),
    );
  }

  /// Checklist editor: live (existing task) or local drafts (new task).
  Widget _buildSubtaskSection() {
    final t = TimeThemeKit.of(context).palette;
    final existing = widget.existingTask;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.checklist_rounded, size: 20, color: tasksAccent),
            const SizedBox(width: 10),
            Text(
              'زیرکارها',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (existing != null)
          _LiveSubtaskEditor(taskId: existing.id)
        else
          _DraftSubtaskEditor(
            drafts: _draftSubtasks,
            controller: _subtaskController,
            onAdd: (text) {
              final t = text.trim();
              if (t.isEmpty) return;
              setState(() {
                _draftSubtasks.add(t);
                _subtaskController.clear();
              });
            },
            onRemove: (i) => setState(() => _draftSubtasks.removeAt(i)),
          ),
      ],
    );
  }

  /// «تاکنون X بار انجام شده • زنجیره Y روز» for recurring duties.
  Widget _buildHistoryLine() {
    final t = TimeThemeKit.of(context).palette;
    final id = widget.existingTask!.id;
    final stats = ref.watch(taskStreakProvider(id));
    return stats.when(
      data: (s) {
        if (s.total == 0) return const SizedBox.shrink();
        final streak = s.streak >= 2 ? ' • زنجیره ${s.streak} ${s.unit}' : '';
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 15, color: t.textMuted),
              const SizedBox(width: 6),
              Text(
                'تاکنون ${s.total} بار انجام شده$streak',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11.5),
                  color: t.textMuted,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPriorityRow() {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: _priorities.map((p) {
        final val = p['value'] as int;
        final selected = _priority == val;
        final color = p['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _priority = val),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? color : t.outline,
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.flag,
                      size: 16,
                      color: selected ? color : t.textMuted),
                  const SizedBox(height: 4),
                  Text(
                    p['label'] as String,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? t.textPrimary
                          : t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Live checklist rows for an already-saved task (persisted immediately).
class _LiveSubtaskEditor extends ConsumerStatefulWidget {
  final String taskId;
  const _LiveSubtaskEditor({required this.taskId});

  @override
  ConsumerState<_LiveSubtaskEditor> createState() => _LiveSubtaskEditorState();
}

class _LiveSubtaskEditorState extends ConsumerState<_LiveSubtaskEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(subtaskListProvider(widget.taskId));
    final notifier = ref.read(subtaskListProvider(widget.taskId).notifier);
    return _SubtaskEditorBody(
      rows: [
        for (final s in subs)
          _SubtaskRowData(
            title: s.title,
            done: s.isCompleted,
            onToggle: () => notifier.toggleSubtask(s.id),
            onDelete: () => notifier.deleteSubtask(s.id),
          ),
      ],
      controller: _controller,
      onAdd: (text) {
        if (text.trim().isEmpty) return;
        notifier.addSubtask(text);
        _controller.clear();
      },
    );
  }
}

/// Draft checklist rows for a not-yet-saved task (kept in dialog state).
class _DraftSubtaskEditor extends StatelessWidget {
  final List<String> drafts;
  final TextEditingController controller;
  final void Function(String text) onAdd;
  final void Function(int index) onRemove;
  const _DraftSubtaskEditor({
    required this.drafts,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return _SubtaskEditorBody(
      rows: [
        for (var i = 0; i < drafts.length; i++)
          _SubtaskRowData(
            title: drafts[i],
            done: false,
            onToggle: null,
            onDelete: () => onRemove(i),
          ),
      ],
      controller: controller,
      onAdd: onAdd,
    );
  }
}

class _SubtaskRowData {
  final String title;
  final bool done;
  final VoidCallback? onToggle;
  final VoidCallback onDelete;
  const _SubtaskRowData({
    required this.title,
    required this.done,
    required this.onToggle,
    required this.onDelete,
  });
}

class _SubtaskEditorBody extends StatelessWidget {
  final List<_SubtaskRowData> rows;
  final TextEditingController controller;
  final void Function(String text) onAdd;
  const _SubtaskEditorBody({
    required this.rows,
    required this.controller,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  checked: r.done,
                  label: r.done ? 'لغو انجام' : 'انجام شد',
                  child: GestureDetector(
                    onTap: r.onToggle,
                    child: Icon(
                      r.done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: r.done ? tasksAccent : t.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.title,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      color: r.done
                          ? t.textMuted
                          : t.textPrimary,
                      decoration: r.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'حذف ${r.title}',
                  child: GestureDetector(
                    onTap: r.onDelete,
                    child: Icon(Icons.close_rounded,
                        size: 17, color: t.textMuted),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'زیرکار جدید…',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor:
                      isDark ? t.surfaceAlt : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: onAdd,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => onAdd(controller.text),
              icon: const Icon(Icons.add, size: 18),
              tooltip: 'افزودن برچسب',
              style: IconButton.styleFrom(backgroundColor: tasksAccent),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Shared building blocks
// ══════════════════════════════════════════════════════════════
