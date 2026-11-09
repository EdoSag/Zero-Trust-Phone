package dev.sagron.zerotrustphone

import android.os.Handler
import android.os.Looper
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.VideoProfile

/**
 * The calls Telecom has handed to [ZtInCallService], and the controls the
 * in-call screen uses. Lives for the process; everything runs on the main
 * thread, where Telecom delivers its callbacks.
 */
object CallManager {
    /** Notified with [snapshot] whenever a call or the audio route changes. */
    fun interface Listener {
        fun onChanged(state: Map<String, Any?>)
    }

    private val main = Handler(Looper.getMainLooper())
    private val calls = linkedMapOf<Call, String>()
    private val listeners = mutableSetOf<Listener>()
    private var nextId = 1
    var service: ZtInCallService? = null
    var audioState: CallAudioState? = null
        set(value) {
            field = value
            notifyChanged()
        }

    /** Names known only while the vault is unlocked; never written to disk. */
    private val vaultNames = mutableMapOf<String, String>()

    private val callback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) = notifyChanged()
        override fun onDetailsChanged(call: Call, details: Call.Details) = notifyChanged()
        override fun onConferenceableCallsChanged(call: Call, conferenceableCalls: MutableList<Call>) =
            notifyChanged()
        override fun onChildrenChanged(call: Call, children: MutableList<Call>) = notifyChanged()
    }

    fun add(call: Call) {
        calls[call] = "c${nextId++}"
        call.registerCallback(callback)
        notifyChanged()
    }

    fun remove(call: Call) {
        call.unregisterCallback(callback)
        calls.remove(call)
        notifyChanged()
    }

    val hasCalls: Boolean get() = calls.isNotEmpty()

    fun ringing(): Call? = calls.keys.firstOrNull { it.stateCompat() == Call.STATE_RINGING }

    fun primary(): Call? =
        calls.keys.firstOrNull { it.stateCompat() == Call.STATE_RINGING }
            ?: calls.keys.firstOrNull { it.stateCompat() == Call.STATE_ACTIVE && it.parent == null }
            ?: calls.keys.firstOrNull { it.parent == null }

    fun addListener(listener: Listener) {
        listeners.add(listener)
        listener.onChanged(snapshot())
    }

    fun removeListener(listener: Listener) {
        listeners.remove(listener)
    }

    fun notifyChanged() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            main.post { notifyChanged() }
            return
        }
        val state = snapshot()
        listeners.toList().forEach { it.onChanged(state) }
        service?.let { CallNotifications.update(it) }
    }

    fun setVaultNames(names: Map<String, String>) {
        vaultNames.clear()
        vaultNames.putAll(names)
        notifyChanged()
    }

    fun clearVaultNames() {
        vaultNames.clear()
    }

    /** The caller's name: the unlocked vault first, then the phone's contacts. */
    fun nameFor(number: String): String? {
        val key = PhoneNumbers.lookupKey(number)
        if (key.isNotEmpty()) vaultNames[key]?.let { return it }
        val ctx = service ?: return null
        return SystemContacts.lookupName(ctx, number)
    }

    private fun byId(id: String?): Call? = calls.entries.firstOrNull { it.value == id }?.key

    fun snapshot(): Map<String, Any?> {
        val audio = audioState
        return mapOf(
            "calls" to calls.entries.map { (call, id) -> describe(call, id) },
            "audio" to if (audio == null) null else mapOf(
                "muted" to audio.isMuted,
                "route" to audio.route,
                "supportedRoutes" to audio.supportedRouteMask,
            ),
        )
    }

    private fun describe(call: Call, id: String): Map<String, Any?> {
        val details = call.details
        val number = details.handle?.schemeSpecificPart ?: ""
        val caps = details.callCapabilities
        return mapOf(
            "id" to id,
            "number" to number,
            "name" to (if (number.isNotEmpty()) nameFor(number) else null),
            "state" to stateName(call.stateCompat()),
            "connectedAt" to details.connectTimeMillis.takeIf { it > 0 },
            "isConference" to details.hasProperty(Call.Details.PROPERTY_CONFERENCE),
            "parentId" to call.parent?.let { calls[it] },
            "canHold" to ((caps and Call.Details.CAPABILITY_HOLD) != 0),
            "canMerge" to (call.conferenceableCalls.isNotEmpty() ||
                (caps and Call.Details.CAPABILITY_MERGE_CONFERENCE) != 0),
            "canSwap" to ((caps and Call.Details.CAPABILITY_SWAP_CONFERENCE) != 0),
            "disconnectReason" to details.disconnectCause?.label?.toString(),
        )
    }

    private fun stateName(state: Int): String = when (state) {
        Call.STATE_NEW -> "new"
        Call.STATE_RINGING -> "ringing"
        Call.STATE_DIALING -> "dialing"
        Call.STATE_CONNECTING -> "connecting"
        Call.STATE_ACTIVE -> "active"
        Call.STATE_HOLDING -> "holding"
        Call.STATE_DISCONNECTING -> "disconnecting"
        Call.STATE_DISCONNECTED -> "disconnected"
        Call.STATE_SELECT_PHONE_ACCOUNT -> "selectAccount"
        Call.STATE_PULLING_CALL -> "connecting"
        Call.STATE_AUDIO_PROCESSING -> "connecting"
        Call.STATE_SIMULATED_RINGING -> "ringing"
        else -> "unknown"
    }

    // Controls, by the id the in-call screen got from [snapshot].

    fun answer(id: String?) {
        (byId(id) ?: ringing())?.answer(VideoProfile.STATE_AUDIO_ONLY)
    }

    fun reject(id: String?) {
        (byId(id) ?: ringing())?.reject(false, null)
    }

    fun hangUp(id: String?) {
        (byId(id) ?: primary())?.disconnect()
    }

    fun hold(id: String?, on: Boolean) {
        val call = byId(id) ?: primary() ?: return
        if (on) call.hold() else call.unhold()
    }

    fun swap() {
        val held = calls.keys.firstOrNull { it.stateCompat() == Call.STATE_HOLDING && it.parent == null }
        val conference = calls.keys.firstOrNull { it.details.hasProperty(Call.Details.PROPERTY_CONFERENCE) }
        if (conference != null && conference.details.can(Call.Details.CAPABILITY_SWAP_CONFERENCE)) {
            conference.swapConference()
        } else {
            held?.unhold() // Telecom holds the active call first.
        }
    }

    fun merge() {
        val active = calls.keys.firstOrNull { it.stateCompat() == Call.STATE_ACTIVE && it.parent == null }
            ?: return
        val other = active.conferenceableCalls.firstOrNull()
        if (other != null) {
            active.conference(other)
        } else if (active.details.can(Call.Details.CAPABILITY_MERGE_CONFERENCE)) {
            active.mergeConference()
        }
    }

    fun dtmf(digit: Char) {
        val call = calls.keys.firstOrNull { it.stateCompat() == Call.STATE_ACTIVE } ?: return
        call.playDtmfTone(digit)
        main.postDelayed({ call.stopDtmfTone() }, 150)
    }

    fun setMuted(muted: Boolean) {
        service?.setMuted(muted)
    }

    @Suppress("DEPRECATION")
    fun setRoute(route: Int) {
        service?.setAudioRoute(route)
    }
}

@Suppress("DEPRECATION")
fun Call.stateCompat(): Int =
    if (android.os.Build.VERSION.SDK_INT >= 31) details.state else state
