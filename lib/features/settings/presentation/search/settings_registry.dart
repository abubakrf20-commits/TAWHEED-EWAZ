import 'package:tawheeed/app/router/route_names.dart';

/// Single source of truth for settings search, summaries and tests.
///
/// One entry per searchable row. [prefs] lists the preference keys the row
/// surfaces (Drift fields and SharedPreferences keys alike); the integrity
/// test requires every known key to be covered or explicitly orphaned.
/// [route] is null for anchor rows living on the main page itself; [rowKey]
/// addresses the row for scroll-to + highlight inside its page.
class SettingsSearchEntry {
  const SettingsSearchEntry({
    required this.id,
    required this.title,
    this.subtitle,
    this.keywords = const [],
    required this.page,
    this.route,
    this.rowKey,
    this.prefs = const [],
  });

  final String id;
  final String title;
  final String? subtitle;
  final List<String> keywords;
  final SettingsSearchPage page;
  final String? route;
  final String? rowKey;
  final List<String> prefs;
}

enum SettingsSearchPage {
  main,
  prayer,
  notifications,
  widgets,
  account,
  font,
  about,
}

/// Persian/Arabic query normalization for search.
///
/// Folds the letters whose code points differ between the two scripts,
/// drops diacritics/tatweel, drops ZWNJ (a query typed without it still
/// matches), folds all digit shapes to Latin, lowercases. Same fold table
/// as the goals search so behavior is identical everywhere.
String normalizeSettingsQuery(String input) {
  const folds = <int, int>{
    0x064A: 0x06CC, // ARABIC YEH   → FARSI YEH
    0x0649: 0x06CC, // ALEF MAKSURA → FARSI YEH
    0x0643: 0x06A9, // ARABIC KAF   → KEHEH
    0x0629: 0x0647, // TEH MARBUTA  → HEH
    0x0623: 0x0627, // ALEF WITH HAMZA ABOVE → ALEF
    0x0622: 0x0627, // ALEF WITH MADDA ABOVE → ALEF
    0x0625: 0x0627, // ALEF WITH HAMZA BELOW → ALEF
    0x06F0: 0x0030,
    0x06F1: 0x0031,
    0x06F2: 0x0032,
    0x06F3: 0x0033,
    0x06F4: 0x0034,
    0x06F5: 0x0035,
    0x06F6: 0x0036,
    0x06F7: 0x0037,
    0x06F8: 0x0038,
    0x06F9: 0x0039,
    0x0660: 0x0030,
    0x0661: 0x0031,
    0x0662: 0x0032,
    0x0663: 0x0033,
    0x0664: 0x0034,
    0x0665: 0x0035,
    0x0666: 0x0036,
    0x0667: 0x0037,
    0x0668: 0x0038,
    0x0669: 0x0039,
  };
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x064B && rune <= 0x065F) continue; // diacritics/tanwin
    if (rune == 0x0670) continue; // superscript alef
    if (rune == 0x0640) continue; // tatweel
    if (rune == 0x200C) continue; // ZWNJ
    buffer.writeCharCode(folds[rune] ?? rune);
  }
  return buffer.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

int _scoreToken(String token, String title, String rest) {
  if (title.startsWith(token)) return 3;
  if (title.contains(token)) return 2;
  if (rest.contains(token)) return 1;
  return 0;
}

/// Interchangeable words for settings search.
///
/// Settings vocabulary varies far more than the row labels do: the same person
/// types «نوتیفیکیشن» one day and «اعلان» the next, «بکاپ» for «پشتیبان»,
/// «آپدیت» for «بروزرسانی», «ولوم» for «بلندی», or the Latin word they know
/// from another app («azan», «widget», «backup»). Every list below is a set of
/// terms that mean the same thing *for a settings search* — not a hierarchy.
///
/// A query token matches an entry when the token itself appears in the entry's
/// text, or when any term of its group does. Matching never widens a row's
/// scope: it only lets the row be found by the words the user already knows.
///
/// Rule for adding a group: every member must be interchangeable with every
/// other member. A loose member costs precision for all the others, so
/// ambiguous words («وقت», «کارت») stay out. Terms are normalized on load, so
/// «ي»/«ی», «آ»/«ا» and ZWNJ variants need only be listed once.
const settingsSearchSynonymGroups = <List<String>>[
  // اعلان
  [
    'اعلان',
    'نوتیف',
    'نوتیفیکیشن',
    'اطلاع',
    'اطلاعیه',
    'هشدار',
    'یادآوری',
    'یاداور',
    'reminder',
    'notification',
    'alert',
  ],
  // صدا
  ['صدا', 'صوت', 'آواز', 'بلندی', 'ولوم', 'volume', 'sound'],
  // ظاهر
  ['تم', 'رنگ', 'پوسته', 'ظاهر', 'قالب', 'پالت', 'theme', 'palette'],
  // فونت
  ['فونت', 'خط', 'قلم', 'font', 'typeface'],
  // اندازه
  ['اندازه', 'بزرگی', 'زوم', 'zoom', 'size'],
  // نماز
  ['نماز', 'صلات', 'صلاه', 'prayer', 'salat'],
  // اذان
  ['اذان', 'azan', 'adhan'],
  // وضعیت روشن/خاموش — the words people use for a toggle row. «روشن» is also
  // the light-theme keyword; that only overlaps on a single-word query, since
  // any second token separates the rows again.
  ['فعال', 'غیرفعال', 'روشن', 'خاموش', 'enable', 'disable', 'toggle'],
  // اقامه
  ['اقامه', 'iqamah', 'iqama'],
  // موقعیت
  ['موقعیت', 'مکان', 'شهر', 'لوکیشن', 'location', 'gps', 'city'],
  // روزه
  ['روزه', 'صیام', 'fasting'],
  // تسبیح
  ['تسبیح', 'ذکر', 'ورد', 'tasbih', 'dhikr'],
  // ویجت
  ['ویجت', 'ابزارک', 'widget'],
  // پول
  ['پول', 'ارز', 'واحد', 'currency', 'money'],
  // فضا
  ['فضا', 'حجم', 'حافظه', 'storage', 'cache', 'کش'],
  // نسخه («آپدیت» folds to «اپدیت» — one term, not two)
  ['نسخه', 'بروزرسانی', 'اپدیت', 'update', 'version'],
  // پشتیبان
  ['پشتیبان', 'بکاپ', 'backup', 'بازیابی', 'restore'],
  // قرآن
  ['قرآن', 'قران', 'quran', 'مصحف'],
  // جمعه
  ['جمعه', 'jumuah', 'friday'],
  // هجری
  ['هجری', 'قمری', 'هلال', 'hijri', 'lunar'],
  // باتری
  ['باتری', 'battery', 'doze'],
  // بی‌صدا
  ['بی‌صدا', 'سایلنت', 'silent', 'سکوت'],
  // امتیاز
  ['امتیاز', 'نمره', 'point', 'score'],
  // همگام
  ['همگام', 'سینک', 'sync'],
  // تقویم
  ['تقویم', 'ماه', 'calendar', 'month'],
  // ساعت
  ['ساعت', 'زمان', 'clock', 'time'],
  // خروجی و دریافت
  ['خروجی', 'صادرات', 'export', 'دریافت', 'واردات', 'import'],
  // بازنشانی
  ['بازنشانی', 'ریست', 'reset', 'پیش‌فرض', 'default'],
  // دسترسی
  ['مجوز', 'اجازه', 'permission', 'دسترسی'],
  // تست
  ['تست', 'آزمایش', 'test'],
];

