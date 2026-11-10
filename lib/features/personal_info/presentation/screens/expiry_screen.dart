import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal_info/data/repositories/personal_info_repository_impl.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/personal_info_provider.dart';
import 'package:tawheeed/features/personal_info/services/expiry_reminder_scheduler.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

/// «تاریخ‌های مهم» — expiry countdowns + local reminders.
class ExpiryScreen extends ConsumerStatefulWidget {
  const ExpiryScreen({super.key});

  @override
  ConsumerState<ExpiryScreen> createState() => _ExpiryScreenState();
}

class _ExpiryScreenState extends ConsumerState<ExpiryScreen> {
  final Color _accent = TopicHues.personalExpiry;
  List<ExpiryItemTableData>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(personalInfoRepositoryProvider);
    try {
      final all = await repo.getExpiryItems();
      if (mounted) setState(() => _items = all);
    } catch (e) {
      AppLogger.warning('expiry_screen', 'load failed: $e');
      if (mounted) {
        setState(() => _items = const []);
        AppSnackBar.error(context, 'بارگذاری داده‌ها ناموفق بود.');
      }
    }
  }

  Future<void> _openEditor([ExpiryItemTableData? e]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ExpiryEditor(
        accent: _accent,
        item: e,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
          ref.invalidate(expiringItemsProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final onPrimary = dsOnAccent(context);
    final items = _items;
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'تاریخ‌های مهم'),
      floatingActionButton: InsetFab(
        inset: MediaQuery.paddingOf(context).bottom,
        child: FloatingActionButton(
          tooltip: 'افزودن سررسید',
          backgroundColor: t.primary,
          foregroundColor: onPrimary,
          onPressed: _openEditor,
          child: const Icon(Icons.add),
        ),
      ),
      body: SafeArea(
        child: items == null
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? _empty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        DsSpacing.page, 12, DsSpacing.page, 90),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final e = items[i];
                      return _ExpiryCard(
                        item: e,
                        accent: _accent,
                        today: today,
                        onTap: () => _openEditor(e),
                        onDeleted: _load,
                      );
                    },
                  ),
      ),
    );
  }

  Widget _empty() {
    return AppEmptyState(
      icon: Icons.event_outlined,
      message: 'تاریخ مهمی ثبت نشده',
      subtitle:
          'قسط، کارت، ویزا، گواهی‌نامه یا بیمه‌ای را اضافه کنید تا چند روز '
          'قبل از سررسید یادآوری محلی بگیرید.',
      accent: _accent,
    );
  }
}

class _ExpiryCard extends ConsumerWidget {
  final ExpiryItemTableData item;
  final Color accent;
  final DateTime today;
  final VoidCallback onTap;
  final VoidCallback onDeleted;
  const _ExpiryCard({
    required this.item,
    required this.accent,
    required this.today,
    required this.onTap,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = _parseDate(item.dueDate);
    final daysLeft =
        due?.difference(DateTime(today.year, today.month, today.day)).inDays;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final warn = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final t = TimeThemeKit.of(context).palette;
    final Color badgeColor;
    if (daysLeft == null) {
      badgeColor = t.textMuted;
    } else if (daysLeft < 0) {
      badgeColor = danger;
    } else if (daysLeft <= 7) {
      badgeColor = warn;
    } else {
      badgeColor = success;
    }
    final badgeInk =
        daysLeft == null ? t.textMuted : dsContentColor(context, badgeColor);

    final badgeLabel = due == null
        ? '─'
        : daysLeft! < 0
            ? '${-daysLeft} روز گذشته'
            : daysLeft == 0
                ? 'امروز'
                : '$daysLeft روز';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        onLongPress: () => _confirmDelete(context, ref),
        borderColor: accent.withValues(alpha: 0.25),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_categoryIcon(item.category), color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 15),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _faDate(item.dueDate),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: t.textMuted,
                    ),
                  ),
                  if (item.remindEnabled) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.notifications_active_outlined,
                            size: 14, color: t.textPrimary),
                        const SizedBox(width: 4),
                        Text(
                          'یادآوری ${item.remindDaysBefore == 0 ? 'در روز سررسید' : '${item.remindDaysBefore} روز قبل'}',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            color: dsContentColor(context, accent),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w700,
                  color: badgeInk,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_left, color: t.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف این مورد؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: danger),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(personalInfoRepositoryProvider).deleteExpiryItem(item.id);
    // Drop the OS notification too — the row it keyed off is gone.
    await ExpiryReminderScheduler.cancelFor(item.id);
    ref.invalidate(expiringItemsProvider);
    onDeleted();
  }

  IconData _categoryIcon(String cat) => switch (cat) {
        'expiry_warning' => Icons.warning_amber_outlined,
        'installment' => Icons.payments_outlined,
        'visa' => Icons.airplane_ticket_outlined,
        'certificate' => Icons.military_tech_outlined,
        _ => Icons.event_outlined,
      };

  static String _faDate(String iso) => jalaliDayMonth(iso);

  static DateTime? _parseDate(String iso) {
    try {
      final p = iso.split('-');
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (e) {
      AppLogger.warning('expiry_screen', 'operation failed: $e');
      return null;
    }
  }
}

