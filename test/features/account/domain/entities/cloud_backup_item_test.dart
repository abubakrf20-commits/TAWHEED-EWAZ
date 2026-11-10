import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/account/domain/entities/cloud_backup_item.dart';

void main() {
  group('CloudBackupItem', () {
    test('keeps the constructor values', () {
      final updated = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final item = CloudBackupItem(
        name: 'backup-2026.zip',
        sizeBytes: 2048,
        updated: updated,
      );

      expect(item.name, 'backup-2026.zip');
      expect(item.sizeBytes, 2048);
      expect(item.updated, updated);
    });

    test('supports zero size and arbitrary timestamps', () {
      final item = CloudBackupItem(
        name: 'a.zip',
        sizeBytes: 0,
        updated: DateTime(2025),
      );
      expect(item.sizeBytes, 0);
      expect(item.updated.year, 2025);
    });
  });
}