/// normalized term → every term in its group (itself included), built once.
final Map<String, Set<String>> _synonymGroups = () {
  final index = <String, Set<String>>{};
  for (final group in settingsSearchSynonymGroups) {
    final normalized = <String>{
      for (final term in group)
        if (normalizeSettingsQuery(term).isNotEmpty)
          normalizeSettingsQuery(term),
    };
    if (normalized.length < 2) continue;
    for (final term in normalized) {
      index.putIfAbsent(term, () => normalized);
    }
  }
  return index;
}();

/// The other words a query token stands for (never the token itself).
Set<String> _otherTerms(String normalizedToken) {
  final group = _synonymGroups[normalizedToken];
  if (group == null) return const <String>{};
  return group.length == 1
      ? const <String>{}
      : (group.toSet()..remove(normalizedToken));
}

/// Every term a query token stands for — the token itself first, then its
/// synonym group. Exposed so tests (and anything explaining a match) can see
/// exactly why a row was returned.
List<String> settingsSearchAlternatives(String token) {
  final normalized = normalizeSettingsQuery(token);
  if (normalized.isEmpty) return const [];
  return [normalized, ..._otherTerms(normalized)];
}

/// Normalized `(title, rest)` per entry, computed once.
///
/// Search runs on every keystroke over ~90 entries; re-normalizing each
/// entry's title, subtitle and keywords on each keystroke was pure waste. The
/// registry is `const`, so an entry's text can never change — but the map is
/// identity-keyed so a caller that passes its own entries still gets correct
/// text rather than a stale hit.
final Map<SettingsSearchEntry, (String, String)> _normalizedText =
    Map<SettingsSearchEntry, (String, String)>.identity();

(String, String) _textOf(SettingsSearchEntry entry) =>
    _normalizedText[entry] ??= (
      normalizeSettingsQuery(entry.title),
      normalizeSettingsQuery(
          '${entry.subtitle ?? ''} ${entry.keywords.join(' ')}'),
    );

/// Punctuation a query may carry that no label ever contains. Typing
/// «اذان؟» on a mobile keyboard (or letting autocorrect add «،») used to match
/// nothing at all, because the token kept its trailing mark.
const _queryPunctuation = <String>[
  '؟',
  '،',
  '؛',
  '.',
  '!',
  '?',
  ',',
  ';',
  ':',
  '(',
  ')',
  '[',
  ']',
  '«',
  '»',
  '"',
  "'",
  '…',
  '-',
  '–',
  '—',
  '/',
  '\\',
  '*',
  '+',
  '=',
  '%',
  '#',
  '@',
  '&',
  '~',
  '|',
];

/// Words that carry no setting meaning on their own: the filler in a question
/// like «چطور اذان را خاموش کنم؟». Dropped only when the query has at least
/// one other token, so a query that IS one of these words still searches it
/// literally («تنظیمات» alone must not become an empty query).
///
/// Nothing here may also be a label word: «روشن», «زمان», «اندازه» and friends
/// are real settings vocabulary and must survive. Entries are written in their
/// NORMALIZED form (no «آ», no ZWNJ, «ی» not «ي») — that is what a token is
/// compared against, so a decorated spelling here would never match.
const settingsSearchStopWords = <String>{
  'چطور',
  'چگونه',
  'کجا',
  'کدام',
  'چیه',
  'چیست',
  'چه',
  'چرا',
  'ایا',
  'را',
  'از',
  'به',
  'در',
  'که',
  'و',
  'با',
  'برای',
  'بر',
  'تا',
  'هم',
  'رو',
  'می',
  'کنم',
  'کن',
  'کردن',
  'کرد',
  'کرده',
  'شود',
  'شده',
  'است',
  'هست',
  'باید',
  'میخواهم',
  'میخوام',
  'دادن',
  'عوض',
  'تغییر',
  'تنظیم',
  'تنظیمات',
  'گزینه',
  'قسمت',
  'بخش',
  'الان',
  'حالا',
};

/// Split a raw query into search tokens: normalized, punctuation-free, with
/// filler words dropped while at least one meaningful token remains.
List<String> settingsSearchTokens(String query) {
  var cleaned = normalizeSettingsQuery(query);
  for (final mark in _queryPunctuation) {
    if (cleaned.contains(mark)) cleaned = cleaned.replaceAll(mark, ' ');
  }
  final tokens =
      cleaned.split(' ').where((t) => t.isNotEmpty).toList(growable: false);
  if (tokens.length < 2) return tokens;
  final meaningful =
      tokens.where((t) => !settingsSearchStopWords.contains(t)).toList();
  return meaningful.isEmpty ? tokens : meaningful;
}

