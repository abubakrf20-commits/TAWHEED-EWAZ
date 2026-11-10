package com.islamic.tawheeed.core

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.util.Log

/**
 * The phone's own notification tones, alarm tones and ringtones, plus a single
 * preview player so the app never stacks two previews on top of each other.
 *
 * Android exposes these through [RingtoneManager]'s media cursor; the titles are
 * already localized by the system, so the picker shows exactly what the user
 * sees in Settings → Sound. The preview is played here (MediaPlayer) rather than
 * in Dart because a `content://media/...` URI is not a file path audioplayers can
 * open reliably.
 */
object SystemSoundCatalog {
    private const val TAG = "SystemSoundCatalog"

    private var previewPlayer: MediaPlayer? = null

    /** Ids used by the Dart picker; the order is the picker's order. */
    const val TYPE_NOTIFICATION = "notification"
    const val TYPE_ALARM = "alarm"
    const val TYPE_RINGTONE = "ringtone"

    /**
     * Every system tone, grouped by kind. Each entry is
     * `{title, uri}`; duplicates are collapsed by URI because several OEMs
     * expose the same tone under multiple provider rows.
     */
    fun list(context: Context): Map<String, List<Map<String, String>>> = mapOf(
        TYPE_NOTIFICATION to listOfType(context, RingtoneManager.TYPE_NOTIFICATION),
        TYPE_ALARM to listOfType(context, RingtoneManager.TYPE_ALARM),
        TYPE_RINGTONE to listOfType(context, RingtoneManager.TYPE_RINGTONE),
    )

    private fun listOfType(
        context: Context,
        type: Int,
    ): List<Map<String, String>> {
        val out = LinkedHashMap<String, Map<String, String>>()
        try {
            val manager = RingtoneManager(context)
            manager.setType(type)
            val cursor = manager.cursor ?: return emptyList()
            cursor.use { c ->
                val titleColumn = RingtoneManager.TITLE_COLUMN_INDEX
                while (c.moveToNext()) {
                    val uri = manager.getRingtoneUri(c.position)?.toString() ?: continue
                    if (uri.isBlank()) continue
                    if (out.containsKey(uri)) continue
                    val rawTitle = c.getString(titleColumn)
                    val title = rawTitle?.takeIf { it.isNotBlank() } ?: uri.substringAfterLast('/')
                    out[uri] = mapOf("title" to title, "uri" to uri)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "list system sounds (type $type) failed: ${e.message}")
        }
        return out.values.toList()
    }

    /**
     * Plays [uri] as a preview. [alarm] selects the alarm stream so a tone is
     * auditioned at the same loudness and with the same DND behaviour it will
     * have when the reminder actually rings.
     */
    fun preview(context: Context, uri: Uri, alarm: Boolean): Boolean {
        stop()
        return try {
            previewPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(
                            if (alarm) AudioAttributes.USAGE_ALARM
                            else AudioAttributes.USAGE_NOTIFICATION
                        )
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(context, uri)
                setOnPreparedListener { it.start() }
                setOnCompletionListener { stop() }
                setOnErrorListener { _, what, extra ->
                    Log.w(TAG, "preview error: $what, $extra")
                    stop()
                    true
                }
                prepareAsync()
            }
            true
        } catch (e: Exception) {
            Log.w(TAG, "preview failed: ${e.message}")
            stop()
            false
        }
    }

    /** Stops and releases the preview player; safe to call at any time. */
    fun stop() {
        val player = previewPlayer
        previewPlayer = null
        try {
            player?.stop()
        } catch (_: Throwable) {
        }
        try {
            player?.release()
        } catch (_: Throwable) {
        }
    }

    fun isPreviewing(): Boolean = try {
        previewPlayer?.isPlaying == true
    } catch (_: Throwable) {
        false
    }
}
