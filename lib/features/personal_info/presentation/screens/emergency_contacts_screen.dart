import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal_info/data/repositories/personal_info_repository_impl.dart';

/// «تماس‌های اضطراری».
class EmergencyContactsScreen extends ConsumerStatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  ConsumerState<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState
    extends ConsumerState<EmergencyContactsScreen> {
  final Color _accent = TopicHues.personalEmergency;
  List<EmergencyContactTableData>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(personalInfoRepositoryProvider);
    try {
      final all = await repo.getEmergencyContacts();
      if (mounted) setState(() => _items = all);
    } catch (e) {
      AppLogger.warning('emergency_contacts_screen', 'load failed: $e');
      if (mounted) {
        setState(() => _items = const []);
        AppSnackBar.error(context, 'بارگذاری داده‌ها ناموفق بود.');
      }
    }
  }

  Future<void> _openEditor([EmergencyContactTableData? c]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ContactEditor(
        accent: _accent,
        contact: c,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  Future<void> _delete(EmergencyContactTableData c) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف این تماس؟'),
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
    await ref.read(personalInfoRepositoryProvider).deleteEmergencyContact(c.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final onPrimary = dsOnAccent(context);
    final items = _items;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'تماس‌های اضطراری'),
      floatingActionButton: InsetFab(
        inset: MediaQuery.paddingOf(context).bottom,
        child: FloatingActionButton(
          tooltip: 'افزودن تماس اضطراری',
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
                        const Icon(Icons.emergency_outlined, size: 56),
                        const SizedBox(height: 12),
                        Text(
                          'تماس اضطراری ثبت نشده',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 15),
                            fontWeight: FontWeight.w700,
                            color: t.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'افرادی که در لحظهٔ نیاز در دسترس‌اند را اضافه کنید.',
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
                      final c = items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          padding: const EdgeInsets.all(14),
                          onTap: () => _openEditor(c),
                          onLongPress: () => _delete(c),
                          borderColor: _accent.withValues(alpha: 0.25),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.emergency_outlined,
                                    color: _accent),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.name,
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: AppTheme.scaledFontSize(
                                            context, 15),
                                        fontWeight: FontWeight.w700,
                                        color: t.textPrimary,
                                      ),
                                    ),
                                    if (c.relation.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        c.relation,
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: AppTheme.scaledFontSize(
                                              context, 11),
                                          color: t.textMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'تماس',
                                icon: Icon(Icons.call_outlined,
                                    size: 18, color: _accent),
                                onPressed: () async {
                                  final uri = Uri(scheme: 'tel', path: c.phone);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri,
                                        mode: LaunchMode.externalApplication);
                                  } else if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'امکان تماس وجود ندارد.')));
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: 'کپی شماره',
                                icon: Icon(Icons.copy_outlined,
                                    size: 18, color: t.textMuted),
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: c.phone));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('شماره کپی شد.')));
                                },
                              ),
                              Icon(Icons.chevron_left, color: t.textMuted),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _ContactEditor extends ConsumerStatefulWidget {
  final Color accent;
  final EmergencyContactTableData? contact;
  final VoidCallback onSaved;
  const _ContactEditor({
    required this.accent,
    this.contact,
    required this.onSaved,
  });

  @override
  ConsumerState<_ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends ConsumerState<_ContactEditor> {
  late final _nameCtrl =
      TextEditingController(text: widget.contact?.name ?? '');
  late final _phoneCtrl =
      TextEditingController(text: widget.contact?.phone ?? '');
  late final _relationCtrl =
      TextEditingController(text: widget.contact?.relation ?? '');
  late final _notesCtrl =
      TextEditingController(text: widget.contact?.notes ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _relationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('نام و شماره تماس را وارد کنید.')));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final entry = EmergencyContactTableCompanion(
      id: Value(widget.contact?.id ??
          DateTime.now().millisecondsSinceEpoch.toString()),
      name: Value(name),
      phone: Value(phone),
      relation: Value(_relationCtrl.text.trim()),
      notes: Value(_notesCtrl.text.trim()),
      updatedAt: Value(now),
      createdAt: Value(widget.contact?.createdAt ?? now),
    );
    await ref
        .read(personalInfoRepositoryProvider)
        .upsertEmergencyContact(entry);
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
                widget.contact == null ? 'افزودن تماس' : 'ویرایش تماس',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _field(_nameCtrl, 'نام و نام خانوادگی'),
            _field(_phoneCtrl, 'شماره تماس', keyboard: TextInputType.phone),
            _field(_relationCtrl, 'نسبت (مثلاً همسر، برادر...)'),
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
      {TextInputType? keyboard, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        textDirection: TextDirection.rtl,
        maxLines: maxLines,
        keyboardType: keyboard,
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
