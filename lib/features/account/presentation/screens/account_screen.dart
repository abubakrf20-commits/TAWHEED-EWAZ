import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/constants/legal_links.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/account/domain/entities/cloud_backup_item.dart';
import 'package:tawheeed/features/account/domain/auth_error_messages.dart';
import 'package:tawheeed/features/account/presentation/providers/account_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/widgets/cloud_backup_sheet.dart';
import 'package:tawheeed/features/settings/presentation/widgets/local_backup_section.dart';
import 'package:tawheeed/features/settings/presentation/widgets/restore_flow.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_flash.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_transfer_section.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart'
    show SettingsDivider;
import 'package:tawheeed/features/settings/services/backup_service.dart';
import 'package:tawheeed/features/settings/services/drive_backup_service.dart';
import 'package:tawheeed/features/settings/services/google_auth_service.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';

/// حساب و پشتیبان — the single hub for everything the old three places
/// split apart: sign-in, both clouds, the on-device backup doors, settings
/// transfer, and the danger zone (reset / wipe / delete-account). The
/// settings page keeps a single nav tile here; search lands on the sections
/// below through [accountHighlightKeys].
class AccountScreen extends ConsumerStatefulWidget {
  /// Search landing anchors for the individual sections of this hub. The
  /// settings registry asserts its account-page rowKeys are all in this set,
  /// so a renamed or removed section fails loudly instead of landing on a
  /// dead anchor.
  static const accountHighlightKeys = <String>{
    'signin',
    'cloud-drive',
    'cloud-app',
    'local',
    'transfer',
    'danger',
  };

  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen>
    with SettingsHighlight<AccountScreen> {
  late final Map<String, GlobalKey> _anchors = {
    for (final key in AccountScreen.accountHighlightKeys) key: GlobalKey(),
  };

  @override
  Map<String, GlobalKey> get highlightAnchors => _anchors;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    bindSettingsHighlight();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _backupPasswordCtrl.dispose();
    disposeSettingsHighlight();
    super.dispose();
  }
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  /// Controller of the backup-password dialog. It must outlive the dialog's
  /// pop animation (the route keeps the TextField mounted for a few frames
  /// after `showDialog` returns), so it is owned by the State and disposed
  /// with it instead of being disposed right after the dialog closes.
  final _backupPasswordCtrl = TextEditingController();
  bool _signUpMode = false;
  bool _busy = false;
  String? _error;

  List<CloudBackupItem>? _backups;
  bool _listing = false;
  bool _listError = false;
  String? _busyName;

