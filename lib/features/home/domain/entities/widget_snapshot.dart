import 'package:tawheeed/features/home/domain/entities/calendar_event.dart';

/// Single source of truth for all widget data.
///
/// Used by both the Flutter sync layer and the native Kotlin widget renderers.
/// Serialized via [toMethodChannel] for the Flutter→Kotlin bridge.
class WidgetSnapshot {
  final String nextPrayerName;
  final int nextPrayerMinutes;
  final String nextPrayerTime;
  final int nextPrayerIqamahOffset;

  /// Iqamah offset (minutes after adhan) per prayer, indexed by [prayerOrder].
  final List<int> iqamahOffsets;
  final String shamsiDate;
  final String gregorianDate;
  final String hijriDate;
  final String cityName;
  final Map<String, String> prayers;
  final String sunrise;
  final String sunset;
  final String azanSound;
  final String tasbihDhikr;
  final int tasbihCount;
  final int tasbihTarget;
  final bool tasbihActive;
  final int tasbihZikrIndex;
  final List<String> tasbihZikrList;

  /// Per-zikr targets, aligned with [tasbihZikrList] (each zikr can have its
  /// own count target in the app; the widget must show the same «از X»).
  final List<int> tasbihZikrTargets;

  /// Per-zikr counts, aligned with [tasbihZikrList] — the same counters the
  /// widget keeps natively, so switching zikrs on the widget shows the app's
  /// latest counts for every zikr (not just the current one).
  final List<int> tasbihZikrCounts;

  /// Whether the tasbih counters auto-reset daily (the app's
  /// «ریست خودکار روزانه» setting). Pushed to the widget so its native
  /// midnight reset only fires when the user actually enabled it.
  final bool tasbihAutoReset;

  /// The app's azkar haptic toggle («لرزش»). The widget's tap feedback
  /// vibrates only while this is on.
  final bool azkarHaptic;

  /// «بعد از رسیدن به هدف» — when true, the tap that completes the active
  /// zikr's target hands the next tap to the following zikr. Default false =
  /// «ادامه شمارش»: the counter keeps climbing past the target.
  final bool tasbihAutoAdvance;

  /// Prayer widget: paint the elapsed-adhan progress bar («نمایش نوار پیشرفت»).
  final bool widgetShowProgress;

  /// Prayer widget: paint the Gregorian date chip («نمایش تاریخ میلادی»).
  /// The native layout additionally hides it below 300 dp of width.
  final bool widgetShowGregorian;

  /// The prayer clock's digit locale: false = Latin (default), true = the
  /// fa-variant TextClock layout (arabic-indic digits).
  final bool widgetFaDigits;

  /// «چیدمان ویجت اوقات نماز» — `horizontal` (the shipped card: five boxes in
  /// a row) or `vertical` (the second option: five rows, one prayer per line).
  ///
  /// Pushed as a string so a newer build can add a third layout without
  /// breaking an older native side, which coerces anything it does not know
  /// back to [prayerLayoutHorizontal].
  final String prayerLayout;

  /// The shipped five-box card — the default, and the value a missing pref
  /// resolves to, so an install that has never opened the option keeps the
  /// widget it already had.
  static const String prayerLayoutHorizontal = 'horizontal';

  /// The second option: the five prayers as five rows, one per line.
  static const String prayerLayoutVertical = 'vertical';
  final List<CalendarEvent> calendarEvents;
  final int? syncTimestamp;

  /// Whether to display time in 12-hour format (AM/PM)
  final bool use12Hour;

  // --- Native self-refresh (prayer-time recompute) fields ---
  /// Latitude used for prayer-time calculation, so the home-screen widget can
  /// recompute today's times itself (midnight / stale sync) without the app.
  final double? calcLatitude;

  /// Longitude used for prayer-time calculation.
  final double? calcLongitude;

  /// Calculation method id (matches `CalculationMethodOption.name`).
  final String calcMethod;

  /// Fajr angle of the effective method (degrees).
  final double calcFajrAngle;

