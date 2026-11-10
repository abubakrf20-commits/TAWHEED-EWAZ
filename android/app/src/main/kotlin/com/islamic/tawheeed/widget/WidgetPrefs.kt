package com.islamic.tawheeed.widget

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * The **contract** for every key the home-screen widgets read or write.
 *
 * One pref file, one owner per key. Reading is always free; writing is not.
 * When a key has two possible writers the rule is written next to it, and the
 * widget never rewrites a key it does not own — a snapshot push must be able to
 * land at any moment without clobbering a bead the user just counted.
 *
 * | key | type | writer | reader |
 * |---|---|---|---|
 * | `prayer_1..5` | `String` «فجر 04:31» | Flutter (+ native recompute) | both |
 * | `iqamah_offsets` | JSON `int[5]` | Flutter | Kotlin |
 * | `sunrise` / `sunset` | `String` `HH:mm` | Flutter (+ recompute) | Kotlin |
 * | [KEY_TIMES_JSON] | JSON `{date,today:{…},tomorrow:{…}}` | Kotlin; Flutter may override | Kotlin |
 * | [KEY_TIMES_DATE] | `YYYY-MM-DD` | Kotlin | Kotlin |
 * | `shamsi_date` / `hijri_date` / `gregorian_date` | `String` | Flutter (+ recompute) | Kotlin |
 * | `city_name` | `String` | Flutter | Kotlin |
 * | `widget_use_12_hour` | `Boolean` | Flutter | Kotlin |
 * | [KEY_SHOW_PROGRESS] / [KEY_SHOW_GREGORIAN] | `Boolean` | Flutter | Kotlin |
 * | [KEY_PRAYER_LAYOUT] | `String` `horizontal`\|`vertical` | Flutter | Kotlin |
 * | `prayer_statuses` | JSON `{name: done\|missed\|pending}` | **Flutter only** | both |
 * | [KEY_PRAYER_READ] | JSON `{date, idx:[…]}` | **Kotlin only** | Kotlin + Flutter drain |
 * | [KEY_PRAYER_CLEARED] | JSON `{date, idx:[…]}` | **Kotlin only** | Kotlin + Flutter drain |
 * | [KEY_ACCENT_ARGB] / [KEY_TEXT_ARGB] / [KEY_BG_ARGB] / [KEY_BG_END_ARGB] | `Int` ARGB | Flutter | Kotlin |
 * | `widget_palette_id_{prayer,tasbih}` | `String` | Flutter | Kotlin |
 * | `widget_opacity_step_{prayer,tasbih}` | `Int` 0..3 | Flutter | Kotlin |
 * | `tasbih_dhikr`, `tasbih_zikr_index`, `tasbih_count`, `tasbih_target` | — | both | both |
 * | `tasbih_per_zikr_counts` / `_targets` | JSON | Kotlin writes, Flutter merges | both |
 * | `tasbih_zikr_list` | JSON `string[]` | Flutter | Kotlin |
 * | `tasbih_auto_reset`, `tasbih_auto_advance`, `azkar_haptic` | `Boolean` | Flutter | Kotlin |
 * | `widget_tasbih_daily_total` / `_date` | `Int` / `String` | Kotlin | Kotlin |
 * | `widget_tasbih_pending` / `_seq` | JSON / `Int` | Kotlin | Kotlin + Flutter drain |
 * | `widget_tasbih_last_tap_at` | `Long` | both | both |
 * | [KEY_TAP_DELIVERY] | `String` `broadcast`\|`activity` | Kotlin (probe) | Kotlin |
 * | [KEY_LIVE_LEAVES] | `Boolean` | Kotlin (probe) / Flutter | Kotlin |
 *
 * **Two rules that must not be broken:**
 *  1. Flutter never rewrites `tasbih_per_zikr_counts` or `widget_tasbih_pending*`
 *     — it merges. Otherwise a snapshot push silently undoes widget taps.
 *  2. The widget never rewrites `prayer_statuses`. A tap records the user's
 *     intent in [KEY_PRAYER_READ] (ticked) or [KEY_PRAYER_CLEARED] (unticked);
 *     the app drains both and decides what the tracker row becomes.
 */
