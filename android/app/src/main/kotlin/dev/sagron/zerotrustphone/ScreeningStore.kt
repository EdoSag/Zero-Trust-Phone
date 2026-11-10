package dev.sagron.zerotrustphone

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey

/**
 * What call screening and the ringer need while the vault is locked, kept
 * on this phone only. Numbers are never stored: only an HMAC of each
 * number's lookup key, with a key that stays inside Android's Keystore, so
 * the file alone doesn't reveal who is in the address book.
 *
 * Written by the app while unlocked (`setScreening` on the telecom
 * channel); read by [ZtCallScreeningService] and [CallRinger].
 */
class ScreeningStore(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences("zt_screening", Context.MODE_PRIVATE)

    /** Unknown callers: "ring", "silence" or "voicemail". */
    val unknownMode: String get() = prefs.getString(KEY_UNKNOWN, "ring") ?: "ring"
    val blockHidden: Boolean get() = prefs.getBoolean(KEY_HIDDEN, false)
    val blockedPrefixes: Set<String> get() = prefs.getStringSet(KEY_PREFIXES, emptySet()) ?: emptySet()

    fun isContact(number: String): Boolean = hashOf(number)?.let { it in (prefs.getStringSet(KEY_CONTACTS, emptySet()) ?: emptySet()) } ?: false
    fun sendsToVoicemail(number: String): Boolean = hashOf(number)?.let { it in (prefs.getStringSet(KEY_VOICEMAIL, emptySet()) ?: emptySet()) } ?: false
    fun ringtoneFor(number: String): String? = hashOf(number)?.let { prefs.getString("$KEY_RINGTONE$it", null) }

    /** Replaces everything from the unlocked app. */
    fun update(
        unknownMode: String,
        blockHidden: Boolean,
        prefixes: List<String>,
        contactKeys: List<String>,
        voicemailKeys: List<String>,
        ringtones: Map<String, String>,
    ) {
        val edit = prefs.edit()
        prefs.all.keys.filter { it.startsWith(KEY_RINGTONE) }.forEach { edit.remove(it) }
        edit.putString(KEY_UNKNOWN, unknownMode)
            .putBoolean(KEY_HIDDEN, blockHidden)
            .putStringSet(KEY_PREFIXES, prefixes.map { PhoneNumbersPrefix.normalize(it) }.filter { it.isNotEmpty() }.toSet())
            .putStringSet(KEY_CONTACTS, contactKeys.mapNotNull { hashKey(it) }.toSet())
            .putStringSet(KEY_VOICEMAIL, voicemailKeys.mapNotNull { hashKey(it) }.toSet())
        for ((key, uri) in ringtones) hashKey(key)?.let { edit.putString("$KEY_RINGTONE$it", uri) }
        edit.apply()
    }

    /** Signing out removes the address-book hashes and per-contact rules. */
    fun clearContacts() {
        val edit = prefs.edit()
        prefs.all.keys.filter { it.startsWith(KEY_RINGTONE) }.forEach { edit.remove(it) }
        edit.remove(KEY_CONTACTS).remove(KEY_VOICEMAIL).apply()
    }

    private fun hashOf(number: String): String? = hashKey(PhoneNumbers.lookupKey(number))

    private fun hashKey(lookupKey: String): String? {
        if (lookupKey.isEmpty()) return null
        return try {
            val mac = Mac.getInstance("HmacSHA256")
            mac.init(key())
            mac.doFinal(lookupKey.toByteArray()).joinToString("") { "%02x".format(it) }.take(32)
        } catch (_: Exception) {
            null
        }
    }

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_HMAC_SHA256, "AndroidKeyStore")
        gen.init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_SIGN).build())
        return gen.generateKey()
    }

    companion object {
        private const val ALIAS = "zt_phone_screening_hmac"
        private const val KEY_UNKNOWN = "unknown_mode"
        private const val KEY_HIDDEN = "block_hidden"
        private const val KEY_PREFIXES = "blocked_prefixes"
        private const val KEY_CONTACTS = "contacts"
        private const val KEY_VOICEMAIL = "to_voicemail"
        private const val KEY_RINGTONE = "ringtone_"
    }
}

object PhoneNumbersPrefix {
    /** Digits with a leading + kept, as prefixes are compared. */
    fun normalize(number: String): String {
        val t = number.trim()
        val digits = t.filter { it.isDigit() }
        return if (t.startsWith("+")) "+$digits" else digits
    }

    fun matches(number: String, prefix: String): Boolean {
        if (prefix.isEmpty()) return false
        val n = normalize(number)
        if (n.startsWith(prefix)) return true
        // "+44" also matches "0044..." dialled forms.
        return prefix.startsWith("+") && n.startsWith("00" + prefix.drop(1))
    }
}
