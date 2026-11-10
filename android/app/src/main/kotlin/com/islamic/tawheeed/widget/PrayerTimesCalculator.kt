package com.islamic.tawheeed.widget

import java.util.Calendar
import java.util.TimeZone
import kotlin.math.abs
import kotlin.math.acos
import kotlin.math.asin
import kotlin.math.atan
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Faithful Kotlin port of the `adhan` Dart package (which the Flutter side uses
 * for prayer times) so the home-screen widget can recompute today's times by
 * itself — after midnight, after a reboot, or after several days without the
 * app being opened — from the coordinates + calculation parameters that the app
 * persisted into SharedPreferences.
 *
 * All astronomical math runs in UTC (matching the Dart package); the final
 * times are converted to the device's local timezone with minute rounding.
 */
object PrayerTimesCalculator {

    // ────────────────────────────────────────────────────────────────
    // Calculation method (only the moon-sighting special cases behave
    // differently at runtime; angles/adjustments are supplied by the app).
    // ────────────────────────────────────────────────────────────────
    enum class Method(val id: String) {
        MUSLIM_WORLD_LEAGUE("muslimWorldLeague"),
        KARACHI("karachi"),
        UMM_AL_QURA("ummAlQura"),
        EGYPTIAN("egyptian"),
        TEHRAN("tehran"),
        TURKEY("turkey"),
        DUBAI("dubai"),
        KUWAIT("kuwait"),
        QATAR("qatar"),
        SINGAPORE("singapore"),
        NORTH_AMERICA("northAmerica"),
        MOON_SIGHTING_COMMITTEE("moonsightingCommittee"),
        CUSTOM("custom");

        companion object {
            fun fromId(id: String?): Method =
                entries.firstOrNull { it.id == id } ?: MUSLIM_WORLD_LEAGUE
        }
    }

    class Parameters(
        val method: Method,
        val fajrAngle: Double,
        val ishaAngle: Double,
        val maghribAngle: Double = 0.0,
        val ishaInterval: Int = 0,
        val madhab: Int = 0, // 0 = Shafi, 1 = Hanafi
        val highLatitude: Int = 0, // 0 = middle of night, 1 = seventh, 2 = twilight angle
        val methodAdjustments: IntArray = intArrayOf(0, 0, 0, 0, 0, 0),
        val adjustments: IntArray = intArrayOf(0, 0, 0, 0, 0, 0),
        /** IANA zone the final wall-clock times are rendered in — must match the app's `settings.timezone`. */
        val timezone: String = "Asia/Tehran",
        /**
         * Exact UTC offset (minutes) the APP itself used for these times.
         * When set, final wall-clock rendering uses this offset INSTEAD of the
         * device tz database entry for [timezone]. Android's bundled tzdata
         * can lag behind real-world rule changes (Iran dropped DST in 2022 but
         * older devices still applied it), which made the widget render a
         * stale +1h while the in-app times were correct. The app computes the
         * offset with the Flutter `timezone` package (2026-correct), so pinning
         * the widget to it keeps both displays identical.
         * [Int.MIN_VALUE] = absent → fall back to the tz database entry.
         */
        val fixedUtcOffsetMinutes: Int = Int.MIN_VALUE,
    )

    class Times(
        val fajr: Calendar,
        val sunrise: Calendar,
        val dhuhr: Calendar,
        val asr: Calendar,
        val maghrib: Calendar,
        val isha: Calendar,
    )

