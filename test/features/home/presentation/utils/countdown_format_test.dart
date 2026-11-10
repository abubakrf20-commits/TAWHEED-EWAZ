import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/home/presentation/utils/time_formatters.dart';

void main() {
  group('formatCountdown', () {
    test('one hour or more renders HH:MM without seconds', () {
      expect(
        TimeFormatters.formatCountdown(const Duration(hours: 2, minutes: 12)),
        (text: '02:12', showSeconds: false),
      );
      expect(
        TimeFormatters.formatCountdown(const Duration(hours: 1)),
        (text: '01:00', showSeconds: false),
      );
    });

    test('under one hour renders MM:SS with seconds', () {
      expect(
        TimeFormatters.formatCountdown(const Duration(minutes: 36, seconds: 5)),
        (text: '36:05', showSeconds: true),
      );
      expect(
        TimeFormatters.formatCountdown(const Duration(seconds: 9)),
        (text: '00:09', showSeconds: true),
      );
    });

    test('the format switches exactly at the one-hour boundary', () {
      expect(
        TimeFormatters.formatCountdown(const Duration(seconds: 3600))
            .showSeconds,
        isFalse,
      );
      expect(
        TimeFormatters.formatCountdown(const Duration(seconds: 3599))
            .showSeconds,
        isTrue,
      );
      expect(
        TimeFormatters.formatCountdown(const Duration(seconds: 3599)).text,
        '59:59',
      );
    });

    test('negative durations clamp to zero, never a minus sign', () {
      expect(
        TimeFormatters.formatCountdown(const Duration(seconds: -30)),
        (text: '00:00', showSeconds: true),
      );
    });
  });

  group('arcSemantics', () {
    test('daytime between dhuhr and asr matches the spec example', () {
      expect(
        TimeFormatters.arcSemantics(
          moon: false,
          prevMarker: 'ظهر',
          nextMarker: 'عصر',
          nextLabel: 'اذان عصر',
          remaining: const Duration(hours: 2, minutes: 12),
        ),
        'خورشید بین ظهر و عصر، 2 ساعت و 12 دقیقه تا اذان عصر',
      );
    });

    test('night names the moon and the last-third stretch', () {
      // The fajr-anchored arc has no «pre-fajr» stretch: before today's
      // fajr the previous cycle is completing, so the sun/moon always sits
      // BETWEEN two markers.
      expect(
        TimeFormatters.arcSemantics(
          moon: true,
          prevMarker: 'ثلث آخر',
          nextMarker: 'صبح',
          nextLabel: 'اذان صبح',
          remaining: const Duration(minutes: 40, seconds: 5),
        ),
        'ماه بین ثلث آخر و صبح، 40 دقیقه و 5 ثانیه تا اذان صبح',
      );
    });

    test('after isha the stretch runs to midnight, sub-minute clamps', () {
      expect(
        TimeFormatters.arcSemantics(
          moon: true,
          prevMarker: 'عشاء',
          nextMarker: 'نیمه‌شب',
          nextLabel: 'اذان عشاء',
          remaining: const Duration(seconds: 45),
        ),
        'ماه بین عشاء و نیمه‌شب، 45 ثانیه تا اذان عشاء',
      );
    });

    test('past the last marker collapses to «پس از»', () {
      expect(
        TimeFormatters.arcSemantics(
          moon: true,
          prevMarker: 'صبح',
          nextMarker: 'صبح',
          nextLabel: 'اذان صبح',
          remaining: Duration.zero,
        ),
        'ماه پس از صبح، 0 ثانیه تا اذان صبح',
      );
    });
  });
}
