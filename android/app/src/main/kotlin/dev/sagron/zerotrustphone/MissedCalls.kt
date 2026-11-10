package dev.sagron.zerotrustphone

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.ContactsContract
import android.telecom.TelecomManager
import android.telephony.TelephonyManager
import androidx.core.app.NotificationCompat

/**
 * ZT Phone's own missed-call and voicemail notifications. As the default
 * Phone app, Telecom asks this receiver to show them instead of Android's
 * generic ones.
 */
class MissedCallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            TelecomManager.ACTION_SHOW_MISSED_CALLS_NOTIFICATION -> showMissed(context, intent)
            TelephonyManager.ACTION_SHOW_VOICEMAIL_NOTIFICATION -> showVoicemail(context, intent)
        }
    }

    private fun showMissed(context: Context, intent: Intent) {
        val count = intent.getIntExtra(TelecomManager.EXTRA_NOTIFICATION_COUNT, 0)
        if (count <= 0) {
            cancel(context, MISSED_ID)
            return
        }
        createChannels(context)
        val number = intent.getStringExtra(TelecomManager.EXTRA_NOTIFICATION_PHONE_NUMBER)
        val name = number?.let { CallManager.nameFor(context, it) }
        val who = name ?: number?.takeIf { it.isNotBlank() } ?: "Private number"
        val title = if (count == 1) "Missed call" else "$count missed calls"
        val builder = NotificationCompat.Builder(context, MISSED_CHANNEL)
            .setSmallIcon(android.R.drawable.stat_notify_missed_call)
            .setContentTitle(title)
            .setContentText(if (count == 1) who else "Latest from $who")
            .setCategory(NotificationCompat.CATEGORY_MISSED_CALL)
            .setAutoCancel(true)
            .setContentIntent(openRecents(context))
        @Suppress("DEPRECATION")
        val clear = intent.getParcelableExtra<PendingIntent>(TelecomManager.EXTRA_CLEAR_MISSED_CALLS_INTENT)
        if (clear != null) builder.setDeleteIntent(clear)
        if (!number.isNullOrBlank()) {
            builder.addAction(0, "Call back", PendingIntent.getBroadcast(
                context, 10, Intent(context, CallBackReceiver::class.java)
                    .setAction(ACTION_CALL_BACK).putExtra(EXTRA_NUMBER, number),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))
            builder.addAction(0, "Message", PendingIntent.getActivity(
                context, 11, Intent(Intent.ACTION_SENDTO, Uri.fromParts("smsto", number, null))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))
            if (name == null) {
                builder.addAction(0, "Add to contacts", PendingIntent.getActivity(
                    context, 12, addContactIntent(number),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                ))
            }
        }
        notify(context, MISSED_ID, builder.build())
    }

    private fun showVoicemail(context: Context, intent: Intent) {
        val count = intent.getIntExtra(TelephonyManager.EXTRA_NOTIFICATION_COUNT, 0)
        if (count == 0) {
            cancel(context, VOICEMAIL_ID)
            return
        }
        createChannels(context)
        @Suppress("DEPRECATION")
        val call = intent.getParcelableExtra<PendingIntent>(TelephonyManager.EXTRA_CALL_VOICEMAIL_INTENT)
        val listen = call ?: PendingIntent.getBroadcast(
            context, 20, Intent(context, CallBackReceiver::class.java)
                .setAction(ACTION_CALL_BACK).putExtra(EXTRA_NUMBER, "voicemail"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = NotificationCompat.Builder(context, VOICEMAIL_CHANNEL)
            .setSmallIcon(android.R.drawable.stat_notify_voicemail)
            .setContentTitle("New voicemail")
            .setContentText(if (count > 1) "$count messages. Tap to call voicemail" else "Tap to call voicemail")
            .setOngoing(false)
            .setContentIntent(listen)
            .addAction(0, "Call voicemail", listen)
        notify(context, VOICEMAIL_ID, builder.build())
    }

    companion object {
        const val ACTION_CALL_BACK = "dev.sagron.zerotrustphone.CALL_BACK"
        const val EXTRA_NUMBER = "number"
        private const val MISSED_CHANNEL = "missed_calls"
        private const val VOICEMAIL_CHANNEL = "voicemail"
        const val MISSED_ID = 4300
        private const val VOICEMAIL_ID = 4301

        fun createChannels(context: Context) {
            val nm = context.getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(
                NotificationChannel(MISSED_CHANNEL, "Missed calls", NotificationManager.IMPORTANCE_DEFAULT)
                    .apply { lockscreenVisibility = Notification.VISIBILITY_PRIVATE }
            )
            nm.createNotificationChannel(
                NotificationChannel(VOICEMAIL_CHANNEL, "Voicemail", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }

        fun cancel(context: Context, id: Int) =
            context.getSystemService(NotificationManager::class.java).cancel(id)

        private fun notify(context: Context, id: Int, n: Notification) {
            try {
                context.getSystemService(NotificationManager::class.java).notify(id, n)
            } catch (_: SecurityException) {
                // Notifications turned off for ZT Phone.
            }
        }

        private fun openRecents(context: Context): PendingIntent = PendingIntent.getActivity(
            context, 13, Intent(context, MainActivity::class.java)
                .setAction(MainActivity.ACTION_SHOW_RECENTS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        fun addContactIntent(number: String): Intent =
            Intent(Intent.ACTION_INSERT, ContactsContract.Contacts.CONTENT_URI)
                .putExtra(ContactsContract.Intents.Insert.PHONE, number)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
}

/**
 * "Call back" and "Call voicemail" from ZT Phone's notifications. Not
 * exported, so only those notifications can start a call through it.
 */
class CallBackReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != MissedCallReceiver.ACTION_CALL_BACK) return
        MissedCallReceiver.cancel(context, MissedCallReceiver.MISSED_ID)
        val number = intent.getStringExtra(MissedCallReceiver.EXTRA_NUMBER) ?: return
        val uri = if (number == "voicemail") {
            Uri.fromParts("voicemail", "", null)
        } else {
            Uri.fromParts("tel", number, null)
        }
        try {
            context.getSystemService(TelecomManager::class.java).placeCall(uri, Bundle())
        } catch (_: SecurityException) {
            // No CALL_PHONE permission: open the dialpad with the number.
            context.startActivity(
                Intent(Intent.ACTION_DIAL, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }
}
