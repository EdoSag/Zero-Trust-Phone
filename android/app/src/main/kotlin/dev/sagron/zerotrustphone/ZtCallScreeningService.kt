package dev.sagron.zerotrustphone

import android.app.NotificationManager
import android.media.AudioManager
import android.telecom.Call
import android.telecom.CallScreeningService
import android.telecom.TelecomManager

/**
 * Screens incoming calls on the phone, with no server and no list of
 * spam numbers: hidden numbers, blocked prefixes, unknown callers, and
 * contacts set to go straight to voicemail. Runs while the vault is
 * locked, from [ScreeningStore].
 */
class ZtCallScreeningService : CallScreeningService() {
    override fun onScreenCall(details: Call.Details) {
        if (details.callDirection != Call.Details.DIRECTION_INCOMING) {
            respondToCall(details, CallResponse.Builder().build())
            return
        }
        val store = ScreeningStore(this)
        val number = details.handle?.schemeSpecificPart ?: ""
        val hidden = number.isBlank() ||
            details.handlePresentation != TelecomManager.PRESENTATION_ALLOWED
        val response = CallResponse.Builder()
        val decision = decide(
            store = store,
            number = number,
            hidden = hidden,
            knownToPhone = number.isNotBlank() && SystemContacts.lookupName(this, number) != null,
        )
        when (decision) {
            Decision.ALLOW -> {
                // A custom ringtone is played by ZT Phone itself (CallRinger),
                // so the system's ringtone is silenced for that call. Only
                // when the phone would ring normally anyway; otherwise the
                // system's own rules (vibrate, silent, Do Not Disturb) apply.
                if (store.ringtoneFor(number) != null && canRingItself()) {
                    response.setSilenceCall(true)
                    CallRinger.expectCustom(number)
                }
            }
            Decision.SILENCE -> response.setSilenceCall(true)
            Decision.VOICEMAIL -> response.setDisallowCall(true).setRejectCall(true)
            Decision.BLOCK -> response.setDisallowCall(true).setRejectCall(true)
                .setSkipNotification(true)
        }
        respondToCall(details, response.build())
        // P23: a private contact's call that never rings (sent to voicemail)
        // is still logged by Telecom; take it out of the shared log too.
        if (decision != Decision.ALLOW && decision != Decision.SILENCE &&
            number.isNotBlank() && store.isPrivate(number)
        ) {
            PrivateCallLog.scrubSoon(this, number, System.currentTimeMillis())
        }
    }

    private fun canRingItself(): Boolean {
        val audio = getSystemService(AudioManager::class.java)
        val nm = getSystemService(NotificationManager::class.java)
        return audio.ringerMode == AudioManager.RINGER_MODE_NORMAL &&
            nm.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL
    }

    enum class Decision { ALLOW, SILENCE, VOICEMAIL, BLOCK }

    companion object {
        fun decide(
            store: ScreeningStore,
            number: String,
            hidden: Boolean,
            knownToPhone: Boolean,
        ): Decision {
            if (hidden) return if (store.blockHidden) Decision.BLOCK else unknown(store)
            if (store.blockedPrefixes.any { PhoneNumbersPrefix.matches(number, it) }) return Decision.BLOCK
            val isContact = knownToPhone || store.isContact(number)
            if (isContact) {
                return if (store.sendsToVoicemail(number)) Decision.VOICEMAIL else Decision.ALLOW
            }
            return unknown(store)
        }

        private fun unknown(store: ScreeningStore): Decision = when (store.unknownMode) {
            "silence" -> Decision.SILENCE
            "voicemail" -> Decision.VOICEMAIL
            else -> Decision.ALLOW
        }
    }
}
