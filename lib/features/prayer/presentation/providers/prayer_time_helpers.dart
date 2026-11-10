import 'package:adhan/adhan.dart';

/// The adhan package returns UTC-tagged values when an explicit UTC offset is
/// supplied. Their date/time fields are the requested location's wall clock,
/// not the instant represented by the UTC marker. Normalize those fields before
/// comparing them with the device clock or scheduling an alarm.
DateTime wallClockTime(DateTime time) => DateTime(
      time.year,
      time.month,
      time.day,
      time.hour,
      time.minute,
      time.second,
      time.millisecond,
      time.microsecond,
    );

/// Converts a wall-clock prayer time into a real epoch instant. `adhan` values
/// produced with [utcOffset] carry the local fields but are UTC-tagged, so the
/// offset must be applied exactly once before crossing into native Android.
int wallClockEpochMillis(DateTime time, {Duration? utcOffset}) {
  final wall = wallClockTime(time);
  if (utcOffset == null) return wall.millisecondsSinceEpoch;
  return DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
    wall.millisecond,
    wall.microsecond,
  ).subtract(utcOffset).millisecondsSinceEpoch;
}

String formatTime(DateTime? time) {
  if (time == null) return '--:--';
  final localTime = wallClockTime(time);
  final h = localTime.hour.toString().padLeft(2, '0');
  final m = localTime.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String formatTime12(DateTime? time) {
  if (time == null) return '--:--';
  final localTime = wallClockTime(time);
  final hour = localTime.hour;
  final minute = localTime.minute;
  final period = hour < 12 ? 'صبح' : 'بعد از ظهر';
  final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
}

String formatTimeStr(int hour, int minute) {
  final h = hour.toString().padLeft(2, '0');
  final m = minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String formatTimeStr12(int hour, int minute) {
  final period = hour < 12 ? 'صبح' : 'بعد از ظهر';
  final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
}

/// The next upcoming adhan (name, time) for [now] among the five prayers
/// (فجر، ظهر، عصر، مغرب، عشاء). Sunrise is deliberately excluded so the app,
/// the home-screen widget and the widget preview all count down to the same
/// event — the next *adhan* — instead of the app reporting «طلوع آفتاب» while
/// the widget counts down to «اذان ظهر». After Isha the countdown wraps to
/// tomorrow's Fajr.
(String, DateTime) nextAdhanFor(
  DateTime now,
  DateTime fajr,
  DateTime dhuhr,
  DateTime asr,
  DateTime maghrib,
  DateTime isha,
) {
  final normalized = [
    wallClockTime(fajr),
    wallClockTime(dhuhr),
    wallClockTime(asr),
    wallClockTime(maghrib),
    wallClockTime(isha),
  ];
  const names = ['اذان صبح', 'اذان ظهر', 'اذان عصر', 'اذان مغرب', 'اذان عشاء'];
  for (var i = 0; i < normalized.length; i++) {
    if (now.isBefore(normalized[i])) return (names[i], normalized[i]);
  }
  final first = normalized.first;
  return (
    names.first,
    DateTime(first.year, first.month, first.day + 1, first.hour, first.minute),
  );
}

extension PrayerTimesWallClock on PrayerTimes {
  DateTime get wallFajr => wallClockTime(fajr);
  DateTime get wallSunrise => wallClockTime(sunrise);
  DateTime get wallDhuhr => wallClockTime(dhuhr);
  DateTime get wallAsr => wallClockTime(asr);
  DateTime get wallMaghrib => wallClockTime(maghrib);
  DateTime get wallIsha => wallClockTime(isha);
}

extension PrayerTimesX on PrayerTimes {
  DateTime getNextPrayerTime() {
    final now = DateTime.now();
    return nextAdhanFor(
      now,
      wallFajr,
      wallDhuhr,
      wallAsr,
      wallMaghrib,
      wallIsha,
    ).$2;
  }

  String get nextPrayerName => nextAdhanFor(
        DateTime.now(),
        wallFajr,
        wallDhuhr,
        wallAsr,
        wallMaghrib,
        wallIsha,
      ).$1;

  Duration getTimeUntilNextPrayer() =>
      getNextPrayerTime().difference(DateTime.now());

  bool isPrayerPassed(String prayerName) {
    final now = DateTime.now();
    return switch (prayerName) {
      'fajr' => now.isAfter(wallFajr),
      'sunrise' => now.isAfter(wallSunrise),
      'dhuhr' => now.isAfter(wallDhuhr),
      'asr' => now.isAfter(wallAsr),
      'maghrib' => now.isAfter(wallMaghrib),
      'isha' => now.isAfter(wallIsha),
      _ => false,
    };
  }

  String get currentPeriodLabel {
    final now = DateTime.now();
    if (now.isBefore(wallFajr)) return 'شب';
    if (now.isBefore(wallSunrise)) return 'فجر';
    if (now.isBefore(wallDhuhr)) return 'اشراق و صبح';
    if (now.isBefore(wallAsr)) return 'ظهر';
    if (now.isBefore(wallMaghrib)) return 'عصر';
    if (now.isBefore(wallIsha)) return 'مغرب';
    return 'عشاء';
  }

  Map<String, String> allTimes(SunnahTimes? sunnahTimes) {
    return {
      'fajr': formatTime(wallFajr),
      'sunrise': formatTime(wallSunrise),
      'dhuhr': formatTime(wallDhuhr),
      'asr': formatTime(wallAsr),
      'maghrib': formatTime(wallMaghrib),
      'isha': formatTime(wallIsha),
      'فجر': formatTime(wallFajr),
      'طلوع': formatTime(wallSunrise),
      'ظهر': formatTime(wallDhuhr),
      'عصر': formatTime(wallAsr),
      'مغرب': formatTime(wallMaghrib),
      'عشاء': formatTime(wallIsha),
      'نیمه شب': formatTime(sunnahTimes?.middleOfTheNight),
      'ثلث آخر': formatTime(sunnahTimes?.lastThirdOfTheNight),
    };
  }
}