object WidgetPrefs {

    /** The single shared pref file. Kept as a constant so the Flutter side and
     *  every Kotlin caller cannot drift apart. */
    const val FILE = "tawheeed_widgets"

    // ── Prayer times (Kotlin-owned cache of today + tomorrow) ──
    const val KEY_TIMES_JSON = "widget_times_json"
    const val KEY_TIMES_DATE = "widget_times_date"

    // ── Theme colours as raw ARGB (Flutter-owned) ──
    const val KEY_ACCENT_ARGB = "widget_accent_argb"
    const val KEY_TEXT_ARGB = "widget_text_argb"
    const val KEY_BG_ARGB = "widget_bg_argb"
    const val KEY_BG_END_ARGB = "widget_bg_end_argb"

    // ── Prayer card display flags (Flutter-owned) ──
    /** «نمایش نوار پیشرفت» — the thin day-progress rule under the five
     *  prayer boxes. Default true: the card has always carried it since the
     *  Glance rewrite, and a missing key must not silently drop a band the
     *  budget already priced. */
    const val KEY_SHOW_PROGRESS = "widget_show_progress"

    /** «نمایش تاریخ میلادی» — the third line of the date strip. Default true;
     *  the width gate (≥ 300 dp) is applied on top of it in
     *  [PrayerWidgetBudget.metrics], so the pref alone can never clip. */
    const val KEY_SHOW_GREGORIAN = "widget_show_gregorian"

    // ── Prayer card layout (Flutter-owned) ──
    /**
     * «چیدمان ویجت اوقات نماز» — which of the two prayer cards is drawn.
     *
     * [LAYOUT_HORIZONTAL] is the shipped card: five boxes side by side under a
     * big clock. [LAYOUT_VERTICAL] is the second option: the same five prayers
     * as five ROWS, one per line, name at the right edge and time at the left.
     *
     * The default is horizontal, and it is a *missing-key* default as well, so
     * an install that has never touched the option keeps exactly the card it
     * had — [prayerLayout] can never answer anything but these two values, and
     * the horizontal path in [PrayerNativeViews] is not gated on this pref at
     * all (only the vertical branch is). That is what makes the new option
     * purely additive: with the key absent, `full()` and `capsules()` run the
     * code they ran before this option existed.
     */
    const val KEY_PRAYER_LAYOUT = "widget_prayer_layout"

    const val LAYOUT_HORIZONTAL = "horizontal"
    const val LAYOUT_VERTICAL = "vertical"

    /** The stored layout, coerced to a value this build can draw. */
    fun prayerLayout(prefs: SharedPreferences): String =
        if (prefs.getString(KEY_PRAYER_LAYOUT, LAYOUT_HORIZONTAL) == LAYOUT_VERTICAL) {
            LAYOUT_VERTICAL
        } else {
            LAYOUT_HORIZONTAL
        }

    /** True when the five prayers must be drawn as rows. */
    fun isVerticalLayout(prefs: SharedPreferences): Boolean =
        prayerLayout(prefs) == LAYOUT_VERTICAL

    // ── Widget-local prayer marks (Kotlin-owned) ──
    const val KEY_PRAYER_READ = "widget_prayer_read"

    /** Ticks the user took BACK on the card. See [readCleared]. */
    const val KEY_PRAYER_CLEARED = "widget_prayer_cleared"

