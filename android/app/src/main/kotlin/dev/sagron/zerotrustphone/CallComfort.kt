package dev.sagron.zerotrustphone

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.telecom.TelecomManager

/**
 * Keypad tones (P17), flip to silence and the pocket-dial guard (P29).
 * The two switches are copied here by the app ([save]) so flip to silence
 * works while ZT Phone is closed and the phone locked.
 */
object CallComfort {
    private const val PREFS = "zt_call_comfort"
    private const val FLIP = "flip_to_silence"
    private const val POCKET = "pocket_guard"

    fun save(context: Context, flipToSilence: Boolean, pocketGuard: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(FLIP, flipToSilence)
            .putBoolean(POCKET, pocketGuard)
            .apply()
    }

    private fun flipOn(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(FLIP, false)

    // ---- Keypad tones (P17) ----

    private var tones: ToneGenerator? = null

    /** A short DTMF tone for [key], like the built-in dialer's. */
    fun playKeyTone(context: Context, key: String) {
        val audio = context.getSystemService(AudioManager::class.java)
        if (audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) return
        // Android's own "Dial pad tones" switch.
        if (Settings.System.getInt(context.contentResolver, Settings.System.DTMF_TONE_WHEN_DIALING, 1) == 0) return
        val tone = when (key) {
            "0" -> ToneGenerator.TONE_DTMF_0
            "1" -> ToneGenerator.TONE_DTMF_1
            "2" -> ToneGenerator.TONE_DTMF_2
            "3" -> ToneGenerator.TONE_DTMF_3
            "4" -> ToneGenerator.TONE_DTMF_4
            "5" -> ToneGenerator.TONE_DTMF_5
            "6" -> ToneGenerator.TONE_DTMF_6
            "7" -> ToneGenerator.TONE_DTMF_7
            "8" -> ToneGenerator.TONE_DTMF_8
            "9" -> ToneGenerator.TONE_DTMF_9
            "*" -> ToneGenerator.TONE_DTMF_S
            "#" -> ToneGenerator.TONE_DTMF_P
            else -> return
        }
        val generator = tones ?: try {
            ToneGenerator(AudioManager.STREAM_DTMF, 80).also { tones = it }
        } catch (_: RuntimeException) {
            return
        }
        generator.startTone(tone, 150)
    }

    // ---- Pocket-dial guard (P29) ----

    /**
     * Calls [done] with whether something covers the proximity sensor now.
     * Waits for the sensor's first reading (most report one at once), at
     * most 400 ms; no sensor or no reading counts as not covered.
     */
    fun screenCovered(context: Context, done: (Boolean) -> Unit) {
        val sensors = context.getSystemService(SensorManager::class.java)
        val proximity = sensors?.getDefaultSensor(Sensor.TYPE_PROXIMITY)
        if (proximity == null) {
            done(false)
            return
        }
        val main = Handler(Looper.getMainLooper())
        var answered = false
        lateinit var listener: SensorEventListener
        val finish = { covered: Boolean ->
            if (!answered) {
                answered = true
                sensors.unregisterListener(listener)
                done(covered)
            }
        }
        listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                val near = event.values[0] < proximity.maximumRange.coerceAtMost(5f)
                main.post { finish(near) }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        sensors.registerListener(listener, proximity, SensorManager.SENSOR_DELAY_FASTEST, main)
        main.postDelayed({ finish(false) }, 400)
    }

    // ---- Flip to silence (P29) ----

    private var flipListener: SensorEventListener? = null

    /**
     * Starts watching the phone's position while a call rings. Turning it
     * face down (screen to the table for about half a second) silences
     * the ringer; the call keeps ringing for the caller and can still be
     * answered. A phone that was already face down when the call came in
     * must be lifted first, so lying on a table never silences by itself.
     */
    fun watchRinging(context: Context) {
        if (!flipOn(context) || flipListener != null) return
        val app = context.applicationContext
        val sensors = app.getSystemService(SensorManager::class.java) ?: return
        val gravity = sensors.getDefaultSensor(Sensor.TYPE_GRAVITY)
            ?: sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            ?: return
        val listener = object : SensorEventListener {
            var seenFaceUp = false
            var downSince = 0L

            override fun onSensorChanged(event: SensorEvent) {
                if (CallManager.ringing() == null) {
                    stopWatching(app)
                    return
                }
                val z = event.values[2]
                val now = SystemClock.elapsedRealtime()
                if (z > -2f) {
                    seenFaceUp = true
                    downSince = 0L
                } else if (z < -8.5f && seenFaceUp) {
                    if (downSince == 0L) downSince = now
                    if (now - downSince >= 500L) {
                        silence(app)
                        stopWatching(app)
                    }
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        flipListener = listener
        sensors.registerListener(listener, gravity, SensorManager.SENSOR_DELAY_UI, Handler(Looper.getMainLooper()))
    }

    fun stopWatching(context: Context) {
        val listener = flipListener ?: return
        flipListener = null
        context.applicationContext.getSystemService(SensorManager::class.java)?.unregisterListener(listener)
    }

    private fun silence(context: Context) {
        // Android's ringer, and a contact's own ringtone (CallRinger).
        CallRinger.stop()
        try {
            context.getSystemService(TelecomManager::class.java).silenceRinger()
        } catch (_: SecurityException) {
        }
        CallNotifications.update(context)
    }
}
