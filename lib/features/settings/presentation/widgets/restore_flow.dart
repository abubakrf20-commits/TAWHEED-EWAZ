import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/core/services/permission_service.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_provider.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/services/backup_service.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';

/// Shortens an exception for a snackbar line. Shared by the backup, restore
/// and transfer rows so every failure reads the same way.
String restoreShortErr(Object e, int max) {
  final msg = e.toString();
  return msg.length > max ? msg.substring(0, max) : msg;
}

/// Asks for the password of an encrypted backup (restore side).
/// Returns null when the dialog is dismissed.
///
/// The controller is intentionally NOT disposed: the route keeps the
/// TextField mounted for a few pop-animation frames after `showDialog`
/// returns, so disposing it synchronously fires "used after dispose".
/// An undisposed controller with no listeners is plain garbage, not a leak.
Future<String?> askRestorePassword(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('رمز پشتیبان'),
      content: TextField(
        controller: controller,
        obscureText: true,
        autofocus: true,
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(
          labelText: 'رمز عبور هنگام ساخت پشتیبان',
          prefixIcon: Icon(Icons.lock_outline),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('بازیابی')),
      ],
    ),
  );
}

/// Destructive-restore confirm shared by every restore door (local auto/file,
/// Drive sheet, Firebase list): the caller names the source, the vault
/// caveat is always appended, and the dialog reads identically everywhere.
Future<bool> confirmDestructiveRestore(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  if (!context.mounted) return false;
  final fullBody = body + await BackupService.vaultRestoreCaveat();
  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(fullBody),
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
  return confirmed == true;
}

/// Result of [restoreZipAndRepair]: [applied] tells whether the backup is now
/// live; [error] is null on success AND on user-cancel (stay silent),
/// otherwise the short failure line the caller shows verbatim.
typedef RestoreResult = ({bool applied, String? error});

/// Applies an already-confirmed ZIP restore: password retry, completeness
/// check, provider invalidation, repair. No dialogs of its own (the caller
/// confirmed already); shows NO snackbars either.
///
/// Returns [RestoreResult.applied] only when the backup is now live;
/// [RestoreResult.error] is null on cancel (stay silent), otherwise the short
/// failure line the caller shows verbatim.
Future<RestoreResult> applyZipRestore({
  required BuildContext context,
  required WidgetRef ref,
  String? path,
  List<int>? zipBytes,
}) async {
  assert(path != null || zipBytes != null);
  try {
    final db = ref.read(appDatabaseProvider);
    RestoreOutcome outcome;
    try {
      outcome = await BackupService()
          .restoreBackup(path ?? '', database: db, zipBytes: zipBytes);
    } on BackupPasswordRequiredException {
      if (!context.mounted) return (applied: false, error: null);
      final password = await askRestorePassword(context);
      if (password == null || password.isEmpty || !context.mounted) {
        return (applied: false, error: null);
      }
      outcome = await BackupService().restoreBackup(path ?? '',
          database: db, zipBytes: zipBytes, password: password);
    }
    // A partial restore is a failure, not a success: claiming it would leave
    // the user on a half-old, half-new dataset believing it is whole.
    if (outcome.restoredTables < 2) {
      return (
        applied: false,
        error: 'فقط ${outcome.restoredTables} بخش از پشتیبان بازگردانی شد.'
      );
    }
    // The restore replaced everything; the copy taken beforehand is the only
    // way back, so say where it is rather than leaving it unfindable.
    if (outcome.safetyCopyPath != null) {
      AppLogger.info('restore_flow',
          'pre-restore copy kept at ${outcome.safetyCopyPath}');
    }
    ref.invalidate(settingsProvider);
    ref.invalidate(appDatabaseProvider);
    // The repair half pops dialogs; skip it when the route is already gone
    // (the invalidations above still make a rebuilt tree read fresh data).
    if (!context.mounted) return (applied: true, error: null);
    unawaited(postRestoreRepair(ref, context));
    return (applied: true, error: null);
  } catch (e) {
    AppLogger.warning('restore_flow', 'restore failed: $e');
    return (applied: false, error: restoreShortErr(e, 100));
  }
}

/// The one restore pipeline every door runs: confirm → [applyZipRestore].
///
/// Shows NO snackbars — the caller reports the outcome in its own words, so
/// no Persian string moves when a new door is added. Cancelled dialogs stay
/// silent ([error] null); failures carry the short line to show.
Future<RestoreResult> restoreZipAndRepair({
  required BuildContext context,
  required WidgetRef ref,
  String? path,
  List<int>? zipBytes,
  required String confirmTitle,
  required String confirmBody,
}) async {
  assert(path != null || zipBytes != null);
  final confirmed = await confirmDestructiveRestore(
    context,
    title: confirmTitle,
    body: confirmBody,
  );
  if (!confirmed || !context.mounted) {
    return (applied: false, error: null);
  }
  return applyZipRestore(
    context: context,
    ref: ref,
    path: path,
    zipBytes: zipBytes,
  );
}

/// Post-restore repair (local or cloud): restored rows are inert until the
/// notification schedules are rebuilt and permissions re-granted on the new
/// device. Rebuilds the prayer/khatm schedules, then guides the user to the
/// diagnostics screen when notifications or exact alarms are denied.
Future<void> postRestoreRepair(WidgetRef ref, BuildContext context) async {
  var rescheduleFailed = false;
  try {
    // Await a fresh load: the providers were just invalidated, so the cached
    // state may still hold the pre-restore settings.
    final settings = await ref.read(settingsProvider.future);
    final prayerService = ref.read(prayerTimeServiceProvider);
    await ref
        .read(dailyNotificationSchedulerProvider)
        .forceReschedule(
          prayerService: prayerService,
          settings: settings,
        );
    await NotificationService().syncKhatmReminder();
  } catch (e) {
    // The restore itself succeeded; only the schedule rebuild failed. That is
    // the difference between «داده برگشت» and «اذان فردا می‌آید», and the
    // reader is the one who needs to know which they got — the permission
    // dialog below does not cover it, because permissions can be fine and the
    // reschedule still fail.
    AppLogger.warning('BackupRepair', 'reschedule failed: $e');
    rescheduleFailed = true;
  }
  if (!context.mounted) return;
  if (rescheduleFailed) {
    AppSnackBar.error(
      context,
      'بازیابی انجام شد، ولی زمان‌بندی اذان و یادآوری‌ها بازسازی نشد.',
      onRetry: () => postRestoreRepair(ref, context),
    );
  }
  bool notifOk = true;
  bool exactOk = true;
  try {
    notifOk = await PermissionService().isNotificationGranted();
    exactOk = await PermissionService().isExactAlarmGranted();
  } catch (e) {
    AppLogger.warning('restore_flow', 'permission re-check failed: $e');
  }
  if ((!notifOk || !exactOk) && context.mounted) {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('یادآوری‌ها نیاز به مجوز دارند'),
        content: const Text(
            'برای فعال شدن اذان و یادآوری‌ها در این دستگاه، مجوز اعلان را بدهید.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('بعداً')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تنظیمات گوشی')),
        ],
      ),
    );
    if (go == true && context.mounted) {
      context.push(RouteNames.notificationDiagnostics);
    }
  }
}
