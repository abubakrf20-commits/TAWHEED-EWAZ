enum PrayerPeriod {
  fajr,
  shorouq,
  morningAzkar,
  duhr,
  asr,
  maghrib,
  eveningAzkar,
  isha,
  night,
  postPrayer,
}

extension PrayerPeriodExt on PrayerPeriod {
  String get label {
    switch (this) {
      case PrayerPeriod.fajr:
        return 'اذکار نماز فجر';
      case PrayerPeriod.shorouq:
        return 'اذکار شروق';
      case PrayerPeriod.morningAzkar:
        return 'اذکار صبح';
      case PrayerPeriod.duhr:
        return 'اذکار نماز ظهر';
      case PrayerPeriod.asr:
        return 'اذکار نماز عصر';
      case PrayerPeriod.maghrib:
        return 'اذکار نماز مغرب';
      case PrayerPeriod.eveningAzkar:
        return 'اذکار کامل شب';
      case PrayerPeriod.isha:
        return 'اذکار نماز عشاء';
      case PrayerPeriod.night:
        return 'اذکار شب';
      case PrayerPeriod.postPrayer:
        return 'اذکار بعد از نماز';
    }
  }

  String get icon {
    switch (this) {
      case PrayerPeriod.fajr:
        return '🌅';
      case PrayerPeriod.shorouq:
        return '🌄';
      case PrayerPeriod.morningAzkar:
        return '☀️';
      case PrayerPeriod.duhr:
        return '🌞';
      case PrayerPeriod.asr:
        return '🌇';
      case PrayerPeriod.maghrib:
        return '🌆';
      case PrayerPeriod.eveningAzkar:
        return '🌃';
      case PrayerPeriod.isha:
        return '🌙';
      case PrayerPeriod.night:
        return '🌌';
      case PrayerPeriod.postPrayer:
        return '🕌';
    }
  }
}
