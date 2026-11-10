// Option types used by [AppSettings]. Kept in a separate file so the
// settings model stays readable.

enum CalculationMethodOption {
  muslimWorldLeague,
  karachi,
  ummAlQura,
  egyptian,
  tehran,
  turkey,
  dubai,
  kuwait,
  qatar,
  singapore,
  northAmerica,
  moonsightingCommittee,
  custom,
  // --- Appended AFTER `custom` on purpose (index-stable). ---
  // The Drift settings table stores this enum as its int index and the JSON
  // model as its name, so an existing user's row only stays valid if new
  // values are appended at the end, never inserted in the middle.
  jafari,
  france,
  russia,
  gulfRegion,
  auto,
}

extension CalculationMethodExt on CalculationMethodOption {
  String get label {
    switch (this) {
      case CalculationMethodOption.muslimWorldLeague:
        return 'رابطه عالم اسلامی';
      case CalculationMethodOption.karachi:
        return 'کراچی (پاکستان)';
      case CalculationMethodOption.ummAlQura:
        return 'ام‌القرا (عربستان)';
      case CalculationMethodOption.egyptian:
        return 'مصری';
      case CalculationMethodOption.tehran:
        return 'تهران (ایران رسمی)';
      case CalculationMethodOption.turkey:
        return 'ترکیه';
      case CalculationMethodOption.dubai:
        return 'دبی (امارات)';
      case CalculationMethodOption.kuwait:
        return 'کویت';
      case CalculationMethodOption.qatar:
        return 'قطر';
      case CalculationMethodOption.singapore:
        return 'سنگاپور';
      case CalculationMethodOption.northAmerica:
        return 'آمریکای شمالی (ISNA)';
      case CalculationMethodOption.moonsightingCommittee:
        return 'کمیته رویت هلال';
      case CalculationMethodOption.custom:
        return 'روش محاسبه مخصص';
      case CalculationMethodOption.jafari:
        return 'جعفری (شیعه)';
      case CalculationMethodOption.france:
        return 'فرانسه (مسجد پاریس)';
      case CalculationMethodOption.russia:
        return 'روسیه (مسکو)';
      case CalculationMethodOption.gulfRegion:
        return 'منطقه خلیج';
      case CalculationMethodOption.auto:
        return 'خودکار — بر اساس کشور';
    }
  }

  /// توضیح کوتاه برای انتخاب روش — زاویه‌های پیش‌فرض فجر/عشاء هر روش تا
  /// کاربر بداند محاسبه با چه فرضی انجام می‌شود (اعتماد به محاسبه).
  String get description {
    switch (this) {
      case CalculationMethodOption.muslimWorldLeague:
        return 'زاویه فجر 18° و عشاء 17°';
      case CalculationMethodOption.karachi:
        return 'زاویه فجر 18° و عشاء 18°';
      case CalculationMethodOption.ummAlQura:
        return 'زاویه فجر 18.5° — عشاء 90 دقیقه پس از مغرب';
      case CalculationMethodOption.egyptian:
        return 'زاویه فجر 19.5° و عشاء 17.5°';
      case CalculationMethodOption.tehran:
        return 'زاویه فجر 17.7°، عشاء 14° و مغرب 4.5°';
      case CalculationMethodOption.turkey:
        return 'دیانت ترکیه — فجر 18° و عشاء 17°';
      case CalculationMethodOption.dubai:
        return 'زاویه فجر 18.2° و عشاء 18.2°';
      case CalculationMethodOption.kuwait:
        return 'زاویه فجر 18° و عشاء 17.5°';
      case CalculationMethodOption.qatar:
        return 'زاویه فجر 18° — عشاء 90 دقیقه پس از مغرب';
      case CalculationMethodOption.singapore:
        return 'زاویه فجر 20° و عشاء 18°';
      case CalculationMethodOption.northAmerica:
        return 'ISNA — فجر 15° و عشاء 15°';
      case CalculationMethodOption.moonsightingCommittee:
        return 'زاویه فجر 18° و عشاء 18°';
      case CalculationMethodOption.custom:
        return 'زاویه فجر و عشاء را خودتان تنظیم کنید';
      case CalculationMethodOption.jafari:
        return 'زاویه فجر 16°، عشاء 14° و مغرب 4°';
      case CalculationMethodOption.france:
        return 'زاویه فجر 12° و عشاء 12°';
      case CalculationMethodOption.russia:
        return 'زاویه فجر 16° و عشاء 15°';
      case CalculationMethodOption.gulfRegion:
        return 'زاویه فجر 19.5° — عشاء 90 دقیقه پس از مغرب';
      case CalculationMethodOption.auto:
        return 'روش هر کشور طبق رسم آن کشور؛ در صورت ناشناخته بودن، رابطه عالم اسلامی';
    }
  }
}

enum AsrMethod { hanafi, shafi }

extension AsrMethodExt on AsrMethod {
  String get label {
    switch (this) {
      case AsrMethod.hanafi:
        return 'حنفی';
      case AsrMethod.shafi:
        return 'شافعی / مالکی / حنبلی';
    }
  }
}

/// High-latitude rule for Fajr/Isha when the sun never dips far enough
/// (latitudes above ~48°). Mirrors `adhan.HighLatitudeRule` index order:
/// 0 = middle of the night (default), 1 = seventh of the night,
/// 2 = twilight angle.
enum HighLatitudeRuleOption {
  middleOfTheNight,
  seventhOfTheNight,
  twilightAngle,
}

extension HighLatitudeRuleOptionExt on HighLatitudeRuleOption {
  String get label {
    switch (this) {
      case HighLatitudeRuleOption.middleOfTheNight:
        return 'نیمه شب (پیش‌فرض)';
      case HighLatitudeRuleOption.seventhOfTheNight:
        return 'یک‌هفتم شب';
      case HighLatitudeRuleOption.twilightAngle:
        return 'زاویه گرگ‌ومیش';
    }
  }
}

enum ThemeModeOption { light, dark, system }

enum QuranThemeMode { light, dark, followApp }

extension QuranThemeModeExt on QuranThemeMode {
  String get label {
    switch (this) {
      case QuranThemeMode.light:
        return 'روشن';
      case QuranThemeMode.dark:
        return 'تاریک';
      case QuranThemeMode.followApp:
        return 'هماهنگ با برنامه';
    }
  }
}

/// Stored by [name] (never by index), so appending a value never reinterprets
/// an existing settings row.
enum FontFamilyOption {
  vazirmatn,
  amiri,
  calibri,
  tktTika,
  harir,
  parastoo,
  sakkalMajalla,
  sultanMedium,
  tabliq,
}

extension FontFamilyExt on FontFamilyOption {
  String get name {
    switch (this) {
      case FontFamilyOption.vazirmatn:
        return 'Vazirmatn';
      case FontFamilyOption.amiri:
        return 'Amiri';
      case FontFamilyOption.calibri:
        return 'Calibri';
      case FontFamilyOption.tktTika:
        return 'TKT-Tika';
      case FontFamilyOption.harir:
        return 'Harir';
      case FontFamilyOption.parastoo:
        return 'Parastoo';
      case FontFamilyOption.sakkalMajalla:
        return 'Sakkal Majalla';
      case FontFamilyOption.sultanMedium:
        return 'Sultan Medium';
      case FontFamilyOption.tabliq:
        return 'Tabliq';
    }
  }
}