    /** Computes today's prayer times for a Gregorian [year]/[month]/[day] in local time. */
    fun calculate(
        year: Int,
        month: Int,
        day: Int,
        latitude: Double,
        longitude: Double,
        params: Parameters,
    ): Times {
        val date = utc(year, month, day)
        val tomorrow = utc(year, month, day + 1)
        val yesterday = utc(year, month, day - 1)

        val solar = SolarTime(date, latitude, longitude)
        val tomorrowSolar = SolarTime(tomorrow, latitude, longitude)

        val transit = TimeComponents.fromDouble(solar.transit).dateComponents(date)
        val sunriseComponents = TimeComponents.fromDouble(solar.sunrise).dateComponents(date)
        val sunsetComponents = TimeComponents.fromDouble(solar.sunset).dateComponents(date)
        val tomorrowSunriseComponents = TimeComponents.fromDouble(tomorrowSolar.sunrise)

        val asr = TimeComponents
            .fromDouble(solar.afternoon(if (params.madhab == 1) 2.0 else 1.0))
            .dateComponents(date)

        // Night length = ms between today's sunset and tomorrow's sunrise.
        val tomorrowSunrise = tomorrowSunriseComponents.dateComponents(tomorrow)
        val night = tomorrowSunrise.timeInMillis - sunsetComponents.timeInMillis

        val dayOfYear = dayOfYear(date)
        val nightPortions = nightPortions(params)

        // ── Fajr ──
        var tempFajr: Calendar? = null
        val fajrValue = solar.hourAngle(-params.fajrAngle, false)
        if (isValid(fajrValue)) {
            tempFajr = TimeComponents.fromDouble(fajrValue).dateComponents(date)
        }
        if (params.method == Method.MOON_SIGHTING_COMMITTEE && latitude >= 55) {
            tempFajr = addSeconds(sunriseComponents, -(night / 7000))
        }
        val safeFajr = if (params.method == Method.MOON_SIGHTING_COMMITTEE) {
            seasonAdjustedMorningTwilight(latitude, dayOfYear, year, sunriseComponents)
        } else {
            val fraction = (nightPortions.first * night) / 1000.0
            addSeconds(sunriseComponents, -fraction.toLong())
        }
        if (tempFajr == null || tempFajr.timeInMillis < safeFajr.timeInMillis) {
            tempFajr = safeFajr
        }

        // ── Isha ──
        var tempIsha: Calendar? = null
        if (params.ishaInterval > 0) {
            tempIsha = addSeconds(sunsetComponents, params.ishaInterval * 60L)
        } else {
            val ishaValue = solar.hourAngle(-params.ishaAngle, true)
            if (isValid(ishaValue)) {
                tempIsha = TimeComponents.fromDouble(ishaValue).dateComponents(date)
            }
            if (params.method == Method.MOON_SIGHTING_COMMITTEE && latitude >= 55) {
                tempIsha = addSeconds(sunsetComponents, night / 7000)
            }
            val safeIsha = if (params.method == Method.MOON_SIGHTING_COMMITTEE) {
                seasonAdjustedEveningTwilight(latitude, dayOfYear, year, sunsetComponents)
            } else {
                val fraction = (nightPortions.second * night) / 1000.0
                addSeconds(sunsetComponents, fraction.toLong())
            }
            if (tempIsha == null || tempIsha.timeInMillis > safeIsha.timeInMillis) {
                tempIsha = safeIsha
            }
        }

        // ── Maghrib (Tehran uses a 4.5° angle instead of sunset) ──
        var tempMaghrib = sunsetComponents
        if (params.maghribAngle > 0) {
            val angleMaghrib = TimeComponents
                .fromDouble(solar.hourAngle(-params.maghribAngle, true))
                .dateComponents(date)
            if (sunsetComponents.timeInMillis < angleMaghrib.timeInMillis &&
                tempIsha.timeInMillis > angleMaghrib.timeInMillis
            ) {
                tempMaghrib = angleMaghrib
            }
        }

        fun finalize(c: Calendar, adj: Int, methodAdj: Int): Calendar {
            val utcAdjusted = c.clone() as Calendar
            utcAdjusted.add(Calendar.MINUTE, adj + methodAdj)
            val tz = TimeZone.getTimeZone(params.timezone)
            val tzOffsetMin = tz.getOffset(utcAdjusted.timeInMillis) / 60000
            // Prefer the app's exact offset; the device tz database can be
            // stale (Iran DST removal shipped to old devices years late).
            val offsetMin =
                if (params.fixedUtcOffsetMinutes != Int.MIN_VALUE) params.fixedUtcOffsetMinutes
                else tzOffsetMin
            val local = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
                clear()
                timeInMillis = utcAdjusted.timeInMillis + offsetMin * 60000L
            }
            return roundedMinute(local)
        }