/// AND-semantics search over the registry: every query token must match
/// somewhere — title, subtitle, keywords, or a synonym of the token — and
/// title matches outrank the rest.
///
/// A literal hit always outranks a synonym hit for the same token: the score
/// is `literal * 4 + synonym`. Expanding a query can therefore add results but
/// can never push a row the user actually spelled out below one that only
/// matched a synonym.
List<SettingsSearchEntry> searchSettings(
  String query, {
  List<SettingsSearchEntry> entries = SettingsRegistry.entries,
}) {
  final tokens = settingsSearchTokens(query);
  if (tokens.isEmpty) return const [];
  // Resolve synonyms once per query, not once per entry.
  final alternatives = <Set<String>>[
    for (final token in tokens) _otherTerms(token),
  ];
  final scored = <(SettingsSearchEntry, int)>[];
  for (final entry in entries) {
    final (title, rest) = _textOf(entry);
    var literal = 0;
    var synonym = 0;
    var matchedAll = true;
    for (var i = 0; i < tokens.length; i++) {
      final direct = _scoreToken(tokens[i], title, rest);
      if (direct > 0) {
        literal += direct;
        continue;
      }
      var best = 0;
      for (final alt in alternatives[i]) {
        final s = _scoreToken(alt, title, rest);
        if (s > best) best = s;
      }
      if (best == 0) {
        matchedAll = false;
        break;
      }
      synonym += best;
    }
    if (!matchedAll) continue;
    scored.add((entry, literal * 4 + synonym));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final s in scored) s.$1];
}

/// Preference keys with no settings UI (kept intentionally — engine,
/// reader or checklist surfaces own them). The integrity test requires
/// every other known key to appear in some entry's [SettingsSearchEntry.prefs].
const settingsOrphanKeys = <String, String>{
  'quranFontSize': 'mushaf reader owns it; no settings row',
  'showEnglishTranslation': 'no settings row',
  'dailyWordEnabled': 'word-of-day scheduler; no settings row',
  'dailyWordHour': 'word-of-day scheduler; no settings row',
  'dailyWordMinute': 'word-of-day scheduler; no settings row',
  'quranThemeMode': 'mushaf reader owns it',
  'widgetRefreshMinutes': 'no settings row',
  'tafsirId': 'mushaf sheets own it',
  'tasbihDhikrSource': 'tasbih source; no settings row',
  'firstLaunch': 'onboarding flow, not a setting',
  'onboardingCompleted': 'onboarding flow, not a setting',
  'isPremium': 'not surfaced in settings UI',
  'quickActions': 'home quick-access editor owns it',
  'excludedWorship': 'worship-checklist screen owns it',
  'customWorshipItems': 'worship-checklist screen owns it',
  'hiddenWorshipItems': 'worship-checklist screen owns it',
  'widget_bg_color':
      'legacy widget style; read once to mirror the native migration',
  'widget_text_color':
      'legacy widget style; read once to mirror the native migration',
  'widget_opacity':
      'legacy widget style; read once to mirror the native migration',
  'widget_corner_radius':
      'legacy widget style; read once to mirror the native migration',
  'zakat_currency_code':
      'legacy zakat unit; migrated into app_currency_code on first read',
};

/// Every known preference key (Drift fields + SharedPreferences keys used
/// by settings UI). The integrity test requires each to be covered by an
/// entry or listed in [settingsOrphanKeys].
const settingsAllKeys = <String>[
  // AppSettings fields.
  'calculationMethod',
  'asrMethod',
  'highLatitudeRule',
  'useLocation',
  'city',
  'manualLat',
  'manualLng',
  'hasLocation',
  'customFajrAngle',
  'customIshaAngle',
  'fajrOffset',
  'sunriseOffset',
  'dhuhrOffset',
  'asrOffset',
  'maghribOffset',
  'ishaOffset',
  'globalPrayerOffset',
  'iqamahOffsetFajr',
  'iqamahOffsetDhuhr',
  'iqamahOffsetAsr',
  'iqamahOffsetMaghrib',
  'iqamahOffsetIsha',
  'fridayPrayerTime',
  'prayerNotifications',
  'prayerNotifMinutes',
  'morningAzkarNotification',
  'morningAzkarTime',
  'eveningAzkarNotification',
  'eveningAzkarTime',
  'quranReminder',
  'quranReminderTime',
  'silentDuringPrayer',
  'silentDuration',
  'silentBeforeIqamah',
  'silentBeforeIqamahMinutes',
  'dailyVerse',
  'dailyVerseTime',
  'dailyHadith',
  'dailyHadithTime',
  'dailyDua',
  'dailyDuaTime',
  'dailyWordEnabled',
  'dailyWordHour',
  'dailyWordMinute',
  'themeMode',
  'quranThemeMode',
  'fontFamily',
  'fontScale',
  'showArabicText',
  'showDaleel',
  'largeArabicFont',
  'showEnglishTranslation',
  'quranFontSize',
  'appFontSize',
  'accentPreset',
  'isPremium',
  'use12Hour',
  'azanSound',
  'customAzanPath',
  'azanVolume',
  'azanEnabledForFajr',
  'azanEnabledForDhuhr',
  'azanEnabledForAsr',
  'azanEnabledForMaghrib',
  'azanEnabledForIsha',
  'widgetRefreshMinutes',
  'tafsirId',
  'elevationCorrection',
  'firstLaunch',
  'onboardingCompleted',
  'hijriOffset',
  'quickActions',
  'tasbihDhikrSource',
  'timezone',
  'fardhPoint',
  'sunnahPoint',
  'duhaPoint',
  'adhkarPoint',
  'tasbihPoint',
  'worshipMultiplier',
  'excludedWorship',
  'customWorshipItems',
  'hiddenWorshipItems',
  // SharedPreferences keys used by settings UI.
  'azkar_sound_volume',
  'azkar_sound',
  'sound_alert_volume',
  'silent_after_iqamah_minutes',
  'widget_palette_id',
  'widget_opacity_step',
  'month_display',
  // Legacy widget-style keys, still read once to mirror the native migration.
  'widget_bg_color',
  'widget_text_color',
  'widget_opacity',
  'widget_corner_radius',
  'notif_azkar_master_recall',
  'notif_azkar_morning_manual',
  'notif_azkar_evening_manual',
  'notif_post_prayer_enabled',
  'notif_post_prayer_delay_minutes',
  'notif_islamic_events_enabled',
  'friday_reminder_enabled',
  'friday_reminder_hour',
  'friday_reminder_minute',
  'friday_kahf_reminder_enabled',
  'friday_kahf_reminder_hour',
  'friday_kahf_reminder_minute',
  'fasting_monday_thursday_enabled',
  'fasting_monday_thursday_hour',
  'fasting_monday_thursday_minute',
  'fasting_ayam_al_bidh_enabled',
  'fasting_ayam_al_bidh_hour',
  'fasting_ayam_al_bidh_minute',
  'notif_snooze_minutes',
  // Unit of entry for the money tools (see CurrencyStore): the calculators
  // (zakat, fitr, inheritance) and the expenses ledger are separate stores.
  'app_currency_code',
  'expenses_currency_code',
];

