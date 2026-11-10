import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/features/announcements/domain/entities/announcement.dart';
import 'package:tawheeed/features/announcements/domain/repositories/announcements_repository.dart';
import 'package:tawheeed/features/announcements/presentation/providers/announcements_providers.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/shared/widgets/service_unavailable_banner.dart';
import 'package:tawheeed/shared/widgets/expandable_text.dart';

/// صفحهٔ «پیام‌های مدیریت».
///
/// همهٔ کاربران پیام‌های منتشرشده را می‌خوانند؛ بخش مدیریت (انتشار، سنجاق و
/// حذف) با همان حساب Firebase Auth پنل پیشنهادها باز می‌شود.
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  bool _adminUnlocked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _restoreAdminSession();
  }

  /// جلسهٔ Firebase Auth ماندگار است؛ اگر مدیر قبلاً وارد شده باشد دیگر
  /// لازم نیست ایمیل/رمز را دوباره تایپ کند.
  Future<void> _restoreAdminSession() async {
    try {
      final ok = await ref.read(announcementsAdminGateProvider).isAdminActive();
      if (mounted && ok) setState(() => _adminUnlocked = true);
    } catch (_) {
      // Firebase/اینترنت در دسترس نیست — بی‌صدا بگذر.
    }
  }

  Future<void> _promptAdminLogin() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _AdminLoginDialog(),
    );
    if (ok == true && mounted) {
      setState(() => _adminUnlocked = true);
    }
  }

  Future<void> _lockAdmin() async {
    setState(() => _adminUnlocked = false);
    await ref.read(announcementsAdminGateProvider).signOut();
  }

  Future<void> _promptPublish() async {
    final payload = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => const _PublishDialog(),
    );
    if (payload == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(announcementsRepositoryProvider)
          .publish(title: payload.$1, body: payload.$2);
      if (!mounted) return;
      AppSnackBar.success(context, 'پیام منتشر شد.');
    } on AnnouncementsWriteError catch (e) {
      AppLogger.error('AnnouncementsScreen', 'publish failed: $e');
      if (mounted) AppSnackBar.error(context, e.message);
    } catch (e) {
      AppLogger.error('AnnouncementsScreen', 'publish failed: $e');
      if (mounted) {
        AppSnackBar.error(context, 'انتشار ناموفق بود؛ دوباره تلاش کنید.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _togglePin(Announcement a, bool value) async {
    try {
      await ref.read(announcementsRepositoryProvider).setPinned(a.id, value);
      if (mounted) {
        AppSnackBar.success(
            context, value ? 'پیام سنجاق شد.' : 'سنجاق پیام لغو شد.');
      }
    } on AnnouncementsWriteError catch (e) {
      AppLogger.error('AnnouncementsScreen', 'toggle pin failed: $e');
      if (mounted) AppSnackBar.error(context, e.message);
    } catch (e) {
      AppLogger.error('AnnouncementsScreen', 'toggle pin failed: $e');
      if (mounted) {
        AppSnackBar.error(context, 'تغییر ناموفق بود؛ دوباره تلاش کنید.');
      }
    }
  }

  Future<void> _promptEdit(Announcement a) async {
    final payload = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => _EditDialog(title: a.title, body: a.body),
    );
    if (payload == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(announcementsRepositoryProvider)
          .update(id: a.id, title: payload.$1, body: payload.$2);
      if (mounted) AppSnackBar.success(context, 'پیام ویرایش شد.');
    } on AnnouncementsWriteError catch (e) {
      AppLogger.error('AnnouncementsScreen', 'update failed: $e');
      if (mounted) AppSnackBar.error(context, e.message);
    } catch (e) {
      AppLogger.error('AnnouncementsScreen', 'update failed: $e');
      if (mounted) {
        AppSnackBar.error(context, 'ویرایش ناموفق بود؛ دوباره تلاش کنید.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete(Announcement a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف پیام'),
        content: Text('«${a.title}» برای همیشه حذف شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لغو')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(announcementsRepositoryProvider).delete(a.id);
      if (mounted) AppSnackBar.success(context, 'حذف شد.');
    } on AnnouncementsWriteError catch (e) {
      AppLogger.error('AnnouncementsScreen', 'delete failed: $e');
      if (mounted) AppSnackBar.error(context, e.message);
    } catch (e) {
      AppLogger.error('AnnouncementsScreen', 'delete failed: $e');
      if (mounted) {
        AppSnackBar.error(context, 'حذف ناموفق بود؛ دوباره تلاش کنید.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final repo = ref.watch(announcementsRepositoryProvider);
    final available = repo.isAvailable;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'پیام‌های مدیریت'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'اطلاعیه‌ها و پیام‌های رسمی برنامه در این بخش نمایش داده می‌شود.',
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            if (!available)
              // سکوتِ کامل به‌جای فهرست خالی گمراه‌کننده بود؛ بنر صریح دلیل
              // را می‌گوید و کاربر می‌داند اتصال را چک کند.
              const ServiceUnavailableBanner(
                detail:
                    'دریافت پیام‌های مدیریت به سرویس ابری متصل است که هم‌اکنون '
                    'در دسترس نیست؛ اتصال اینترنت را بررسی کنید و دوباره '
                    'وارد صفحه شوید.',
              )
            else
              _buildList(context),
            const SizedBox(height: 20),
            // ── پنل مدیریت ──
            if (available) ...[
              _adminHeader(),
              const SizedBox(height: 8),
              if (_adminUnlocked)
                _buildAdminPanel(context)
              else
                _card(
                  context,
                  children: [
                    Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.lock_outline, color: t.primary),
                        title: const Text('ورود به پنل مدیریت'),
                        subtitle: const Text('برای انتشار پیام وارد شوید'),
                        trailing: Icon(Icons.chevron_left, color: t.textMuted),
                        onTap: _promptAdminLogin,
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final stream = ref.watch(announcementsStreamProvider);
    return stream.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator())),
      // A failed read is said as a failure, not as «no messages» — and it
      // offers the one action that can fix it.
      error: (_, __) => _errorState(
        context,
        'دریافت پیام‌ها ممکن نشد',
        id: 'announcements_list',
        onRetry: () => ref.invalidate(announcementsStreamProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _emptyState(
            context,
            Icons.campaign_outlined,
            'هنوز پیامی منتشر نشده است.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final a in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _announcementRow(context, a),
              ),
          ],
        );
      },
    );
  }

  /// یک پیام در فهرست کاربران؛ پیام‌های سنجاق‌شده رنگ و کادر متفاوت می‌گیرند.
  Widget _announcementRow(BuildContext context, Announcement a) {
    final t = TimeThemeKit.of(context).palette;
    final j = Jalali.fromDateTime(a.createdAt);
    final primary = t.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: a.isPinned ? primary.withValues(alpha: 0.06) : t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: a.isPinned ? primary.withValues(alpha: 0.35) : (t.outline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.campaign_outlined, size: 19, color: primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(a.title,
                              style: TextStyle(
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 14),
                                  fontWeight: FontWeight.w700,
                                  color: t.textPrimary)),
                        ),
                        if (a.isPinned) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.push_pin,
                              size: 15, color: AppTheme.doneColor),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(jalaliYmdShort(j),
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 10),
                            color: t.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ExpandableText(
            a.body,
            maxLines: 3,
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 13),
              height: 1.8,
              color: t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminHeader() {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        Icon(Icons.admin_panel_settings_outlined, size: 20, color: t.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text('پنل مدیریت',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary)),
        ),
        if (_adminUnlocked) ...[
          TextButton.icon(
            onPressed: _busy ? null : _promptPublish,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('پیام جدید'),
          ),
          TextButton(
            onPressed: _lockAdmin,
            child: const Text('قفل'),
          ),
        ],
      ],
    );
  }

  Widget _buildAdminPanel(BuildContext context) {
    final stream = ref.watch(announcementsStreamProvider);
    return stream.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator())),
      // A failed read is said as a failure, not as «no messages» — and it
      // offers the one action that can fix it.
      error: (_, __) => _errorState(
        context,
        'دریافت پیام‌ها ممکن نشد',
        id: 'announcements_admin',
        onRetry: () => ref.invalidate(announcementsStreamProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _emptyState(
            context,
            Icons.campaign_outlined,
            'پیامی برای مدیریت منتشر نشده است.',
          );
        }
        return _card(
          context,
          children: [
            for (final a in items) ...[
              _adminRow(context, a),
              const Divider(height: 1),
            ],
          ],
        );
      },
    );
  }

  /// ردیف مدیریت: ویرایش/سنجاق/حذف همراه با پیش‌نمایش متن پیام.
  Widget _adminRow(BuildContext context, Announcement a) {
    final t = TimeThemeKit.of(context).palette;
    final j = Jalali.fromDateTime(a.createdAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(jalaliYmdShort(j),
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 10),
                                color: t.textMuted)),
                        if (a.isPinned) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.push_pin,
                              size: 12, color: AppTheme.doneColor),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'ویرایش',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.edit_outlined, size: 19, color: t.primary),
                onPressed: _busy ? null : () => _promptEdit(a),
              ),
              IconButton(
                tooltip: 'حذف',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_outline,
                    size: 19, color: Theme.of(context).colorScheme.error),
                onPressed: _busy ? null : () => _confirmDelete(a),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ExpandableText(
            a.body,
            maxLines: 2,
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 12),
              height: 1.6,
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text('سنجاق',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted)),
              Switch(value: a.isPinned, onChanged: (v) => _togglePin(a, v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, IconData icon, String message) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(icon, size: 34, color: t.textMuted),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  color: t.textMuted)),
        ],
      ),
    );
  }

  Widget _errorState(
    BuildContext context,
    String title, {
    required VoidCallback onRetry,
    String id = 'announcements_load',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: FailureView(
        id: id,
        title: title,
        detail: 'پیام‌ها پاک نشده‌اند؛ فقط این فهرست باز نشد.',
        onRetry: onRetry,
        layout: FailureLayout.page,
        icon: Icons.cloud_off_outlined,
      ),
    );
  }

  Widget _card(BuildContext context, {required List<Widget> children}) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkOutline
                : AppTheme.lightOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// دیالوگ ورود مدیر؛ کنترلرهای متن را خودش نگه می‌دارد تا در چرخهٔ عمر