  /// Isha angle of the effective method (degrees).
  final double calcIshaAngle;

  /// Maghrib angle preset (Tehran = 4.5°); 0 = none (sunset-based).
  final double calcMaghribAngle;

  /// Isha interval in minutes (Umm al-Qura / Qatar); 0 = angle-based.
  final int calcIshaInterval;

  /// Asr madhab: 0 = Shafi, 1 = Hanafi.
  final int calcMadhab;

  /// High-latitude rule: 0 = middle of night, 1 = seventh of night,
  /// 2 = twilight angle.
  final int calcHighLatitude;

  /// Method preset minute adjustments `[fajr, sunrise, dhuhr, asr, maghrib, isha]`.
  final List<int> calcMethodAdjustments;

  /// User minute adjustments (settings offsets), same order.
  final List<int> calcUserAdjustments;

  /// App timezone (IANA name) the times were computed for — the native
  /// recompute must use the same zone, not a hardcoded one.
  final String calcTimezone;

  /// Elevation (horizon-dip) correction deltas for `[sunrise, maghrib]` in
  /// minutes, already resolved by the app. Kept as a pre-baked pair so the
  /// native recompute never needs the elevation solver.
  final List<int> calcElevationAdjustments;

  /// Hijri date offset used by the app's HijriUtils.
  final int calcHijriOffset;

  /// Exact UTC offset (minutes) the app's engine used for these times.
  /// The native widget renders with this instead of its own (possibly stale)
  /// tz database entry — keeps the widget identical to the in-app display on
  /// devices whose Android tzdata still applies Iran's removed DST.
  /// [absentOffset] = not provided → widget falls back to `calcTimezone`.
  static const int absentOffset = -100000;
  final int calcFixedOffsetMinutes;

  // --- Khatm (ختم قرآن) fields ---
  /// Whether an in-progress khatm exists (shown on the home-screen widget).
  final bool khatmActive;

  /// Pages read today by the active khatm.
  final int khatmPagesToday;

  /// Today's reading target (pages) for the active khatm.
  final int khatmDailyTarget;

  /// Juz number (1-30) at the current reading position (first unread page).
  final int khatmCurrentJuz;

  /// Arabic surah name (e.g. «البقرة») at the current reading position.
  final String khatmCurrentSurah;

  /// Total pages of the active khatm (604 for a full Quran).
  final int khatmTotalPages;

  /// Pages read so far across the whole khatm (overall progress).
  final int khatmReadPages;

  // --- Prayer Dashboard Engine fields ---
  /// Current prayer period color as hex (e.g. "#5C6BC0" for Fajr)
  final String dynamicPrimaryColor;

  /// Accent color as hex
  final String dynamicAccentColor;

  /// Background gradient start color as hex
  final String dynamicBgStart;

  /// Background gradient end color as hex
  final String dynamicBgEnd;

  /// Timeline progress 0..1 as integer (0-10000)
  final int timelineProgress;

  /// Current prayer name (Arabic)
  final String currentPrayerName;

  /// Ordered list of prayer names with their status: "completed|current|upcoming"
  final List<String> timelineStatuses;

  /// Today's per-prayer completion keyed by [prayerOrder] names:
  /// "done" (done or qada), "missed" (window closed, unlogged) or "pending".
  /// Null when the tracker has not loaded — native keeps its previous state
  /// rather than painting one it cannot vouch for.
  final Map<String, String>? prayerStatuses;

  // --- Widget paint contract (see android/.../widget/WidgetPrefs.kt) ---
  /// Raw ARGB the card must paint with; `0` = «not pushed», in which case the
  /// native palette resolver stays authoritative. Pushed only for an explicit
  /// palette choice (an «خودکار» palette pushes `0`, because the *phase*
  /// decision lives in Kotlin's boundary alarms and duplicating it here would
  /// let the two drift).
  final int accentArgb;
  final int textArgb;
  final int bgArgb;
  final int bgEndArgb;

