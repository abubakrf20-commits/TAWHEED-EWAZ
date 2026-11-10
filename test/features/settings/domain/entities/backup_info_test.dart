import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/settings/domain/entities/backup_info.dart';

void main() {
  final now = DateTime(2026, 7, 10, 12);

  group('BackupInfo', () {
    test('constructor sets all fields', () {
      final info = BackupInfo(
        version: '1.3.2',
        date: now,
        app: 'tawheeed',
      );
      expect(info.version, '1.3.2');
      expect(info.date, now);
      expect(info.app, 'tawheeed');
    });

    group('copyWith', () {
      test('creates new object with same field values when no args', () {
        final info = BackupInfo(version: '1.0', date: now, app: 'app');
        final copy = info.copyWith();
        expect(copy.version, info.version);
        expect(copy.date, info.date);
        expect(copy.app, info.app);
      });

      test('replaces version', () {
        final info = BackupInfo(version: '1.0', date: now, app: 'app');
        final copy = info.copyWith(version: '2.0');
        expect(copy.version, '2.0');
        expect(copy.date, now);
      });
    });
  });
}