/// درست آزاد شوند.
class _AdminLoginDialog extends ConsumerStatefulWidget {
  const _AdminLoginDialog();

  @override
  ConsumerState<_AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends ConsumerState<_AdminLoginDialog> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _error = '';
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final allowed = await ref
          .read(announcementsAdminGateProvider)
          .signIn(_emailCtrl.text, _passCtrl.text);
      if (!mounted) return;
      if (allowed) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _busy = false;
          _error = 'این حساب دسترسی مدیر ندارد.';
        });
      }
    } catch (e) {
      AppLogger.error('AnnouncementsLoginDialog', 'admin login failed: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'ورود ناموفق بود؛ ایمیل یا رمز را بررسی کنید.';
      });
    }
  }

  Future<void> _submitWithGoogle() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final allowed =
          await ref.read(announcementsAdminGateProvider).signInWithGoogle();
      if (!mounted) return;
      if (allowed == null) {
        // کاربر انتخاب‌گر را بست — خطایی نشان نده.
        setState(() => _busy = false);
      } else if (allowed) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _busy = false;
          _error = 'این حساب دسترسی مدیر ندارد.';
        });
      }
    } catch (e) {
      AppLogger.error('AnnouncementsLoginDialog', 'google login failed: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'ورود با گوگل ناموفق بود؛ دوباره تلاش کنید.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ورود به پنل مدیریت'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'ایمیل مدیر'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'رمز عبور'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('یا',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: Theme.of(context).colorScheme.outline)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _submitWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 26),
              label: const Text('ورود با حساب گوگل'),
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_error,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('ورود'),
        ),
      ],
    );
  }
}

