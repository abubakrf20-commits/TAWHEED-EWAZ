import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/services/permission_service.dart';
import 'package:tawheeed/features/settings/services/backup_service.dart';
import 'package:tawheeed/shared/providers/service_providers.dart';
import 'package:tawheeed/shared/services/azan_service.dart';
import 'package:tawheeed/shared/services/widget_sync_service.dart';

/// A permission service that only proves the override seam works — no real
/// platform channels are touched.
class _FakePermissionService implements PermissionService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('fake: ${invocation.memberName}');
}

void main() {
  test('providers default to the production singletons', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(permissionServiceProvider), isA<PermissionService>());
    expect(container.read(backupServiceProvider), isA<BackupService>());
    expect(container.read(azanServiceProvider), isA<AzanService>());
    expect(container.read(widgetSyncServiceProvider), isA<WidgetSyncService>());
  });

  test('permissionServiceProvider can be overridden for tests', () {
    final fake = _FakePermissionService();
    final container = ProviderContainer(overrides: [
      permissionServiceProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    expect(identical(container.read(permissionServiceProvider), fake), isTrue);
    // The other seams stay untouched by this override.
    expect(container.read(backupServiceProvider), isA<BackupService>());
  });
}
