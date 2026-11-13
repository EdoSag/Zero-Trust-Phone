package dev.sagron.zerotrustphone

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
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

    /** After a restart Android has forgotten every alarm. */
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

    private fun setAlarm(context: Context, id: String, at: Long) {
        // Inexact but allowed while the phone dozes: on time to a few
        // minutes, without the "Alarms & reminders" special permission.
        alarms(context).setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            maxOf(at, System.currentTimeMillis() + 1000),
            alarmIntent(context, id),
        )
    }

    private fun alarmIntent(context: Context, id: String): PendingIntent = PendingIntent.getBroadcast(
        context, notificationId(id),
        Intent(context, CallBackAlarmReceiver::class.java).setAction(ACTION_FIRE).putExtra(EXTRA_ID, id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    private fun notificationId(id: String) = 5000 + (id.hashCode() and 0xffff)

    private fun alarms(context: Context) = context.getSystemService(AlarmManager::class.java)

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
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
                CallBackAlarms.rescheduleAll(context)
        }
    }
}
