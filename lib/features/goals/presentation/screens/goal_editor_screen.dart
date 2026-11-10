import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:tawheeed/features/goals/domain/goal_query.dart';
import 'package:tawheeed/features/goals/domain/goal_source_link.dart';
import 'package:tawheeed/features/goals/domain/goal_templates.dart';
import 'package:tawheeed/features/goals/presentation/providers/goals_provider.dart';
import 'package:tawheeed/features/goals/presentation/utils/goal_dates.dart';
import 'package:tawheeed/features/goals/presentation/utils/goal_ids.dart';
import 'package:tawheeed/features/goals/services/goal_reminder_scheduler.dart';
import 'package:tawheeed/features/hifz/data/daos/hifz_dao.dart';
import 'package:tawheeed/features/khatm/data/repositories/khatm_repository_impl.dart';
import 'package:tawheeed/features/notes/data/repositories/note_repository_impl.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';
import 'package:tawheeed/shared/widgets/latin_time_picker.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';

/// ویرایشگر هدف — افزودن یا ویرایش (extra = GoalTableData) یا پیش‌پر از
/// قالب (extra = GoalTemplate). قالب فقط مقادیر اولیه را می‌دهد؛ ذخیره یک
/// ردیف کاملاً جدید با id تازه می‌سازد.
class GoalEditorScreen extends ConsumerStatefulWidget {
  final GoalTableData? goal;
  final GoalTemplate? template;
  const GoalEditorScreen({super.key, this.goal, this.template});

  @override
  ConsumerState<GoalEditorScreen> createState() => _GoalEditorScreenState();
}

class _GoalEditorScreenState extends ConsumerState<GoalEditorScreen> {
  final Color _accent = TopicHues.goals;

  static String _numText(int n) => n > 0 ? NumberFormat.grouped(n) : '';

  late final _titleCtrl = TextEditingController(
      text: widget.goal?.title ?? widget.template?.title ?? '');
  late final _descCtrl = TextEditingController(
      text: widget.goal?.description ?? widget.template?.description ?? '');
  late final _targetCtrl = TextEditingController(
      text: _numText(
          widget.goal?.targetNumber ?? widget.template?.targetNumber ?? 0));
  late String _category =
      widget.goal?.category ?? widget.template?.category ?? 'hifz';
  late String _targetType =
      widget.goal?.targetType ?? widget.template?.targetType ?? 'count';
  late String _startDate = widget.goal?.startDate ?? '';
  late String _deadline = widget.goal?.deadline ?? '';
  late bool _isActive = widget.goal?.isActive ?? true;
  late bool _isArchived = widget.goal?.isArchived ?? false;

  /// Phase-2 fields. All default to «off / zero / unlinked» so an existing goal
  /// that was never edited behaves exactly as it did before.
  late int _priority = widget.goal?.priority ?? 0;
  late int _dailyTarget =
      widget.goal?.dailyTarget ?? widget.template?.dailyTarget ?? 0;
  late bool _remindEnabled = widget.goal?.remindEnabled ?? false;
  late String _remindAt = widget.goal?.remindAt ?? '09:00';

  // Owned at State level: a controller built inside build() is recreated on
  // every rebuild, which both leaks the old one and wipes what the user had
  // typed — the same bug the detail screen already had.
  late final _dailyTargetCtrl = TextEditingController(
      text: _numText(
          widget.goal?.dailyTarget ?? widget.template?.dailyTarget ?? 0));
  late final _remindAtCtrl =
      TextEditingController(text: widget.goal?.remindAt ?? '09:00');

  late String _linkedType = widget.goal?.linkedType ?? '';
  late String _linkedId = widget.goal?.linkedId ?? '';
  bool _saving = false;

  static const _categories = {
    'hifz': 'حفظ قرآن',
    'quran': 'قرائت',
    'prayer': 'نماز و عبادات',
    'study': 'مطالعه',
    'ibadat': 'اذکار',
    'health': 'سلامتی',
    'other': 'سایر',
  };

  static const _types = {
    'count': 'شمارشی',
    'minutes': 'دقیقه',
    'boolean': 'انجام / نشد',
  };

