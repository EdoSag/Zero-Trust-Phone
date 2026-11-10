package dev.sagron.zerotrustphone

import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.InCallService

/**
 * Bound by Telecom while ZT Phone is the default Phone app and a call
 * exists. Hands calls to [CallManager] and opens the in-call screen.
 */
class ZtInCallService : InCallService() {
    override fun onCreate() {
        super.onCreate()
        CallManager.service = this
        CallNotifications.createChannels(this)
        // Warm the in-call screen's Flutter engine so it opens quickly.
        CallEngine.ensure(applicationContext)
    }

    override fun onDestroy() {
        CallNotifications.cancel(this)
        if (CallManager.service === this) CallManager.service = null
        super.onDestroy()
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        CallManager.add(call)
        if (call.stateCompat() == Call.STATE_RINGING) {
            call.details.handle?.schemeSpecificPart?.let { CallRinger.start(this, it) }
            // The full-screen notification opens the call screen when the
            // phone is locked or idle, and shows a heads-up card otherwise.
            CallNotifications.update(this)
        } else {
            CallActivity.start(this)
        }
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        CallManager.remove(call)
        if (!CallManager.hasCalls) CallNotifications.cancel(this)
    }

    @Deprecated("Still delivered on every supported Android version")
    override fun onCallAudioStateChanged(audioState: CallAudioState?) {
        CallManager.audioState = audioState
    }

}
