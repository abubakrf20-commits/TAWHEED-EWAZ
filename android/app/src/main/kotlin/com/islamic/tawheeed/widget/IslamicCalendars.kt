package com.islamic.tawheeed.widget

/**
 * Gregorian ↔ Julian-day conversions plus Jalali (Persian) and tabular-Hijri
 * date conversions — faithful ports of the Dart `HijriUtils` and the
 * `shamsi_date` package used by the Flutter side, so the home-screen widget can
 * render today's three calendar dates by itself when it recomputes times.
 */
object IslamicCalendars {

    // ────────────────────────────────────────────────────────────────
    // Gregorian ↔ Julian day
    // ────────────────────────────────────────────────────────────────
    fun gregToJd(year: Int, month: Int, day: Int): Int {
        val a = (14 - month) / 12
        val y = year + 4800 - a
        val m = month + 12 * a - 3
        return day +
            (153 * m + 2) / 5 +
            365 * y +
            y / 4 -
            y / 100 +
            y / 400 -
            32045
    }

    fun jdToGreg(jd: Int): IntArray {
        var l = jd + 68569
        val n = (4 * l) / 146097
        l = l - ((146097 * n + 3) / 4)
        val i = (4000 * (l + 1)) / 1461001
        l = l - (1461 * i) / 4 + 31
        val j = (80 * l) / 2447
        val d = l - (2447 * j) / 80
        l = j / 11
        val m = j + 2 - 12 * l
        val y = 100 * (n - 49) + i + l
        return intArrayOf(y, m, d)
    }

    // ────────────────────────────────────────────────────────────────
    // Jalali (shamsi_date `_Algo` port)
    // ────────────────────────────────────────────────────────────────
    private val JALALI_BREAKS = intArrayOf(
        -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210,
        1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178,
    )

    private class JalaliCalculation(val leap: Int, val gy: Int, val march: Int)

    private fun jalaliCalculate(jy: Int): JalaliCalculation {
        val bl = JALALI_BREAKS.size
        val gy = jy + 621
        var leapJ = -14
        var jp = JALALI_BREAKS[0]
        var jump = 0

        var i = 1
        while (i < bl) {
            val jm = JALALI_BREAKS[i]
            jump = jm - jp
            if (jy < jm) break
            leapJ = leapJ + (jump / 33) * 8 + ((jump % 33) / 4)
            jp = jm
            i++
        }
        var n = jy - jp

        leapJ = leapJ + (n / 33) * 8 + ((n % 33 + 3) / 4)
        if (jump % 33 == 4 && jump - n == 4) {
            leapJ += 1
        }

        val leapG = gy / 4 - (((gy / 100) + 1) * 3) / 4 - 150
        val march = 20 + leapJ - leapG

        if (jump - n < 6) {
            n = n - jump + ((jump + 4) / 33) * 33
        }
        var leap = (((n + 1) % 33) - 1) % 4
        if (leap == -1) leap = 4

        return JalaliCalculation(leap, gy, march)
    }

    /** Gregorian (year, month, day) → Jalali (year, month, day). */
    fun jalaliFromGregorian(year: Int, month: Int, day: Int): IntArray {
        val jdn = gregToJd(year, month, day)
        val gy = jdToGreg(jdn)[0]
        var jy = gy - 621
        val r = jalaliCalculate(jy)
        val jdn1f = gregToJd(gy, 3, r.march)
        var k = jdn - jdn1f

        if (k >= 0) {
            if (k <= 185) {
                val jm = 1 + k / 31
                val jd = k % 31 + 1
                return intArrayOf(jy, jm, jd)
            }
            k -= 186
        } else {
            jy -= 1
            k += 179
            if (r.leap == 1) k += 1
        }
        val jm = 7 + k / 30
        val jd = k % 30 + 1
        return intArrayOf(jy, jm, jd)
    }

    // ────────────────────────────────────────────────────────────────
    // Tabular Hijri (HijriUtils port, with the app's day offset)
    // ────────────────────────────────────────────────────────────────
    private const val HIJRI_EPOCH = 1948440

    private fun isHijriLeapYear(year: Int): Boolean =
        (11 * year + 3) / 30 > (11 * (year - 1) + 3) / 30

    private fun hijriMonthLength(month: Int): Int =
        if (month % 2 == 1 || month == 12) 30 else 29

    private fun hijriYearStart(year: Int): Int =
        (year - 1) * 354 + (11 * year + 3) / 30 + HIJRI_EPOCH

    private fun findHijriYear(jd: Int): Int {
        var year = ((jd - HIJRI_EPOCH) / 354.0).toInt() + 1
        if (year < 1) year = 1
        while (hijriYearStart(year + 1) <= jd) year++
        while (hijriYearStart(year) > jd) year--
        return year
    }

    /** Gregorian (year, month, day) → Hijri (year, month, day) with [offset] days. */
    fun hijriFromGregorian(year: Int, month: Int, day: Int, offset: Int = 2): IntArray {
        val jd = gregToJd(year, month, day) + offset
        val hy = findHijriYear(jd)
        val doy = jd - hijriYearStart(hy) + 1
        var remaining = doy
        var hm = 1
        while (hm <= 12) {
            val days = hijriMonthLength(hm)
            if (remaining <= days) break
            remaining -= days
            hm++
        }
        if (hm > 12) hm = 12
        return intArrayOf(hy, hm, remaining)
    }
}
