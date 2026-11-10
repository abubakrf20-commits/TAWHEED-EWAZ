import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_provider.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:tawheeed/features/settings/services/settings_transfer_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';

import 'restore_flow.dart';

/// «انتقال تنظیمات» — settings-only transfer (export a JSON of the current
/// preferences via the share sheet, import one back from a file). Moved
/// verbatim out of the settings page's reset section so the account hub owns
/// every move/reset door; export/import deliberately keep what a reset keeps
/// (onboarding state, premium status, all user content untouched — see
/// `SettingsNotifier.importPreferences`).
class SettingsTransferSection extends ConsumerWidget {
  const SettingsTransferSection({super.key});

  Future<void> _exportSettings(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider).value;
    if (settings == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$kSettingsTransferFileName');
      await file.writeAsString(encodeSettingsTransfer(settings), flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        text: 'تنظیمات توحید',
      ));
      if (context.mounted) {
        AppSnackBar.success(context, 'فایل تنظیمات ساخته و به اشتراک گذاشته شد');
      }
    } catch (e) {
      AppLogger.warning('settings_transfer_section', 'export failed: $e');
      if (context.mounted) {
        AppSnackBar.error(
            context, 'خروجی گرفتن ممکن نشد: ${restoreShortErr(e, 80)}');
      }
    }
  }

  Future<void> _importSettings(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'انتخاب فایل تنظیمات',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked == null || !context.mounted) return; // user cancelled
    final String raw;
    try {
      raw = utf8.decode(await picked.readAsBytes());
    } on Object catch (e) {
      AppLogger.warning('settings_transfer_section', 'read picked failed: $e');
      if (context.mounted) {
        AppSnackBar.error(context, 'خواندن فایل ممکن نشد؛ دوباره تلاش کنید.');
      }
      return;
    }
    if (!context.mounted) return;
    final next = decodeSettingsTransfer(raw);
    if (next == null) {
      AppSnackBar.error(context,
          'این فایل یک خروجی تنظیمات توحید نیست یا نسخهٔ پشتیبانی‌شده ندارد.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('دریافت تنظیمات از فایل'),
        content: const Text(
            'تنظیمات برنامه با محتوای فایل جایگزین می‌شود.\n\n'
            'وضعیت راه‌اندازی و حق «پشتیبانی» دست‌نخورده می‌ماند.\n\n'
            'ادامه می‌دهید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('دریافت'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final applied =
        await ref.read(settingsProvider.notifier).importPreferences(next);
    if (!context.mounted) return;
    if (applied) {
      AppSnackBar.success(context, 'تنظیمات از فایل دریافت شد');
    } else {
      AppSnackBar.error(context,
          'تنظیمات دریافت نشد؛ نوشتن روی دستگاه ناموفق بود. تنظیمات قبلی دست‌نخورده ماند.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return settingsCard([
      settingsRow(
        SettingRow(
          icon: Icons.upload_file_outlined,
          title: 'خروجی گرفتن از تنظیمات',
          subtitle: 'فقط تنظیمات، در یک فایل JSON برای دستگاه دیگر',
          onTap: () => _exportSettings(context, ref),
        ),
      ),
      settingsRow(
        SettingRow(
          icon: Icons.download_outlined,
          title: 'دریافت از فایل',
          subtitle: 'بازگردانی تنظیمات از فایل JSON',
          onTap: () => _importSettings(context, ref),
        ),
      ),
    ]);
  }
}
