package dev.sagron.zerotrustphone

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Decline and Hang up from the call notification. */
class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            DECLINE -> CallManager.reject(null)
            HANG_UP -> CallManager.hangUp(null)
        }
    }

    companion object {
        const val DECLINE = "dev.sagron.zerotrustphone.DECLINE"
        const val HANG_UP = "dev.sagron.zerotrustphone.HANG_UP"

        fun intent(context: Context, action: String): PendingIntent = PendingIntent.getBroadcast(
            context, action.hashCode(),
            Intent(context, CallActionReceiver::class.java).setAction(action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
