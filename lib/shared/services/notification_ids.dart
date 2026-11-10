/// Centralized notification ID constants to prevent collisions
class NotificationIds {
  NotificationIds._();

  // Today's prayer notifications
  static const int fajr = 100;
  static const int dhuhr = 101;
  static const int asr = 102;
  static const int maghrib = 103;
  static const int isha = 104;
  static const int morningAzkar = 105;
  static const int eveningAzkar = 106;
  static const int duha = 107;

  // Tomorrow's prayer notifications
  static const int tomorrowFajr = 110;
  static const int tomorrowDhuhr = 111;
  static const int tomorrowAsr = 112;
  static const int tomorrowMaghrib = 113;
  static const int tomorrowIsha = 114;
  static const int tomorrowDuha = 117;

  // Post-prayer azkar
  static const int postFajr = 120;
  static const int postDhuhr = 121;
  static const int postAsr = 122;
  static const int postMaghrib = 123;
  static const int postIsha = 124;

  // Manual post-prayer azkar — fired when the user marks a prayer done in the
  // tracker. Kept in their own range so they never collide with (or overwrite)
  // the daily auto-scheduled azkar (120-129).
  static const int manualPostFajr = 300;
  static const int manualPostDhuhr = 301;
  static const int manualPostAsr = 302;
  static const int manualPostMaghrib = 303;
  static const int manualPostIsha = 304;

  // Post-prayer azkar (tomorrow)
  static const int tomorrowPostFajr = 125;
  static const int tomorrowPostDhuhr = 126;
  static const int tomorrowPostAsr = 127;
  static const int tomorrowPostMaghrib = 128;
  static const int tomorrowPostIsha = 129;

  // Morning/evening azkar (tomorrow) — separate IDs to avoid overwriting today's
  static const int tomorrowMorningAzkar = 130;
  static const int tomorrowEveningAzkar = 131;

  // Pre-adhan reminders — silent «N minutes to prayer» notices scheduled
  // minutesBefore the adhan when prayerNotifMinutes > 0. Kept in their own
  // ranges (500s today, 510s tomorrow, 520s day-after) so they never collide
  // with the adhan notifications (100s/110s/210s) fired at the exact time.
  static const int preAdhanFajr = 500;
  static const int preAdhanDhuhr = 501;
  static const int preAdhanAsr = 502;
  static const int preAdhanMaghrib = 503;
  static const int preAdhanIsha = 504;

  static const int tomorrowPreAdhanFajr = 510;
  static const int tomorrowPreAdhanDhuhr = 511;
  static const int tomorrowPreAdhanAsr = 512;
  static const int tomorrowPreAdhanMaghrib = 513;
  static const int tomorrowPreAdhanIsha = 514;

  static const int dayAfterTomorrowPreAdhanFajr = 520;
  static const int dayAfterTomorrowPreAdhanDhuhr = 521;
  static const int dayAfterTomorrowPreAdhanAsr = 522;
  static const int dayAfterTomorrowPreAdhanMaghrib = 523;
  static const int dayAfterTomorrowPreAdhanIsha = 524;

  // Day-after-tomorrow window — extends coverage so notifications keep firing
  // for up to two days even if the app is never opened.
  static const int dayAfterTomorrowFajr = 210;
  static const int dayAfterTomorrowDhuhr = 211;
  static const int dayAfterTomorrowAsr = 212;
  static const int dayAfterTomorrowMaghrib = 213;
  static const int dayAfterTomorrowIsha = 214;
  static const int dayAfterTomorrowDuha = 215;
  static const int dayAfterTomorrowPostFajr = 216;
  static const int dayAfterTomorrowPostDhuhr = 217;
  static const int dayAfterTomorrowPostAsr = 218;
  static const int dayAfterTomorrowPostMaghrib = 219;
  static const int dayAfterTomorrowPostIsha = 220;
  static const int dayAfterTomorrowMorningAzkar = 221;
  static const int dayAfterTomorrowEveningAzkar = 222;

  // Quran reminder — kept out of the manual post-prayer range (300-304)
  // so enabling it never cancels the manual post-Fajr azkar (and vice-versa).
  static const int quranReminder = 405;

  // Daily khatm reminder (ختم قرآن)
  static const int khatmReminder = 404;

  // Daily content
  static const int dailyVerse = 400;
  static const int dailyHadith = 401;
  static const int dailyDua = 402;

  // Daily content PER-DAY window — one one-shot notification per day, so the
  // آیه/حدیث/دعا content rotates daily even when background re-scheduling is
  // deferred (a single repeating notification would re-show the same captured
  // body every day). Id = base + day-of-year of the fire date (1..366), so
  // bases are 7000/7400/7900: verse 7001-7366, hadith 7401-7766,
  // dua 7901-8266 — never overlapping each other, the pomodoro id (7843),
  // or the task range (10000+).
  static const int dailyVerseDayBase = 7000;
  static const int dailyHadithDayBase = 7400;
  static const int dailyDuaDayBase = 7900;

  // Weekly Friday reminder (اذکار و آداب روز جمعه، صلوات و دعا)
  static const int fridayReminder = 403;

  // Weekly Surah Kahf reminder (سوره کهف) — its own 06:00 alert, deliberately
  // separate from the 07:00 Friday adab reminder. 406 is free inside the
  // documented 400-431 block; the pre-audit snapshot used 404 here, which
  // collides with khatmReminder and made the two cancel each other.
  static const int fridayKahf = 406;

  // Fasting reminders — Monday and Thursday share ONE user-facing toggle but
  // need one id each: `DateTimeComponents.dayOfWeekAndTime` matches exactly
  // one weekday, so a single repeating notification can never fire twice a
  // week. Both sit in the free 400-431 block.
  static const int fastingMonday = 407;
  static const int fastingThursday = 408;

