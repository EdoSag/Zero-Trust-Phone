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
        val who = name ?: number?.takeIf { it.isNotBlank() } ?: NativeStrings.get(context, "nativePrivateNumber", R.string.private_number)
        val title = if (count == 1) NativeStrings.get(context, "nativeMissedCall", R.string.missed_call)
            else NativeStrings.format(context, "nativeMissedCalls", R.string.missed_calls, count)
        val builder = NotificationCompat.Builder(context, MISSED_CHANNEL)
            .setSmallIcon(android.R.drawable.stat_notify_missed_call)
            .setContentTitle(title)
            .setContentText(if (count == 1) who else NativeStrings.format(context, "nativeLatestFrom", R.string.latest_from, who))
            .setCategory(NotificationCompat.CATEGORY_MISSED_CALL)
            .setAutoCancel(true)
            .setContentIntent(openRecents(context))
        @Suppress("DEPRECATION")
        val clear = intent.getParcelableExtra<PendingIntent>(EXTRA_CLEAR_MISSED_CALLS)
        if (clear != null) builder.setDeleteIntent(clear)
        if (!number.isNullOrBlank()) {
            builder.addAction(0, NativeStrings.get(context, "nativeCallBack", R.string.call_back), PendingIntent.getBroadcast(
                context, 10, Intent(context, CallBackReceiver::class.java)
                    .setAction(ACTION_CALL_BACK).putExtra(EXTRA_NUMBER, number),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))
            builder.addAction(0, NativeStrings.get(context, "message", R.string.message), PendingIntent.getActivity(
                context, 11, Intent(Intent.ACTION_SENDTO, Uri.fromParts("smsto", number, null))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))
            // P25: pick a time in the app; it reminds and adds a ZT Task.
            builder.addAction(0, NativeStrings.get(context, "nativeRemindMe", R.string.remind_me), PendingIntent.getActivity(
                context, 14, Intent(context, MainActivity::class.java)
                    .setAction(MainActivity.ACTION_CALL_BACK_LATER)
                    .putExtra(EXTRA_NUMBER, number)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))
            if (name == null) {
                builder.addAction(0, NativeStrings.get(context, "addToContacts", R.string.add_to_contacts), PendingIntent.getActivity(
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
            .setContentTitle(NativeStrings.get(context, "nativeNewVoicemail", R.string.new_voicemail))
            .setContentText(
                if (count > 1) NativeStrings.format(context, "nativeVoicemailMessages", R.string.voicemail_messages, count)
                else NativeStrings.get(context, "nativeTapToCallVoicemail", R.string.tap_to_call_voicemail)
            )
            .setOngoing(false)
            .setContentIntent(listen)
            .addAction(0, NativeStrings.get(context, "nativeCallVoicemail", R.string.call_voicemail), listen)
        notify(context, VOICEMAIL_ID, builder.build())
    }

    companion object {
        const val ACTION_CALL_BACK = "dev.sagron.zerotrustphone.CALL_BACK"
        const val EXTRA_NUMBER = "number"
        const val EXTRA_NOTIFICATION_ID = "notificationId"
        private const val MISSED_CHANNEL = "missed_calls"
        private const val VOICEMAIL_CHANNEL = "voicemail"
        const val MISSED_ID = 4300
        /** TelecomManager.EXTRA_CLEAR_MISSED_CALLS_INTENT, which the SDK hides. */
        const val EXTRA_CLEAR_MISSED_CALLS = "android.telecom.extra.CLEAR_MISSED_CALLS_INTENT"
        private const val VOICEMAIL_ID = 4301

        fun createChannels(context: Context) {
            val nm = context.getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(
                NotificationChannel(MISSED_CHANNEL, NativeStrings.get(context, "nativeMissedChannel", R.string.missed_calls_channel), NotificationManager.IMPORTANCE_DEFAULT)
                    .apply { lockscreenVisibility = Notification.VISIBILITY_PRIVATE }
            )
            nm.createNotificationChannel(
                NotificationChannel(VOICEMAIL_CHANNEL, NativeStrings.get(context, "voicemail", R.string.voicemail), NotificationManager.IMPORTANCE_DEFAULT)
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
        intent.getIntExtra(MissedCallReceiver.EXTRA_NOTIFICATION_ID, 0).takeIf { it != 0 }
            ?.let { MissedCallReceiver.cancel(context, it) }
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
