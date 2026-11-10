import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/domain/entities/silent_mode_settings.dart';

void main() {
  group('SilentModeSettings', () {
    test('constructor sets default values', () {
      const settings = SilentModeSettings();
      expect(settings.enabled, false);
      expect(settings.duration, 10);
      expect(settings.beforeIqamah, false);
      expect(settings.beforeIqamahMinutes, 15);
    });

    test('constructor sets custom values', () {
      const settings = SilentModeSettings(
        enabled: true,
        duration: 20,
        beforeIqamah: true,
        beforeIqamahMinutes: 10,
      );
      expect(settings.enabled, true);
      expect(settings.duration, 20);
      expect(settings.beforeIqamah, true);
      expect(settings.beforeIqamahMinutes, 10);
    });

    group('copyWith', () {
      test('creates new object with same field values when no args', () {
        const settings = SilentModeSettings();
        final copy = settings.copyWith();
        expect(copy.enabled, settings.enabled);
        expect(copy.duration, settings.duration);
      });

      test('replaces single field', () {
        const settings = SilentModeSettings();
        final copy = settings.copyWith(enabled: true);
        expect(copy.enabled, true);
        expect(copy.duration, 10);
      });

      test('replaces all fields', () {
        const settings = SilentModeSettings();
        final copy = settings.copyWith(
          enabled: true,
          duration: 30,
          beforeIqamah: true,
          beforeIqamahMinutes: 5,
        );
        expect(copy.enabled, true);
        expect(copy.duration, 30);
        expect(copy.beforeIqamah, true);
        expect(copy.beforeIqamahMinutes, 5);
      });
    });
  });
}