  /// JSON `{date, today:{fajr,dhuhr,asr,maghrib,isha,sunrise},
  /// tomorrow:{…}}` written to `widget_times_json`.
  ///
  /// This is the widget's *only* time input: it derives «current prayer,
  /// next prayer, remaining time» from these clocks and never runs the
  /// astronomical solver inside a composition. Tomorrow is carried so the
  /// «after Isha» countdown stays truthful across midnight.
  final String? prayerTimesJson;

  static const List<String> prayerOrder = ['فجر', 'ظهر', 'عصر', 'مغرب', 'عشاء'];

  const WidgetSnapshot({
    required this.nextPrayerName,
    required this.nextPrayerMinutes,
    required this.nextPrayerTime,
    this.nextPrayerIqamahOffset = 10,
    this.iqamahOffsets = const [10, 10, 10, 10, 10],
    required this.shamsiDate,
    required this.gregorianDate,
    required this.hijriDate,
    required this.cityName,
    required this.prayers,
    required this.sunrise,
    required this.sunset,
    required this.azanSound,
    required this.tasbihDhikr,
    required this.tasbihCount,
    required this.tasbihTarget,
    required this.tasbihActive,
    required this.tasbihZikrIndex,
    required this.tasbihZikrList,
    this.tasbihZikrTargets = const [],
    this.tasbihZikrCounts = const [],
    this.tasbihAutoReset = true,
    this.azkarHaptic = true,
    this.tasbihAutoAdvance = false,
    this.widgetShowProgress = true,
    this.widgetShowGregorian = true,
    this.widgetFaDigits = false,
    this.prayerLayout = WidgetSnapshot.prayerLayoutHorizontal,
    this.use12Hour = true,
    this.calcLatitude,
    this.calcLongitude,
    this.calcMethod = 'muslimWorldLeague',
    this.calcFajrAngle = 18.0,
    this.calcIshaAngle = 17.0,
    this.calcMaghribAngle = 0,
    this.calcIshaInterval = 0,
    this.calcMadhab = 0,
    this.calcHighLatitude = 0,
    this.calcMethodAdjustments = const [0, 0, 0, 0, 0, 0],
    this.calcUserAdjustments = const [0, 0, 0, 0, 0, 0],
    this.calcTimezone = 'Asia/Tehran',
    this.calcElevationAdjustments = const [0, 0],
    this.calcHijriOffset = 2,
    this.calcFixedOffsetMinutes = absentOffset,
    this.khatmActive = false,
    this.khatmPagesToday = 0,
    this.khatmDailyTarget = 0,
    this.khatmCurrentJuz = 0,
    this.khatmCurrentSurah = '',
    this.khatmTotalPages = 604,
    this.khatmReadPages = 0,
    this.calendarEvents = const [],
    this.syncTimestamp,
    this.dynamicPrimaryColor = '#C9A94E',
    this.dynamicAccentColor = '#D4B96A',
    this.dynamicBgStart = '#4A3426',
    this.dynamicBgEnd = '#3B281B',
    this.timelineProgress = 0,
    this.currentPrayerName = '',
    this.timelineStatuses = const [],
    this.prayerStatuses,
    this.accentArgb = 0,
    this.textArgb = 0,
    this.bgArgb = 0,
    this.bgEndArgb = 0,
    this.prayerTimesJson,
  });

