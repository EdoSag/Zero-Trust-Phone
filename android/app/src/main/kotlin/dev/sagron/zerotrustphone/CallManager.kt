package dev.sagron.zerotrustphone

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
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

    /** SIMs a call may use, while it waits for one to be picked. */
    private val accountChoices = mutableMapOf<Call, List<PhoneAccountHandle>>()
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
        override fun onStateChanged(call: Call, state: Int) {
            if (ringing() == null) CallRinger.stop()
            notifyChanged()
        }
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
        if (ringing() == null || ringing() === call) CallRinger.stop()
        calls.remove(call)
        accountChoices.remove(call)
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
        // The call screen and notification drop names only the vault knew.
        notifyChanged()
    }

    /** The caller's name: the unlocked vault first, then the phone's contacts. */
    fun nameFor(number: String): String? {
        val ctx = service ?: return vaultNames[PhoneNumbers.lookupKey(number)]
        return nameFor(ctx, number)
    }

    fun nameFor(context: Context, number: String): String? {
        val key = PhoneNumbers.lookupKey(number)
        if (key.isNotEmpty()) vaultNames[key]?.let { return it }
        return SystemContacts.lookupName(context, number)
    }

    private fun byId(id: String?): Call? = calls.entries.firstOrNull { it.value == id }?.key

    fun snapshot(): Map<String, Any?> {
        val audio = audioState
        return mapOf(
            "calls" to calls.entries.map { (call, id) -> describe(call, id) },
            "carMode" to carMode(),
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
            "accounts" to if (call.stateCompat() == Call.STATE_SELECT_PHONE_ACCOUNT) {
                accountsFor(call).map { accountLabel(it) }
            } else {
                null
            },
        )
    }

    /** The SIMs Telecom offers for [call], or every SIM that can call. */
    @Suppress("DEPRECATION")
    private fun accountsFor(call: Call): List<PhoneAccountHandle> {
        accountChoices[call]?.let { return it }
        val offered: List<PhoneAccountHandle> = call.details.intentExtras
            ?.getParcelableArrayList<PhoneAccountHandle>(Call.AVAILABLE_PHONE_ACCOUNTS)
            ?: emptyList()
        val list = offered.ifEmpty {
            val ctx = service ?: return emptyList()
            try {
                ctx.getSystemService(TelecomManager::class.java).callCapablePhoneAccounts
            } catch (_: SecurityException) {
                emptyList()
            }
        }
        if (list.isNotEmpty()) accountChoices[call] = list
        return list
    }

    private fun accountLabel(handle: PhoneAccountHandle): String {
        val ctx = service ?: return "SIM"
        return try {
            ctx.getSystemService(TelecomManager::class.java)
                .getPhoneAccount(handle)?.label?.toString()
        } catch (_: SecurityException) {
            null
        } ?: "SIM"
    }

    /** Places [id]'s call on the SIM at [index] of its "accounts". */
    fun selectAccount(id: String?, index: Int) {
        val call = byId(id) ?: return
        val handle = accountsFor(call).getOrNull(index) ?: return
        call.phoneAccountSelected(handle, false)
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
        CallRinger.stop()
        (byId(id) ?: ringing())?.answer(VideoProfile.STATE_AUDIO_ONLY)
    }

    fun reject(id: String?) {
        CallRinger.stop()
        (byId(id) ?: ringing())?.reject(false, null)
    }

    /** Declines and texts [message] through the phone's SMS app (Telecom). */
    fun rejectWithMessage(id: String?, message: String) {
        CallRinger.stop()
        (byId(id) ?: ringing())?.reject(true, message)
    }

    /** Call waiting: ends the current call, then answers the new one. */
    fun endAndAnswer(id: String?) {
        val incoming = byId(id) ?: ringing() ?: return
        calls.keys.filter { it !== incoming && it.parent == null &&
            it.stateCompat() in setOf(Call.STATE_ACTIVE, Call.STATE_HOLDING, Call.STATE_DIALING) }
            .forEach { it.disconnect() }
        CallRinger.stop()
        incoming.answer(VideoProfile.STATE_AUDIO_ONLY)
    }

    /** Car mode (Android Auto, a car dock or the driving mode). */
    private fun carMode(): Boolean {
        val ctx = service ?: return false
        val ui = ctx.getSystemService(android.app.UiModeManager::class.java)
        return ui?.currentModeType == android.content.res.Configuration.UI_MODE_TYPE_CAR
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
