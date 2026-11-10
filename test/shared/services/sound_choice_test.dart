import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/services/sound_choice.dart';

void main() {
  group('SoundChoice wire format', () {
    test('a system tone round-trips its kind and URI', () {
      const uri = 'content://media/internal/audio/media/42';
      final wire = SoundChoice.system(SoundChoice.kindAlarm, uri);
      expect(wire, 'system:alarm:$uri');
      expect(SoundChoice.isSystem(wire), isTrue);
      expect(SoundChoice.systemKind(wire), SoundChoice.kindAlarm);
      expect(SoundChoice.systemUri(wire), uri);
      expect(SoundChoice.isAlarm(wire), isTrue);
    });

    test('a content URI keeps every colon after the first separator', () {
      const uri = 'content://settings/system/notification_sound?x=1:2';
      final wire = SoundChoice.system(SoundChoice.kindNotification, uri);
      expect(SoundChoice.systemKind(wire), SoundChoice.kindNotification);
      expect(SoundChoice.systemUri(wire), uri);
    });

    test('custom paths are recognised, not confused with system tones', () {
      const wire = 'custom:/data/user/0/app/files/custom_sounds/a.mp3';
      expect(SoundChoice.isCustom(wire), isTrue);
      expect(SoundChoice.isSystem(wire), isFalse);
      expect(SoundChoice.customPath(wire),
          '/data/user/0/app/files/custom_sounds/a.mp3');
      expect(SoundChoice.systemUri(wire), isNull);
    });

    test('plain values stay plain', () {
      for (final wire in ['silent', 'default', 'notif', 'ios17']) {
        expect(SoundChoice.isSystem(wire), isFalse, reason: wire);
        expect(SoundChoice.isCustom(wire), isFalse, reason: wire);
        expect(SoundChoice.systemUri(wire), isNull, reason: wire);
      }
    });

    test('rough labels never fall back to a raw URI', () {
      expect(SoundChoice.roughLabel('silent'), 'بی‌صدا');
      expect(SoundChoice.roughLabel('default'), 'صدای پیش‌فرض سیستم');
      expect(
        SoundChoice.roughLabel(
            SoundChoice.system(SoundChoice.kindAlarm, 'content://x/y/1')),
        'آلارم گوشی',
      );
    });
  });
}