  WidgetSnapshot copyWith({
    String? nextPrayerName,
    int? nextPrayerMinutes,
    String? nextPrayerTime,
    int? nextPrayerIqamahOffset,
    List<int>? iqamahOffsets,
    String? shamsiDate,
    String? gregorianDate,
    String? hijriDate,
    String? cityName,
    Map<String, String>? prayers,
    String? sunrise,
    String? sunset,
    String? azanSound,
    String? tasbihDhikr,
    int? tasbihCount,
    int? tasbihTarget,
    bool? tasbihActive,
    int? tasbihZikrIndex,
    List<String>? tasbihZikrList,
    List<int>? tasbihZikrTargets,
    List<int>? tasbihZikrCounts,
    bool? tasbihAutoReset,
    bool? azkarHaptic,
    bool? tasbihAutoAdvance,
    bool? widgetShowProgress,
    bool? widgetShowGregorian,
    bool? widgetFaDigits,
    String? prayerLayout,
    List<CalendarEvent>? calendarEvents,
    int? syncTimestamp,
    bool? use12Hour,
    double? calcLatitude,
    double? calcLongitude,
    String? calcMethod,
    double? calcFajrAngle,
    double? calcIshaAngle,
    double? calcMaghribAngle,
    int? calcIshaInterval,
    int? calcMadhab,
    int? calcHighLatitude,
    List<int>? calcMethodAdjustments,
    List<int>? calcUserAdjustments,
    String? calcTimezone,
    List<int>? calcElevationAdjustments,
    int? calcHijriOffset,
    int? calcFixedOffsetMinutes,
    bool? khatmActive,
    int? khatmPagesToday,
    int? khatmDailyTarget,
    int? khatmCurrentJuz,
    String? khatmCurrentSurah,
    int? khatmTotalPages,
    int? khatmReadPages,
    String? dynamicPrimaryColor,
    String? dynamicAccentColor,
    String? dynamicBgStart,
    String? dynamicBgEnd,
    int? timelineProgress,
    String? currentPrayerName,
    List<String>? timelineStatuses,
    Map<String, String>? prayerStatuses,
    int? accentArgb,
    int? textArgb,
    int? bgArgb,
    int? bgEndArgb,
    String? prayerTimesJson,
  }) {
    return WidgetSnapshot(
      nextPrayerName: nextPrayerName ?? this.nextPrayerName,
      nextPrayerMinutes: nextPrayerMinutes ?? this.nextPrayerMinutes,
      nextPrayerTime: nextPrayerTime ?? this.nextPrayerTime,
      nextPrayerIqamahOffset:
          nextPrayerIqamahOffset ?? this.nextPrayerIqamahOffset,
      iqamahOffsets: iqamahOffsets ?? this.iqamahOffsets,
      shamsiDate: shamsiDate ?? this.shamsiDate,
      gregorianDate: gregorianDate ?? this.gregorianDate,
      hijriDate: hijriDate ?? this.hijriDate,
      cityName: cityName ?? this.cityName,
      prayers: prayers ?? this.prayers,
      sunrise: sunrise ?? this.sunrise,
      sunset: sunset ?? this.sunset,
      azanSound: azanSound ?? this.azanSound,
      tasbihDhikr: tasbihDhikr ?? this.tasbihDhikr,
      tasbihCount: tasbihCount ?? this.tasbihCount,
      tasbihTarget: tasbihTarget ?? this.tasbihTarget,
      tasbihActive: tasbihActive ?? this.tasbihActive,
      tasbihZikrIndex: tasbihZikrIndex ?? this.tasbihZikrIndex,
      tasbihZikrList: tasbihZikrList ?? this.tasbihZikrList,
      tasbihZikrTargets: tasbihZikrTargets ?? this.tasbihZikrTargets,
      tasbihZikrCounts: tasbihZikrCounts ?? this.tasbihZikrCounts,
      tasbihAutoReset: tasbihAutoReset ?? this.tasbihAutoReset,
      azkarHaptic: azkarHaptic ?? this.azkarHaptic,
      tasbihAutoAdvance: tasbihAutoAdvance ?? this.tasbihAutoAdvance,
      widgetShowProgress: widgetShowProgress ?? this.widgetShowProgress,
      widgetShowGregorian: widgetShowGregorian ?? this.widgetShowGregorian,
      widgetFaDigits: widgetFaDigits ?? this.widgetFaDigits,
      prayerLayout: prayerLayout ?? this.prayerLayout,
      calendarEvents: calendarEvents ?? this.calendarEvents,
      syncTimestamp: syncTimestamp ?? this.syncTimestamp,
      use12Hour: use12Hour ?? this.use12Hour,
      calcLatitude: calcLatitude ?? this.calcLatitude,
      calcLongitude: calcLongitude ?? this.calcLongitude,
      calcMethod: calcMethod ?? this.calcMethod,
      calcFajrAngle: calcFajrAngle ?? this.calcFajrAngle,
      calcIshaAngle: calcIshaAngle ?? this.calcIshaAngle,
      calcMaghribAngle: calcMaghribAngle ?? this.calcMaghribAngle,
      calcIshaInterval: calcIshaInterval ?? this.calcIshaInterval,
      calcMadhab: calcMadhab ?? this.calcMadhab,
      calcHighLatitude: calcHighLatitude ?? this.calcHighLatitude,
      calcMethodAdjustments:
          calcMethodAdjustments ?? this.calcMethodAdjustments,
      calcUserAdjustments: calcUserAdjustments ?? this.calcUserAdjustments,
      calcTimezone: calcTimezone ?? this.calcTimezone,
      calcElevationAdjustments:
          calcElevationAdjustments ?? this.calcElevationAdjustments,
      calcHijriOffset: calcHijriOffset ?? this.calcHijriOffset,
      calcFixedOffsetMinutes:
          calcFixedOffsetMinutes ?? this.calcFixedOffsetMinutes,
      khatmActive: khatmActive ?? this.khatmActive,
      khatmPagesToday: khatmPagesToday ?? this.khatmPagesToday,
      khatmDailyTarget: khatmDailyTarget ?? this.khatmDailyTarget,
      khatmCurrentJuz: khatmCurrentJuz ?? this.khatmCurrentJuz,
      khatmCurrentSurah: khatmCurrentSurah ?? this.khatmCurrentSurah,
      khatmTotalPages: khatmTotalPages ?? this.khatmTotalPages,
      khatmReadPages: khatmReadPages ?? this.khatmReadPages,
      dynamicPrimaryColor: dynamicPrimaryColor ?? this.dynamicPrimaryColor,
      dynamicAccentColor: dynamicAccentColor ?? this.dynamicAccentColor,
      dynamicBgStart: dynamicBgStart ?? this.dynamicBgStart,
      dynamicBgEnd: dynamicBgEnd ?? this.dynamicBgEnd,
      timelineProgress: timelineProgress ?? this.timelineProgress,
      currentPrayerName: currentPrayerName ?? this.currentPrayerName,
      timelineStatuses: timelineStatuses ?? this.timelineStatuses,
      prayerStatuses: prayerStatuses ?? this.prayerStatuses,
      accentArgb: accentArgb ?? this.accentArgb,
      textArgb: textArgb ?? this.textArgb,
      bgArgb: bgArgb ?? this.bgArgb,
      bgEndArgb: bgEndArgb ?? this.bgEndArgb,
      prayerTimesJson: prayerTimesJson ?? this.prayerTimesJson,
    );
  }

