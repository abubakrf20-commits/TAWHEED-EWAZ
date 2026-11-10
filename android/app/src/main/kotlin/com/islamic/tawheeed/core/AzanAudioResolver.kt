package com.islamic.tawheeed.core

import java.io.File
import java.io.IOException

/**
 * Resolves which audio file an adhan (or a reminder with a custom sound)
 * should play.
 *
 * A custom path travels through a `PendingIntent` extra and persisted
 * schedules, so it is app-internal data that can still be wrong: a restored
 * backup, a stale row, or a hand-edited preferences blob. It is never a
 * licence to open an arbitrary URI.
 *
 * The only accepted location is the directory the file picker copies into
 * (`filesDir/custom_azans` for the adhan, `filesDir/custom_sounds` for
 * reminders), resolved through `canonicalFile` so `..` segments and symlinks
 * cannot escape it. Anything else returns null and the caller falls back to
 * its default sound.
 */
object AzanAudioResolver {

    /** Directory `MainActivity.handleAzanCopyPick` writes the picked file to. */
    private const val CUSTOM_DIR = "custom_azans"

    /** Directory `MainActivity.handleReminderCopyPick` writes into. */
    private const val REMINDER_SOUNDS_DIR = "custom_sounds"

    /**
     * The custom azan file for [customPath], or null when the path is absent,
     * unreadable, empty, or points outside the custom azan directory.
     */
    fun customAzanFileOrNull(filesDir: File, customPath: String?): File? =
        customFileOrNull(filesDir, CUSTOM_DIR, customPath)

    /**
     * The custom reminder sound for [customPath] (the `custom:` payload the
     * reminder editor stores), or null on the same conditions as above.
     */
    fun customReminderFileOrNull(filesDir: File, customPath: String?): File? =
        customFileOrNull(filesDir, REMINDER_SOUNDS_DIR, customPath)

    /**
     * A real file that is a direct child of `filesDir/[dirName]`, or null.
     * Comparing canonical parents is what makes `..` and symlink escapes
     * fail; the direct-child rule keeps one reminder's file from ever
     * addressing another entry.
     */
    fun customFileOrNull(filesDir: File, dirName: String, customPath: String?): File? {
        if (customPath.isNullOrBlank()) return null

        val canonicalDir = try {
            File(filesDir, dirName).canonicalFile
        } catch (e: IOException) {
            return null
        }

        val candidate = try {
            File(customPath).canonicalFile
        } catch (e: IOException) {
            return null
        } catch (e: SecurityException) {
            return null
        }

        // Direct child of the directory, and nothing deeper.
        if (candidate.parentFile != canonicalDir) return null
        if (!candidate.isFile) return null
        if (candidate.length() <= 0L) return null
        return candidate
    }

    /** The bundled `res/raw` azan URI for [sound], ignoring anything unexpected. */
    fun bundledAzanUri(packageName: String, sound: String?): String {
        val resName = when (sound) {
            "takbir" -> "azan_takbir"
            "takbirShort" -> "azan_takbir_short"
            else -> "azan_kamel"
        }
        return "android.resource://$packageName/raw/$resName"
    }

    /** Clamps a persisted/intent volume into the range MediaPlayer accepts. */
    fun safeVolume(volume: Float): Float =
        if (volume.isNaN()) 1.0f else volume.coerceIn(0f, 1f)
}
