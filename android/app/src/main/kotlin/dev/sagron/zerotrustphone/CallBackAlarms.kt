package dev.sagron.zerotrustphone

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import org.json.JSONObject

/**
 * Call back reminders (P25): "call Dana back in 1 hour". ZT Phone reminds
 * on its own, even if ZT Tasks isn't installed or hasn't synced yet; the
 * matching task in ZT Tasks is for the to-do list.
 *
 * The number and time are kept on this phone encrypted with a Keystore key
 * ([LocalSealer]), so reminders survive a restart. Names aren't stored:
 * the notification looks the caller up when it shows.
 */
object CallBackAlarms {
    private const val PREFS = "zt_call_backs"
    private const val CHANNEL = "call_backs"
    const val ACTION_FIRE = "dev.sagron.zerotrustphone.CALL_BACK_DUE"
    const val EXTRA_ID = "id"

    fun schedule(context: Context, id: String, number: String, at: Long) {
        val sealed = LocalSealer.seal(JSONObject().put("number", number).put("at", at).toString())
        prefs(context).edit().putString(id, sealed).apply()
        setAlarm(context, id, at)
    }

    fun cancel(context: Context, id: String) {
        prefs(context).edit().remove(id).apply()
        alarms(context).cancel(alarmIntent(context, id))
        context.getSystemService(NotificationManager::class.java).cancel(notificationId(id))
    }

    /** Signing out: no reminders for the next account. */
    fun cancelAll(context: Context) {
        for (id in prefs(context).all.keys.toList()) cancel(context, id)
    }

    /**
     * After a restart Android has forgotten every alarm; after "Alarms &
     * reminders" is taken away, the exact ones. Reminders not yet shown
     * are set again, and ones already due ring at once.
     */
    fun rescheduleAll(context: Context) {
        for ((id, value) in prefs(context).all) {
            val json = (value as? String)?.let { LocalSealer.open(it) } ?: continue
            setAlarm(context, id, JSONObject(json).optLong("at"))
        }
    }

    fun fire(context: Context, id: String) {
        val sealed = prefs(context).getString(id, null) ?: return
        prefs(context).edit().remove(id).apply()
        val number = LocalSealer.open(sealed)?.let { JSONObject(it).optString("number") } ?: return
        if (number.isBlank()) return
        createChannel(context)
        val who = CallManager.nameFor(context, number) ?: number
        val title = NativeStrings.format(context, "nativeCallBackReminder", R.string.call_back_reminder, who)
        val nid = notificationId(id)
        val call = PendingIntent.getBroadcast(
            context, nid, Intent(context, CallBackReceiver::class.java)
                .setAction(MissedCallReceiver.ACTION_CALL_BACK)
                .setData(reminderUri(id))
                .putExtra(MissedCallReceiver.EXTRA_NUMBER, number)
                .putExtra(MissedCallReceiver.EXTRA_NOTIFICATION_ID, nid),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val open = PendingIntent.getActivity(
            context, nid, Intent(context, MainActivity::class.java)
                .setAction(MainActivity.ACTION_SHOW_RECENTS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // On the lock screen: only "Call back reminder", no name or number.
        val public = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.stat_sys_phone_call)
            .setContentTitle(NativeStrings.get(context, "nativeCallBackChannel", R.string.call_back_channel))
            .build()
        val n = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.stat_sys_phone_call)
            .setContentTitle(title)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(public)
            .setAutoCancel(true)
            .setContentIntent(open)
            .addAction(0, NativeStrings.get(context, "nativeCallBack", R.string.call_back), call)
            .build()
        try {
            context.getSystemService(NotificationManager::class.java).notify(nid, n)
        } catch (_: SecurityException) {
            // Notifications are off for ZT Phone.
        }
    }

    /**
     * Whether reminders can ring on the minute. Android 12+ needs the
     * "Alarms & reminders" special access for that, off by default on
     * Android 14+; without it they're inexact (a few minutes late at most).
     */
    fun canBeExact(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms(context).canScheduleExactAlarms()

    /** Whether ZT Phone already asked for "Alarms & reminders" (asks once). */
    fun askedForExact(context: Context): Boolean =
        meta(context).getBoolean(KEY_ASKED_EXACT, false)

    fun markAskedForExact(context: Context) {
        meta(context).edit().putBoolean(KEY_ASKED_EXACT, true).apply()
    }

    /** Android's "Alarms & reminders" page for ZT Phone. False if none. */
    fun openExactSettings(context: Context): Boolean {
        markAskedForExact(context)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        return try {
            context.startActivity(
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${context.packageName}"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun setAlarm(context: Context, id: String, at: Long) {
        val whenMs = maxOf(at, System.currentTimeMillis() + 1000)
        val intent = alarmIntent(context, id)
        if (canBeExact(context)) {
            try {
                alarms(context).setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMs, intent)
                return
            } catch (_: SecurityException) {
                // Access taken away just now: fall back below.
            }
        }
        // Inexact but allowed while the phone dozes: on time to a few
        // minutes, without the "Alarms & reminders" special access.
        alarms(context).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMs, intent)
    }

    private fun alarmIntent(context: Context, id: String): PendingIntent = PendingIntent.getBroadcast(
        context, notificationId(id),
        Intent(context, CallBackAlarmReceiver::class.java)
            .setAction(ACTION_FIRE)
            .setData(reminderUri(id))
            .putExtra(EXTRA_ID, id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    /**
     * Makes each reminder's PendingIntents its own: the request code is a
     * 16-bit hash, so two ids can share it, and Android would then treat
     * their alarms (and Call back buttons) as one.
     */
    private fun reminderUri(id: String): Uri =
        Uri.Builder().scheme("ztphone").authority("call-back").appendPath(id).build()

    private fun notificationId(id: String) = 5000 + (id.hashCode() and 0xffff)

    private fun alarms(context: Context) = context.getSystemService(AlarmManager::class.java)

    private const val KEY_ASKED_EXACT = "asked_exact"

    /** Kept apart from [prefs], whose keys are all reminder ids. */
    private fun meta(context: Context) =
        context.applicationContext.getSharedPreferences("zt_call_back_meta", Context.MODE_PRIVATE)

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun createChannel(context: Context) {
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(
                CHANNEL,
                NativeStrings.get(context, "nativeCallBackChannel", R.string.call_back_channel),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { lockscreenVisibility = Notification.VISIBILITY_PRIVATE }
        )
    }
}

/** The reminder is due, or the phone restarted. Not exported for FIRE. */
class CallBackAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            CallBackAlarms.ACTION_FIRE ->
                intent.getStringExtra(CallBackAlarms.EXTRA_ID)?.let { CallBackAlarms.fire(context, it) }
            // After a restart, an update, or "Alarms & reminders" being
            // allowed (so waiting reminders become exact).
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED ->
                CallBackAlarms.rescheduleAll(context)
        }
    }
}