/// Route table the registry may point at. The integrity test requires every
/// entry route to be one of these (all verified in RouteNames).
const settingsKnownRoutes = <String>[
  RouteNames.settings,
  RouteNames.fontSettings,
  RouteNames.prayerSettings,
  RouteNames.mapPicker,
  RouteNames.notificationSettings,
  RouteNames.notificationDiagnostics,
  RouteNames.widgetSettings,
  RouteNames.account,
  RouteNames.about,
  RouteNames.suggestions,
  RouteNames.announcements,
  RouteNames.personalInfo,
  RouteNames.batteryOptimization,
  RouteNames.storageSettings,
  RouteNames.worshipScoring,
  RouteNames.worshipScoringPrayer,
  RouteNames.worshipScoringAdhkar,
  RouteNames.worshipScoringTaaat,
];

abstract final class SettingsRegistry {
  static const List<SettingsSearchEntry> entries = [
    // ── Main page ──
    SettingsSearchEntry(
      id: 'main.appearance',
      title: 'تم و حالت نمایش',
      keywords: [
        'تم', 'حالت', 'نمایش', 'روشن', 'تاریک', 'سیستم', 'theme',
        // The six theme names, so «طلایی» / «سحر» / «شب» find the row the
        // user remembers by its look rather than by its section title.
        'زنده', 'طلایی', 'سحر', 'روز', 'غروب', 'شب',
      ],
      page: SettingsSearchPage.main,
      rowKey: 'appearance',
      prefs: ['themeMode', 'accentPreset'],
    ),
    SettingsSearchEntry(
      id: 'main.font',
      title: 'فونت و نمایش',
      keywords: [
        'فونت', 'اندازه', 'متن عربی', 'نام ماه', 'font',
        // Font names — a user looking for the typeface types the typeface.
        'Vazirmatn', 'Amiri', 'Calibri', 'Tika', 'Harir',
      ],
      page: SettingsSearchPage.main,
      route: RouteNames.fontSettings,
      prefs: ['fontFamily', 'appFontSize', 'fontScale'],
    ),
    SettingsSearchEntry(
      id: 'main.prayer',
      title: 'تنظیمات اذان و اقامه',
      keywords: ['اذان', 'اقامه', 'نماز', 'adhan'],
      page: SettingsSearchPage.main,
      route: RouteNames.prayerSettings,
    ),
    SettingsSearchEntry(
      id: 'main.hijri',
      title: 'تنظیم تاریخ هجری',
      keywords: ['هجری', 'هلال', 'تقویم', 'hijri'],
      page: SettingsSearchPage.main,
      rowKey: 'hijri',
      prefs: ['hijriOffset'],
    ),
    SettingsSearchEntry(
      id: 'main.tasbih_sound',
      title: 'صدای کلیک تسبیح',
      keywords: ['صدا', 'تسبیح', 'کلیک', 'volume'],
      page: SettingsSearchPage.main,
      rowKey: 'sounds',
      prefs: ['azkar_sound_volume', 'azkar_sound'],
    ),
    SettingsSearchEntry(
      id: 'main.alert_sound',
      title: 'صدای هشدار',
      keywords: ['صدا', 'هشدار', 'پومودورو', 'volume'],
      page: SettingsSearchPage.main,
      rowKey: 'sounds',
      prefs: ['sound_alert_volume'],
    ),
    SettingsSearchEntry(
      id: 'main.adhan_volume',
      title: 'صدای اذان',
      keywords: ['صدا', 'اذان', 'volume', 'بلندی'],
      page: SettingsSearchPage.main,
      rowKey: 'sounds',
      prefs: ['azanVolume'],
    ),
    SettingsSearchEntry(
      id: 'main.score.fardh',
      title: 'امتیاز هر نماز واجب',
      keywords: ['امتیاز', 'فرض', 'نماز واجب', 'نمره'],
      page: SettingsSearchPage.main,
      route: RouteNames.worshipScoringPrayer,
      prefs: ['fardhPoint'],
    ),
    SettingsSearchEntry(
      id: 'main.score.sunnah',
      title: 'امتیاز هر سنت و وتر',
      keywords: ['امتیاز', 'سنت', 'وتر', 'رواتب'],
      page: SettingsSearchPage.main,
      route: RouteNames.worshipScoringPrayer,
      prefs: ['sunnahPoint'],
    ),
    SettingsSearchEntry(
      id: 'main.score.duha',
      title: 'امتیاز نماز ضحی',
      keywords: ['امتیاز', 'ضحی', 'چاشت'],
      page: SettingsSearchPage.main,
      route: RouteNames.worshipScoringPrayer,
      prefs: ['duhaPoint'],
    ),
    SettingsSearchEntry(
      id: 'main.score.adhkar',
      title: 'امتیاز اذکار صبح و شام',
      keywords: ['امتیاز', 'اذکار', 'صبح', 'شام'],
      page: SettingsSearchPage.main,
      route: RouteNames.worshipScoringAdhkar,
      prefs: ['adhkarPoint'],
    ),
    SettingsSearchEntry(
      id: 'main.score.tasbih',
      title: 'امتیاز تسبیح',
      keywords: ['امتیاز', 'تسبیح'],
      page: SettingsSearchPage.main,
      route: RouteNames.worshipScoringAdhkar,
      prefs: ['tasbihPoint'],
    ),
    SettingsSearchEntry(
      id: 'main.score.multiplier',
      title: 'ضریب امتیاز طاعات',
      keywords: ['امتیاز', 'طاعات', 'ضریب', 'درصد'],
      page: SettingsSearchPage.main,
      route: RouteNames.worshipScoringTaaat,
      prefs: ['worshipMultiplier'],
    ),
    SettingsSearchEntry(
      id: 'main.notifications',
      title: 'تنظیمات اعلان‌ها و اذکار',
      keywords: ['اعلان', 'اذکار', 'یادآوری', 'notification'],
      page: SettingsSearchPage.main,
      route: RouteNames.notificationSettings,
    ),
    SettingsSearchEntry(
      id: 'main.diagnostics',
      title: 'تشخیص تنظیمات گوشی',
      keywords: ['مجوز', 'باتری', 'تشخیص', 'permission'],
      page: SettingsSearchPage.main,
      route: RouteNames.notificationDiagnostics,
    ),
    SettingsSearchEntry(
      id: 'main.widgets',
      title: 'تنظیم ویجت‌ها',
      keywords: ['ویجت', 'صفحه اصلی', 'رنگ', 'widget'],
      page: SettingsSearchPage.main,
      route: RouteNames.widgetSettings,
      prefs: ['widget_palette_id', 'widget_opacity_step'],
    ),
    SettingsSearchEntry(
      id: 'main.currency',
      title: 'واحد پول',
      subtitle:
          'واحد همهٔ بخش‌های مالی: زکات، فطر، میراث، کفاره، قلک، بدهی، مغازه و هزینه‌ها',
      keywords: [
        'واحد',
        'پول',
        'تومان',
        'دلار',
        'درهم',
        'افغانی',
        'دینار',
        'یورو',
        'هزینه',
        'currency',
      ],
      page: SettingsSearchPage.main,
      rowKey: 'currency',
      prefs: ['app_currency_code', 'expenses_currency_code'],
    ),
    SettingsSearchEntry(
      id: 'main.account',
      title: 'حساب و پشتیبان',
      keywords: [
        'حساب',
        'ابری',
        'ورود',
        'پشتیبان',
        'انتقال',
        'account',
        'backup'
      ],
      page: SettingsSearchPage.account,
      route: RouteNames.account,
    ),
    SettingsSearchEntry(
      id: 'main.backup.auto',
      title: 'پشتیبان‌گیری خودکار روزانه',
      keywords: ['پشتیبان', 'خودکار', 'روزانه', 'backup', 'export'],
      page: SettingsSearchPage.account,
      route: RouteNames.account,
      rowKey: 'local',
    ),
    SettingsSearchEntry(
      id: 'main.backup.full',
      title: 'ایجاد پشتیبان کامل',
      keywords: ['پشتیبان', 'کامل', 'زیپ', 'فایل', 'backup', 'export', 'zip'],
      page: SettingsSearchPage.account,
      route: RouteNames.account,
      rowKey: 'local',
    ),
    SettingsSearchEntry(
      id: 'main.backup.restore',
      title: 'بازگردانی پشتیبان',
      keywords: ['بازگردانی', 'بازیابی', 'پشتیبان', 'restore', 'json'],
      page: SettingsSearchPage.account,
      route: RouteNames.account,
      rowKey: 'local',
    ),
    SettingsSearchEntry(
      id: 'main.export_settings',
      title: 'خروجی گرفتن از تنظیمات',
      keywords: ['انتقال', 'خروجی', 'json', 'فایل', 'تنظیمات', 'export'],
      page: SettingsSearchPage.account,
      route: RouteNames.account,
      rowKey: 'transfer',
    ),
    SettingsSearchEntry(
      id: 'main.import_settings',
      title: 'دریافت تنظیمات از فایل',
      keywords: [
        'انتقال',
        'دریافت',
        'بازگردانی',
        'json',
        'فایل',
        'تنظیمات',
        'import',
      ],
      page: SettingsSearchPage.account,
      route: RouteNames.account,
      rowKey: 'transfer',
    ),
    SettingsSearchEntry(
      id: 'main.reset',
      title: 'بازنشانی تنظیمات',
      keywords: ['بازنشانی', 'ریست', 'پیش‌فرض', 'اولیه', 'reset'],
      page: SettingsSearchPage.account,
      route: RouteNames.account,
      rowKey: 'danger',
    ),
    SettingsSearchEntry(
      id: 'main.wipe',
      title: 'پاک‌سازی کامل دستگاه',
      keywords: ['پاک', 'حذف همه', 'داده', 'wipe', 'erase', 'reset'],
      page: SettingsSearchPage.account,
      route: RouteNames.account,
      rowKey: 'danger',
    ),
    SettingsSearchEntry(
      id: 'main.battery',
      title: 'بهینه‌سازی باتری',
      keywords: ['باتری', 'پس‌زمینه', 'battery'],
      page: SettingsSearchPage.main,
      route: RouteNames.batteryOptimization,
    ),
    SettingsSearchEntry(
      id: 'main.storage',
      title: 'مدیریت فضا',
      keywords: ['فضا', 'حجم', 'storage', 'پاک‌سازی', 'دانلود'],
      page: SettingsSearchPage.main,
      route: RouteNames.storageSettings,
    ),
    SettingsSearchEntry(
      id: 'main.suggestions',
      title: 'ارسال پیشنهاد',
      keywords: ['پیشنهاد', 'انتقاد', 'خطا', 'گزارش'],
      page: SettingsSearchPage.main,
      route: RouteNames.suggestions,
    ),
    SettingsSearchEntry(
      id: 'main.announcements',
      title: 'پیام‌های مدیریت',
      keywords: ['پیام', 'اطلاعیه', 'مدیریت', 'announcements'],
      page: SettingsSearchPage.main,
      route: RouteNames.announcements,
    ),
    SettingsSearchEntry(
      id: 'main.about',
      title: 'درباره برنامه',
      keywords: ['درباره', 'نسخه', 'about'],
      page: SettingsSearchPage.main,
      route: RouteNames.about,
    ),
    // ── Prayer & Adhan page ──
    SettingsSearchEntry(
      id: 'prayer.adhan_sound',
      title: 'صوت اذان',
      keywords: ['اذان', 'صوت', 'الغامدی', 'مؤذن', 'adhan'],
      page: SettingsSearchPage.prayer,
      rowKey: 'adhan_sound',
      prefs: ['azanSound', 'customAzanPath'],
    ),
    SettingsSearchEntry(
      id: 'prayer.adhan_test',
      title: 'پخش صدای اذان (تست)',
      keywords: ['اذان', 'تست', 'پخش', 'test'],
      page: SettingsSearchPage.prayer,
      rowKey: 'adhan_sound',
    ),
    SettingsSearchEntry(
      id: 'prayer.adhan_notif_test',
      title: 'تست اعلان اذان',
      keywords: ['اذان', 'اعلان', 'تست', 'test'],
      page: SettingsSearchPage.prayer,
      rowKey: 'adhan_sound',
    ),
    SettingsSearchEntry(
      id: 'prayer.calc_method',
      title: 'روش محاسبه',
      keywords: [
        'محاسبه',
        'روش',
        'زاویه',
        'فجر',
        'عشاء',
        // The method names, so a city/method word finds this row.
        'خودکار',
        'کشور',
        'رابطه عالم اسلامی',
        'کراچی',
        'ایران',
        'تهران',
        'جعفری',
        'عربستان',
        'مصر',
        'ترکیه',
        'فرانسه',
        'روسیه',
      ],
      page: SettingsSearchPage.prayer,
      rowKey: 'calc',
      prefs: ['calculationMethod'],
    ),
    SettingsSearchEntry(
      id: 'prayer.asr',
      title: 'مذهب عصر',
      keywords: ['عصر', 'حنفی', 'شافعی', 'مذهب'],
      page: SettingsSearchPage.prayer,
      rowKey: 'calc',
      prefs: ['asrMethod'],
    ),
    SettingsSearchEntry(
      id: 'prayer.high_lat',
      title: 'قانون عرض بالا',
      keywords: ['عرض', 'قطب', 'نیمه شب', 'گرگ'],
      page: SettingsSearchPage.prayer,
      rowKey: 'calc',
      prefs: ['highLatitudeRule'],
    ),
    SettingsSearchEntry(
      id: 'prayer.fajr_angle',
      title: 'زاویه فجر',
      keywords: ['زاویه', 'فجر', 'درجه'],
      page: SettingsSearchPage.prayer,
      rowKey: 'calc',
      prefs: ['customFajrAngle'],
    ),
    SettingsSearchEntry(
      id: 'prayer.isha_angle',
      title: 'زاویه عشاء',
      keywords: ['زاویه', 'عشاء', 'درجه'],
      page: SettingsSearchPage.prayer,
      rowKey: 'calc',
      prefs: ['customIshaAngle'],
    ),
    SettingsSearchEntry(
      id: 'prayer.elevation',
      title: 'اصلاح ارتفاع مکان',
      keywords: ['ارتفاع', 'افق', 'دریا', 'elevation'],
      page: SettingsSearchPage.prayer,
      rowKey: 'calc',
      prefs: ['elevationCorrection'],
    ),
    SettingsSearchEntry(
      id: 'prayer.calc_details',
      title: 'جزئیات محاسبه',
      keywords: ['جزئیات', 'ورودی', 'صحت', 'مختصات'],
      page: SettingsSearchPage.prayer,
      rowKey: 'calc',
      prefs: ['city', 'manualLat', 'manualLng', 'timezone', 'hasLocation'],
    ),
    SettingsSearchEntry(
      id: 'prayer.location',
      title: 'موقعیت مکانی',
      keywords: ['موقعیت', 'شهر', 'نقشه', 'GPS', 'مختصات'],
      page: SettingsSearchPage.prayer,
      rowKey: 'location',
      prefs: ['useLocation', 'city', 'manualLat', 'manualLng', 'timezone'],
    ),
    SettingsSearchEntry(
      id: 'prayer.map',
      title: 'انتخاب از روی نقشه',
      keywords: ['نقشه', 'موقعیت', 'map'],
      page: SettingsSearchPage.prayer,
      route: RouteNames.mapPicker,
      prefs: ['useLocation', 'manualLat', 'manualLng'],
    ),
    SettingsSearchEntry(
      id: 'prayer.adhan.fajr',
      title: 'اذان فجر',
      subtitle: 'پخش، جابجایی و اقامه فجر',
      keywords: ['فجر', 'صبح', 'اذان', 'اقامه', 'خاموش'],
      page: SettingsSearchPage.prayer,
      rowKey: 'prayer.fajr',
      prefs: ['azanEnabledForFajr', 'fajrOffset', 'iqamahOffsetFajr'],
    ),
    SettingsSearchEntry(
      id: 'prayer.adhan.dhuhr',
      title: 'اذان ظهر',
      subtitle: 'پخش، جابجایی و اقامه ظهر',
      keywords: ['ظهر', 'اذان', 'اقامه', 'خاموش'],
      page: SettingsSearchPage.prayer,
      rowKey: 'prayer.dhuhr',
      prefs: ['azanEnabledForDhuhr', 'dhuhrOffset', 'iqamahOffsetDhuhr'],
    ),
    SettingsSearchEntry(
      id: 'prayer.adhan.asr',
      title: 'اذان عصر',
      subtitle: 'پخش، جابجایی و اقامه عصر',
      keywords: ['عصر', 'اذان', 'اقامه', 'خاموش'],
      page: SettingsSearchPage.prayer,
      rowKey: 'prayer.asr',
      prefs: ['azanEnabledForAsr', 'asrOffset', 'iqamahOffsetAsr'],
    ),
    SettingsSearchEntry(
      id: 'prayer.adhan.maghrib',
      title: 'اذان مغرب',
      subtitle: 'پخش، جابجایی و اقامه مغرب',
      keywords: ['مغرب', 'اذان', 'اقامه', 'خاموش'],
      page: SettingsSearchPage.prayer,
      rowKey: 'prayer.maghrib',
      prefs: ['azanEnabledForMaghrib', 'maghribOffset', 'iqamahOffsetMaghrib'],
    ),
    SettingsSearchEntry(
      id: 'prayer.adhan.isha',
      title: 'اذان عشاء',
      subtitle: 'پخش، جابجایی و اقامه عشاء',
      keywords: ['عشاء', 'اذان', 'اقامه', 'خاموش'],
      page: SettingsSearchPage.prayer,
      rowKey: 'prayer.isha',
      prefs: ['azanEnabledForIsha', 'ishaOffset', 'iqamahOffsetIsha'],
    ),
    SettingsSearchEntry(
      id: 'prayer.notif',
      title: 'یادآوری اوقات نماز',
      keywords: ['یادآوری', 'نماز', 'اعلان'],
      page: SettingsSearchPage.prayer,
      rowKey: 'prayer_notif',
      prefs: ['prayerNotifications'],
    ),
    SettingsSearchEntry(
      id: 'prayer.notif_minutes',
      title: 'یادآوری قبل از اذان',
      keywords: ['یادآوری', 'قبل', 'دقیقه', 'اذان'],
      page: SettingsSearchPage.prayer,
      rowKey: 'prayer_notif',
      prefs: ['prayerNotifMinutes'],
    ),
    SettingsSearchEntry(
      id: 'prayer.global_shift',
      title: 'جابجایی کلی اوقات',
      keywords: ['جابجایی', 'کلی', 'تابستانی', 'اختلاف'],
      page: SettingsSearchPage.prayer,
      rowKey: 'global_shift',
      prefs: ['globalPrayerOffset'],
    ),
    SettingsSearchEntry(
      id: 'prayer.sunrise',
      title: 'جابجایی طلوع آفتاب',
      keywords: ['طلوع', 'آفتاب', 'sunrise'],
      page: SettingsSearchPage.prayer,
      rowKey: 'global_shift',
      prefs: ['sunriseOffset'],
    ),
    SettingsSearchEntry(
      id: 'prayer.friday',
      title: 'وقت نماز جمعه',
      keywords: ['جمعه', 'ظهر', 'friday'],
      page: SettingsSearchPage.prayer,
      rowKey: 'friday',
      prefs: ['fridayPrayerTime'],
    ),
    SettingsSearchEntry(
      id: 'prayer.silent.iqamah',
      title: 'بی‌صدا قبل از اقامه',
      keywords: ['بی‌صدا', 'اقامه', 'مزاحمت', 'silent'],
      page: SettingsSearchPage.prayer,
      rowKey: 'silent',
      prefs: ['silentBeforeIqamah', 'silentBeforeIqamahMinutes'],
    ),
    SettingsSearchEntry(
      id: 'prayer.silent.after',
      title: 'ماندن بی‌صدا بعد از اقامه',
      keywords: ['بی‌صدا', 'بعد', 'اقامه', 'silent'],
      page: SettingsSearchPage.prayer,
      rowKey: 'silent',
      prefs: ['silent_after_iqamah_minutes'],
    ),
    SettingsSearchEntry(
      id: 'prayer.silent.during',
      title: 'بی‌صدا در وقت نماز',
      keywords: ['بی‌صدا', 'نماز', 'مدت', 'silent'],
      page: SettingsSearchPage.prayer,
      rowKey: 'silent',
      prefs: ['silentDuringPrayer', 'silentDuration'],
    ),
    // ── Notifications page ──
    SettingsSearchEntry(
      id: 'notif.adhkar',
      title: 'یادآوری اذکار صبح و شب',
      keywords: ['اذکار', 'صبح', 'شب', 'یادآوری'],
      page: SettingsSearchPage.notifications,
      route: RouteNames.notificationSettings,
      rowKey: 'adhkar',
      prefs: [
        'morningAzkarNotification',
        'morningAzkarTime',
        'eveningAzkarNotification',
        'eveningAzkarTime',
        'notif_azkar_master_recall',
        'notif_azkar_morning_manual',
        'notif_azkar_evening_manual'
      ],
    ),
    SettingsSearchEntry(
      id: 'notif.post_prayer',
      title: 'اذکار بعد از نماز',
      keywords: ['اذکار', 'بعد', 'نماز', 'اقامه'],
      page: SettingsSearchPage.notifications,
      route: RouteNames.notificationSettings,
      rowKey: 'post_prayer',
      prefs: ['notif_post_prayer_enabled', 'notif_post_prayer_delay_minutes'],
    ),
    SettingsSearchEntry(
      id: 'notif.verse',
      title: 'آیه روز',
      keywords: ['آیه', 'قرآن', 'روز'],
      page: SettingsSearchPage.notifications,
      route: RouteNames.notificationSettings,
      rowKey: 'daily',
      prefs: ['dailyVerse', 'dailyVerseTime'],
    ),
    SettingsSearchEntry(
      id: 'notif.hadith',
      title: 'حدیث روز',
      keywords: ['حدیث', 'روز', 'چهل'],
      page: SettingsSearchPage.notifications,
      route: RouteNames.notificationSettings,
      rowKey: 'daily',
      prefs: ['dailyHadith', 'dailyHadithTime'],
    ),
    SettingsSearchEntry(
      id: 'notif.dua',
      title: 'دعای روز',
      keywords: ['دعا', 'روز'],
      page: SettingsSearchPage.notifications,
      route: RouteNames.notificationSettings,
      rowKey: 'daily',
      prefs: ['dailyDua', 'dailyDuaTime'],
    ),
    SettingsSearchEntry(
      id: 'notif.quran',
      title: 'یادآوری تلاوت قرآن',
      keywords: ['قرآن', 'تلاوت', 'یادآوری'],
      page: SettingsSearchPage.notifications,
      route: RouteNames.notificationSettings,
      rowKey: 'quran',
      prefs: ['quranReminder', 'quranReminderTime'],
    ),
    SettingsSearchEntry(
      id: 'notif.events',
      title: 'یادآوری مناسبت‌ها',
      keywords: ['مناسبت', 'اعیاد', 'اسلامی'],
      page: SettingsSearchPage.notifications,
      route: RouteNames.notificationSettings,
      rowKey: 'events',
      prefs: ['notif_islamic_events_enabled'],
    ),
    SettingsSearchEntry(
      id: 'notif.friday',
      title: 'یادآوری روز جمعه',
      keywords: ['جمعه', 'کهف', 'آداب'],
      page: SettingsSearchPage.notifications,
      route: RouteNames.notificationSettings,
      rowKey: 'friday',
      prefs: [
        'friday_reminder_enabled',
        'friday_reminder_hour',
        'friday_reminder_minute',
        'friday_kahf_reminder_enabled',
        'friday_kahf_reminder_hour',
        'friday_kahf_reminder_minute'
      ],
    ),
    SettingsSearchEntry(
      id: 'notif.fasting',
      title: 'یادآوری روزه‌های مستحب',
      keywords: ['روزه', 'دوشنبه', 'پنجشنبه', 'ایام بیض', 'fasting'],
      page: SettingsSearchPage.notifications,
      route: RouteNames.notificationSettings,
      rowKey: 'fasting',
      prefs: [
        'fasting_monday_thursday_enabled',
        'fasting_monday_thursday_hour',
        'fasting_monday_thursday_minute',
        'fasting_ayam_al_bidh_enabled',
        'fasting_ayam_al_bidh_hour',
        'fasting_ayam_al_bidh_minute'
      ],
    ),
    SettingsSearchEntry(
      id: 'notif.snooze',
      title: 'مدت به تعویق',
      keywords: ['تعویق', 'snooze', 'دقیقه'],
      page: SettingsSearchPage.notifications,
      route: RouteNames.notificationSettings,
      rowKey: 'misc',
      prefs: ['notif_snooze_minutes'],
    ),
    SettingsSearchEntry(
      id: 'notif.cancel_all',
      title: 'لغو همه یادآوری‌ها',
      keywords: ['لغو', 'همه', 'خاموش'],
      page: SettingsSearchPage.notifications,
      route: RouteNames.notificationSettings,
      rowKey: 'misc',
    ),
    // ── Widgets page ──
    SettingsSearchEntry(
      id: 'widgets.colors',
      title: 'پالت رنگ ویجت‌ها',
      keywords: ['ویجت', 'رنگ', 'پالت', 'پس‌زمینه'],
      page: SettingsSearchPage.widgets,
      route: RouteNames.widgetSettings,
      rowKey: 'colors',
      prefs: ['widget_palette_id'],
    ),
    SettingsSearchEntry(
      id: 'widgets.opacity',
      title: 'شفافیت ویجت',
      keywords: ['ویجت', 'شفافیت', 'opacity'],
      page: SettingsSearchPage.widgets,
      route: RouteNames.widgetSettings,
      rowKey: 'sliders',
      prefs: ['widget_opacity_step'],
    ),
    // ── Account page ──
    SettingsSearchEntry(
      id: 'account.signin',
      title: 'ورود به حساب',
      keywords: ['حساب', 'ورود', 'گوگل', 'ایمیل', 'account'],
      page: SettingsSearchPage.account,
      route: RouteNames.account,
      rowKey: 'signin',
    ),
    SettingsSearchEntry(
      id: 'account.cloud.drive',
      title: 'نسخه‌های Google Drive',
      keywords: ['ابری', 'درایو', 'آپلود', 'بازیابی', 'cloud', 'drive'],
      page: SettingsSearchPage.account,
      route: RouteNames.account,
      rowKey: 'cloud-drive',
    ),
    SettingsSearchEntry(
      id: 'account.cloud.app',
      title: 'نسخه‌های فضای ابری برنامه',
      keywords: ['ابری', 'آپلود', 'بازیابی', 'cloud', 'firebase'],
      page: SettingsSearchPage.account,
      route: RouteNames.account,
      rowKey: 'cloud-app',
    ),
    SettingsSearchEntry(
      id: 'account.delete',
      title: 'حذف حساب کاربری',
      keywords: ['حذف', 'حساب', 'delete'],
      page: SettingsSearchPage.account,
      route: RouteNames.account,
      rowKey: 'danger',
    ),
    // ── Font page ──
    SettingsSearchEntry(
      id: 'font.family',
      title: 'فونت برنامه',
      keywords: ['فونت', 'وزیرمتن', 'font'],
      page: SettingsSearchPage.font,
      route: RouteNames.fontSettings,
      rowKey: 'family',
      prefs: ['fontFamily'],
    ),
    SettingsSearchEntry(
      id: 'font.size',
      title: 'اندازه فونت',
      keywords: ['فونت', 'اندازه', 'بزرگ', 'کوچک'],
      page: SettingsSearchPage.font,
      route: RouteNames.fontSettings,
      rowKey: 'size',
      prefs: ['appFontSize', 'fontScale'],
    ),
    SettingsSearchEntry(
      id: 'font.clock12',
      title: 'ساعت 12 ساعته',
      keywords: ['ساعت', 'صبح', 'عصر', 'قالب'],
      page: SettingsSearchPage.font,
      route: RouteNames.fontSettings,
      rowKey: 'toggles',
      prefs: ['use12Hour'],
    ),
    SettingsSearchEntry(
      id: 'font.month_display',
      title: 'روش عرضه ماه',
      subtitle: 'نام ماه‌های شمسی: ایرانی یا افغانی',
      keywords: [
        'ماه',
        'نام ماه',
        'شمسی',
        'افغانستان',
        'حمل',
        'ثور',
        'جوزا',
        'month',
        'afghan'
      ],
      page: SettingsSearchPage.font,
      route: RouteNames.fontSettings,
      rowKey: 'monthDisplay',
      prefs: ['month_display'],
    ),
    SettingsSearchEntry(
      id: 'font.arabic',
      title: 'نمایش متن عربی',
      keywords: ['عربی', 'متن', 'اذکار'],
      page: SettingsSearchPage.font,
      route: RouteNames.fontSettings,
      rowKey: 'toggles',
      prefs: ['showArabicText'],
    ),
    SettingsSearchEntry(
      id: 'font.daleel',
      title: 'نمایش دلیل',
      keywords: ['دلیل', 'منبع', 'روایت'],
      page: SettingsSearchPage.font,
      route: RouteNames.fontSettings,
      rowKey: 'toggles',
      prefs: ['showDaleel'],
    ),
    SettingsSearchEntry(
      id: 'font.arabic_big',
      title: 'فونت بزرگ‌تر عربی',
      keywords: ['عربی', 'بزرگ', 'فونت', 'اذکار'],
      page: SettingsSearchPage.font,
      route: RouteNames.fontSettings,
      rowKey: 'toggles',
      prefs: ['largeArabicFont'],
    ),
    // ── About page ──
    SettingsSearchEntry(
      id: 'about.share',
      title: 'اشتراک‌گذاری برنامه',
      keywords: ['اشتراک', 'معرفی', 'share'],
      page: SettingsSearchPage.about,
      route: RouteNames.about,
      rowKey: 'support',
    ),
    SettingsSearchEntry(
      id: 'about.feedback',
      title: 'پیشنهاد و گزارش خطا',
      keywords: ['پیشنهاد', 'خطا', 'گزارش', 'تلگرام', 'feedback'],
      page: SettingsSearchPage.about,
      route: RouteNames.about,
      rowKey: 'support',
    ),
    SettingsSearchEntry(
      id: 'about.privacy',
      title: 'حریم خصوصی و شرایط استفاده',
      keywords: ['حریم', 'خصوصی', 'شرایط', 'privacy'],
      page: SettingsSearchPage.about,
      route: RouteNames.about,
      rowKey: 'support',
    ),
    SettingsSearchEntry(
      id: 'about.update',
      title: 'بررسی بروزرسانی',
      keywords: ['بروزرسانی', 'نسخه', 'جدید', 'update'],
      page: SettingsSearchPage.about,
      route: RouteNames.about,
      rowKey: 'support',
    ),
    SettingsSearchEntry(
      id: 'about.features',
      title: 'امکانات برنامه',
      keywords: ['امکانات', 'ویژگی', 'قرآن', 'قبله'],
      page: SettingsSearchPage.about,
      route: RouteNames.about,
      rowKey: 'features',
    ),
  ];
}
