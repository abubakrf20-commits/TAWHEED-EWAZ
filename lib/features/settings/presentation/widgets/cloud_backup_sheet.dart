import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/services/drive_backup_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Human Shamsi date label for a backup timestamp («امروز ساعت …» /
/// «دیروز ساعت …» / day month year). Shared by the Drive sheet and the
/// account screen's Firebase list so both clouds read the same way.
String cloudBackupDateLabel(DateTime t) {
  final now = DateTime.now();
  final hm = '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  final daysAgo = DateTime(now.year, now.month, now.day)
      .difference(DateTime(t.year, t.month, t.day))
      .inDays;
  if (daysAgo == 0) return 'امروز ساعت $hm';
  if (daysAgo == 1) return 'دیروز ساعت $hm';
  final j = Jalali.fromDateTime(t);
  return '${j.day} ${DateConstants.persianMonths[j.month - 1]} ${j.year}'
      ' ساعت $hm';
}

/// Bottom sheet listing the cloud backups in the hidden Drive folder with
/// restore/delete actions. Shown from the backup section's Google tile.
class CloudBackupSheet extends StatefulWidget {
  /// Called with the downloaded local ZIP path when the user picks a version.
  /// The host screen runs the normal (destructive-confirm + password) restore.
  final Future<void> Function(String localZipPath, String displayName) onPick;

  const CloudBackupSheet({super.key, required this.onPick});

  @override
  State<CloudBackupSheet> createState() => _CloudBackupSheetState();
}

class _CloudBackupSheetState extends State<CloudBackupSheet> {
  List<CloudBackupInfo>? _items;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final items = await DriveBackupService.instance.listBackups();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      AppLogger.warning('CloudBackupSheet', 'list failed: $e');
      if (mounted) {
        setState(
            () => _error = 'دریافت فهرست ناموفق بود. اینترنت را بررسی کنید.');
      }
    }
  }

  /// The Drive filename is machine-generated (`tawheeed_backup_<millis>_<device>.zip`),
  /// so it is useless both in the list and in the destructive restore confirm —
  /// show when the version was taken instead, in the same Shamsi wording the
  /// local backup list uses.
  String _label(CloudBackupInfo info) =>
      cloudBackupDateLabel(info.modifiedTime);

  String _subtitle(CloudBackupInfo info) {
    final parts = <String>[
      if (_size(info.sizeBytes).isNotEmpty) _size(info.sizeBytes),
      if (info.deviceLabel?.isNotEmpty == true) info.deviceLabel!,
    ];
    return parts.join(' · ');
  }

  Future<void> _download(CloudBackupInfo info) async {
    setState(() => _busyId = info.fileId);
    try {
      final tmp = Directory.systemTemp;
      final path = await DriveBackupService.instance.downloadBackup(
        info,
        tmp,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onPick(path, _label(info));
    } catch (e) {
      AppLogger.warning('CloudBackupSheet', 'download failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('دانلود از گوگل درایو ناموفق بود.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(CloudBackupInfo info) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف نسخه ابری'),
        content: Text('نسخهٔ «${_label(info)}» از Google Drive حذف شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('لغو')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busyId = info.fileId);
    try {
      await DriveBackupService.instance.deleteBackup(info.fileId);
      if (mounted) _load();
    } catch (e) {
      AppLogger.warning('CloudBackupSheet', 'delete failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حذف نسخه ابری ناموفق بود.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _size(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(0)}KB';
    return '${(bytes / 1048576).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
            const SizedBox(height: 12),
            Text(
              'نسخه‌های ابری (Google Drive)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 16),
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'پوشه مخفی مخصوص برنامه — فقط همین اپ به آن دسترسی دارد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: _items == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _error != null
                      ? FailureView(
                          id: 'cloud_backup_list',
                          title: 'فهرست نسخه‌های پشتیبان خوانده نشد',
                          detail: 'نسخه‌هایی که قبلاً ساخته‌اید پاک نشده‌اند؛ '
                              'فقط فهرستشان باز نشد.',
                          onRetry: _load,
                          layout: FailureLayout.page,
                          icon: Icons.cloud_off_rounded,
                          error: _error,
                        )
                      : _items!.isEmpty
                          ? Center(
                              child: Text(
                                'هنوز نسخه‌ای در ابر ذخیره نشده است.',
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: t.textMuted),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: _items!.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final info = _items![i];
                                final busy = _busyId == info.fileId;
                                return AppCard(
                                  padding: EdgeInsets.zero,
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(22)),
                                    leading: Icon(Icons.cloud_done_outlined,
                                        color: t.primary),
                                    title: Text(
                                      _label(info),
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: AppTheme.scaledFontSize(
                                            context, 13),
                                        color: t.textPrimary,
                                      ),
                                    ),
                                    subtitle: Text(
                                      _subtitle(info),
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: AppTheme.scaledFontSize(
                                            context, 11),
                                        color: t.textMuted,
                                      ),
                                    ),
                                    trailing: busy
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton(
                                                onPressed: () =>
                                                    _download(info),
                                                child: const Text('بازیابی'),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 20),
                                                onPressed: () => _delete(info),
                                                tooltip: 'حذف نسخهٔ پشتیبان',
                                              ),
                                            ],
                                          ),
                                  ),
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