    // ── Capability flags (Kotlin-owned) ──
    /** Which delivery a tap uses: `broadcast` (default, ~10× cheaper than an
     *  activity) or `activity` (the trampoline, kept as a fallback).
     *
     *  The `_v2` suffix is deliberate. The key is *shared state that outlives
     *  the APK*: an older build wrote `activity` into `widget_tap_delivery`
     *  on this very device, and a plain `install -r` keeps the prefs file, so
     *  the new code would have honoured a stale value and kept every tap on
     *  the expensive path forever. A new key starts from the new default. */
    const val KEY_TAP_DELIVERY = "widget_tap_delivery_v2"

    const val DELIVERY_BROADCAST = "broadcast"
    const val DELIVERY_ACTIVITY = "activity"

    /** Whether the card may host the live `TextClock` leaf.
     *
     *  `true` is the right default: the leaf ticks inside the launcher, so the
     *  clock is exact with no alarm, no update and no Doze grant. It is a flag
     *  rather than a constant because a host CAN refuse a nested RemoteViews,
     *  and `AppWidgetHostView` then shows its «cannot load widget» error view
     *  for the WHOLE card. With the flag off the card renders through
     *  `widget_prayer_clock_baked.xml` and the minute tick carries the value. */
    const val KEY_LIVE_LEAVES = "widget_live_leaves"

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    // ── Capability flags ──

    fun tapDelivery(prefs: SharedPreferences): String =
        prefs.getString(KEY_TAP_DELIVERY, DELIVERY_BROADCAST) ?: DELIVERY_BROADCAST

    fun useActivityTaps(prefs: SharedPreferences): Boolean =
        tapDelivery(prefs) == DELIVERY_ACTIVITY

    /** Whether the live clock leaf may be hosted. Read on every render, so a
     *  flip takes effect on the next update. */
    fun liveLeaves(prefs: SharedPreferences): Boolean =
        prefs.getBoolean(KEY_LIVE_LEAVES, true)

    // ── ARGB theme overrides ──

    /** The colour the app says to use, or 0 when it never pushed one. */
    fun argb(prefs: SharedPreferences, key: String): Int = prefs.getInt(key, 0)

    // ── Widget-local prayer marks ──

    /**
     * Which prayers the user tapped «خواندم» on, for [date] only.
     *
     * The app owns `prayer_statuses`; the widget must not rewrite it, or the
     * next snapshot push would undo the tap (and the app's own tracker would
     * lose the distinction between «recorded in the app» and «tapped on the
     * home screen»). Marks expire by date, so yesterday's taps can never leak
     * into today's card.
     */
    fun readMarks(prefs: SharedPreferences, date: String): Set<Int> =
        readIndexSet(prefs, KEY_PRAYER_READ, date)

    /**
     * Which prayers the user tapped to UNtick, for [date] only.
     *
     * The tick on the card is a union of three sources: the app's
     * `prayer_statuses`, [KEY_PRAYER_READ], and this. Without the third, a tick
     * the app had recorded could never be taken back from the home screen — the
     * tap would clear the mark while the status still said «done», and the box
     * would not change («تیک برداشت برای هر ۵ نماز»).
     *
     * A clear beats everything: it is the user's most recent word on this card.
     * The app drains it (`reconcilePrayerMarksFromWidget`) and resets the
     * tracker row to `pending`; [clearCleared] acks it only after that, so a
     * clear the app has never seen keeps winning.
     */
    fun readCleared(prefs: SharedPreferences, date: String): Set<Int> =
        readIndexSet(prefs, KEY_PRAYER_CLEARED, date)

    /** Toggles one prayer's mark and returns the new state (true = marked). */
    fun toggleMark(prefs: SharedPreferences, date: String, index: Int): Boolean {
        val marked = readMarks(prefs, date).contains(index) &&
            !readCleared(prefs, date).contains(index)
        return setDone(prefs, date, index, !marked)
    }

