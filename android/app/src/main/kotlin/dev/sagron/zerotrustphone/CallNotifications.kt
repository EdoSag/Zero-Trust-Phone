package dev.sagron.zerotrustphone

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.telecom.Call
import android.app.KeyguardManager
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person

/** The incoming-call card (full screen when locked) and the ongoing-call one. */
object CallNotifications {
    private const val INCOMING = "incoming_calls"
    private const val ONGOING = "ongoing_calls"
    private const val ID = 4242

    fun createChannels(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(INCOMING, "Incoming calls", NotificationManager.IMPORTANCE_HIGH).apply {
                // Telecom already plays the ringtone and vibrates.
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(ONGOING, "Ongoing calls", NotificationManager.IMPORTANCE_DEFAULT).apply {
                setSound(null, null)
                enableVibration(false)
            }
        )
    }

    /**
     * Whether Android will show the incoming-call card, and open the call
     * screen over the lock screen from it. Both need the notification
     * permission; Android 14+ also needs the full-screen permission, which
     * the user can turn off.
     */
    fun alertsReady(context: Context): Boolean {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return false
        val nm = context.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(INCOMING)?.importance == NotificationManager.IMPORTANCE_NONE) return false
        return Build.VERSION.SDK_INT < 34 || nm.canUseFullScreenIntent()
    }

    /** Locked, or the screen is off: the call screen should open itself. */
    fun deviceIdle(context: Context): Boolean {
        val keyguard = context.getSystemService(KeyguardManager::class.java)
        val power = context.getSystemService(PowerManager::class.java)
        return keyguard?.isKeyguardLocked == true || power?.isInteractive == false
    }

    fun cancel(context: Context) {
        context.getSystemService(NotificationManager::class.java).cancel(ID)
    }

    fun update(context: Context) {
        val call = CallManager.primary()
        if (call == null) {
            cancel(context)
            return
        }
        val number = call.details.handle?.schemeSpecificPart ?: ""
        val title = CallManager.nameFor(number) ?: number.ifEmpty { "Private number" }
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, CallActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val ringing = call.stateCompat() == Call.STATE_RINGING
        val builder = NotificationCompat.Builder(context, if (ringing) INCOMING else ONGOING)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(title)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setOngoing(true)
            .setOnlyAlertOnce(!ringing)
            .setContentIntent(open)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        if (ringing) {
            val answer = PendingIntent.getActivity(
                context, 1, Intent(context, CallActivity::class.java)
                    .setAction(CallActivity.ACTION_ANSWER)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val caller = Person.Builder().setName(title).setImportant(true).build()
            // The system's incoming-call card: big Answer and Decline buttons,
            // pinned on top and on the lock screen.
            builder.setContentText("Incoming call")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setFullScreenIntent(open, true)
                .setStyle(
                    NotificationCompat.CallStyle.forIncomingCall(
                        caller,
                        CallActionReceiver.intent(context, CallActionReceiver.DECLINE),
                        answer,
                    )
                )
        } else {
            val connectedAt = call.details.connectTimeMillis
            builder.setSmallIcon(android.R.drawable.sym_action_call)
                .setContentText(
                    when (call.stateCompat()) {
                        Call.STATE_ACTIVE -> "Ongoing call"
                        Call.STATE_HOLDING -> "On hold"
                        else -> "Calling…"
                    }
                )
                .addAction(0, "Hang up", CallActionReceiver.intent(context, CallActionReceiver.HANG_UP))
            if (connectedAt > 0) builder.setWhen(connectedAt).setUsesChronometer(true)
        }
        context.getSystemService(NotificationManager::class.java).notify(ID, builder.build())
    }
}
