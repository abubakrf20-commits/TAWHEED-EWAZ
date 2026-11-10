import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/data/daos/settings_dao.dart';
import 'package:tawheeed/features/settings/data/datasources/settings_drift_datasource.dart';
import 'package:tawheeed/features/settings/data/models/app_settings_model.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_provider.dart';
import 'package:tawheeed/features/settings/presentation/widgets/cloud_backup_sheet.dart';
import 'package:tawheeed/features/settings/presentation/widgets/restore_flow.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:tawheeed/features/settings/services/backup_service.dart';
import 'package:tawheeed/shared/services/saf_file_picker.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';

/// Local backup rows («پشتیبان‌گیری در این گوشی»): the daily auto-backup
/// status + one-shot creation, the full shareable ZIP and both local restore
/// doors (latest auto + from file). Moved verbatim out of the settings page
/// so the account hub owns every backup door; behaviour and wording are
/// unchanged — only the restore pipeline now runs through [restore_flow].
class LocalBackupSection extends ConsumerStatefulWidget {
  const LocalBackupSection({super.key});

  @override
  ConsumerState<LocalBackupSection> createState() =>
      _LocalBackupSectionState();
}

class _LocalBackupSectionState extends ConsumerState<LocalBackupSection> {
  bool _backupLoading = false;
  bool _restoreLoading = false;
  DateTime? _lastAutoBackup;

  @override
  void initState() {
    super.initState();
    _loadLastAutoBackup();
  }

  Future<void> _loadLastAutoBackup() async {
    final time = await BackupService().lastAutoBackupTime();
    if (mounted) setState(() => _lastAutoBackup = time);
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return settingsCard([
      _autoBackupStatusTile(context),
      _backupTile(
        context,
        Icons.backup_outlined,
        t.primary,
        'ایجاد پشتیبان کامل',
        'ذخیره تمام اطلاعات در یک فایل ZIP',
        _backupLoading ? null : _doFullBackup,
        loading: _backupLoading,
      ),
      _restoreAutoTile(context),
      _backupTile(
        context,
        Icons.restore_outlined,
        isDark ? AppTheme.darkError : AppTheme.lightError,
        'بازگردانی از فایل',
        'بازگردانی اطلاعات از فایل ZIP یا JSON',
        _restoreLoading ? null : _restoreFromFile,
        loading: _restoreLoading,
      ),
    ]);
  }