    /**
     * States one prayer's «خواندم» explicitly and returns it.
     *
     * The two sets are written in ONE editor commit and are always mutually
     * exclusive for an index — marking removes a clear, clearing removes a
     * mark — so the card can never read both and pick the wrong one.
     */
    fun setDone(prefs: SharedPreferences, date: String, index: Int, done: Boolean): Boolean {
        val marks = readMarks(prefs, date).toMutableSet()
        val cleared = readCleared(prefs, date).toMutableSet()
        if (done) {
            marks.add(index)
            cleared.remove(index)
        } else {
            marks.remove(index)
            cleared.add(index)
        }
        writeIndexSets(prefs, date, marks, cleared)
        return done
    }

    /**
     * `{date, indices}` for the app's drain — the date the marks belong to,
     * carried inside the payload rather than inferred from
     * [KEY_TIMES_DATE], so a mark can never be reported against a day whose
     * times happen to have been recomputed in the meantime.
     */
    fun readMarkPayload(prefs: SharedPreferences): Pair<String, List<Int>> =
        readIndexPayload(prefs, KEY_PRAYER_READ)

    /** The same payload for the clears, which the app drains into `pending`. */
    fun readClearedPayload(prefs: SharedPreferences): Pair<String, List<Int>> =
        readIndexPayload(prefs, KEY_PRAYER_CLEARED)

    /**
     * Acks the marks the app has applied: only [indices] for [date] are
     * removed, so a tap that landed between the app's read and this ack is
     * still reported on the next pass instead of being cleared unread.
     */
    fun clearMarks(prefs: SharedPreferences, date: String, indices: Collection<Int>) {
        if (indices.isEmpty()) return
        val current = readMarks(prefs, date).toMutableSet()
        if (!current.removeAll(indices.toSet())) return
        writeIndexSets(prefs, date, current, readCleared(prefs, date))
    }

    /** Acks the clears the app has applied — same contract as [clearMarks]. */
    fun clearCleared(prefs: SharedPreferences, date: String, indices: Collection<Int>) {
        if (indices.isEmpty()) return
        val current = readCleared(prefs, date).toMutableSet()
        if (!current.removeAll(indices.toSet())) return
        writeIndexSets(prefs, date, readMarks(prefs, date), current)
    }

    private fun readIndexSet(prefs: SharedPreferences, key: String, date: String): Set<Int> {
        val json = prefs.getString(key, null) ?: return emptySet()
        return try {
            val obj = JSONObject(json)
            if (obj.optString("date", "") != date) return emptySet()
            val arr = obj.optJSONArray("idx") ?: return emptySet()
            val out = HashSet<Int>(arr.length())
            for (i in 0 until arr.length()) out.add(arr.getInt(i))
            out
        } catch (_: Throwable) {
            emptySet()
        }
    }

    private fun readIndexPayload(prefs: SharedPreferences, key: String): Pair<String, List<Int>> {
        val json = prefs.getString(key, null) ?: return "" to emptyList()
        return try {
            val obj = JSONObject(json)
            val date = obj.optString("date", "")
            val arr = obj.optJSONArray("idx") ?: return date to emptyList()
            val out = ArrayList<Int>(arr.length())
            for (i in 0 until arr.length()) out.add(arr.getInt(i))
            out.sort()
            date to out
        } catch (_: Throwable) {
            "" to emptyList()
        }
    }

    /**
     * One commit for both sets. A half-written pair is the one state the card
     * cannot read correctly: a mark without its clear (or the reverse) would
     * flip a box the user did not touch.
     */
    private fun writeIndexSets(
        prefs: SharedPreferences,
        date: String,
        marks: Set<Int>,
        cleared: Set<Int>,
    ) {
        prefs.edit()
            .putString(KEY_PRAYER_READ, indexJson(date, marks))
            .putString(KEY_PRAYER_CLEARED, indexJson(date, cleared))
            .apply()
    }

    private fun indexJson(date: String, values: Set<Int>): String {
        val arr = JSONArray()
        values.sorted().forEach { arr.put(it) }
        return JSONObject().put("date", date).put("idx", arr).toString()
    }

