package dev.sagron.zerotrustphone

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey
import javax.crypto.spec.SecretKeySpec

/**
 * What call screening and the ringer need while the vault is locked, kept
 * on this phone only. Numbers are never stored: only an HMAC of each
 * number's lookup key, so the file alone doesn't reveal who is in the
 * address book.
 *
 * The HMAC key comes from a key that stays inside Android's Keystore: the
 * Keystore key signs a fixed label once per run of the app, and the answer
 * (kept in memory only, never written anywhere) is the key the numbers are
 * hashed with. Each number used to be hashed by the Keystore itself, one
 * slow round trip to the phone's secure hardware per number, on the main
 * thread: with a few thousand contacts that froze the whole app for the
 * better part of a minute every time the rules were sent.
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
    /** P23: this number's calls stay out of Android's shared call log. */
    fun isPrivate(number: String): Boolean = hashOf(number)?.let { it in (prefs.getStringSet(KEY_PRIVATE, emptySet()) ?: emptySet()) } ?: false
    fun hasPrivate(): Boolean = !(prefs.getStringSet(KEY_PRIVATE, emptySet()) ?: emptySet()).isEmpty()
    fun ringtoneFor(number: String): String? = hashOf(number)?.let { prefs.getString("$KEY_RINGTONE$it", null) }

    /**
     * Replaces everything from the unlocked app. Not for the main thread:
     * a long address book is thousands of hashes (see [writer]).
     */
    fun update(
        unknownMode: String,
        blockHidden: Boolean,
        prefixes: List<String>,
        contactKeys: List<String>,
        voicemailKeys: List<String>,
        ringtones: Map<String, String>,
        privateKeys: List<String> = emptyList(),
    ) {
        val edit = prefs.edit()
        edit.putString(KEY_UNKNOWN, unknownMode)
            .putBoolean(KEY_HIDDEN, blockHidden)
            .putStringSet(KEY_PREFIXES, prefixes.map { PhoneNumbersPrefix.normalize(it) }.filter { it.isNotEmpty() }.toSet())
        // One Mac for the whole update, with the in-memory key.
        val mac: Mac? = try {
            Mac.getInstance("HmacSHA256").apply { init(derivedKey()) }
        } catch (_: Exception) {
            // No Keystore right now: the numbers already saved stay as
            // they are, rather than every contact turning into a stranger.
            null
        }
        if (mac != null) {
            fun hash(lookupKey: String): String? =
                if (lookupKey.isEmpty()) null else hex(mac.doFinal(lookupKey.toByteArray()))
            prefs.all.keys.filter { it.startsWith(KEY_RINGTONE) }.forEach { edit.remove(it) }
            edit.putStringSet(KEY_CONTACTS, contactKeys.mapNotNull { hash(it) }.toSet())
                .putStringSet(KEY_VOICEMAIL, voicemailKeys.mapNotNull { hash(it) }.toSet())
                .putStringSet(KEY_PRIVATE, privateKeys.mapNotNull { hash(it) }.toSet())
                .putInt(KEY_HASHES, HASHES_DERIVED)
            for ((key, uri) in ringtones) hash(key)?.let { edit.putString("$KEY_RINGTONE$it", uri) }
        }
        edit.apply()
    }

    /** Signing out removes the address-book hashes and per-contact rules. */
    fun clearContacts() {
        val edit = prefs.edit()
        prefs.all.keys.filter { it.startsWith(KEY_RINGTONE) }.forEach { edit.remove(it) }
        edit.remove(KEY_CONTACTS).remove(KEY_VOICEMAIL).remove(KEY_PRIVATE).apply()
    }

    private fun hashOf(number: String): String? = hashKey(PhoneNumbers.lookupKey(number))

    /**
     * The hash a number is saved under. Rules saved by a version before
     * 0.8.2 were hashed by the Keystore key itself; they are read that way
     * until the app is next unlocked and sends them again.
     */
    private fun hashKey(lookupKey: String): String? {
        if (lookupKey.isEmpty()) return null
        return try {
            val newer = prefs.getInt(KEY_HASHES, HASHES_KEYSTORE) >= HASHES_DERIVED
            val mac = Mac.getInstance("HmacSHA256")
            mac.init(if (newer) derivedKey() else key())
            hex(mac.doFinal(lookupKey.toByteArray()))
        } catch (_: Exception) {
            null
        }
    }

    /** The first 16 bytes as hex, as the hashes have always been saved. */
    private fun hex(bytes: ByteArray): String {
        val out = StringBuilder(32)
        for (i in 0 until 16) {
            val b = bytes[i].toInt() and 0xff
            out.append(HEX[b ushr 4]).append(HEX[b and 0x0f])
        }
        return out.toString()
    }

    /**
     * The key numbers are hashed with: the Keystore key's HMAC of a fixed
     * label. Worked out once per run of the app and kept in memory only.
     */
    private fun derivedKey(): SecretKey {
        derived?.let { return it }
        synchronized(lock) {
            derived?.let { return it }
            val mac = Mac.getInstance("HmacSHA256")
            mac.init(key())
            val made = SecretKeySpec(mac.doFinal(DERIVE_LABEL.toByteArray()), "HmacSHA256")
            derived = made
            return made
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
        private const val KEY_PRIVATE = "private_log"

        /** How the saved hashes were made. */
        private const val KEY_HASHES = "hashes"
        private const val HASHES_KEYSTORE = 1
        private const val HASHES_DERIVED = 2
        private const val DERIVE_LABEL = "zt_phone_screening_numbers_v2"
        private const val HEX = "0123456789abcdef"

        private val lock = Any()
        @Volatile private var derived: SecretKey? = null

        /**
         * Saves and clears run here, one after another and off the main
         * thread, so the newest rules always land last and the app never
         * waits on them.
         */
        val writer: ExecutorService = Executors.newSingleThreadExecutor()
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