  /// نمایش وضعیت پشتیبان‌گیری خودکار روزانه + ساخت فوری.
  Widget _autoBackupStatusTile(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final iconColor = t.primary;
    // Honest about the new device-key seal: this copy never leaves the phone
    // and cannot be opened elsewhere, so it must not read like the shareable
    // backup row below it.
    final sub = _lastAutoBackup == null
        ? 'رمزگذاری‌شده روی همین گوشی'
        : 'آخرین پشتیبان: ${cloudBackupDateLabel(_lastAutoBackup!)} · فقط همین گوشی';
    return settingsRow(
      SettingRow(
        icon: Icons.event_repeat,
        color: iconColor,
        title: 'پشتیبان‌گیری روزانه',
        subtitle: sub,
        showChevron: false,
        trailing: _backupLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: iconColor))
            : OutlinedButton(
                onPressed: _createAutoBackupNow,
                style: OutlinedButton.styleFrom(
                  foregroundColor: dsContentColor(context, iconColor),
                  side: BorderSide(color: iconColor.withValues(alpha: 0.45)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  // A bounded minimum is required here: this button is a bare
                  // Row child (the row's trailing), so the theme's full-width
                  // `minimumSize: Size.fromHeight(48)` would ask for an
                  // infinite width and trip the layout assertion.
                  minimumSize: const Size(64, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('همین حالا'),
              ),
      ),
    );
  }

  Widget _restoreAutoTile(BuildContext context) {
    return _backupTile(
      context,
      Icons.settings_backup_restore_outlined,
      AppPalette.emerald,
      'بازگردانی آخرین پشتیبان خودکار',
      'بازیابی آمارها از آخرین نسخه ذخیره‌شده روزانه',
      _restoreLoading ? null : _restoreFromAutoBackup,
      loading: _restoreLoading,
    );
  }

  // ─── ساخت فوری ─────────────────────────────────────────────

  /// ساخت فوری یک پشتیبان خودکار.
  Future<void> _createAutoBackupNow() async {
    setState(() => _backupLoading = true);
    final file = await BackupService().createAutoBackup();
    await _loadLastAutoBackup();
    if (mounted) {
      setState(() => _backupLoading = false);
      if (file != null) {
        AppSnackBar.success(context, 'پشتیبان خودکار ساخته شد');
      } else {
        AppSnackBar.error(context, 'خطا در ساخت پشتیبان خودکار');
      }
    }
  }

  /// بازگردانی از آخرین پشتیبان خودکار ذخیره‌شده روی گوشی.
  Future<void> _restoreFromAutoBackup() async {
    final file = await BackupService().findLatestAutoBackup();
    if (!mounted) return;
    if (file == null) {
      AppSnackBar.show(context, 'هنوز پشتیبان خودکاری ساخته نشده است.');
      return;
    }
    setState(() => _restoreLoading = true);
    try {
      final result = await restoreZipAndRepair(
        context: context,
        ref: ref,
        path: file.path,
        confirmTitle: 'بازگردانی از پشتیبان خودکار',
        confirmBody:
            'تمام اطلاعات فعلی (تنظیمات، تسبیح، ختم، مطالعه، نماز، روزه و…) با آخرین نسخه پشتیبان خودکار جایگزین می‌شود.',
      );
      if (!mounted) return;
      if (result.applied) {
        AppSnackBar.success(context, 'پشتیبان با موفقیت بازگردانی شد.');
      } else if (result.error != null) {
        AppSnackBar.error(context, 'خطا در بازگردانی: ${result.error}');
      }
    } finally {
      if (mounted) setState(() => _restoreLoading = false);
    }
  }

  Widget _backupTile(BuildContext context, IconData icon, Color iconColor,
      String title, String subtitle, VoidCallback? onTap,
      {bool loading = false}) {
    return settingsRow(
      SettingRow(
        icon: icon,
        color: iconColor,
        title: title,
        subtitle: subtitle,
        onTap: loading ? null : onTap,
        trailing: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: iconColor))
            : null,
      ),
    );
  }

  // ─── پشتیبان کامل (ZIP) ─────────────────────────────────────

  /// Asks for the optional creation password. Empty = plain ZIP (as before);
  /// a non-empty password AES-encrypts the whole backup file. The restore
  /// side asks through [askRestorePassword] instead — one dialog per
  /// direction, never two spellings of the same question.
  Future<String?> _askCreationPassword() async {
    final t = TimeThemeKit.of(context).palette;
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('رمز اختیاری پشتیبان',
                style: TextStyle(fontFamily: AppTheme.fontFamily)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'اگر رمز بگذارید، فایل پشتیبان رمزنگاری می‌شود و بدون آن باز نمی‌گردد. خالی بگذارید یعنی بدون رمز.',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      color: t.textSecondary),
                ),
                // PRIVACY WARNING: a passwordless backup carries the user's
                // personal data (notes, expenses, period records) in a plain
                // ZIP readable by anyone holding the file.
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined,
                          size: 16,
                          color:
                              Theme.of(context).colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'پشتیبانِ بدون رمز شامل یادداشت‌ها، هزینه‌ها و داده‌های خصوصی شماست و هر کسی فایل را داشته باشد می‌تواند بخواندش.',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11.5),
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'رمز',
                    labelStyle: TextStyle(fontFamily: AppTheme.fontFamily),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'تکرار رمز',
                    labelStyle: TextStyle(fontFamily: AppTheme.fontFamily),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('لغو',
                      style: TextStyle(fontFamily: AppTheme.fontFamily))),
              FilledButton(
                  onPressed: () {
                    final p1 = controller.text;
                    if (p1 != confirmController.text) {
                      AppSnackBar.error(context, 'تکرار رمز یکسان نیست.');
                      return;
                    }
                    Navigator.pop(ctx, p1.isEmpty ? '' : p1);
                  },
                  child: Text('ادامه',
                      style: TextStyle(fontFamily: AppTheme.fontFamily))),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
      confirmController.dispose();
    }
  }

  Future<void> _doFullBackup() async {
    final password = await _askCreationPassword();
    if (password == null || !mounted) return; // dialog cancelled
    setState(() => _backupLoading = true);
    try {
      final xfile = await BackupService()
          .shareBackup(password: password.isEmpty ? null : password);
      await SharePlus.instance
          .share(ShareParams(files: [xfile], text: 'پشتیبان کامل توحید'));
      if (mounted) {
        AppSnackBar.success(
            context, 'پشتیبان کامل ساخته و به اشتراک گذاشته شد');
      }
    } catch (e) {
      AppLogger.warning('local_backup_section', 'error: $e');
      if (mounted) {
        AppSnackBar.error(
            context, 'خطا در ایجاد پشتیبان: ${restoreShortErr(e, 80)}');
      }
    } finally {
      if (mounted) setState(() => _backupLoading = false);
    }
  }

  // ─── بازگردانی از فایل (ZIP یا JSON) ─────────────────────────

  Future<void> _restoreFromFile() async {
    setState(() => _restoreLoading = true);
    try {
      final safFile = await SAFFilePicker.pickBackupFile();
      if (!mounted) return;
      if (safFile == null) {
        AppSnackBar.show(context, 'انتخاب فایل لغو شد');
        return;
      }

      final ext = safFile.name.split('.').last.toLowerCase();
      if (ext == 'zip') {
        final result = await restoreZipAndRepair(
          context: context,
          ref: ref,
          zipBytes: safFile.bytes,
          confirmTitle: 'بازگردانی از پشتیبان ZIP',
          confirmBody:
              'تمام اطلاعات فعلی (تنظیمات، اذکار، نشان‌ها، پیشرفت نماز و...) با اطلاعات فایل پشتیبان جایگزین می‌شود.',
        );
        if (!mounted) return;
        if (result.applied) {
          AppSnackBar.success(context, 'پشتیبان با موفقیت بازگردانی شد.');
        } else if (result.error != null) {
          AppSnackBar.error(context, 'خطا در بازگردانی: ${result.error}');
        }
      } else if (ext == 'json') {
        await _restoreFromJson(safFile);
      } else {
        if (mounted) {
          AppSnackBar.error(context,
              'فرمت فایل پشتیبانی نمی‌شود. لطفاً فایل ZIP یا JSON انتخاب کنید.');
        }
      }
    } on PlatformException catch (e) {
      AppLogger.warning('local_backup_section', 'error: $e');
      if (mounted) {
        if (e.code == 'read_external_storage_denied') {
          AppSnackBar.error(context,
              'دسترسی به حافظه رد شد. لطفاً از طریق فایل‌پیکر سیستمی فایل را انتخاب کنید.');
        } else {
          AppSnackBar.error(
              context, 'خطا در بازگردانی: ${e.message ?? 'خطای ناشناخته'}');
        }
      }
    } catch (e) {
      AppLogger.warning('local_backup_section', 'error: $e');
      if (mounted) {
        AppSnackBar.error(
            context, 'خطا در بازگردانی: ${restoreShortErr(e, 100)}');
      }
    } finally {
      if (mounted) setState(() => _restoreLoading = false);
    }
  }

  Future<void> _restoreFromJson(SAFFile file) async {
    final jsonStr = utf8.decode(file.bytes);

    if (jsonStr.isEmpty) {
      if (mounted) AppSnackBar.error(context, 'فایل JSON خالی است');
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازگردانی تنظیمات از JSON'),
        content: const Text(
            'تنظیمات برنامه از فایل JSON بازگردانی می‌شود.\n(دیتابیس اصلی و اطلاعات عبادی تحت تأثیر قرار نمی‌گیرد)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لغو')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('بازگردانی')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _restoreLoading = true);
    try {
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      // Counted honestly. This used to increment only for the settings blob,
      // so the summary always read «۱ تنظیمات بازگردانی شد» however many
      // preference keys had actually been written — and said it even when some
      // writes had failed and been swallowed.
      var written = 0;
      var failed = 0;

      // بازگردانی تنظیمات Drift (دیتابیس)
      if (data.containsKey('_driftSettings') && data['_driftSettings'] is Map) {
        try {
          final dao = ref.read(settingsDaoProvider);
          final driftSource = SettingsDriftDataSource(dao);
          final dto = AppSettingsDto.fromJson(
              data['_driftSettings'] as Map<String, dynamic>);
          await driftSource.save(dto);
          written++;
        } catch (e, st) {
          failed++;
          AppLogger.error(
              'local_backup_section', 'drift settings restore failed: $e', st);
        }
      }

      for (final entry in data.entries) {
        if (entry.key == '_driftSettings') continue;
        // Same guard the ZIP restore uses: a hand-crafted JSON must not be able
        // to write plugin- or auth-owned SharedPreferences keys.
        if (!BackupService.isRestorablePreferenceKey(entry.key)) {
          AppLogger.warning(
              'Settings', 'restore skipped disallowed key: ${entry.key}');
          continue;
        }
        try {
          if (entry.value is String) {
            await prefs.setString(entry.key, entry.value as String);
          } else if (entry.value is int) {
            await prefs.setInt(entry.key, entry.value as int);
          } else if (entry.value is double) {
            await prefs.setDouble(entry.key, entry.value as double);
          } else if (entry.value is bool) {
            await prefs.setBool(entry.key, entry.value as bool);
          } else if (entry.value is List) {
            final list = entry.value as List;
            if (list.every((e) => e is String)) {
              await prefs.setStringList(entry.key, list.cast<String>());
            } else {
              await prefs.setString(entry.key, json.encode(list));
            }
          } else {
            await prefs.setString(entry.key, json.encode(entry.value));
          }
          written++;
        } catch (e) {
          failed++;
          AppLogger.warning('Settings', 'restore write failed: $e');
        }
      }
      if (mounted) {
        if (failed == 0) {
          AppSnackBar.success(
              context, '$written مورد با موفقیت بازگردانی شد');
        } else {
          AppSnackBar.error(
              context,
              '$written مورد بازگردانی شد و $failed مورد نشد. '
              'تنظیمات ناقص بازگردانی شده است.');
        }
        // The settings row and prefs were rewritten behind the providers'
        // back — reload them so the UI reflects the restored values now,
        // then rebuild the notification schedule from them.
        ref.invalidate(settingsProvider);
        unawaited(postRestoreRepair(ref, context));
      }
    } catch (e) {
      AppLogger.warning('local_backup_section', 'error: $e');
      if (mounted) {
        AppSnackBar.error(
            context, 'خطا در بازگردانی تنظیمات: ${restoreShortErr(e, 80)}');
      }
    } finally {
      if (mounted) setState(() => _restoreLoading = false);
    }
  }
}