  /// Serializes to a Map suitable for MethodChannel transport to native Kotlin.
  Map<String, dynamic> toMethodChannel() {
    final prayerList =
        prayerOrder.map((name) => '$name ${prayers[name] ?? '--:--'}').toList();

    final eventsJson = calendarEvents
        .map((e) => <String, dynamic>{
              'title': e.title,
              'date': e.date,
            })
        .toList();

    return <String, dynamic>{
      'nextPrayerName': nextPrayerName,
      'nextPrayerMinutes': nextPrayerMinutes,
      'nextPrayerTime': nextPrayerTime,
      'nextPrayerIqamahOffset': nextPrayerIqamahOffset,
      'iqamahOffsets': iqamahOffsets,
      'shamsiDate': shamsiDate,
      'gregorianDate': gregorianDate,
      'hijriDate': hijriDate,
      'cityName': cityName,
      'prayer1': prayerList.isNotEmpty ? prayerList[0] : '',
      'prayer2': prayerList.length > 1 ? prayerList[1] : '',
      'prayer3': prayerList.length > 2 ? prayerList[2] : '',
      'prayer4': prayerList.length > 3 ? prayerList[3] : '',
      'prayer5': prayerList.length > 4 ? prayerList[4] : '',
      'sunrise': sunrise,
      'sunset': sunset,
      'azanSound': azanSound,
      'tasbihDhikr': tasbihDhikr,
      'tasbihCount': tasbihCount,
      'tasbihTarget': tasbihTarget,
      'tasbihActive': tasbihActive,
      'tasbihZikrIndex': tasbihZikrIndex,
      'tasbihZikrList': tasbihZikrList,
      'tasbihZikrTargets': tasbihZikrTargets,
      'tasbihZikrCounts': tasbihZikrCounts,
      'tasbihAutoReset': tasbihAutoReset,
      'azkarHaptic': azkarHaptic,
      'tasbihAutoAdvance': tasbihAutoAdvance,
      'widgetShowProgress': widgetShowProgress,
      'widgetShowGregorian': widgetShowGregorian,
      'widgetFaDigits': widgetFaDigits,
      'prayerLayout': prayerLayout,
      'calendarEvents': eventsJson,
      'syncTimestamp': syncTimestamp ?? DateTime.now().millisecondsSinceEpoch,
      'calcLatitude': calcLatitude,
      'calcLongitude': calcLongitude,
      'calcMethod': calcMethod,
      'calcFajrAngle': calcFajrAngle,
      'calcIshaAngle': calcIshaAngle,
      'calcMaghribAngle': calcMaghribAngle,
      'calcIshaInterval': calcIshaInterval,
      'calcMadhab': calcMadhab,
      'calcHighLatitude': calcHighLatitude,
      'calcMethodAdjustments': calcMethodAdjustments,
      'calcUserAdjustments': calcUserAdjustments,
      'calcTimezone': calcTimezone,
      'calcElevationAdjustments': calcElevationAdjustments,
      'calcHijriOffset': calcHijriOffset,
      'calcFixedOffsetMinutes': calcFixedOffsetMinutes,
      'dynamicPrimaryColor': dynamicPrimaryColor,
      'dynamicAccentColor': dynamicAccentColor,
      'dynamicBgStart': dynamicBgStart,
      'dynamicBgEnd': dynamicBgEnd,
      'timelineProgress': timelineProgress,
      'currentPrayerName': currentPrayerName,
      'timelineStatuses': timelineStatuses,
      'use12Hour': use12Hour,
      'khatmActive': khatmActive,
      'khatmPagesToday': khatmPagesToday,
      'khatmDailyTarget': khatmDailyTarget,
      'khatmCurrentJuz': khatmCurrentJuz,
      'khatmCurrentSurah': khatmCurrentSurah,
      'khatmTotalPages': khatmTotalPages,
      'khatmReadPages': khatmReadPages,
      // Omitted (not null) when the tracker is unloaded: persistSnapshot only
      // writes keys it receives, so the widget keeps its previous statuses.
      if (prayerStatuses != null) 'prayerStatuses': prayerStatuses,
      // Always sent (0 = «no override») so switching to an «خودکار» palette
      // clears a previously pushed colour instead of leaving it stuck.
      'accentArgb': accentArgb,
      'textArgb': textArgb,
      'bgArgb': bgArgb,
      'bgEndArgb': bgEndArgb,
      if (prayerTimesJson != null) 'prayerTimesJson': prayerTimesJson,
    };
  }

  factory WidgetSnapshot.initial() {
    return const WidgetSnapshot(
      nextPrayerName: '',
      nextPrayerMinutes: 0,
      nextPrayerTime: '',
      shamsiDate: '',
      gregorianDate: '',
      hijriDate: '',
      cityName: '',
      prayers: {},
      sunrise: '',
      sunset: '',
      azanSound: '',
      tasbihDhikr: '',
      tasbihCount: 0,
      tasbihTarget: 33,
      tasbihActive: false,
      tasbihZikrIndex: 0,
      tasbihZikrList: <String>[],
    );
  }
}