        return Times(
            fajr = finalize(tempFajr, params.adjustments[0], params.methodAdjustments[0]),
            sunrise = finalize(sunriseComponents, params.adjustments[1], params.methodAdjustments[1]),
            dhuhr = finalize(transit, params.adjustments[2], params.methodAdjustments[2]),
            asr = finalize(asr, params.adjustments[3], params.methodAdjustments[3]),
            maghrib = finalize(tempMaghrib, params.adjustments[4], params.methodAdjustments[4]),
            isha = finalize(tempIsha, params.adjustments[5], params.methodAdjustments[5]),
        )
    }

    // ────────────────────────────────────────────────────────────────
    // Night portions (high-latitude guard rails)
    // ────────────────────────────────────────────────────────────────
    private fun nightPortions(params: Parameters): Pair<Double, Double> = when (params.highLatitude) {
        1 -> 1.0 / 7.0 to 1.0 / 7.0
        2 -> params.fajrAngle / 60.0 to params.ishaAngle / 60.0
        else -> 0.5 to 0.5
    }

    private fun isValid(v: Double) = !v.isInfinite() && !v.isNaN()

    private fun addSeconds(c: Calendar, seconds: Long): Calendar {
        val out = c.clone() as Calendar
        out.add(Calendar.SECOND, seconds.toInt())
        return out
    }

    /** Rounds the seconds into the minute (the Dart `CalendarUtil.roundedMinute`). */
    private fun roundedMinute(c: Calendar): Calendar {
        val second = c.get(Calendar.SECOND)
        val extra = (second / 60.0).roundToInt()
        val out = c.clone() as Calendar
        out.set(Calendar.SECOND, 0)
        out.set(Calendar.MILLISECOND, 0)
        if (extra != 0) out.add(Calendar.MINUTE, extra)
        return out
    }

    private fun dayOfYear(c: Calendar): Int {
        val start = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(c.get(Calendar.YEAR), 0, 1)
        }
        return ((c.timeInMillis - start.timeInMillis) / 86400000L).toInt() + 1
    }

    private fun utc(year: Int, month: Int, day: Int): Calendar =
        Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(year, month - 1, day, 0, 0, 0)
        }

    // ────────────────────────────────────────────────────────────────
    // Solar time model (SolarTime + SolarCoordinates + Astronomical)
    // ────────────────────────────────────────────────────────────────
    private class SolarTime(date: Calendar, latitude: Double, longitude: Double) {
        private val observer = Coordinates(latitude, longitude)
        private val solar: SolarCoordinates
        private val prevSolar: SolarCoordinates
        private val nextSolar: SolarCoordinates
        private val approximateTransit: Double

        val transit: Double
        val sunrise: Double
        val sunset: Double

        init {
            val tomorrow = date.clone() as Calendar
            tomorrow.add(Calendar.DAY_OF_YEAR, 1)
            val yesterday = date.clone() as Calendar
            yesterday.add(Calendar.DAY_OF_YEAR, -1)

            prevSolar = SolarCoordinates(julianDayByDate(yesterday))
            solar = SolarCoordinates(julianDayByDate(date))
            nextSolar = SolarCoordinates(julianDayByDate(tomorrow))

            approximateTransit = approximateTransit(
                observer.longitude,
                solar.apparentSiderealTime,
                solar.rightAscension,
            )
            val solarAltitude = -50.0 / 60.0

            transit = correctedTransit(
                approximateTransit, observer.longitude, solar.apparentSiderealTime,
                solar.rightAscension, prevSolar.rightAscension, nextSolar.rightAscension,
            )
            sunrise = correctedHourAngle(
                approximateTransit, solarAltitude, observer, false,
                solar.apparentSiderealTime, solar.rightAscension,
                prevSolar.rightAscension, nextSolar.rightAscension,
                solar.declination, prevSolar.declination, nextSolar.declination,
            )
            sunset = correctedHourAngle(
                approximateTransit, solarAltitude, observer, true,
                solar.apparentSiderealTime, solar.rightAscension,
                prevSolar.rightAscension, nextSolar.rightAscension,
                solar.declination, prevSolar.declination, nextSolar.declination,
            )
        }

        fun hourAngle(angle: Double, afterTransit: Boolean): Double = correctedHourAngle(
            approximateTransit, angle, observer, afterTransit,
            solar.apparentSiderealTime, solar.rightAscension,
            prevSolar.rightAscension, nextSolar.rightAscension,
            solar.declination, prevSolar.declination, nextSolar.declination,
        )

        /** Hours from transit at which the shadow is [shadowLength] times the object height. */
        fun afternoon(shadowLength: Double): Double {
            val tangent = abs(observer.latitude - solar.declination)
            val inverse = shadowLength + Math.tan(radians(tangent))
            val angle = degrees(Math.atan(1.0 / inverse))
            return hourAngle(angle, true)
        }
    }

    private class SolarCoordinates(julianDay: Double) {
        val declination: Double
        val rightAscension: Double
        val apparentSiderealTime: Double

        init {
            val t = julianCentury(julianDay)
            val l0 = meanSolarLongitude(t)
            val lp = meanLunarLongitude(t)
            val omega = ascendingLunarNodeLongitude(t)
            val lambda = radians(apparentSolarLongitude(t, l0))

            val theta0 = meanSiderealTime(t)
            val deltaPsi = nutationInLongitude(t, l0, lp, omega)
            val deltaEpsilon = nutationInObliquity(t, l0, lp, omega)

            val epsilon0 = meanObliquityOfTheEcliptic(t)
            val epsilonApp = radians(apparentObliquityOfTheEcliptic(t, epsilon0))

            declination = degrees(asin(sin(epsilonApp) * sin(lambda)))
            rightAscension = unwindAngle(
                degrees(atan2(cos(epsilonApp) * sin(lambda), cos(lambda)))
            )
            apparentSiderealTime = theta0 +
                ((deltaPsi * 3600.0) * cos(radians(epsilon0 + deltaEpsilon))) / 3600.0
        }
    }

    private data class Coordinates(val latitude: Double, val longitude: Double)

    // ── Astronomy helpers (Astronomical Algorithms, same as the adhan package) ──
    private fun julianDay(year: Int, month: Int, day: Int, hours: Double = 0.0): Double {
        val y = if (month > 2) year else year - 1
        val m = if (month > 2) month else month + 12
        val d = day + hours / 24.0
        val a = y / 100
        val b = (2 - a + a / 4.0).toInt()
        val i0 = (365.25 * (y + 4716)).toInt()
        val i1 = (30.6001 * (m + 1)).toInt()
        return i0 + i1 + d + b - 1524.5
    }

    private fun julianDayByDate(c: Calendar): Double {
        val h = c.get(Calendar.HOUR_OF_DAY)
        val mi = c.get(Calendar.MINUTE)
        return julianDay(c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH), hours = (h + mi) / 60.0)
    }

    private fun julianCentury(jd: Double): Double = (jd - 2451545.0) / 36525.0

    private fun meanSolarLongitude(t: Double): Double =
        unwindAngle(280.4664567 + 36000.76983 * t + 0.0003032 * t.pow(2))

    private fun meanLunarLongitude(t: Double): Double =
        unwindAngle(218.3165 + 481267.8813 * t)

    private fun ascendingLunarNodeLongitude(t: Double): Double =
        unwindAngle(125.04452 - 1934.136261 * t + 0.0020708 * t.pow(2) + t.pow(3) / 450000.0)

    private fun meanSolarAnomaly(t: Double): Double =
        unwindAngle(357.52911 + 35999.05029 * t - 0.0001537 * t.pow(2))

    private fun solarEquationOfTheCenter(t: Double, m: Double): Double {
        val mRad = radians(m)
        return (1.914602 - 0.004817 * t - 0.000014 * t.pow(2)) * sin(mRad) +
            (0.019993 - 0.000101 * t) * sin(2 * mRad) +
            0.000289 * sin(3 * mRad)
    }

    private fun apparentSolarLongitude(t: Double, l0: Double): Double {
        val longitude = l0 + solarEquationOfTheCenter(t, meanSolarAnomaly(t))
        val omega = 125.04 - 1934.136 * t
        return unwindAngle(longitude - 0.00569 - 0.00478 * sin(radians(omega)))
    }

    private fun meanObliquityOfTheEcliptic(t: Double): Double =
        23.439291 - 0.013004167 * t - 0.0000001639 * t.pow(2) + 0.0000005036 * t.pow(3)

    private fun apparentObliquityOfTheEcliptic(t: Double, epsilon0: Double): Double =
        epsilon0 + 0.00256 * cos(radians(125.04 - 1934.136 * t))

    private fun meanSiderealTime(t: Double): Double {
        val jd = t * 36525.0 + 2451545.0
        return unwindAngle(
            280.46061837 + 360.98564736629 * (jd - 2451545.0) +
                0.000387933 * t.pow(2) - t.pow(3) / 38710000.0
        )
    }

    private fun nutationInLongitude(t: Double, l0: Double, lp: Double, omega: Double): Double =
        (-17.2 / 3600.0) * sin(radians(omega)) -
            (1.32 / 3600.0) * sin(2 * radians(l0)) -
            (0.23 / 3600.0) * sin(2 * radians(lp)) +
            (0.21 / 3600.0) * sin(2 * radians(omega))

    private fun nutationInObliquity(t: Double, l0: Double, lp: Double, omega: Double): Double =
        (9.2 / 3600.0) * cos(radians(omega)) +
            (0.57 / 3600.0) * cos(2 * radians(l0)) +
            (0.10 / 3600.0) * cos(2 * radians(lp)) -
            (0.09 / 3600.0) * cos(2 * radians(omega))

    private fun altitudeOfCelestialBody(phi: Double, delta: Double, h: Double): Double =
        degrees(asin(
            sin(radians(phi)) * sin(radians(delta)) +
                cos(radians(phi)) * cos(radians(delta)) * cos(radians(h))
        ))

    private fun approximateTransit(l: Double, theta0: Double, alpha2: Double): Double =
        normalizeWithBound((alpha2 + l * -1 - theta0) / 360.0, 1.0)

    private fun correctedTransit(
        m0: Double, l: Double, theta0: Double,
        alpha2: Double, alpha1: Double, alpha3: Double,
    ): Double {
        val lw = l * -1
        val theta = unwindAngle(theta0 + 360.985647 * m0)
        val alpha = unwindAngle(interpolateAngles(alpha2, alpha1, alpha3, m0))
        val h = closestAngle(theta - lw - alpha)
        val deltaM = h / -360.0
        return (m0 + deltaM) * 24
    }

    private fun correctedHourAngle(
        m0: Double, h0: Double, coordinates: Coordinates, afterTransit: Boolean,
        theta0: Double, alpha2: Double, alpha1: Double, alpha3: Double,
        delta2: Double, delta1: Double, delta3: Double,
    ): Double {
        val lw = coordinates.longitude * -1
        val term1 = sin(radians(h0)) -
            sin(radians(coordinates.latitude)) * sin(radians(delta2))
        val term2 = cos(radians(coordinates.latitude)) * cos(radians(delta2))
        val h0deg = degrees(acos(term1 / term2))
        val m = if (afterTransit) m0 + h0deg / 360.0 else m0 - h0deg / 360.0
        val theta = unwindAngle(theta0 + 360.985647 * m)
        val alpha = unwindAngle(interpolateAngles(alpha2, alpha1, alpha3, m))
        val delta = interpolate(delta2, delta1, delta3, m)
        val h = theta - lw - alpha
        val alt = altitudeOfCelestialBody(coordinates.latitude, delta, h)
        val term3 = alt - h0
        val term4 = 360.0 * cos(radians(delta)) * cos(radians(coordinates.latitude)) * sin(radians(h))
        val deltaM = term3 / term4
        return (m + deltaM) * 24
    }

    private fun interpolate(y2: Double, y1: Double, y3: Double, n: Double): Double {
        val a = y2 - y1
        val b = y3 - y2
        val c = b - a
        return y2 + (n / 2.0) * (a + b + n * c)
    }

    private fun interpolateAngles(y2: Double, y1: Double, y3: Double, n: Double): Double {
        val a = unwindAngle(y2 - y1)
        val b = unwindAngle(y3 - y2)
        val c = b - a
        return y2 + (n / 2.0) * (a + b + n * c)
    }

    private fun normalizeWithBound(value: Double, max: Double): Double =
        value - max * floor(value / max)

    private fun unwindAngle(value: Double): Double = normalizeWithBound(value, 360.0)

    private fun closestAngle(angle: Double): Double {
        if (angle >= -180 && angle <= 180) return angle
        return angle - 360.0 * (angle / 360.0).roundToInt()
    }

    // ── Angle conversion ──
    private fun radians(degrees: Double): Double = degrees * Math.PI / 180.0
    private fun degrees(radians: Double): Double = radians * 180.0 / Math.PI

    // ── Time components (hours float → h/m/s) ──
    private data class TimeComponents(val hours: Int, val minutes: Int, val seconds: Int) {
        companion object {
            fun fromDouble(value: Double): TimeComponents {
                val h = floor(value).toInt()
                val m = floor((value - h) * 60.0).toInt()
                val s = floor((value - (h + m / 60.0)) * 3600.0).toInt()
                return TimeComponents(h, m, s)
            }
        }

        fun dateComponents(date: Calendar): Calendar {
            val out = date.clone() as Calendar
            out.set(Calendar.HOUR_OF_DAY, hours)
            out.set(Calendar.MINUTE, minutes)
            out.set(Calendar.SECOND, seconds)
            out.set(Calendar.MILLISECOND, 0)
            return out
        }
    }

    // ── Moon-sighting committee seasonal adjustments (lat ≥ 55) ──
    private fun seasonAdjustedMorningTwilight(
        latitude: Double, day: Int, year: Int, sunrise: Calendar,
    ): Calendar {
        val a = 75.0 + (28.65 / 55.0) * abs(latitude)
        val b = 75.0 + (19.44 / 55.0) * abs(latitude)
        val c = 75.0 + (32.74 / 55.0) * abs(latitude)
        val d = 75.0 + (48.10 / 55.0) * abs(latitude)
        val dyy = daysSinceSolstice(day, year, latitude)
        val adjustment = when {
            dyy < 91 -> a + (b - a) / 91.0 * dyy
            dyy < 137 -> b + (c - b) / 46.0 * (dyy - 91)
            dyy < 183 -> c + (d - c) / 46.0 * (dyy - 137)
            dyy < 229 -> d + (c - d) / 46.0 * (dyy - 183)
            dyy < 275 -> c + (b - c) / 46.0 * (dyy - 229)
            else -> b + (a - b) / 91.0 * (dyy - 275)
        }
        return addSeconds(sunrise, -(adjustment * 60.0).roundToInt().toLong())
    }

    private fun seasonAdjustedEveningTwilight(
        latitude: Double, day: Int, year: Int, sunset: Calendar,
    ): Calendar {
        val a = 75.0 + (25.60 / 55.0) * abs(latitude)
        val b = 75.0 + (2.050 / 55.0) * abs(latitude)
        val c = 75.0 - (9.210 / 55.0) * abs(latitude)
        val d = 75.0 + (6.140 / 55.0) * abs(latitude)
        val dyy = daysSinceSolstice(day, year, latitude)
        val adjustment = when {
            dyy < 91 -> a + (b - a) / 91.0 * dyy
            dyy < 137 -> b + (c - b) / 46.0 * (dyy - 91)
            dyy < 183 -> c + (d - c) / 46.0 * (dyy - 137)
            dyy < 229 -> d + (c - d) / 46.0 * (dyy - 183)
            dyy < 275 -> c + (b - c) / 46.0 * (dyy - 229)
            else -> b + (a - b) / 91.0 * (dyy - 275)
        }
        return addSeconds(sunset, (adjustment * 60.0).roundToInt().toLong())
    }

    private fun daysSinceSolstice(dayOfYear: Int, year: Int, latitude: Double): Int {
        val northernOffset = 10
        val isLeap = year % 4 == 0 && !(year % 100 == 0 && year % 400 != 0)
        val southernOffset = if (isLeap) 173 else 172
        val daysInYear = if (isLeap) 366 else 365
        return if (latitude >= 0) {
            var d = dayOfYear + northernOffset
            if (d >= daysInYear) d -= daysInYear
            d
        } else {
            var d = dayOfYear - southernOffset
            if (d < 0) d += daysInYear
            d
        }
    }
}
