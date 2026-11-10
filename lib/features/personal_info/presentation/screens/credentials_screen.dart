import 'dart:math';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal_info/data/repositories/personal_info_repository_impl.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/secret_vault.dart';

/// «رمزها، کارت‌ها و حساب‌ها» — credentials (حساس، رمزشده).
class CredentialsScreen extends ConsumerStatefulWidget {
  const CredentialsScreen({super.key});

  @override
  ConsumerState<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends ConsumerState<CredentialsScreen> {
  final Color _accent = TopicHues.personalCredentials;
  List<CredentialTableData>? _items;
  String _category = 'all';
  bool _showSecrets = false;

  static const _categories = {
    'all': 'همه',
    'password': 'رمزها',
    'card': 'کارت‌ها',
    'bank': 'بانک',
    'social': 'شبکه اجتماعی',
    'email': 'ایمیل',
    'other': 'سایر',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(personalInfoRepositoryProvider);
    try {
      final all = await repo.getCredentials();
      if (mounted) setState(() => _items = all);
    } catch (e) {
      AppLogger.warning('credentials_screen', 'load failed: $e');
      if (mounted) {
        setState(() => _items = const []);
        AppSnackBar.error(context, 'بارگذاری داده‌ها ناموفق بود.');
      }
    }
  }

  List<CredentialTableData> _filtered(List<CredentialTableData> list) =>
      _category == 'all'
          ? list
          : list.where((c) => c.category == _category).toList();

  Future<void> _openEditor([CredentialTableData? c]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CredentialEditor(
        accent: _accent,
        credential: c,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  Future<void> _delete(CredentialTableData c) async {
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
    // The stored row holds ciphertext (username/password/extraJson are
    // encrypted on save), so re-inserting the exact row restores it faithfully
    // — no decrypt/re-encrypt round trip that could corrupt the secret.
    final snapshot = c.toCompanion(false);
    await ref.read(personalInfoRepositoryProvider).deleteCredential(c.id);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    _load();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('«${c.title}» حذف شد'),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        action: SnackBarAction(
          label: 'بازگردانی',
          onPressed: () async {
            await ref
                .read(personalInfoRepositoryProvider)
                .upsertCredential(snapshot);
            _load();
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final onPrimary = dsOnAccent(context);
    final items = _items;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'رمزها، کارت‌ها و حساب‌ها',
        actions: [
          IconButton(
            tooltip: _showSecrets ? 'پنهان کردن مقادیر' : 'نمایش مقادیر',
            icon: Icon(_showSecrets
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            onPressed: () => setState(() => _showSecrets = !_showSecrets),
          ),
        ],
      ),
      floatingActionButton: InsetFab(
        inset: MediaQuery.paddingOf(context).bottom,
        child: FloatingActionButton(
          tooltip: 'افزودن مورد',
          backgroundColor: t.primary,
          foregroundColor: onPrimary,
          onPressed: _openEditor,
          child: const Icon(Icons.add),
        ),
      ),
      body: SafeArea(
        child: items == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.page),
                      children: [
                        for (final entry in _categories.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ChoiceChip(
                              label: Text(entry.value,
                                  style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 12))),
                              selected: _category == entry.key,
                              onSelected: (_) =>
                                  setState(() => _category = entry.key),
                              visualDensity: VisualDensity.compact,
                              selectedColor: _accent.withValues(alpha: 0.2),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: _filtered(items).isEmpty
                        ? const Center(child: Text('موردی ثبت نشده'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                DsSpacing.page, 8, DsSpacing.page, 90),
                            itemCount: _filtered(items).length,
                            itemBuilder: (context, i) {
                              final c = _filtered(items)[i];
                              return _CredentialCard(
                                credential: c,
                                accent: _accent,
                                showSecrets: _showSecrets,
                                onTap: () => _openEditor(c),
                                onDelete: () => _delete(c),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CredentialCard extends ConsumerWidget {
  final CredentialTableData credential;
  final Color accent;
  final bool showSecrets;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _CredentialCard({
    required this.credential,
    required this.accent,
    required this.showSecrets,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final cipher = ref.watch(secretVaultProvider).value;
    String? dec(String v) => cipher == null ? null : decryptSafely(cipher, v);
    final username = dec(credential.username) ?? credential.username;
    final password = dec(credential.password) ?? credential.password;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        onLongPress: onDelete,
        borderColor: accent.withValues(alpha: 0.25),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_categoryIcon(credential.category), color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    credential.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 15),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  if (username.isNotEmpty && showSecrets) ...[
                    const SizedBox(height: 2),
                    Text(
                      'نام کاربری: $username',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                  if (password.isNotEmpty && showSecrets) ...[
                    const SizedBox(height: 2),
                    Text(
                      'رمز: $password',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (password.isNotEmpty)
              IconButton(
                tooltip: 'کپی رمز',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.copy_rounded,
                    size: 18, color: dsContentColor(context, accent)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: password));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('رمز کپی شد.')));
                },
              ),
            Icon(Icons.lock_outline, size: 16, color: t.textMuted),
            const SizedBox(width: 6),
            Icon(Icons.chevron_left, color: t.textMuted),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String cat) => switch (cat) {
        'password' => Icons.password_outlined,
        'card' => Icons.credit_card_outlined,
        'bank' => Icons.account_balance_outlined,
        'social' => Icons.share_outlined,
        'email' => Icons.mail_outline,
        _ => Icons.vpn_key_outlined,
      };
}

class _CredentialEditor extends ConsumerStatefulWidget {
  final Color accent;
  final CredentialTableData? credential;
  final VoidCallback onSaved;
  const _CredentialEditor({
    required this.accent,
    this.credential,
    required this.onSaved,
  });

  @override
  ConsumerState<_CredentialEditor> createState() => _CredentialEditorState();
}

class _CredentialEditorState extends ConsumerState<_CredentialEditor> {
  late final _titleCtrl =
      TextEditingController(text: widget.credential?.title ?? '');
  late final _usernameCtrl =
      TextEditingController(text: widget.credential?.username ?? '');
  late final _passwordCtrl =
      TextEditingController(text: widget.credential?.password ?? '');
  late final _extraCtrl =
      TextEditingController(text: widget.credential?.extraJson ?? '');
  late final _notesCtrl =
      TextEditingController(text: widget.credential?.notes ?? '');
  late String _category = widget.credential?.category ?? 'password';
  bool _saving = false;
  bool _showPass = false;

  @override
  void initState() {
    super.initState();
    final vault = ref.read(secretVaultProvider).asData?.value;
    if (vault != null) {
      if ((widget.credential?.username ?? '').isNotEmpty) {
        _usernameCtrl.text = vault.decrypt(widget.credential!.username);
      }
      if ((widget.credential?.password ?? '').isNotEmpty) {
        _passwordCtrl.text = vault.decrypt(widget.credential!.password);
      }
      if ((widget.credential?.extraJson ?? '').isNotEmpty) {
        _extraCtrl.text = vault.decrypt(widget.credential!.extraJson);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _extraCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _generatePassword() {
    final rng = Random.secure();
    const lower = 'abcdefghijklmnopqrstuvwxyz';
    const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const digits = '0123456789';
    const symbols = '!@#\$%^&*()-_=+[]{};:,.?';
    const all = lower + upper + digits + symbols;
    final pwd = StringBuffer();
    for (var i = 0; i < 14; i++) {
      pwd.write(all[rng.nextInt(all.length)]);
    }
    _passwordCtrl.text = pwd.toString();
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
    String enc(String v) => vault.encrypt(v);

    final entry = CredentialTableCompanion(
      id: Value(widget.credential?.id ??
          DateTime.now().millisecondsSinceEpoch.toString()),
      category: Value(_category),
      title: Value(title),
      username: Value(enc(_usernameCtrl.text.trim())),
      password: Value(enc(_passwordCtrl.text.trim())),
      extraJson: Value(enc(_extraCtrl.text.trim())),
      notes: Value(_notesCtrl.text.trim()),
      updatedAt: Value(now),
      createdAt: Value(widget.credential?.createdAt ?? now),
    );
    await ref.read(personalInfoRepositoryProvider).upsertCredential(entry);
    if (mounted) {
      setState(() => _saving = false);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const cats = {
      'password': 'رمز',
      'card': 'کارت',
      'bank': 'بانک',
      'social': 'شبکه اجتماعی',
      'email': 'ایمیل',
      'other': 'سایر',
    };
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
                widget.credential == null ? 'افزودن مورد' : 'ویرایش مورد',
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
                for (final e in cats.entries)
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
            _field(_titleCtrl, 'عنوان (مثلاً «رمز وای‌فای خانه»)'),
            _field(_usernameCtrl, 'نام کاربری / شماره / ایمیل',
                encrypted: true),
            TextField(
              controller: _passwordCtrl,
              obscureText: !_showPass,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                labelText: 'رمز / PIN',
                labelStyle: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12)),
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'تولید رمز تصادفی',
                      icon: Icon(Icons.casino_outlined,
                          size: 18, color: widget.accent),
                      onPressed: _generatePassword,
                    ),
                    IconButton(
                      icon: Icon(
                          _showPass ? Icons.visibility_off : Icons.visibility,
                          size: 18),
                      tooltip:
                          _showPass ? 'پنهان کردن رمز' : 'نمایش رمز',
                      onPressed: () => setState(() => _showPass = !_showPass),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _field(_extraCtrl, 'اطلاعات تکمیلی (شماره کارت، CVV، شبا…)',
                encrypted: true, maxLines: 2),
            _field(_notesCtrl, 'توضیحات', maxLines: 2),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: widget.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'نام کاربری، رمز و اطلاعات تکمیلی رمزنگاری می‌شوند.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted,
                    ),
                  ),
                ),
              ],
            ),
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
}