    // ── Prayer times payload ──

    fun writeTimesPayload(
        prefs: SharedPreferences,
        date: String,
        today: PrayerDayTimes,
        tomorrow: PrayerDayTimes?,
    ) {
        prefs.edit()
            .putString(KEY_TIMES_JSON, PrayerTimesPayload.encode(date, today, tomorrow))
            .putString(KEY_TIMES_DATE, date)
            .apply()
    }

    fun readTimesPayload(prefs: SharedPreferences): PrayerTimesPayload =
        PrayerTimesPayload.parse(
            prefs.getString(KEY_TIMES_JSON, null),
            prefs.getString(KEY_TIMES_DATE, null),
        )
}

/** One day of clock times, `HH:mm`, no labels. */
data class PrayerDayTimes(
    val fajr: String,
    val dhuhr: String,
    val asr: String,
    val maghrib: String,
    val isha: String,
    val sunrise: String = "",
) {
    fun at(index: Int): String = when (index) {
        0 -> fajr
        1 -> dhuhr
        2 -> asr
        3 -> maghrib
        4 -> isha
        else -> ""
    }

    val isComplete: Boolean
        get() = fajr.isNotEmpty() && dhuhr.isNotEmpty() && asr.isNotEmpty() &&
            maghrib.isNotEmpty() && isha.isNotEmpty()

    companion object {
        val EMPTY = PrayerDayTimes("", "", "", "", "", "")
    }
}

/**
 * The widget's whole time input: today's five clocks plus tomorrow's Fajr, so
 * the «after Isha» countdown stays truthful across midnight without the widget
 * ever running the astronomical solver inside a composition.
 */
data class PrayerTimesPayload(
    val date: String,
    val today: PrayerDayTimes,
    val tomorrow: PrayerDayTimes?,
) {
    val hasToday: Boolean get() = today.isComplete

    /** Tomorrow's Fajr, or today's Fajr when tomorrow was never pushed — the
     *  countdown then stays within a minute of the truth instead of vanishing. */
    val nextFajr: String
        get() = tomorrow?.fajr?.takeIf { it.isNotEmpty() } ?: today.fajr

    companion object {
        val EMPTY = PrayerTimesPayload("", PrayerDayTimes.EMPTY, null)

        fun encode(date: String, today: PrayerDayTimes, tomorrow: PrayerDayTimes?): String {
            val root = JSONObject().put("date", date).put("today", encodeDay(today))
            if (tomorrow != null) root.put("tomorrow", encodeDay(tomorrow))
            return root.toString()
        }

        private fun encodeDay(day: PrayerDayTimes): JSONObject = JSONObject()
            .put("fajr", day.fajr)
            .put("dhuhr", day.dhuhr)
            .put("asr", day.asr)
            .put("maghrib", day.maghrib)
            .put("isha", day.isha)
            .put("sunrise", day.sunrise)

        fun parse(json: String?, fallbackDate: String?): PrayerTimesPayload {
            if (json.isNullOrBlank()) return EMPTY
            return try {
                val root = JSONObject(json)
                val date = root.optString("date", fallbackDate ?: "")
                PrayerTimesPayload(
                    date = date,
                    today = decodeDay(root.optJSONObject("today")),
                    tomorrow = root.optJSONObject("tomorrow")?.let { decodeDay(it) },
                )
            } catch (_: Throwable) {
                EMPTY
            }
        }

        private fun decodeDay(obj: JSONObject?): PrayerDayTimes {
            if (obj == null) return PrayerDayTimes.EMPTY
            return PrayerDayTimes(
                fajr = obj.optString("fajr", ""),
                dhuhr = obj.optString("dhuhr", ""),
                asr = obj.optString("asr", ""),
                maghrib = obj.optString("maghrib", ""),
                isha = obj.optString("isha", ""),
                sunrise = obj.optString("sunrise", ""),
            )
        }
    }
}
