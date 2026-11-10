import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/domain/entities/adhan_settings.dart';

void main() {
  group('AdhanSettings', () {
    test('constructor sets default values', () {
      const settings = AdhanSettings();
      expect(settings.sound, 'kamel');
      expect(settings.volume, 1.0);
      expect(settings.enabledForFajr, true);
      expect(settings.enabledForDhuhr, true);
      expect(settings.enabledForAsr, true);
      expect(settings.enabledForMaghrib, true);
      expect(settings.enabledForIsha, true);
      expect(settings.customPath, isNull);
    });

    test('constructor sets custom values', () {
      const settings = AdhanSettings(
        sound: 'makkah',
        volume: 0.5,
        enabledForFajr: false,
        enabledForDhuhr: false,
        enabledForAsr: false,
        enabledForMaghrib: false,
        enabledForIsha: false,
        customPath: '/custom/azan.mp3',
      );
      expect(settings.sound, 'makkah');
      expect(settings.volume, 0.5);
      expect(settings.enabledForFajr, false);
      expect(settings.customPath, '/custom/azan.mp3');
    });

    group('copyWith', () {
      test('creates new object with same field values when no args', () {
        const settings = AdhanSettings();
        final copy = settings.copyWith();
        expect(copy.sound, settings.sound);
        expect(copy.volume, settings.volume);
      });

      test('replaces single field', () {
        const settings = AdhanSettings();
        final copy = settings.copyWith(volume: 0.3);
        expect(copy.volume, 0.3);
        expect(copy.sound, 'kamel');
      });

      test('replaces customPath', () {
        const settings = AdhanSettings();
        final copy = settings.copyWith(customPath: '/new/path.mp3');
        expect(copy.customPath, '/new/path.mp3');
      });
    });
  });
}