  bool get _firebaseAvailable => Firebase.apps.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_firebaseAvailable) {
      Future.microtask(_refreshBackups);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // The reset path trims; an untrimmed submit fails as `invalid-email`
    // on a trailing space instead of signing in.
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(accountRepositoryProvider);
      if (_signUpMode) {
        await repo.signUpWithEmail(email, password);
      } else {
        await repo.signInWithEmail(email, password);
      }
      // The backup card appears on the stream rebuild with a stale (null)
      // list — pull it now so the user sees their cloud copies immediately.
      await _refreshBackups();
    } catch (e) {
      AppLogger.warning('account_screen', 'error: $e');
      // The await above can outlive the route — setState on a disposed state
      // throws, so the error text needs the same guard the `finally` has.
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
      });
      AppLogger.warning('Account', 'submit failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// ارسال ایمیل بازیابی رمز به ایمیل واردشده در فرم.
  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(
          () => _error = 'برای بازیابی رمز، ابتدا ایمیل حساب را وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider).sendPasswordResetEmail(email);
      if (!mounted) return;
      AppSnackBar.success(context,
          'ایمیل بازیابی رمز به $email ارسال شد. صندوق ورودی و اسپم را ببینید.');
    } catch (e) {
      AppLogger.warning('Account', 'password reset failed: $e');
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// پیام خطای شفاف و فارسی برای رایج‌ترین خطاهای احراز هویت.
  ///
  /// Audit U8: the per-code copy and the offline/config distinction now live
  /// in [AuthErrorMessages] (testable without pumping this screen); this
  /// method stays as the screen-local entry point.
  String _friendlyError(Object e) => AuthErrorMessages.map(e);

  /// ورود یک‌ضربهای با حساب گوگل: نشست Drive (نسخه‌های ابری) + نشست
  /// Firebase (شناسهٔ ابری و فهرست پشتیبان‌های برنامه) با همان یک ضربه به
  /// هم گره می‌خورند، پس هر گوشی با همان حساب گوگل همان ابرها را می‌بیند.
  /// توکن همان احراز هویت Drive دوباره استفاده می‌شود تا انتخاب‌گر حساب
  /// گوگل دو بار باز نشود. اگر پیوند Firebase ناموفق باشد (مثلاً ایمیل
  /// قبلاً با رمز ثبت شده)، نشست Drive سر جایش می‌ماند و فقط دلیلش گفته
  /// می‌شود — ورود گوگل هرگز به‌خاطر آن کاملاً نمی‌میرد.
  Future<void> _signInGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final gUser = await GoogleAuthService.instance.signIn();
      try {
        await ref.read(accountRepositoryProvider).signInWithGoogle(
              idToken: gUser.authentication.idToken,
            );
      } catch (e) {
        AppLogger.warning('Account', 'firebase link failed: $e');
        if (mounted) {
          final reason = _friendlyError(e);
          setState(() {
            _error = reason;
          });
          // Drive succeeded, so the signed-in layout is on screen — `_error`
          // only renders inside the signed-out auth forms and would be
          // invisible. Say it where the user is actually looking.
          AppSnackBar.error(
            context,
            e is StateError
                ? reason
                : 'ورود گوگل انجام شد، اما اتصال ابری برنامه برقرار نشد؛ دوباره تلاش کنید.',
          );
        }
      }
      // Same staleness as the email path: pull the Firebase list now that
      // the (possibly linked) session exists.
      await _refreshBackups();
    } catch (e) {
      // انصراف کاربر بی‌صدا می‌ماند؛ بقیه خطاها نمایش داده می‌شوند.
      // Both spellings: platform plugins disagree on canceled/cancelled,
      // and some builds localize the message.
      final msg = e.toString().toLowerCase();
      if (!msg.contains('canceled') && !msg.contains('cancelled')) {
        if (mounted) {
          setState(() {
            _error = _friendlyError(e);
          });
        }
        AppLogger.warning('Account', 'google submit failed: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('خروج از حساب'),
        content: const Text(
            'نسخه‌های ابری در Google Drive و فضای ابری برنامه می‌مانند؛ فقط ارتباط این دستگاه قطع می‌شود.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لغو')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('خروج')),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    var failed = false;
    try {
      // Each session is cleared independently. A Drive failure must not skip
      // the Firebase sign-out, and Firebase is never gated on the email
      // stream: that value can be stale right after a fresh sign-in, which
      // left the app-cloud session alive after a «خروج» the user believed.
      if (GoogleAuthService.instance.account.value != null) {
        try {
          await GoogleAuthService.instance.signOut();
        } catch (e) {
          failed = true;
          AppLogger.warning('Account', 'drive sign out failed: $e');
        }
      }
      try {
        await ref.read(accountRepositoryProvider).signOut();
      } catch (e) {
        failed = true;
        AppLogger.warning('Account', 'firebase sign out failed: $e');
      }
      if (mounted) {
        _passwordCtrl.clear();
        setState(() => _backups = null);
        if (failed) {
          AppSnackBar.error(context, 'خروج ناموفق بود؛ دوباره تلاش کنید.');
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// حذف کامل حساب کاربری (الزام Google Play): شناسهٔ Firebase + نسخه‌های
  /// Storage + نسخه‌های پوشهٔ مخفی Drive + قطع دسترسی Drive، به همین ترتیب.
  /// Drive بعد از حذف موفق Firebase پاک می‌شود (نه قبلش): اگر حذف شناسه به
  /// «ورود مجدد» نیاز داشته باشد و ناموفق بماند، فایل‌های Drive نباید از
  /// قبل رفته باشند. همهٔ مراحل Drive بهترین‌تلاش‌اند — حذف حساب هرگز
  /// به‌خاطر آن‌ها نمی‌میرد. داده‌های روی همین دستگاه پاک نمی‌شود.
  Future<void> _deleteAccount() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final error = isDark ? AppTheme.darkError : AppTheme.lightError;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف حساب کاربری'),
        content: const Text(
            'با تأیید، حساب کاربری، نسخه‌های پشتیبانِ فضای ابری برنامه و '
            'نسخه‌های Google Drive برای همیشه حذف می‌شوند و دسترسی Drive '
            'قطع می‌شود. داده‌های روی همین دستگاه پاک نمی‌شود. این کار '
            'برگشت‌ناپذیر است.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لغو')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف قطعی')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider).deleteAccount();
      // The Firebase identity is gone: now wipe the hidden Drive folder
      // (best-effort) and revoke Drive access server-side.
      await _purgeDriveBackups();
      if (GoogleAuthService.instance.account.value != null) {
        await GoogleAuthService.instance.disconnect();
      }
      if (!mounted) return;
      _passwordCtrl.clear();
      setState(() => _backups = null);
      AppSnackBar.success(context, 'حساب کاربری حذف شد.');
    } catch (e) {
      AppLogger.error('Account', 'delete account failed: $e');
      if (mounted) AppSnackBar.error(context, _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Deletes every backup in the hidden Drive folder. Best-effort by design:
  /// both list and delete swallow their own errors, so this never throws and
  /// never blocks the account deletion it accompanies.
  Future<void> _purgeDriveBackups() async {
    try {
      if (GoogleAuthService.instance.account.value == null) return;
      final files = await DriveBackupService.instance.listBackups();
      for (final f in files) {
        await DriveBackupService.instance.deleteBackup(f.fileId);
      }
      if (files.isNotEmpty) {
        AppLogger.info(
            'Account', 'purged ${files.length} Drive backup(s) on delete');
      }
    } catch (e) {
      AppLogger.warning('Account', 'drive purge failed: $e');
    }
  }

  // ─── نسخهٔ ابری Google Drive ────────────────────────────────────

  /// ساخت ZIP کامل و آپلود آن در پوشهٔ مخفی Drive (همگام با تعویض گوشی).
  Future<void> _uploadToDrive() async {
    final password = await _askUploadPassword();
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final file = await BackupService().exportBackup(
          password: password.isEmpty ? null : password);
      await DriveBackupService.instance.uploadBackup(file);
      if (mounted) {
        AppSnackBar.success(
            context, 'نسخهٔ پشتیبان در Google Drive ذخیره شد.');
      }
    } catch (e) {
      AppLogger.error('Account', 'drive upload failed: $e');
      if (mounted) {
        AppSnackBar.error(
            context, 'آپلود ناموفق بود: ${_friendlyError(e)}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// فهرست نسخه‌های ابری Drive (الگوی Settings) با بازیابی/حذف.
  Future<void> _openDriveCloudList() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => CloudBackupSheet(
          onPick: _restoreFromDrive,
        ),
      ),
    );
  }

  Future<void> _restoreFromDrive(String zipPath, String displayName) async {
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final result = await restoreZipAndRepair(
        context: context,
        ref: ref,
        path: zipPath,
        confirmTitle: 'بازگردانی از نسخه ابری',
        confirmBody: 'تمام اطلاعات فعلی با نسخه «$displayName» از Google Drive '
            'جایگزین می‌شود.',
      );
      if (!mounted) return;
      if (result.applied) {
        AppSnackBar.success(
            context, 'بازیابی انجام شد؛ برنامه را دوباره باز کنید.');
      } else if (result.error != null) {
        AppSnackBar.error(context, 'بازیابی ناموفق بود.');
      }
    } catch (e) {
      AppLogger.error('Account', 'drive restore failed: $e');
      if (mounted) {
        AppSnackBar.error(context, 'بازیابی ناموفق بود.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Optional password for a cloud upload: without it the ZIP rides to the
  /// user's private Drive/Storage as-is (like every cloud copy before);
  /// with it the file is AES-encrypted first, same as the settings backup.
  /// Returns null when the dialog is dismissed (abort the upload).
  /// Uses the State-owned [_backupPasswordCtrl]: a local controller disposed
  /// right after `showDialog` returns fires "used after dispose" — the route
  /// keeps the TextField mounted for a few pop-animation frames.
  Future<String?> _askUploadPassword() async {
    if (!mounted) return null;
    _backupPasswordCtrl.clear();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('رمز اختیاری پشتیبان',
            style: TextStyle(fontFamily: AppTheme.fontFamily)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اگر رمز بگذارید، نسخهٔ ابری رمزنگاری می‌شود. «ادامه بدون رمز» یعنی بدون رمزنگاری.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _backupPasswordCtrl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'رمز (اختیاری)',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('ادامه بدون رمز')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, _backupPasswordCtrl.text),
              child: const Text('ادامه با رمز')),
        ],
      ),
    );
  }

  Future<void> _refreshBackups() async {
    // Read the synchronous auth state, not the stream snapshot: right after
    // a sign-in the stream has not re-emitted yet, so the provider value is
    // still the signed-out one and the list would stay stale.
    final email = ref.read(accountRepositoryProvider).currentAccountLabel ??
        ref.read(accountEmailProvider).value;
    if (email == null) {
      if (mounted) setState(() => _backups = null);
      return;
    }
    setState(() {
      _listing = true;
      _listError = false;
    });
    try {
      final dir = await getTemporaryDirectory();
      final items = await ref.read(accountRepositoryProvider).listBackups(dir);
      if (mounted) setState(() => _backups = items);
    } catch (e) {
      AppLogger.warning('Account', 'list failed: $e');
      if (mounted) {
        setState(() {
          _backups = null;
          _listError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _listing = false);
    }
  }

  Future<void> _uploadNow() async {
    final password = await _askUploadPassword();
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final file = await BackupService().exportBackup(
          password: password.isEmpty
              ? null
              : password); // شامل همهٔ آمارها و تنظیمات
      await ref.read(accountRepositoryProvider).uploadBackup(file);
      if (mounted) {
        AppSnackBar.success(context, 'نسخهٔ پشتیبان در ابر ذخیره شد.');
        await _refreshBackups();
      }
    } catch (e) {
      AppLogger.error('Account', 'upload failed: $e');
      if (mounted) {
        AppSnackBar.error(context, 'آپلود ناموفق بود؛ دوباره تلاش کنید.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(CloudBackupItem item) async {
    if (!mounted) return;
    final caveat = await BackupService.vaultRestoreCaveat();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازیابی نسخه ابری'),
        content: Text('داده‌های فعلی روی گوشی با «${item.name}» جایگزین شوند؟'
            '$caveat'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('لغو')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('بازیابی')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyName = item.name);
    try {
      final tempDir = await getTemporaryDirectory();
      final repo = ref.read(accountRepositoryProvider);
      final zipPath = await repo.downloadBackup(item, tempDir);
      if (!mounted) return;
      final result = await applyZipRestore(
        context: context,
        ref: ref,
        path: zipPath,
      );
      if (!mounted) return;
      if (result.applied) {
        AppSnackBar.success(
            context, 'بازیابی انجام شد؛ برنامه را دوباره باز کنید.');
      } else if (result.error != null) {
        AppSnackBar.error(context, 'بازیابی ناموفق بود.');
      }
    } catch (e) {
      AppLogger.error('Account', 'restore failed: $e');
      if (mounted) {
        AppSnackBar.error(context, 'بازیابی ناموفق بود.');
      }
    } finally {
      if (mounted) setState(() => _busyName = null);
    }
  }

  Future<void> _delete(CloudBackupItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف نسخه ابری'),
        content: Text('«${item.name}» از ابر حذف شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('لغو')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyName = item.name);
    try {
      await ref.read(accountRepositoryProvider).deleteBackup(item);
      if (mounted) await _refreshBackups();
    } catch (e) {
      AppLogger.warning('Account', 'delete failed: $e');
      if (mounted) {
        AppSnackBar.error(context, 'حذف نسخهٔ ابری ناموفق بود.');
      }
    } finally {
      if (mounted) setState(() => _busyName = null);
    }
  }

  /// The same KB/MB/GB ladder the settings storage page prints, grouped by
  /// thousands — but NOT `NumberFormat.formatBytes`, which wraps its answer in
  /// the LTR isolate marks this list's rows do not carry.
  String _size(int bytes) {
    if (bytes <= 0) return '0KB';
    if (bytes < 1048576) {
      return '${NumberFormat.groupDigits((bytes / 1024).toStringAsFixed(0))}KB';
    }
    if (bytes < 1073741824) {
      return '${NumberFormat.groupDigits((bytes / 1048576).toStringAsFixed(1))}MB';
    }
    return '${NumberFormat.groupDigits((bytes / 1073741824).toStringAsFixed(1))}GB';
  }

  @override
  Widget build(BuildContext context) {
    final emailAsync = ref.watch(accountEmailProvider);
    final firebaseEmail = emailAsync.value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SettingsAppBar(title: 'حساب و پشتیبان'),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: GoogleAuthService.instance.account,
          builder: (context, googleAccount, _) {
            final signedIn = googleAccount != null || firebaseEmail != null;
            return ListView(
              controller: highlightScrollController,
              padding: const EdgeInsets.fromLTRB(
                  DsSpacing.page, 4, DsSpacing.page, 32),
              children: [
                if (!signedIn)
                  Column(
                    key: _anchors['signin'],
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildAuthForms(context),
                  )
                else ...[
                  Column(
                    key: _anchors['signin'],
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _accountHeader(
                        context,
                        googleAccount?.email ?? firebaseEmail!,
                        secondEmail:
                            googleAccount != null ? firebaseEmail : null,
                      ),
                    ],
                  ),
                  if (googleAccount != null) ...[
                    const SizedBox(height: 20),
                    SettingsFlashSection(
                      rowKey: 'cloud-drive',
                      flashKey: highlightFlashKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            key: _anchors['cloud-drive'],
                            title: 'Google Drive',
                            margin: const EdgeInsets.only(bottom: 8),
                          ),
                          _googleCloudSection(context),
                        ],
                      ),
                    ),
                  ],
                  if (firebaseEmail != null) ...[
                    const SizedBox(height: 16),
                    SettingsFlashSection(
                      rowKey: 'cloud-app',
                      flashKey: highlightFlashKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _card(context, [
                            SettingRow(
                              icon: Icons.cloud_upload_outlined,
                              title: 'پشتیبان‌گیری ابری برنامه',
                              subtitle:
                                  'نسخهٔ کامل (ZIP) در فضای ابری برنامه (Firebase)',
                              onTap: _busy ? null : _uploadNow,
                              trailing: _busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : null,
                            ),
                          ]),
                          const SizedBox(height: 20),
                          SectionHeader(
                            key: _anchors['cloud-app'],
                            title: 'نسخه‌های فضای ابری برنامه',
                            margin: const EdgeInsets.only(bottom: 8),
                          ),
                          _buildBackupList(context, firebaseEmail),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                SettingsFlashSection(
                  rowKey: 'local',
                  flashKey: highlightFlashKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        key: _anchors['local'],
                        title: 'پشتیبان‌گیری در این گوشی',
                        margin: const EdgeInsets.only(bottom: 8),
                      ),
                      const LocalBackupSection(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SettingsFlashSection(
                  rowKey: 'transfer',
                  flashKey: highlightFlashKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        key: _anchors['transfer'],
                        title: 'انتقال تنظیمات',
                        margin: const EdgeInsets.only(bottom: 8),
                      ),
                      const SettingsTransferSection(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SettingsFlashSection(
                  rowKey: 'danger',
                  flashKey: highlightFlashKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        key: _anchors['danger'],
                        title: 'منطقه خطر',
                        margin: const EdgeInsets.only(bottom: 8),
                      ),
                      _dangerZone(context, firebaseEmail != null),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Reset + wipe (+ delete-account when a Firebase identity exists): the
  /// three destructive doors in one red card, each with its own honest scope.
  Widget _dangerZone(BuildContext context, bool withDeleteAccount) {
    final error = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WarningCard(
          text: '«بازنشانی» فقط تنظیمات را به پیش‌فرض برمی‌گرداند؛ «پاک‌سازی» '
              'همه داده‌های گوشی را می‌برد؛ «حذف حساب» فقط ابر را پاک می‌کند.',
        ),
        const SizedBox(height: 10),
        _card(context, [
          SettingRow(
            icon: Icons.restart_alt_rounded,
            title: 'بازنشانی تنظیمات به پیش‌فرض',
            subtitle: 'بازگرداندن همهٔ گزینه‌ها به حالت اولیه',
            color: error,
            titleColor: error,
            onTap: _busy ? null : _confirmAndReset,
          ),
          const SettingsDivider(),
          SettingRow(
            icon: Icons.delete_sweep_outlined,
            title: 'پاک‌سازی کامل دستگاه',
            subtitle: 'حذف همه داده‌های برنامه از همین گوشی',
            color: error,
            titleColor: error,
            onTap: _busy ? null : _confirmAndWipe,
          ),
          if (withDeleteAccount) ...[
            const SettingsDivider(),
            SettingRow(
              icon: Icons.delete_forever_outlined,
              color: error,
              titleColor: error,
              title: 'حذف حساب کاربری',
              subtitle:
                  'حساب و نسخه‌های پشتیبانِ ابریِ برنامه برای همیشه حذف می‌شوند',
              onTap: _busy ? null : _deleteAccount,
            ),
          ],
        ]),
        if (withDeleteAccount)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _openDeletionGuide,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('راهنمای حذف حساب در وب'),
            ),
          ),
      ],
    );
  }

  /// The public, no-app-required deletion guide (A-03): the Play listing asks
  /// for a URL, and a user who already uninstalled still needs to know how to
  /// erase the account.
  Future<void> _openDeletionGuide() async {
    try {
      final opened = await launchUrl(Uri.parse(LegalLinks.accountDeletion),
          mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        AppSnackBar.error(context, 'باز کردن راهنمای حذف ممکن نشد');
      }
    } catch (e) {
      AppLogger.warning('Account', 'open deletion guide failed: $e');
      if (mounted) {
        AppSnackBar.error(context, 'باز کردن راهنمای حذف ممکن نشد');
      }
    }
  }

  Future<void> _confirmAndReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازنشانی تنظیمات'),
        content: const Text(
            'همهٔ تنظیمات برنامه به حالت پیش‌فرض بازمی‌گردد.\n\n'
            'یادداشت‌ها، هزینه‌ها، اطلاعات شخصی و پشتیبان‌ها پاک نمی‌شوند.\n\n'
            'ادامه می‌دهید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('بازنشانی'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await ref.read(settingsProvider.notifier).resetPreferences();
    if (!mounted) return;
    // The reset can fail to reach disk and roll back. Claiming success anyway
    // was the same defect as a switch that snaps back with no explanation.
    if (done) {
      AppSnackBar.success(context, 'تنظیمات به حالت پیش‌فرض بازگشت');
    } else {
      AppSnackBar.error(context,
          'بازنشانی ذخیره نشد؛ تنظیمات قبلی دست‌نخورده ماند. دوباره تلاش کنید.');
    }
  }

  /// Two-step full-device wipe: scope first (exactly what goes and what
  /// stays), irreversibility second. On success the app restarts into
  /// onboarding through the splash route; on failure nothing is claimed.
  Future<void> _confirmAndWipe() async {
    final error = Theme.of(context).colorScheme.error;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پاک‌سازی کامل دستگاه'),
        content: const Text(
            'همه داده‌های این گوشی پاک می‌شود و برنامه به حالت روز اول '
            'برمی‌گردد:\n\n'
            '• یادداشت‌ها، هزینه‌ها، اطلاعات شخصی، اهداف و وظایف\n'
            '• آمار عبادات (تسبیح، نماز، روزه، ختم، مطالعه)\n'
            '• همه تنظیمات و خروج از حساب‌ها\n'
            '• فایل‌های پشتیبان ذخیره‌شده در این گوشی\n\n'
            'می‌ماند: فایل‌های دانلودی (تلاوت، کتاب‌ها) و '
            'پشتیبان‌های ابری.\n\n'
            'این کار برگشت‌ناپذیر است.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('لغو')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ادامه')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('آخرین هشدار'),
        content: const Text('واقعاً همه‌چیز پاک شود؟ راه برگشتی نیست.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('لغو')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('پاک‌سازی قطعی')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    try {
      // Best-effort: a failed cancel is logged loudly but never blocks the
      // wipe — the boot coordinator cancels and reschedules from defaults on
      // the next launch anyway, while refusing to wipe would leave the very
      // data the user explicitly asked to erase.
      try {
        await NotificationService().cancelAll();
      } catch (e) {
        AppLogger.error('Account', 'pre-wipe cancel-all failed: $e');
      }
      // Best-effort sign-outs while the sessions still exist; the wipe
      // itself clears every persisted token afterwards.
      try {
        if (GoogleAuthService.instance.account.value != null) {
          await GoogleAuthService.instance.signOut();
        }
      } catch (e) {
        AppLogger.warning('Account', 'pre-wipe drive sign-out failed: $e');
      }
      try {
        if (ref.read(accountEmailProvider).value != null) {
          await ref.read(accountRepositoryProvider).signOut();
        }
      } catch (e) {
        AppLogger.warning('Account', 'pre-wipe account sign-out failed: $e');
      }
      final result = await BackupService()
          .wipeAllLocalData(ref.read(appDatabaseProvider));
      AppLogger.success('Account',
          'local wipe done: ${result.tablesEmptied} tables, '
          '${result.preferencesCleared} prefs, ${result.filesDeleted} files');
      ref.invalidate(settingsProvider);
      ref.invalidate(appDatabaseProvider);
      if (!mounted) return;
      // Prefs are empty, so the splash owns the first-launch decision again
      // and lands on onboarding like a fresh install. Best-effort: in a
      // widget test there is no router, and staying put is fine there.
      try {
        context.go(RouteNames.splash);
      } catch (e) {
        AppLogger.warning('Account', 'post-wipe navigation failed: $e');
      }
    } catch (e) {
      AppLogger.error('Account', 'local wipe failed: $e');
      if (mounted) {
        AppSnackBar.error(context, 'پاک‌سازی ناموفق بود؛ دوباره تلاش کنید.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// بخش ابری Google Drive وقتی حساب گوگل متصل است: بارگذاری + فهرست نسخه‌ها.
  Widget _googleCloudSection(BuildContext context) {
    return _card(context, [
      SettingRow(
        icon: Icons.cloud_upload_outlined,
        title: 'بارگذاری نسخه ابری',
        subtitle:
            'نسخهٔ کامل (ZIP) در Google Drive؛ با هر گوشی جدید قابل بازیابی',
        onTap: _busy ? null : _uploadToDrive,
        trailing: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : null,
      ),
      const SettingsDivider(),
      SettingRow(
        icon: Icons.cloud_download_outlined,
        title: 'نسخه‌های Drive',
        subtitle: 'بازیابی یا حذف نسخه‌های ذخیره‌شده در Drive',
        onTap: _busy ? null : _openDriveCloudList,
      ),
    ]);
  }

  List<Widget> _buildAuthForms(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return [
      WarningCard(
        text: 'با ورود به حساب گوگل، داده‌ها در پوشهٔ مخفی Drive ذخیره می‌شوند و با عوض‌کردن گوشی از دست نمی‌روند.\n'
            'برای ورود یک‌ضربهای، دکمهٔ گوگل را بزنید.',
        icon: Icons.info_outline,
        accent: TimeThemeKit.of(context).palette.primary,
      ),
      const SizedBox(height: 12),
      _card(context, [
        FilledButton.tonalIcon(
          onPressed: _busy ? null : _signInGoogle,
          icon: const Icon(Icons.g_mobiledata, size: 26),
          label: const Text('ورود با حساب گوگل'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: Theme.of(context).colorScheme.error)),
        ],
        if (_firebaseAvailable) ...[
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('یا'),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),
          // The Form owns _formKey; without it _formKey.currentState is null
          // and _submit() throws on every email sign-in attempt, while the
          // validators below stay dead code.
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'ایمیل',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'ایمیل را وارد کنید.';
                    if (!t.contains('@')) return 'ایمیل معتبر نیست.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'رمز عبور',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) {
                    final t = v ?? '';
                    if (t.isEmpty) return 'رمز عبور را وارد کنید.';
                    if (_signUpMode && t.length < 6) {
                      return 'رمز حداقل 6 کاراکتر باشد.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_signUpMode ? 'ساخت حساب' : 'ورود'),
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _signUpMode = !_signUpMode;
                      _error = null;
                    }),
            child: Text(_signUpMode
                ? 'از قبل حساب دارید؟ ورود'
                : 'حساب ندارید؟ ساخت حساب'),
          ),
          if (!_signUpMode)
            TextButton(
              onPressed: _busy ? null : _resetPassword,
              child: const Text('رمز عبور را فراموش کرده‌اید؟'),
            ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'ساخت حساب با ایمیل در این نسخه در دسترس نیست.',
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: t.textMuted),
          ),
        ],
      ]),
    ];
  }

  Widget _accountHeader(BuildContext context, String email,
      {String? secondEmail}) {
    final t = TimeThemeKit.of(context).palette;
    return _card(context, [
      Row(children: [
        IconTile(icon: Icons.person_outline, color: t.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w600),
              ),
              // Both sessions at once: name the Firebase identity too, or the
              // cloud list below looks like it belongs to the Google address.
              // No explicit direction: a pure-Latin address is one bidi run
              // and renders correctly; an ltr literal would only move it.
              if (secondEmail != null && secondEmail != email)
                Text(
                  secondEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'خروج از حساب',
          onPressed: _busy ? null : _signOut,
        ),
      ]),
    ]);
  }

  Widget _buildBackupList(BuildContext context, String email) {
    final t = TimeThemeKit.of(context).palette;
    return _card(context, [
      if (_listing)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        )
      else if (_listError)
        SettingRow(
          icon: Icons.cloud_off_outlined,
          title: 'دریافت فهرست ناموفق بود',
          subtitle: 'اتصال را بررسی کنید و دوباره تلاش کنید',
          showChevron: false,
          onTap: _refreshBackups,
        )
      else if (_backups == null || _backups!.isEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'هنوز نسخه‌ای آپلود نشده است. «پشتیبان‌گیری ابری» را بزنید.',
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textMuted),
          ),
        )
      else
        for (var i = 0; i < _backups!.length; i++) ...[
          if (i > 0) const SettingsDivider(),
          _backupRow(context, _backups![i]),
        ],
    ]);
  }

  Widget _backupRow(BuildContext context, CloudBackupItem item) {
    final busy = _busyName == item.name;
    return SettingRow(
      icon: Icons.cloud_done_outlined,
      title: item.name,
      subtitle:
          '${_size(item.sizeBytes)} • ${cloudBackupDateLabel(item.updated)}',
      showChevron: false,
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(
                onPressed: () => _restore(item),
                child: const Text('بازیابی'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'حذف',
                onPressed: () => _delete(item),
              ),
            ]),
    );
  }

  Widget _card(BuildContext context, List<Widget> children) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.outline, width: .5),
        borderRadius: BorderRadius.circular(22),
      ),
      // Material باید بین DecoratedBox رنگی و SettingRow باشد وگرنه ink/splash
      // پشت پس‌زمینهٔ کارت پنهان می‌ماند (هشدار debug فریم‌ورک).
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
