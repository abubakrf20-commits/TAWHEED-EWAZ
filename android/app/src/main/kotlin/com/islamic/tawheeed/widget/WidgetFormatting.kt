package com.islamic.tawheeed.widget

import java.util.Locale

/**
 * The formatters the widget uses to **bake** the clock and the countdown into
 * strings.
 *
 * They exist as one file for one reason: the digits must always be 0-9. Every
 * `String.format` here pins [Locale.US], because the alternative — letting the
 * platform format through `Locale.getDefault()` — is how the card ended up
 * painting Arabic-Indic hours on an `ar`/`fa` device while the rest of the app
 * was Latin.
 *
 * Since the 2026-11 brief the two values that must never lag are NOT baked any
 * more — they are live leaves (a TextClock and a count-down Chronometer that
 * tick inside the LAUNCHER; [PrayerRemoteLeaves] builds the clock's leaf),
 * whose digits come from the leaf's own `android:textLocale` (Latin by
 * default, a `_fa` layout variant when the widget's fa-digit switch is on).
 * These formatters still serve the parts a render bakes: the date strip, the
 * pill caption and the countdown patterns.
 */

/** The pattern used when a caller has no caption of its own. */
internal const val DEFAULT_COUNTDOWN_FORMAT = "%s"

/** `h:mm` in 12-hour form or `HH:mm` in 24-hour form, always ASCII digits. */
internal fun formatClockTime(hour: Int, minute: Int, use12Hour: Boolean): String =
    if (use12Hour) {
        val hour12 = if (hour % 12 == 0) 12 else hour % 12
        String.format(Locale.US, "%d:%02d", hour12, minute)
    } else {
        String.format(Locale.US, "%02d:%02d", hour, minute)
    }

/** `m:ss`, or `h:mm:ss` once the span reaches an hour; always ASCII digits. */
internal fun formatElapsed(totalSeconds: Long): String {
    val hours = totalSeconds / 3_600L
    val minutes = (totalSeconds / 60L) % 60L
    val seconds = totalSeconds % 60L
    return if (hours > 0L) {
        String.format(Locale.US, "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        String.format(Locale.US, "%02d:%02d", minutes, seconds)
    }
}

/** The countdown line for [totalSeconds] through a [PrayerWidgetModel.countdownFormat] pattern. */
internal fun formatCountdown(totalSeconds: Long, format: String): String {
    val elapsed = formatElapsed(totalSeconds)
    return try {
        String.format(Locale.US, format, elapsed)
    } catch (error: IllegalArgumentException) {
        // A malformed pattern must never crash the launcher that inflated this view.
        elapsed
    }
}

/**
 * Remaining time at minute granularity. Ceil to the next minute so the shown
 * value is never smaller than the truth.
 *
 * Moved here from the retired Glance composable (2026-11-04): the card is a
 * hand-built RemoteViews now, and these two were its last residents.
 */
internal fun minuteElapsed(remainingMillis: Long): String {
    val minutes = (remainingMillis + 59_999L) / 60_000L
    val hours = minutes / 60
    val mins = minutes % 60
    return if (hours > 0L) {
        String.format(Locale.US, "%d:%02d", hours, mins)
    } else {
        String.format(Locale.US, "%d:00", mins)
    }
}

/** [minuteElapsed] against a caller-chosen value — same malformed-pattern
 *  guard, so a bad pattern can never crash the launcher that renders it. */
internal fun formatCountdownMinutes(remainingMillis: Long, format: String): String {
    val shown = minuteElapsed(remainingMillis)
    return try {
        String.format(Locale.US, format, shown)
    } catch (error: IllegalArgumentException) {
        shown
    }
}