class _ExpiryEditor extends ConsumerStatefulWidget {
  final Color accent;
  final ExpiryItemTableData? item;
  final VoidCallback onSaved;
  const _ExpiryEditor({
    required this.accent,
    this.item,
    required this.onSaved,
  });

  @override
  ConsumerState<_ExpiryEditor> createState() => _ExpiryEditorState();
}

class _ExpiryEditorState extends ConsumerState<_ExpiryEditor> {
  late final _titleCtrl = TextEditingController(text: widget.item?.title ?? '');
  late final _dueCtrl = TextEditingController(text: widget.item?.dueDate ?? '');
  late final _notesCtrl = TextEditingController(text: widget.item?.notes ?? '');
  late String _category = widget.item?.category ?? 'other';
  late bool _remindEnabled = widget.item?.remindEnabled ?? false;
  late int _remindDaysBefore = widget.item?.remindDaysBefore ?? 0;
  bool _saving = false;

  static const _categories = {
    'expiry_warning': 'انقضای مهم',
    'installment': 'قسط',
    'visa': 'ویزا',
    'certificate': 'گواهی‌نامه',
    'other': 'سایر',
  };

  @override
  void dispose() {
    _titleCtrl.dispose();
    _dueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // شمسی — the card shows the due date through `jalaliDayMonth`, so a
    // Gregorian dialog made the user pick a calendar they never read.
    final picked = await ShamsiDatePicker.show(
      context,
      initialDate: _currentDueDate() ?? now,
      earliestDate: DateTime(now.year - 2),
      latestDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      _dueCtrl.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  /// The already-typed date so re-opening the picker does not reset to today.
  DateTime? _currentDueDate() {
    final parts = _dueCtrl.text.trim().split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]),
        m = int.tryParse(parts[1]),
        d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final due = _dueCtrl.text.trim();
    if (title.isEmpty || due.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عنوان و تاریخ سررسید را وارد کنید.')));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final entry = ExpiryItemTableCompanion(
      id: Value(
          widget.item?.id ?? DateTime.now().millisecondsSinceEpoch.toString()),
      category: Value(_category),
      title: Value(title),
      dueDate: Value(due),
      notes: Value(_notesCtrl.text.trim()),
      remindEnabled: Value(_remindEnabled),
      remindDaysBefore: Value(_remindDaysBefore),
      lastRemindedDate: Value(widget.item?.lastRemindedDate ?? ''),
      isArchived: Value(widget.item?.isArchived ?? false),
      updatedAt: Value(now),
      createdAt: Value(widget.item?.createdAt ?? now),
    );
    await ref.read(personalInfoRepositoryProvider).upsertExpiryItem(entry);
    // Re-sync the OS notification for this item (cancels a stale schedule and
    // re-books it at the new date/lead time). Never throws, never blocks save.
    final saved = await ref
        .read(personalInfoRepositoryProvider)
        .getExpiryItem(entry.id.value);
    if (saved != null) {
      await ExpiryReminderScheduler.syncFor(saved);
    }
    if (mounted) {
      setState(() => _saving = false);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: EdgeInsets.only(
        left: DsSpacing.page,
        right: DsSpacing.page,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: t.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: Text(
                widget.item == null ? 'افزودن تاریخ مهم' : 'ویرایش تاریخ مهم',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
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
                    selectedColor: widget.accent.withValues(alpha: 0.2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _field(_titleCtrl, 'عنوان (مثلاً «انقضای پاسپورت»)'),
            TextField(
              controller: _dueCtrl,
              readOnly: true,
              textDirection: TextDirection.rtl,
              onTap: _pickDate,
              decoration: InputDecoration(
                labelText: 'تاریخ سررسید',
                labelStyle: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12)),
                border: const OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_month_outlined,
                    size: 18, color: widget.accent),
              ),
            ),
            const SizedBox(height: 10),
            _field(_notesCtrl, 'توضیحات', maxLines: 2),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'یادآوری محلی',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  color: t.textPrimary,
                ),
              ),
              subtitle: Text(
                'در روز مشخص‌شده قبل از سررسید اطلاع‌رسانی می‌شود',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: t.textMuted,
                ),
              ),
              activeThumbColor: widget.accent,
              value: _remindEnabled,
              onChanged: (v) => setState(() => _remindEnabled = v),
            ),
            if (_remindEnabled) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'چند روز قبل یادآوری شود؟',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: t.textMuted,
                    ),
                  ),
                  const Spacer(),
                  for (final days in const [0, 1, 3, 7, 14]) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(
                          days == 0 ? 'خود روز' : '$days روز',
                          style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 11)),
                        ),
                        selected: _remindDaysBefore == days,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) =>
                            setState(() => _remindDaysBefore = days),
                        selectedColor: widget.accent.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: widget.accent),
                icon: const Icon(Icons.check),
                label: const Text('ذخیره'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        textDirection: TextDirection.rtl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12)),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
