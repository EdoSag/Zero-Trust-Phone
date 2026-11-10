package dev.sagron.zerotrustphone

import android.content.Context
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings

/**
 * Plays a contact's own ringtone. Only for calls [ZtCallScreeningService]
 * silenced for that reason, so every other call rings exactly as Android
 * would ring it.
 */
object CallRinger {
    private var expected: String? = null
    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null

    fun expectCustom(number: String) {
        expected = PhoneNumbers.lookupKey(number)
    }

    fun start(context: Context, number: String) {
        val key = PhoneNumbers.lookupKey(number)
        if (key.isEmpty() || key != expected) return
        expected = null
        val uri = ScreeningStore(context).ringtoneFor(number) ?: return
        stop()
        val tone = RingtoneManager.getRingtone(context, Uri.parse(uri))
            ?: RingtoneManager.getRingtone(context, Settings.System.DEFAULT_RINGTONE_URI)
            ?: return
        tone.audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        tone.isLooping = true
        tone.play()
        ringtone = tone
        val vibrateWhenRinging = Settings.System.getInt(
            context.contentResolver, "vibrate_when_ringing", 0
        ) == 1
        if (vibrateWhenRinging) {
            val v = context.getSystemService(Vibrator::class.java)
            v?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 1000, 1000), 0))
            vibrator = v
        }
    }

    fun stop() {
        ringtone?.stop()
        ringtone = null
        vibrator?.cancel()
        vibrator = null
    }
}
