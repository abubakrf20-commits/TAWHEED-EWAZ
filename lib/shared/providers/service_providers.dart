import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/services/permission_service.dart';
import 'package:tawheeed/features/settings/services/backup_service.dart';
import 'package:tawheeed/shared/services/azan_service.dart';

/// Infrastructure singletons exposed as plain providers so boot-time flows can
/// be overridden in tests (same pattern as `notificationServiceProvider` in
/// notification_settings_notifier.dart). In production they return the
/// existing app singletons — no behavior change.
final permissionServiceProvider =
    Provider<PermissionService>((ref) => PermissionService());

final backupServiceProvider = Provider<BackupService>((ref) => BackupService());

final azanServiceProvider = Provider<AzanService>((ref) => AzanService());

// `widgetSyncServiceProvider` already lives next to its class in
// shared/services/widget_sync_service.dart — not duplicated here.
