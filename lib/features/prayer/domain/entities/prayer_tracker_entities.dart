enum FardhPrayer { fajr, dhuhr, asr, maghrib, isha }

enum SunnahPrayer {
  fajrRawatib,
  dhuhrRawatibBefore,
  dhuhrRawatibAfter,
  maghribRawatib,
  ishaRawatib,
  witr
}

enum PrayerStatus { missed, done, qada, pending }

const Map<SunnahPrayer, String> sunnahPrayerNames = {
  SunnahPrayer.fajrRawatib: 'راتبه فجر (2 رکعت قبل)',
  SunnahPrayer.dhuhrRawatibBefore: 'راتبه ظهر (4 رکعت قبل)',
  SunnahPrayer.dhuhrRawatibAfter: 'راتبه ظهر (2 رکعت بعد)',
  SunnahPrayer.maghribRawatib: 'راتبه مغرب (2 رکعت بعد)',
  SunnahPrayer.ishaRawatib: 'راتبه عشاء (2 رکعت بعد)',
  SunnahPrayer.witr: 'وتر (3 رکعت بعد از عشاء)',
};

class FardhRecord {
  final String date;
  final PrayerStatus status;

  const FardhRecord({required this.date, required this.status});
}
