package com.example.cam_bien_te_nga

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.net.Uri

/** Local sound only. Never enables monitoring, calls or sends SMS. */
class AlertSound(private val context: Context) {
    companion object {
        private var playing: AlertSound? = null
        fun selectedUri(context: Context): Uri = SafetyStore.prefs(context).getString("alertSoundUri", null)
            ?.let { Uri.parse(it) } ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        fun settings(context: Context): Map<String, Any> {
            val custom = SafetyStore.prefs(context).getString("alertSoundUri", null)
            val title = if (custom == null) "Âm báo thức mặc định" else try {
                RingtoneManager.getRingtone(context, Uri.parse(custom))?.getTitle(context) ?: "Âm đã chọn"
            } catch (_: Exception) { "Âm đã chọn · có thể không còn khả dụng" }
            return mapOf("title" to title, "custom" to (custom != null))
        }
    }
    private var ringtone: Ringtone? = null
    private var tone: ToneGenerator? = null
    private var vibrating = false

    fun start() {
        playing?.stop()
        stop()
        playing = this
        try {
            val candidates = listOf(selectedUri(context), RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM), RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)).distinct()
            for (uri in candidates) {
                try {
                    ringtone = RingtoneManager.getRingtone(context, uri)?.apply {
                audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
                if (Build.VERSION.SDK_INT >= 28) { isLooping = true; volume = 1f }
                play()
                    }
                    if (ringtone != null) break
                } catch (_: Exception) { ringtone = null }
            }
            if (ringtone == null) {
                tone = ToneGenerator(AudioManager.STREAM_ALARM, 100).apply {
                    startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD)
                }
            }
        } catch (_: Exception) { /* Audio failure must not interrupt the countdown. */ }
        // Vibration remains independent of audio failures and device alarm volume.
        try {
            @Suppress("DEPRECATION") val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            val pattern = longArrayOf(0, 300, 200, 300, 800)
            if (Build.VERSION.SDK_INT >= 26) vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0))
            else { @Suppress("DEPRECATION") vibrator.vibrate(pattern, 0) }
            vibrating = true
        } catch (_: Exception) { }
    }

    fun stop() {
        try { ringtone?.stop() } catch (_: Exception) { }
        ringtone = null
        try { tone?.release() } catch (_: Exception) { }
        tone = null
        if (vibrating) try {
            @Suppress("DEPRECATION") (context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator).cancel()
        } catch (_: Exception) { }
        vibrating = false
        if (playing === this) playing = null
    }
}
