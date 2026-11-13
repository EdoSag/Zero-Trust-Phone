package dev.sagron.zerotrustphone

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.InCallService
import android.telecom.PhoneAccount
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

    /** The other person asked to switch to real-time text: Telecom's id. */
    private val rttRequests = mutableMapOf<Call, Int>()

    /** Whether each call's SIM offers RTT (asked once per call). */
    private val rttCapable = mutableMapOf<Call, Boolean>()

    /** P15: calls stopped at a "wait for my tap" (`;`), with the tones left. */
    private val postDialWaits = mutableMapOf<Call, String>()

    /** A short message for the call screen ("rttFailed", "videoFailed"). */
    private val notices = mutableMapOf<Call, String>()
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
            VideoSessions.sync(service, call)
            notifyChanged()
        }
        override fun onDetailsChanged(call: Call, details: Call.Details) {
            VideoSessions.sync(service, call)
            notifyChanged()
        }
        override fun onVideoCallChanged(call: Call, videoCall: InCallService.VideoCall?) {
            VideoSessions.sync(service, call)
            notifyChanged()
        }
        override fun onRttStatusChanged(call: Call, enabled: Boolean, rttCall: Call.RttCall?) {
            if (enabled) calls[call]?.let { RttSessions.start(call, it) }
            notifyChanged()
        }
        override fun onRttRequest(call: Call, id: Int) {
            rttRequests[call] = id
            notifyChanged()
        }
        override fun onPostDialWait(call: Call, remainingPostDialSequence: String?) {
            postDialWaits[call] = remainingPostDialSequence ?: ""
            notifyChanged()
        }
        override fun onRttInitiationFailure(call: Call, reason: Int) = notice(call, "rttFailed")
        override fun onConferenceableCallsChanged(call: Call, conferenceableCalls: MutableList<Call>) =
            notifyChanged()
        override fun onChildrenChanged(call: Call, children: MutableList<Call>) = notifyChanged()
    }

    fun add(call: Call) {
        val id = "c${nextId++}"
        calls[call] = id
        call.registerCallback(callback)
        // Calls placed or answered with RTT already have their stream.
        if (call.isRttActive) RttSessions.start(call, id)
        VideoSessions.sync(service, call)
        notifyChanged()
    }

    fun remove(call: Call) {
        call.unregisterCallback(callback)
        if (ringing() == null || ringing() === call) CallRinger.stop()
        VideoSessions.remove(call)
        calls.remove(call)?.let { RttSessions.clear(it) }
        accountChoices.remove(call)
        rttRequests.remove(call)
        postDialWaits.remove(call)
        rttCapable.remove(call)
        notices.remove(call)
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

    /** Shows [message] on [call]'s screen for a few seconds. */
    fun notice(call: Call, message: String) {
        notices[call] = message
        notifyChanged()
        main.postDelayed({
            if (notices[call] == message) {
                notices.remove(call)
                notifyChanged()
            }
        }, 5000)
    }

    /** RTT works on this call: it's on, or the SIM's carrier offers it. */
    private fun canRtt(call: Call): Boolean {
        if (call.details.hasProperty(Call.Details.PROPERTY_RTT)) return true
        rttCapable[call]?.let { return it }
        val handle = call.details.accountHandle ?: return false
        val ctx = service ?: return false
        val capable = try {
            ctx.getSystemService(TelecomManager::class.java).getPhoneAccount(handle)
                ?.hasCapabilities(PhoneAccount.CAPABILITY_RTT) == true
        } catch (_: SecurityException) {
            false
        }
        rttCapable[call] = capable
        return capable
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
        val number = PhoneNumbers.plain(details.handle?.schemeSpecificPart ?: "")
        val caps = details.callCapabilities
        return VideoSessions.describe(call, service) + mapOf(
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
            "rttActive" to call.isRttActive,
            "canRtt" to canRtt(call),
            "rttRequest" to rttRequests.containsKey(call),
            // Upgrading needs our camera and the other side's screen.
            "canVideo" to ((caps and Call.Details.CAPABILITY_SUPPORTS_VT_LOCAL_TX) != 0 &&
                (caps and Call.Details.CAPABILITY_SUPPORTS_VT_REMOTE_RX) != 0),
            "notice" to notices[call],
            // Only the tones up to the next pause or wait, as the screen asks.
            "postDialWait" to postDialWaits[call]?.substringBefore(',')?.substringBefore(';'),
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

    /** Answers a video call with video; without camera access, only theirs. */
    fun answerVideo(id: String?) {
        CallRinger.stop()
        val call = byId(id) ?: ringing() ?: return
        val offered = call.details.videoState
        val camera = service?.checkSelfPermission(android.Manifest.permission.CAMERA) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
        call.answer(
            when {
                !VideoProfile.isVideo(offered) -> VideoProfile.STATE_AUDIO_ONLY
                camera -> offered
                VideoProfile.isReceptionEnabled(offered) -> VideoProfile.STATE_RX_ENABLED
                else -> VideoProfile.STATE_AUDIO_ONLY
            }
        )
    }

    /** P15: sends the tones after a "wait for my tap", or skips the rest. */
    fun postDialContinue(id: String?, send: Boolean) {
        val call = byId(id) ?: primary() ?: return
        if (postDialWaits.remove(call) == null) return
        call.postDialContinue(send)
        notifyChanged()
    }

    // Real-time text (P12).

    fun rttRequest(id: String?) {
        (byId(id) ?: primary())?.sendRttRequest()
    }

    fun rttRespond(id: String?, accept: Boolean) {
        val call = byId(id) ?: primary() ?: return
        val request = rttRequests.remove(call) ?: return
        call.respondToRttRequest(request, accept)
        notifyChanged()
    }

    fun rttStop(id: String?) {
        (byId(id) ?: primary())?.stopRtt()
    }

    fun rttWrite(id: String?, text: String) {
        val call = byId(id) ?: primary() ?: return
        if (!RttSessions.write(call, text)) notice(call, "rttFailed")
    }

    // Video (P12).

    fun videoRequest(id: String?) {
        (byId(id) ?: primary())?.let { VideoSessions.request(it) }
    }

    fun videoStop(id: String?) {
        (byId(id) ?: primary())?.let { VideoSessions.stop(it) }
    }

    fun videoCamera(id: String?, on: Boolean) {
        (byId(id) ?: primary())?.let {
            VideoSessions.setCameraOn(it, on)
            if (on) {
                // The carrier may have kept the call sending video while the
                // camera was off: then no change arrives to start it again.
                VideoSessions.sync(service, it)
                notifyChanged()
            }
        }
    }

    fun videoSwitchCamera(id: String?) {
        val ctx = service ?: return
        (byId(id) ?: primary())?.let { VideoSessions.switchCamera(ctx, it) }
    }

    fun videoRespond(id: String?, accept: Boolean) {
        (byId(id) ?: primary())?.let {
            VideoSessions.respond(service, it, accept)
            if (accept) {
                // Accepting turns the camera back on. When the call was
                // already sending video nothing changes at the carrier, so
                // start the camera here.
                VideoSessions.sync(service, it)
                notifyChanged()
            }
        }
    }

    /** Camera access arrived: start the preview of a call already in video. */
    fun cameraGranted() {
        calls.keys.forEach { VideoSessions.sync(service, it) }
        notifyChanged()
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
