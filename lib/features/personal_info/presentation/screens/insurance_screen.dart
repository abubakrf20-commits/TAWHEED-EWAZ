import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal_info/data/repositories/personal_info_repository_impl.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/secret_vault.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';

/// «بیمه» — بیمه‌نامه‌ها.
class InsuranceScreen extends ConsumerStatefulWidget {
  const InsuranceScreen({super.key});

  @override
  ConsumerState<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends ConsumerState<InsuranceScreen> {
  final Color _accent = TopicHues.personalInsurance;
  List<InsuranceTableData>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(personalInfoRepositoryProvider);
    try {
      final all = await repo.getInsurances();
      if (mounted) setState(() => _items = all);
    } catch (e) {
      AppLogger.warning('insurance_screen', 'load failed: $e');
      if (mounted) {
        setState(() => _items = const []);
        AppSnackBar.error(context, 'بارگذاری داده‌ها ناموفق بود.');
      }
    }
  }

  Future<void> _openEditor([InsuranceTableData? i]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _InsuranceEditor(
        accent: _accent,
        item: i,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final onPrimary = dsOnAccent(context);
    final items = _items;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'بیمه'),
      floatingActionButton: InsetFab(
        inset: MediaQuery.paddingOf(context).bottom,
        child: FloatingActionButton(
          tooltip: 'افزودن بیمه‌نامه',
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
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.health_and_safety_outlined, size: 56),
                        const SizedBox(height: 12),
                        Text(
                          'بیمه‌ای ثبت نشده',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 15),
                            fontWeight: FontWeight.w700,
                            color: t.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'بیمه درمان، تکمیلی و عمر را با تاریخ اعتبار ثبت کنید.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        DsSpacing.page, 12, DsSpacing.page, 90),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final e = items[i];
                      return _InsuranceCard(
                        item: e,
                        accent: _accent,
                        onTap: () => _openEditor(e),
                        onDeleted: _load,
                      );
                    },
                  ),
      ),
    );
  }
}

class _InsuranceCard extends ConsumerWidget {
  final InsuranceTableData item;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onDeleted;
  const _InsuranceCard({
    required this.item,
    required this.accent,
    required this.onTap,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        onLongPress: () => _delete(context, ref),
        borderColor: accent.withValues(alpha: 0.25),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.health_and_safety_outlined, color: accent),
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
                  if (item.provider.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.provider,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                  if (item.expiryDate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'اعتبار تا: ${_faDate(item.expiryDate)}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: _expiryColor(context, item.expiryDate),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: t.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف این بیمه؟'),
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
    try {
      await ref.read(personalInfoRepositoryProvider).deleteInsurance(item.id);
    } catch (e) {
      // Uncaught before this: the row stayed, the list never refreshed, and
      // nothing was said — a failed delete and a slow one looked identical.
      AppLogger.warning('insurance_screen', 'insurance delete failed: $e');
      if (!context.mounted) return;
      AppSnackBar.error(
        context,
        'بیمه‌نامه حذف نشد و هنوز در فهرست است.',
        onRetry: () => _delete(context, ref),
      );
      return;
    }
    onDeleted();
  }

  static String _faDate(String iso) => jalaliDayMonth(iso);

  Color _expiryColor(BuildContext context, String iso) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final warn = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final t = TimeThemeKit.of(context).palette;
    try {
      final p = iso.split('-');
      final due = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      final days = due.difference(DateTime.now()).inDays;
      if (days < 0) return danger;
      if (days <= 30) return warn;
      return success;
    } catch (e) {
      AppLogger.warning('insurance_screen', 'operation failed: $e');
      return t.textMuted;
    }
  }
}

class _InsuranceEditor extends ConsumerStatefulWidget {
  final Color accent;
  final InsuranceTableData? item;
  final VoidCallback onSaved;
  const _InsuranceEditor({
    required this.accent,
    this.item,
    required this.onSaved,
  });

  @override
  ConsumerState<_InsuranceEditor> createState() => _InsuranceEditorState();
}

class _InsuranceEditorState extends ConsumerState<_InsuranceEditor> {
  late final _titleCtrl = TextEditingController(text: widget.item?.title ?? '');
  late final _providerCtrl =
      TextEditingController(text: widget.item?.provider ?? '');
  late final _policyCtrl =
      TextEditingController(text: widget.item?.policyNo ?? '');
  late final _startCtrl =
      TextEditingController(text: widget.item?.startDate ?? '');
  late final _expiryCtrl =
      TextEditingController(text: widget.item?.expiryDate ?? '');
  late final _notesCtrl = TextEditingController(text: widget.item?.notes ?? '');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final vault = ref.read(secretVaultProvider).asData?.value;
    if (vault != null && (widget.item?.policyNo ?? '').isNotEmpty) {
      _policyCtrl.text = vault.decrypt(widget.item!.policyNo);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _providerCtrl.dispose();
    _policyCtrl.dispose();
    _startCtrl.dispose();
    _expiryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    // شمسی — both dates render through `jalaliDayMonth`, so the Gregorian
    // dialog asked for a calendar the list never shows.
    final picked = await ShamsiDatePicker.show(
      context,
      initialDate: _parseIso(ctrl.text.trim()) ?? now,
      earliestDate: DateTime(now.year - 2),
      latestDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      ctrl.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  /// The already-typed date so re-opening the picker keeps the old choice.
  static DateTime? _parseIso(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]),
        m = int.tryParse(p[1]),
        d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('عنوان را وارد کنید.')));
      return;
    }
    setState(() => _saving = true);
    final vault = await ref.read(secretVaultProvider.future);
    final now = DateTime.now();
    final entry = InsuranceTableCompanion(
      id: Value(
          widget.item?.id ?? DateTime.now().millisecondsSinceEpoch.toString()),
      title: Value(title),
      provider: Value(_providerCtrl.text.trim()),
      policyNo: Value(vault.encrypt(_policyCtrl.text.trim())),
      startDate: Value(_startCtrl.text.trim()),
      expiryDate: Value(_expiryCtrl.text.trim()),
      notes: Value(_notesCtrl.text.trim()),
      updatedAt: Value(now),
      createdAt: Value(widget.item?.createdAt ?? now),
    );
    await ref.read(personalInfoRepositoryProvider).upsertInsurance(entry);
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
                widget.item == null ? 'افزودن بیمه' : 'ویرایش بیمه',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _field(_titleCtrl, 'عنوان (مثلاً «بیمه تکمیلی درمان»)'),
            _field(_providerCtrl, 'شرکت بیمه'),
            _field(_policyCtrl, 'شماره بیمه‌نامه', encrypted: true),
            _dateField(_startCtrl, 'تاریخ شروع'),
            _dateField(_expiryCtrl, 'تاریخ پایان اعتبار'),
            _field(_notesCtrl, 'توضیحات', maxLines: 2),
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

  Widget _field(TextEditingController ctrl, String label,
      {bool encrypted = false, int maxLines = 1}) {
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
          suffixIcon:
              encrypted ? const Icon(Icons.lock_outline, size: 16) : null,
        ),
      ),
    );
  }

  Widget _dateField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        readOnly: true,
        onTap: () => _pickDate(ctrl),
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12)),
          border: const OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_month_outlined,
              size: 18, color: widget.accent),
        ),
      ),
    );
  }
}
