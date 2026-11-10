package com.islamic.tawheeed.widget

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

object WidgetRepository {

    private const val PREF_FILE = "tawheeed_widgets"

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)

    fun persistSnapshot(context: Context, args: Map<String, Any?>) {
        val prefs = prefs(context)
        val editor: SharedPreferences.Editor = prefs.edit()
        args["nextPrayerName"]?.let { editor.putString("next_prayer_name", it.toString()) }
        args["nextPrayerMinutes"]?.let { editor.putInt("next_prayer_minutes", (it as? Number)?.toInt() ?: 0) }
        args["nextPrayerTime"]?.let { editor.putString("next_prayer_time", it.toString()) }
        args["nextPrayerIqamahOffset"]?.let { editor.putInt("next_prayer_iqamah_offset", (it as? Number)?.toInt() ?: 10) }
        val iqamahOffsets = args["iqamahOffsets"] as? List<*>
        if (iqamahOffsets != null) {
            val arr = JSONArray()
            iqamahOffsets.forEach { arr.put((it as? Number)?.toInt() ?: 10) }
            editor.putString("iqamah_offsets", arr.toString())
        }
        args["shamsiDate"]?.let { editor.putString("shamsi_date", it.toString()) }
        args["gregorianDate"]?.let { editor.putString("gregorian_date", it.toString()) }
        args["hijriDate"]?.let { editor.putString("hijri_date", it.toString()) }
        args["cityName"]?.let { editor.putString("city_name", it.toString()) }
        args["prayer1"]?.let { editor.putString("prayer_1", it.toString()) }
        args["prayer2"]?.let { editor.putString("prayer_2", it.toString()) }
        args["prayer3"]?.let { editor.putString("prayer_3", it.toString()) }
        args["prayer4"]?.let { editor.putString("prayer_4", it.toString()) }
        args["prayer5"]?.let { editor.putString("prayer_5", it.toString()) }
        args["sunrise"]?.let { editor.putString("sunrise", it.toString()) }
        args["sunset"]?.let { editor.putString("sunset", it.toString()) }
        args["azanSound"]?.let { editor.putString("azan_sound", it.toString()) }
        args["tasbihDhikr"]?.let { editor.putString("tasbih_dhikr", it.toString()) }
        args["tasbihCount"]?.let { editor.putInt("tasbih_count", (it as? Number)?.toInt() ?: 0) }
        args["tasbihTarget"]?.let { editor.putInt("tasbih_target", (it as? Number)?.toInt() ?: 33) }
        args["tasbihActive"]?.let { editor.putBoolean("tasbih_active", it.toString().toBoolean()) }
        args["tasbihZikrIndex"]?.let { editor.putInt("tasbih_zikr_index", (it as? Number)?.toInt() ?: 0) }
        val zikrList = args["tasbihZikrList"] as? List<*>
        if (zikrList != null) {
            val arr = JSONArray()
            zikrList.forEach { arr.put(it.toString()) }
            editor.putString("tasbih_zikr_list", arr.toString())
        }
        val zikrTargets = args["tasbihZikrTargets"] as? List<*>
        if (zikrTargets != null) {
            val arr = JSONArray()
            zikrTargets.forEach { arr.put((it as? Number)?.toInt() ?: 33) }
            editor.putString("tasbih_per_zikr_targets", arr.toString())
        }
        // Per-zikr counts aligned with the zikr list — keeps the widget's own
        // counters (shown when the user switches zikrs on the widget) in sync
        // with the app for every zikr, not just the currently-selected one.
        val zikrCounts = args["tasbihZikrCounts"] as? List<*>
        if (zikrCounts != null && zikrList != null) {
            val obj = JSONObject()
            for (i in zikrCounts.indices) {
                if (i < zikrList.size) {
                    obj.put(i.toString(), (zikrCounts[i] as? Number)?.toInt() ?: 0)
                }
            }
            editor.putString("tasbih_per_zikr_counts", obj.toString())
            // These pushed counts are now the widget's "as-of" state — stamp
            // the write time so the app-side merge can tell counts that
            // predate the daily reset boundary (yesterday's) from counts
            // recorded today. Without this a reset would be undone by the
            // merge resurrecting the pushed pre-reset counts.
            editor.putLong("widget_tasbih_last_tap_at", System.currentTimeMillis())
        }
        // The app's «ریست خودکار روزانه» setting — the widget's own midnight
        // reset only fires when the user enabled it in the app.
        args["tasbihAutoReset"]?.let {
            editor.putBoolean("tasbih_auto_reset", it.toString().toBoolean())
        }
        // The azkar haptic toggle — the widget's tap feedback vibrates only
        // when the app's tasbih tab vibrates too.
        args["azkarHaptic"]?.let {
            editor.putBoolean("azkar_haptic", it.toString().toBoolean())
        }
        // «بعد از رسیدن به هدف» — true hands the next tap to the following
        // zikr once the active one reaches its target; false keeps counting.
        args["tasbihAutoAdvance"]?.let {
            editor.putBoolean("tasbih_auto_advance", it.toString().toBoolean())
        }
        // Prayer card toggles: the elapsed-adhan progress bar and the
        // Gregorian date chip. Both re-render on the next snapshot push.
        args["widgetShowProgress"]?.let {
            editor.putBoolean("widget_show_progress", it.toString().toBoolean())
        }
        args["widgetShowGregorian"]?.let {
            editor.putBoolean("widget_show_gregorian", it.toString().toBoolean())
        }
        // The clock leaf's digit locale: false = Latin (default), true = the
        // fa-variant layout. Read by PrayerRemoteLeaves at every render.
        args["widgetFaDigits"]?.let {
            editor.putBoolean("widget_fa_digits", it.toString().toBoolean())
        }
        // «چیدمان ویجت اوقات نماز»: horizontal (the shipped five-box card) or
        // vertical (five rows, one prayer per line). Coerced here so a typo or
        // a newer build's value can never leave the renderer without a card it
        // knows how to draw.
        args["prayerLayout"]?.let {
            editor.putString(
                WidgetPrefs.KEY_PRAYER_LAYOUT,
                if (it.toString() == WidgetPrefs.LAYOUT_VERTICAL) {
                    WidgetPrefs.LAYOUT_VERTICAL
                } else {
                    WidgetPrefs.LAYOUT_HORIZONTAL
                },
            )
        }
        val events = args["calendarEvents"] as? List<*>
        if (events != null) {
            // Kept: the app still pushes it and a future «مناسبت امروز» band
            // reads it. Nothing on the card reads it today, so it is stored
            // without being decoded.
            val arr = JSONArray()
            events.forEach { item ->
                val map = item as? Map<*, *>
                val obj = JSONObject()
                obj.put("title", map?.get("title")?.toString() ?: "")
                obj.put("date", map?.get("date")?.toString() ?: "")
                arr.put(obj)
            }
            editor.putString("widget_calendar_events", arr.toString())
        }
        args["syncTimestamp"]?.let { editor.putLong("widget_sync_timestamp", (it as? Number)?.toLong() ?: 0L) }
        // Native self-refresh inputs — the widget recomputes today's times from
        // these (midnight / stale sync) without the app being opened.
        args["calcLatitude"]?.let { editor.putString("calc_lat", it.toString()) }
        args["calcLongitude"]?.let { editor.putString("calc_lng", it.toString()) }
        args["calcMethod"]?.let { editor.putString("calc_method", it.toString()) }
        args["calcFajrAngle"]?.let { editor.putFloat("calc_fajr_angle", (it as? Number)?.toFloat() ?: 18.0f) }
        args["calcIshaAngle"]?.let { editor.putFloat("calc_isha_angle", (it as? Number)?.toFloat() ?: 17.0f) }
        args["calcMaghribAngle"]?.let { editor.putFloat("calc_maghrib_angle", (it as? Number)?.toFloat() ?: 0f) }
        args["calcIshaInterval"]?.let { editor.putInt("calc_isha_interval", (it as? Number)?.toInt() ?: 0) }
        args["calcMadhab"]?.let { editor.putInt("calc_madhab", (it as? Number)?.toInt() ?: 0) }
        args["calcHighLatitude"]?.let { editor.putInt("calc_high_latitude", (it as? Number)?.toInt() ?: 0) }
        val calcMethodAdj = args["calcMethodAdjustments"] as? List<*>
        if (calcMethodAdj != null) {
            val arr = JSONArray()
            calcMethodAdj.forEach { arr.put((it as? Number)?.toInt() ?: 0) }
            editor.putString("calc_method_adj", arr.toString())
        }
        val calcUserAdj = args["calcUserAdjustments"] as? List<*>
        if (calcUserAdj != null) {
            val arr = JSONArray()
            calcUserAdj.forEach { arr.put((it as? Number)?.toInt() ?: 0) }
            editor.putString("calc_user_adj", arr.toString())
        }
        args["calcTimezone"]?.let { editor.putString("calc_timezone", it.toString()) }
        args["calcFixedOffsetMinutes"]?.let {
            editor.putInt(
                "calc_fixed_offset_min",
                (it as? Number)?.toInt() ?: Int.MIN_VALUE,
            )
        }
        val calcElevAdj = args["calcElevationAdjustments"] as? List<*>
        if (calcElevAdj != null) {
            val arr = JSONArray()
            calcElevAdj.forEach { arr.put((it as? Number)?.toInt() ?: 0) }
            editor.putString("calc_elevation_adj", arr.toString())
        }
        args["calcHijriOffset"]?.let { editor.putInt("calc_hijri_offset", (it as? Number)?.toInt() ?: 2) }
        // Record the day these times were computed for. The native recompute
        // triggers when it no longer matches today.
        if (args["prayer1"] != null) {
            editor.putString("widget_times_date", todayKey())
        }
        args["use12Hour"]?.let { editor.putBoolean("widget_use_12_hour", it.toString().toBoolean()) }
        // ── Theme colours as raw ARGB ──
        // The widget must not carry a hardcoded colour: the app decides the
        // palette and these four are the resolved result. 0 means "not
        // pushed", in which case the widget keeps the palette-derived colour.
        args["accentArgb"]?.let {
            editor.putInt(WidgetPrefs.KEY_ACCENT_ARGB, (it as? Number)?.toInt() ?: 0)
        }
        args["textArgb"]?.let {
            editor.putInt(WidgetPrefs.KEY_TEXT_ARGB, (it as? Number)?.toInt() ?: 0)
        }
        args["bgArgb"]?.let {
            editor.putInt(WidgetPrefs.KEY_BG_ARGB, (it as? Number)?.toInt() ?: 0)
        }
        args["bgEndArgb"]?.let {
            editor.putInt(WidgetPrefs.KEY_BG_END_ARGB, (it as? Number)?.toInt() ?: 0)
        }
        // ── Today + tomorrow, straight from the app ──
        // When the app sends the payload it wins: it is the only side that
        // knows tomorrow's Fajr without solving the sun again. Kotlin writes
        // the same key from its own recompute, so a card whose app was never
        // opened still has data.
        (args["prayerTimesJson"] as? String)?.takeIf { it.isNotBlank() }?.let {
            editor.putString(WidgetPrefs.KEY_TIMES_JSON, it)
        }
        val prayerStatuses = args["prayerStatuses"] as? Map<*, *>
        if (prayerStatuses != null) {
            val obj = JSONObject()
            prayerStatuses.forEach { (name, status) ->
                if (name != null && status != null) obj.put(name.toString(), status.toString())
            }
            editor.putString("prayer_statuses", obj.toString())
        }
        // Kotlin keeps `widget_times_json` populated even when the app pushes
        // only the five legacy strings: the payload is what the render reads,
        // so building it here keeps a not-yet-updated app working.
        if (args["prayerTimesJson"] == null && args["prayer1"] != null) {
            fun clockOf(value: Any?): String =
                parsePrayerString(value?.toString() ?: "").second
            val today = PrayerDayTimes(
                fajr = clockOf(args["prayer1"]),
                dhuhr = clockOf(args["prayer2"]),
                asr = clockOf(args["prayer3"]),
                maghrib = clockOf(args["prayer4"]),
                isha = clockOf(args["prayer5"]),
                sunrise = clockOf(args["sunrise"]),
            )
            val previous = PrayerTimesPayload.parse(
                prefs.getString(WidgetPrefs.KEY_TIMES_JSON, null),
                null,
            )
            editor.putString(
                WidgetPrefs.KEY_TIMES_JSON,
                PrayerTimesPayload.encode(todayKey(), today, previous.tomorrow),
            )
        }
        editor.apply()
    }

    fun parsePrayerString(raw: String): Pair<String, String> {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) return Pair("--", "--:--")
        val timeRegex = Regex("""(\d{1,2}:\d{2})""")
        val match = timeRegex.find(trimmed)
        return if (match != null) {
            val time = match.groupValues[1]
            val label = trimmed.replace(time, "").trim()
            if (label.isNotEmpty()) Pair(label, time) else Pair(trimmed, "--:--")
        } else {
            Pair(trimmed, "--:--")
        }
    }

    private fun readStringMap(prefs: SharedPreferences, key: String): Map<String, String> {
        val json = prefs.getString(key, null) ?: return emptyMap()
        return try {
            val obj = JSONObject(json)
            val map = mutableMapOf<String, String>()
            val names = obj.keys()
            while (names.hasNext()) {
                val name = names.next()
                map[name] = obj.optString(name, "")
            }
            map
        } catch (_: Exception) { emptyMap() }
    }

    /**
     * Prayer name (فجر…عشاء) → "done" | "missed" | "pending". Empty until the
     * app pushes its first status map, so a fresh widget simply shows no mark.
     */
    fun readPrayerStatuses(prefs: SharedPreferences): Map<String, String> =
        readStringMap(prefs, "prayer_statuses")

    /** Per-prayer iqamah offsets (minutes after adhan), indexed like prayer_1..5. */
    fun readIqamahOffsets(prefs: SharedPreferences): List<Int> {
        val json = prefs.getString("iqamah_offsets", null)
        if (json != null) {
            try {
                val arr = JSONArray(json)
                val list = mutableListOf<Int>()
                for (i in 0 until arr.length()) list.add(arr.getInt(i))
                if (list.isNotEmpty()) return list
            } catch (_: Exception) { /* fall through */ }
        }
        return listOf(10, 10, 10, 10, 10)
    }

    // ────────────────────────────────────────────────────────────────
    // Native self-refresh — recompute today's prayer times in Kotlin
    // ────────────────────────────────────────────────────────────────

    /** "YYYY-MM-DD" of today (local) — key of the day the times were computed for. */
    fun todayKey(): String {
        val c = Calendar.getInstance()
        return "${c.get(Calendar.YEAR)}-${(c.get(Calendar.MONTH) + 1).toString().padStart(2, '0')}-${c.get(Calendar.DAY_OF_MONTH).toString().padStart(2, '0')}"
    }

    /**
     * Recomputes today's prayer times + calendar dates natively when the stored
     * times were computed for a different day (midnight passed, or the app
     * wasn't opened for days). Returns true when the times were refreshed.
     *
     * **Never call this from `provideGlance`.** It runs the astronomical
     * solver and writes a dozen prefs keys; the render must stay a pure read.
     * The callers are [PrayerWidget.onUpdate], its alarm receivers,
     * [WidgetRefreshWorker] and the boot receiver — all of them before the
     * render they feed.
     *
     * It also refreshes `widget_times_json` with **today and tomorrow**: the
     * card needs tomorrow's Fajr for the «after Isha» countdown, and a widget
     * that was never opened again must not fall back to today's Fajr forever.
     */
    fun recomputeTimesIfStale(context: Context): Boolean {
        val prefs = prefs(context)
        val today = todayKey()
        val storedDay = prefs.getString("widget_times_date", null) ?: ""
        if (storedDay == today) return false

        val latStr = prefs.getString("calc_lat", null) ?: return false
        val lngStr = prefs.getString("calc_lng", null) ?: return false
        val lat = latStr.toDoubleOrNull() ?: return false
        val lng = lngStr.toDoubleOrNull() ?: return false

        try {
            val params = readCalcParams(prefs)
            val now = Calendar.getInstance()
            val times = PrayerTimesCalculator.calculate(
                now.get(Calendar.YEAR),
                now.get(Calendar.MONTH) + 1,
                now.get(Calendar.DAY_OF_MONTH),
                lat,
                lng,
                params,
            )
            val tomorrowCal = (now.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, 1)
            }
            val tomorrowTimes = try {
                PrayerTimesCalculator.calculate(
                    tomorrowCal.get(Calendar.YEAR),
                    tomorrowCal.get(Calendar.MONTH) + 1,
                    tomorrowCal.get(Calendar.DAY_OF_MONTH),
                    lat,
                    lng,
                    params,
                )
            } catch (_: Throwable) {
                null
            }
            val editor = prefs.edit()
            // Elevation (horizon-dip) deltas resolved by the app are baked into
            // sunrise/maghrib exactly like the Flutter engine's second pass.
            val elevAdj = adjList(prefs, "calc_elevation_adj")
            fun withElevation(mins: Int, c: Calendar): Calendar {
                if (mins == 0) return c
                val shifted = c.clone() as Calendar
                shifted.add(Calendar.MINUTE, mins)
                return shifted
            }
            val maghrib = withElevation(elevAdj.getOrElse(1) { 0 }, times.maghrib)
            val sunrise = withElevation(elevAdj.getOrElse(0) { 0 }, times.sunrise)
            editor.putString("prayer_1", "فجر ${fmtTime(times.fajr)}")
            editor.putString("prayer_2", "ظهر ${fmtTime(times.dhuhr)}")
            editor.putString("prayer_3", "عصر ${fmtTime(times.asr)}")
            editor.putString("prayer_4", "مغرب ${fmtTime(maghrib)}")
            editor.putString("prayer_5", "عشاء ${fmtTime(times.isha)}")
            editor.putString("sunrise", fmtTime(sunrise))
            editor.putString("sunset", fmtTime(maghrib))
            editor.putString("shamsi_date", shamsiDate(times.fajr))
            editor.putString("gregorian_date", gregorianDate(times.fajr))
            editor.putString("hijri_date", hijriDate(times.fajr, prefs.getInt("calc_hijri_offset", 2)))
            editor.putString("widget_times_date", today)
            editor.putLong("widget_sync_timestamp", System.currentTimeMillis())
            editor.putString(
                WidgetPrefs.KEY_TIMES_JSON,
                PrayerTimesPayload.encode(
                    date = today,
                    today = PrayerDayTimes(
                        fajr = fmtTime(times.fajr),
                        dhuhr = fmtTime(times.dhuhr),
                        asr = fmtTime(times.asr),
                        maghrib = fmtTime(maghrib),
                        isha = fmtTime(times.isha),
                        sunrise = fmtTime(sunrise),
                    ),
                    tomorrow = tomorrowTimes?.let {
                        PrayerDayTimes(
                            fajr = fmtTime(it.fajr),
                            dhuhr = fmtTime(it.dhuhr),
                            asr = fmtTime(it.asr),
                            maghrib = fmtTime(
                                withElevation(elevAdj.getOrElse(1) { 0 }, it.maghrib),
                            ),
                            isha = fmtTime(it.isha),
                            sunrise = fmtTime(
                                withElevation(elevAdj.getOrElse(0) { 0 }, it.sunrise),
                            ),
                        )
                    },
                ),
            )
            editor.apply()
            Log.d(TAG, "Recomputed today's prayer times natively ($storedDay -> $today)")
            return true
        } catch (e: Throwable) {
            Log.w(TAG, "recomputeTimesIfStale failed: ${e.message}")
            return false
        }
    }

    private fun adjList(prefs: SharedPreferences, key: String): IntArray {
        val json = prefs.getString(key, null)
        if (json != null) {
            try {
                val arr = JSONArray(json)
                val list = IntArray(arr.length())
                for (i in 0 until arr.length()) list[i] = arr.getInt(i)
                return list
            } catch (_: Exception) { /* fall through */ }
        }
        return intArrayOf(0, 0, 0, 0, 0, 0)
    }

    private fun readCalcParams(prefs: SharedPreferences): PrayerTimesCalculator.Parameters {
        return PrayerTimesCalculator.Parameters(
            method = PrayerTimesCalculator.Method.fromId(prefs.getString("calc_method", null)),
            fajrAngle = prefs.getFloat("calc_fajr_angle", 18.0f).toDouble(),
            ishaAngle = prefs.getFloat("calc_isha_angle", 17.0f).toDouble(),
            maghribAngle = prefs.getFloat("calc_maghrib_angle", 0f).toDouble(),
            ishaInterval = prefs.getInt("calc_isha_interval", 0),
            madhab = prefs.getInt("calc_madhab", 0),
            highLatitude = prefs.getInt("calc_high_latitude", 0),
            methodAdjustments = adjList(prefs, "calc_method_adj"),
            adjustments = adjList(prefs, "calc_user_adj"),
            timezone = prefs.getString("calc_timezone", null)
                ?: java.util.TimeZone.getDefault().getID(),
            fixedUtcOffsetMinutes =
                prefs.getInt("calc_fixed_offset_min", Int.MIN_VALUE),
        )
    }

    private fun fmtTime(c: Calendar): String {
        val h = c.get(Calendar.HOUR_OF_DAY).toString().padStart(2, '0')
        val m = c.get(Calendar.MINUTE).toString().padStart(2, '0')
        return "$h:$m"
    }

    private fun shamsiDate(c: Calendar): String {
        val (y, m, d) = IslamicCalendars.jalaliFromGregorian(
            c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH),
        )
        return "$d ${PERSIAN_MONTHS[m - 1]} $y"
    }

    private fun hijriDate(c: Calendar, offset: Int): String {
        val (y, m, d) = IslamicCalendars.hijriFromGregorian(
            c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH), offset,
        )
        return "$d ${HIJRI_MONTHS[m - 1]} $y"
    }

    private fun gregorianDate(c: Calendar): String {
        val d = c.get(Calendar.DAY_OF_MONTH)
        val m = c.get(Calendar.MONTH)
        val y = c.get(Calendar.YEAR)
        return "$d ${GREGORIAN_MONTHS[m]} $y"
    }

    private const val TAG = "WidgetRepository"

    private val PERSIAN_MONTHS = listOf(
        "فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
        "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند",
    )

    private val HIJRI_MONTHS = listOf(
        "محرم", "صفر", "ربیع‌الاول", "ربیع‌الثانی", "جمادی‌الاول", "جمادی‌الثانی",
        "رجب", "شعبان", "رمضان", "شوال", "ذی‌قعده", "ذی‌حجه",
    )

    private val GREGORIAN_MONTHS = listOf(
        "ژانویه", "فوریه", "مارس", "آوریل", "می", "ژوئن",
        "ژوئیه", "اوت", "سپتامبر", "اکتبر", "نوامبر", "دسامبر",
    )
}