  /// Where a goal's progress can come from. Read-only in this phase: the goal
  /// shows the source's progress but does not write to it, so the picker only
  /// offers entities that can be identified reliably.
  ///
  /// The same map the domain resolver validates against, so the editor cannot
  /// offer a type the detail screen then fails to read.
  static const _linkTypes = kGoalLinkTypeLabels;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _targetCtrl.dispose();
    _dailyTargetCtrl.dispose();
    _remindAtCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isDeadline) async {
    final now = DateTime.now();
    // When editing a deadline, start from it instead of always «today».
    final current = isDeadline ? _deadline : _startDate;
    final initial = goalParseIso(current) ?? now;
    // The shared picker defaults to +1 year, which is right for a reminder
    // but would cap a multi-year goal («حفظ 30 جزء» spans years). Five
    // matches the range this screen always offered.
    final picked = await ShamsiDatePicker.show(
      context,
      initialDate: initial,
      maxYearOffset: 5,
    );
    if (picked == null) return;
    setState(() {
      if (isDeadline) {
        _deadline = goalIsoOf(picked);
      } else {
        _startDate = goalIsoOf(picked);
      }
    });
  }

  /// Quick deadline horizons. Day counts, not calendar months: a goal
  /// boundary does not need Jalali month-length precision, and one tap beats
  /// walking the picker month by month.
  static const _deadlinePresets = [
    (30, '30 روز'),
    (90, '3 ماه'),
    (180, '6 ماه'),
    (365, '1 سال'),
  ];

  void _applyDeadlinePreset(int days) {
    final base = goalParseIso(_startDate) ?? DateTime.now();
    final end =
        DateTime(base.year, base.month, base.day).add(Duration(days: days));
    setState(() => _deadline = goalIsoOf(end));
  }

  /// A live hint of the pace the chosen target and deadline imply — the same
  /// arithmetic the detail screen reports as «سرعت لازم», shown while the
  /// choice is still being made instead of after saving.
  String? _pacePreview() {
    if (_targetType == 'boolean') return null;
    final target = NumberFormat.parse(_targetCtrl.text.trim()).toInt();
    final deadline = goalParseIso(_deadline);
    if (target <= 0 || deadline == null) return null;
    final now = DateTime.now();
    final days =
        goalDaysBetween(now, deadline);
    if (days <= 0) return null;
    final perDay = target / days;
    // Whole paces read as «2», fractional ones as «0.3» — `formatPlain` alone
    // rounds 0.3 to «0», which would make a long horizon look free.
    final shown = perDay == perDay.roundToDouble()
        ? NumberFormat.formatPlain(perDay)
        : NumberFormat.groupDigits(perDay.toStringAsFixed(1));
    return 'برای این هدف، روزانه حدود $shown لازم است.';
  }

  /// Deadline must not sit before the start date — otherwise a goal is born
  /// already overdue and the list shows a bogus «N روز از مهلت گذشته».
  bool _deadlineBeforeStart() {
    if (_startDate.isEmpty || _deadline.isEmpty) return false;
    final s = goalParseIso(_startDate);
    final d = goalParseIso(_deadline);
    if (s == null || d == null) return false;
    return d.isBefore(s);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عنوان هدف را وارد کنید.')));
      return;
    }
    if (!goalIsoLooksValid(_startDate) || !goalIsoLooksValid(_deadline)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تاریخ‌ها معتبر نیستند.')));
      return;
    }
    if (_targetType != 'boolean' && _deadlineBeforeStart()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('مهلت نمی‌تواند قبل از تاریخ شروع باشد.')));
      return;
    }
    // Validated here rather than only in the time picker: the value is also
    // reachable when editing a goal saved by an older build, and a malformed
    // time would otherwise be persisted and silently never fire.
    if (_remindEnabled && !_looksLikeHm(_remindAt)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ساعت یادآوری باید به شکل 24 ساعته باشد، مثل 09:00.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final target = _targetType == 'boolean'
          ? 0
          : NumberFormat.parse(_targetCtrl.text.trim()).toInt();
      final now = DateTime.now();
      final goalId = widget.goal?.id ?? newGoalId();
      final entry = GoalTableCompanion(
        id: Value(goalId),
        title: Value(title),
        description: Value(_descCtrl.text.trim()),
        category: Value(_category),
        startDate: Value(_startDate),
        deadline: Value(_deadline),
        targetType: Value(_targetType),
        targetNumber: Value(target),
        isActive: Value(_isActive),
        isArchived: Value(_isArchived),
        priority: Value(_priority),
        // Switching a goal to «انجام/نشد» hides the daily target; storing the
        // old number anyway would resurrect it if the type is flipped back.
        dailyTarget: Value(_targetType == 'boolean' ? 0 : _dailyTarget),
        // Turning the switch off clears the time as well. Keeping a stale time
        // around means re-enabling later resurrects a reminder at a moment the
        // user never chose again.
        remindEnabled: Value(_remindEnabled),
        remindAt: Value(_remindEnabled ? _remindAt.trim() : ''),
        linkedType: Value(_linkedType),
        linkedId: Value(_linkedId.trim()),
        updatedAt: Value(now),
        createdAt: Value(widget.goal?.createdAt ?? now),
      );
      await ref.read(goalRepositoryProvider).upsertGoal(entry);
      invalidateGoal(ref, goalId);
      // The notification is scheduled from the saved row, so it must be in
      // sync before the screen closes — otherwise turning a reminder on appears
      // to do nothing until the next app start.
      await GoalReminderScheduler.syncFor(
        GoalTableData(
          id: goalId,
          title: title,
          description: _descCtrl.text.trim(),
          category: _category,
          startDate: _startDate,
          deadline: _deadline,
          targetType: _targetType,
          targetNumber: target,
          isActive: _isActive,
          isArchived: _isArchived,
          createdAt: widget.goal?.createdAt ?? now,
          updatedAt: now,
          priority: _priority,
          dailyTarget: _targetType == 'boolean' ? 0 : _dailyTarget,
          remindEnabled: _remindEnabled,
          remindAt: _remindEnabled ? _remindAt.trim() : '',
          linkedType: _linkedType,
          linkedId: _linkedId.trim(),
        ),
        isComplete: _targetType == 'boolean'
            ? false
            : (target > 0 &&
                await ref.read(goalRepositoryProvider).goalTotal(goalId) >=
                    target),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // A failed write must not leave the save button dead (stuck _saving).
      AppLogger.warning('GoalEditorScreen', 'save failed: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('ذخیرهٔ هدف ممکن نشد؛ دوباره تلاش کنید.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final paceHint = _pacePreview();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: widget.goal == null ? 'هدف جدید' : 'ویرایش هدف',
        actions: [
          IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'ذخیرهٔ هدف',
              onPressed: _saving ? null : _save),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(DsSpacing.page, 8, DsSpacing.page, 40),
          children: [
            _field(_titleCtrl, 'عنوان هدف (مثلاً «حفظ 30 جزء»)'),
            _field(_descCtrl, 'توضیحات (اختیاری)', maxLines: 2),
            const SizedBox(height: 6),
            Text(
              'دسته‌بندی',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in _categories.entries)
                  ChoiceChip(
                    label: Text(e.value, style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 12))),
                    selected: _category == e.key,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _category = e.key),
                    selectedColor: _accent.withValues(alpha: 0.2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'نوع سنجش',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in _types.entries)
                  ChoiceChip(
                    label: Text(e.value, style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 12))),
                    selected: _targetType == e.key,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _targetType = e.key),
                    selectedColor: _accent.withValues(alpha: 0.2),
                  ),
              ],
            ),
            if (_targetType != 'boolean') ...[
              const SizedBox(height: 14),
              // Rebuilds on each keystroke so the pace preview below the
              // dates tracks the number while it is typed.
              _field(_targetCtrl, 'مقدار هدف (مثلاً 30)',
                  keyboard: TextInputType.number,
                  inputFormatters: const [LatinGroupingFormatter()],
                  onChanged: (_) => setState(() {})),
            ] else ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: isDark ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'هدف «انجام/نشد» عدد نمی‌گیرد؛ هر روز در صفحهٔ هدف، '
                  'انجام‌شدن آن را تیک می‌زنید.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: t.textMuted,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _dateTile(
                      'تاریخ شروع', _startDate, () => _pickDate(false)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dateTile('مهلت${goalDaysLeftLabel(_deadline)}',
                      _deadline, () => _pickDate(true)),
                ),
              ],
            ),
            if (_targetType != 'boolean') ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in _deadlinePresets)
                    ActionChip(
                      key: ValueKey('goal_deadline_${p.$1}'),
                      label: Text(p.$2, style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 12))),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _applyDeadlinePreset(p.$1),
                    ),
                ],
              ),
            ],
            if (_deadlineBeforeStart()) ...[
              const SizedBox(height: 6),
              Text(
                'مهلت قبل از تاریخ شروع است — تاریخ‌ها را اصلاح کنید.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: danger,
                ),
              ),
            ] else if (paceHint != null) ...[
              const SizedBox(height: 6),
              Text(
                paceHint,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: t.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _sectionLabel('برنامه و یادآوری'),
            const SizedBox(height: 8),
            Text(
              'اولویت',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var p = 0; p < kGoalPriorityLabels.length; p++)
                  ChoiceChip(
                    label: Text(kGoalPriorityLabels[p],
                        style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 12))),
                    selected: _priority == p,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _priority = p),
                    selectedColor: _accent.withValues(alpha: 0.2),
                  ),
              ],
            ),
            // A boolean goal is one check a day; a daily quota on top of it
            // would be a number nothing reads.
            if (_targetType != 'boolean') ...[
              const SizedBox(height: 12),
              _field(
                _dailyTargetCtrl,
                'هدف روزانه (اختیاری، مثلاً 1 جز در روز)',
                keyboard: TextInputType.number,
                inputFormatters: const [LatinGroupingFormatter()],
                onChanged: (v) =>
                    _dailyTarget = NumberFormat.parse(v.trim()).toInt(),
              ),
            ],
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'یادآوری روزانه',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  color: t.textPrimary,
                ),
              ),
              subtitle: Text(
                _remindEnabled
                    ? 'هر روز در ساعت $_remindAt یادآوری می‌آید'
                    : 'برای این هدف هر روز یادآوری بگیر',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: t.textMuted,
                ),
              ),
              activeThumbColor: _accent,
              value: _remindEnabled,
              onChanged: (v) => setState(() => _remindEnabled = v),
            ),
            if (_remindEnabled) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _remindAtCtrl,
                      'ساعت یادآوری (24 ساعته)',
                      hint: '09:00',
                      inputFormatters: const [LatinDigitFoldFormatter()],
                      onChanged: (v) => _remindAt = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.schedule),
                    tooltip: 'انتخاب ساعت',
                    onPressed: _pickRemindTime,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _sectionLabel('پیوند به منبع پیشرفت'),
            const SizedBox(height: 8),
            if (_linkedType.isEmpty) ...[
              Text(
                'می‌توانید پیشرفت این هدف را به یک یادداشت یا ختم وصل کنید تا '
                'وضعیت آن منبع در صفحهٔ هدف دیده شود.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: t.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in _linkTypes.entries)
                    ActionChip(
                      label: Text('اتصال به ${e.value}',
                          style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 12))),
                      avatar: const Icon(Icons.link, size: 15),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _pickLinkedSource(e.key),
                    ),
                ],
              ),
            ] else ...[
              _linkPreview(context),
              const SizedBox(height: 6),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _pickLinkedSource(_linkedType),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('تغییر منبع'),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _linkedType = '';
                      _linkedId = '';
                    }),
                    icon: const Icon(Icons.link_off, size: 16),
                    label: const Text('حذف پیوند'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'هدف فعال',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  color: t.textPrimary,
                ),
              ),
              activeThumbColor: _accent,
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            if (widget.goal != null) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'بایگانی',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    color: t.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'از فهرست اصلی پنهان می‌شود؛ پیشرفت‌ها حفظ می‌ماند',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: t.textMuted,
                  ),
                ),
                activeThumbColor: _accent,
                value: _isArchived,
                onChanged: (v) => setState(() => _isArchived = v),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: _accent),
                icon: const Icon(Icons.check),
                label: Text(widget.goal == null ? 'ایجاد هدف' : 'ذخیره'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    final t = TimeThemeKit.of(context).palette;
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(context, 13),
        fontWeight: FontWeight.w700,
        color: t.textPrimary,
      ),
    );
  }

  /// `HH:mm` with real bounds. A time picker can only ever produce valid ones;
  /// this guards the text field, which also accepts Persian digits.
  static bool _looksLikeHm(String s) {
    final t = NumberFormat.normalizeDigits(s.trim());
    final parts = t.split(':');
    if (parts.length != 2) return false;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return false;
    if (parts[0].length != 2 || parts[1].length != 2) return false;
    return h >= 0 && h <= 23 && m >= 0 && m <= 59;
  }

  Future<void> _pickRemindTime() async {
    final existing = _looksLikeHm(_remindAt)
        ? _remindAt.trim().split(':')
        : const ['09', '00'];
    final picked = await showLatinTimePicker(
      context,
      initialTime: TimeOfDay(
        hour: int.parse(existing[0]),
        minute: int.parse(existing[1]),
      ),
      title: 'ساعت یادآوری',
    );
    if (picked == null) return;
    setState(() {
      _remindAt =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      // The time field is the source of truth on save, so it has to follow
      // the picker or the two disagree on screen until the next rebuild.
      _remindAtCtrl.text = _remindAt;
    });
  }

  /// Pick a source to mirror progress from.
  ///
  /// This phase is read-only: the goal displays the source's state but never
  /// writes to it, because a goal that mutates a khatm counter from the wrong
  /// screen is worse than no link at all.
  Future<void> _pickLinkedSource(String type) async {
    final picked = await _showSourcePicker(type);
    if (picked == null) return;
    setState(() {
      _linkedType = type;
      _linkedId = picked;
    });
  }

  Future<String?> _showSourcePicker(String type) async {
    final t = TimeThemeKit.of(context).palette;
    final label = _linkTypes[type] ?? type;
    // One `List<({String id, String title, String hint})>` per kind, so the
    // dialog below is shared instead of three near-identical copies.
    final options = switch (type) {
      'note' => await _noteOptions(),
      'hifz' => await _hifzOptions(),
      'khatm' => await _khatmOptions(),
      _ => const <({String id, String title, String hint})>[],
    };
    if (!mounted) return null;
    if (options.isEmpty) {
      _toast('موردی برای اتصال به «$label» وجود ندارد.');
      return null;
    }
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('انتخاب $label'),
        children: [
          for (final o in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, o.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    o.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (o.hint.isNotEmpty)
                    Text(
                      o.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: t.textMuted,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<List<({String id, String title, String hint})>> _noteOptions() async {
    final notes = await ref.read(noteRepositoryProvider).getAllNotes();
    return notes
        .take(100)
        .map((n) => (
              id: n.id,
              title: n.title.isEmpty ? '(بدون عنوان)' : n.title,
              hint: n.content.trim().replaceAll(RegExp(r'\s+'), ' '),
            ))
        .toList();
  }

  Future<List<({String id, String title, String hint})>> _hifzOptions() async {
    final dao = ref.read(hifzDaoProvider);
    final hafizs = await dao.getAllHafizs();
    final out = <({String id, String title, String hint})>[];
    for (final h in hafizs.take(100)) {
      final lessons = await dao.getLessons(h.id);
      out.add((
        id: h.id,
        title: h.name,
        hint: lessons.isEmpty
            ? 'بدون درس'
            : '${lessons.length} درس • ${lessons.fold<int>(0, (s, l) => s + l.pages)} صفحه',
      ));
    }
    return out;
  }

  Future<List<({String id, String title, String hint})>> _khatmOptions() async {
    final repo = ref.read(khatmRepositoryProvider);
    final khatms = await repo.getAllKhatms();
    return khatms
        .take(100)
        .map((k) => (
              id: k.id,
              title: k.title,
              hint: '${k.readPages} از ${k.totalPages} صفحه',
            ))
        .toList();
  }

  Widget _linkPreview(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.all(12),
      color: _accent.withValues(alpha: isDark ? 0.16 : 0.08),
      borderColor: _accent.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(Icons.link, size: 16, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _linkTypes[_linkedType] ?? _linkedType,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                Text(
                  'پیشرفت این منبع در صفحهٔ هدف نمایش داده می‌شود؛ تغییری در آن '
                  'منبع داده نمی‌شود.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _dateTile(String label, String value, VoidCallback onTap) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      borderColor: _accent.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 16, color: _accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value.isEmpty ? '—' : goalFaDate(value),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {int maxLines = 1,
      TextInputType? keyboard,
      String? hint,
      List<TextInputFormatter> inputFormatters = const [],
      ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        textDirection: TextDirection.rtl,
        maxLines: maxLines,
        keyboardType: keyboard,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12)),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
