package dev.sagron.zerotrustphone

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.InCallService

/**
 * Bound by Telecom while ZT Phone is the default Phone app and a call
 * exists. Hands calls to [CallManager] and opens the in-call screen.
 */
class ZtInCallService : InCallService() {
    /**
     * Brings the call screen back when the phone is unlocked during a call,
     * or its screen comes on while a call rings, so the user never has to
     * look for the notification or reopen the app.
     */
    private val screenEvents = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (CallScreenRules.reopenOn(intent.action, CallManager.hasCalls, CallManager.ringing() != null)) {
                CallActivity.start(this@ZtInCallService)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        CallManager.service = this
        CallNotifications.createChannels(this)
        // Warm the in-call screen's Flutter engine so it opens quickly.
        CallEngine.ensure(applicationContext)
        registerReceiver(
            screenEvents,
            IntentFilter().apply {
                addAction(Intent.ACTION_USER_PRESENT)
                addAction(Intent.ACTION_SCREEN_ON)
            },
        )
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenEvents)
        } catch (_: IllegalArgumentException) {
        }
        CallNotifications.cancel(this)
        if (CallManager.service === this) CallManager.service = null
        super.onDestroy()
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        // P26: in a meeting, decline with a text (no screen at all) or
        // ring silently, as chosen in Settings.
        if (call.stateCompat() == Call.STATE_RINGING &&
            MeetingGuard.handle(this, call) == MeetingGuard.Outcome.DECLINED
        ) {
            CallManager.add(call)
            return
        }
        CallManager.add(call)
        if (call.stateCompat() == Call.STATE_RINGING) {
            call.details.handle?.schemeSpecificPart?.let { CallRinger.start(this, it) }
            // P29: face down silences it, when switched on.
            CallComfort.watchRinging(this)
            // The pinned call card (full screen when locked) ...
            CallNotifications.update(this)
        }
        // ... and the call screen itself, every time: locked, idle or while
        // the phone is in use. A heads-up card alone is easy to miss or
        // swipe away. Android lets a bound InCallService start it.
        CallActivity.start(this)
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        // P23: a private contact's call leaves Android's shared call log.
        val number = call.details.handle?.schemeSpecificPart ?: ""
        if (number.isNotBlank() && ScreeningStore(this).isPrivate(number)) {
            PrivateCallLog.scrubSoon(this, number, call.details.creationTimeMillis)
        }
        CallManager.remove(call)
        if (CallManager.ringing() == null) CallComfort.stopWatching(this)
        if (!CallManager.hasCalls) CallNotifications.cancel(this)
    }

    @Deprecated("Still delivered on every supported Android version")
    override fun onCallAudioStateChanged(audioState: CallAudioState?) {
        CallManager.audioState = audioState
    }

}