/// دیالوگ انتشار پیام؛ کنترلرهای متن را خودش نگه می‌دارد تا در چرخهٔ عمر
/// درست آزاد شوند.
class _PublishDialog extends StatefulWidget {
  const _PublishDialog();

  @override
  State<_PublishDialog> createState() => _PublishDialogState();
}

class _PublishDialogState extends State<_PublishDialog> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _error = 'هم عنوان و هم متن پیام لازم است.');
      return;
    }
    Navigator.pop(context, (title, body));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('پیام جدید'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            maxLength: kAnnouncementMaxTitleLength,
            decoration: const InputDecoration(
              labelText: 'عنوان',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bodyCtrl,
            maxLines: 4,
            maxLength: kAnnouncementMaxBodyLength,
            decoration: const InputDecoration(
              labelText: 'متن پیام',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error.isNotEmpty)
            Text(_error,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: Theme.of(context).colorScheme.error)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('انتشار'),
        ),
      ],
    );
  }
}

/// دیالوگ ویرایش یک پیام؛ با مقادیر فعلی پر می‌شود و همان محدودیت‌های انتشار
/// را اعمال می‌کند.
class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.title, required this.body});

  final String title;
  final String body;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.title);
  late final TextEditingController _bodyCtrl =
      TextEditingController(text: widget.body);
  String _error = '';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _error = 'هم عنوان و هم متن پیام لازم است.');
      return;
    }
    Navigator.pop(context, (title, body));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ویرایش پیام'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            maxLength: kAnnouncementMaxTitleLength,
            decoration: const InputDecoration(
              labelText: 'عنوان',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bodyCtrl,
            maxLines: 4,
            maxLength: kAnnouncementMaxBodyLength,
            decoration: const InputDecoration(
              labelText: 'متن پیام',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error.isNotEmpty)
            Text(_error,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: Theme.of(context).colorScheme.error)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('ذخیره'),
        ),
      ],
    );
  }
}