  // ایام البیض (Hijri 13-15) — per-day one-shots like the daily-content
  // window, because the Hijri days drift through the Gregorian calendar and a
  // weekly match cannot follow them. Id = base + 0-based day-of-year of the
  // fire date, so 8300-8665 (the sweep clears base + 366): free above the dua
  // window (7901-8266).
  static const int ayamAlBidhDayBase = 8300;

  // Islamic events (reminders scheduled a few days before each occasion)
  static const int islamicEventBase = 410;
  static const int islamicEventMax = 430;

  // Snoozed reminder (re-shown after tapping the snooze action)
  static const int snooze = 431;

  // One consolidated digest per app run listing the fixed-time reminders
  // (آیه/حدیث/دعای روز، قرآن، جمعه، کهف، ختم، روزه) whose moment passed while
  // the app was closed. Shown IMMEDIATELY, never scheduled, so it can neither
  // fire late nor repeat — a scheduling API would roll a past time to tomorrow.
  static const int missedRemindersDigest = 432;

  // Period (دوره ماهانه) — upcoming-period reminder + post-period ghusl
  // reminder. Scheduled/rescheduled by the period provider whenever a period
  // is started/ended or the notification setting flips; 600-619 is reserved
  // so the two ids can never collide with anything else.
  static const int periodUpcoming = 600;
  static const int periodGhusl = 601;
  static const int periodStart = 602;
  static const int periodFertile = 603;

  // Diagnostic test adhan notification
  static const int testAdhan = 199;

  // ── Reserved ID map (single source of truth) ──────────────────────────
  // 100-199 : adhan + daily azkar + test adhan
  // 210-229 : day-after-tomorrow window
  // 300-309 : manual post-prayer azkar
  // 400-432 : daily content, khatm, friday, fasting, islamic events, snooze,
  //           missed-reminder digest
  // 500-524 : pre-adhan reminders (today / tomorrow / day-after)
  // 600-619 : period (دوره) reminders — upcoming + ghusl
  // 1000-1999 : custom user reminders (ReminderService)
  // 7000-7366/7401-7766/7901-8266 : per-day daily-content window (base + day-of-year)
  // 7843    : pomodoro timer (single fixed id, between hadith/dua windows)
  // 8301-8666 : ایام البیض per-day window (base + day-of-year)
  // 10000-10999 : task due-date reminders (TaskReminderScheduler)
  // 12000-12949 : goal daily reminders (GoalReminderScheduler)
  // 13000-13999 : personal tools (خودرو / خانه) care reminders — one id per
  //              reminder DAY (13000 + day-of-year), payload `care_*`
  // 14000-14999 : «دفتر مالی» (چک و قسط + دَین) reminders — one id per
  //              reminder DAY (14000 + day-of-year), payload `finance_*`
  // 15000-15399 : «صله رحم» reminders — one id per reminder DAY
  //              (15000 + day-of-year), payload `family_relative_*`
  // 16500-16999 : «قلک» weekly deposit reminders — one id per goal
  //              (16500 + stableSlot(goalId, 499)), payload `family_saving_*`
  // 11000-11949 : «اطلاعات من» expiry reminders (ExpiryReminderScheduler)
  //
  // ── PERSONAL TOOLS (the «ابزارها و پیشرفت» family) ────────────────────
  // One disjoint block per tool. They used to overlap — دفتر مالی sat on the
  // kids block, صله رحم on the teacher block, قضایار and قلک on the shop block —
  // so scheduling one tool's nudge replaced another's, and the overwritten one
  // only reappeared after its own next sync. `notification_range_map_test.dart`
  // now pins this table; keep any new tool outside every existing block.
  // 13000-13999 : خودرو/خانه (CareReminderScheduler: 13000+day-of-year,
  //               plus 13998 for the grouped/overdue reminder)
  // 14000-14999 : دفتر عادت کودک (SoftNotifier.kidsBase + slot, 14999 summary)
  // 15000-15999 : دفتر مربی قرآن (SoftNotifier.teacherBase + slot, 15999 summary)
  // 16000-16998 : حساب مغازه (ShopReminders: 16000+slot)
  // 17000-17399 : دفتر مالی (FinanceReminderScheduler: 17000+day-of-year)
  // 17400-17799 : صله رحم (RelativeReminderScheduler: 17400+day-of-year)
  // 17900-17999 : قلک (SavingsReminderScheduler: 17900+slot)
  //
  // Custom reminders live in 1000-1999 so they can never overwrite the
  // pre-adhan notices (500-524) or the adhan notifications (100-131).
  static const int customReminderBase = 1000;
  static const int customReminderMax = 1999;

  /// Maps [key] to a stable slot in `[0, space)` — a notification id derived
  /// from a row id, for the schedulers that own a range.
  ///
  /// FNV-1a, not [String.hashCode]: Dart documents `hashCode` as unspecified
  /// and it is not guaranteed identical across isolates, so a scheduler
  /// keyed off it silently stopped matching its own pending notifications
  /// after some restarts, and a goal's reminder could never be cancelled by
  /// id. `cancelByPayload` still cancels regardless, which is why this
  /// failure was invisible.
  ///
  /// Collisions are still possible once `space` is smaller than the number of
  /// live rows — there is no way to avoid that with a fixed id range — so the
  /// payload, not the id, stays the authoritative key. Callers pass a range
  /// documented above and keep the payload prefix in sync with it.
  static int stableSlot(String key, int space) {
    assert(space > 0, 'space must be positive');
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash % space;
  }
}
