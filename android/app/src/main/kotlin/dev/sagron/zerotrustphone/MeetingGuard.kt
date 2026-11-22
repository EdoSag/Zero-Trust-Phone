package dev.sagron.zerotrustphone

import android.content.Context
import android.telecom.Call
import android.telecom.TelecomManager
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest

/**
 * P26: what happens to a call that rings during a meeting in ZT Calendar.
 * The app hands over the times I'm busy (start and end only, no titles,
 * sealed with the Keystore key) and the choice: ring, silence, or decline
 * with a text. Works while ZT Phone is locked.
 */
object MeetingGuard {
    private const val PREFS = "zt_meeting_guard"
    private const val RULES = "rules"
    private const val RECENT = "recent_callers"

    /** A second call from the same number within this time rings anyway. */
    private const val REPEAT_MS = 15 * 60 * 1000L

    enum class Outcome { RING, SILENCED, DECLINED }

    fun save(
        context: Context,
        mode: String,
        message: String,
        letRepeatCallersRing: Boolean,
        busy: List<List<Long>>,
    ) {
        val json = JSONObject()
            .put("mode", mode)
            .put("message", message)
            .put("repeat", letRepeatCallersRing)
            .put("busy", JSONArray().apply { busy.forEach { put(JSONArray(it)) } })
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(RULES, LocalSealer.seal(json.toString()))
            .apply()
    }

    private fun rules(context: Context): JSONObject? {
        val sealed = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(RULES, null) ?: return null
        val plain = LocalSealer.open(sealed) ?: return null
        return try {
            JSONObject(plain)
        } catch (_: Exception) {
            null
        }
    }

    /** Whether [now] falls in one of the [busy] [start, end) pairs. */
    fun isBusy(busy: JSONArray, now: Long): Boolean {
        for (i in 0 until busy.length()) {
            val pair = busy.optJSONArray(i) ?: continue
            if (pair.length() < 2) continue
            if (now >= pair.optLong(0) && now < pair.optLong(1)) return true
        }
        return false
    }

    /**
     * Applies the rule to a call that just started ringing. Hidden numbers
     * and emergency call-backs are never declined.
     */
    fun handle(context: Context, call: Call): Outcome {
        val r = rules(context) ?: return Outcome.RING
        val mode = r.optString("mode", "ring")
        if (mode == "ring") return Outcome.RING
        val now = System.currentTimeMillis()
        if (!isBusy(r.optJSONArray("busy") ?: JSONArray(), now)) return Outcome.RING
        val number = call.details.handle?.schemeSpecificPart ?: ""
        val key = PhoneNumbers.lookupKey(number)
        if (key.isEmpty()) return Outcome.RING
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val hashed = hash(key)
        // One time per caller, so A, B, then A again still counts as a repeat.
        val recent = recentCallers(prefs.getString(RECENT, null), now)
        if (r.optBoolean("repeat", true) && isRepeat(recent, hashed, now)) {
            return Outcome.RING
        }
        recent.put(hashed, now)
        prefs.edit().putString(RECENT, recent.toString()).apply()
        return if (mode == "decline") {
            val message = r.optString("message", "")
            if (message.isNotBlank()) call.reject(true, message) else call.reject(false, null)
            Outcome.DECLINED
        } else {
            try {
                context.getSystemService(TelecomManager::class.java).silenceRinger()
            } catch (_: SecurityException) {
            }
            Outcome.SILENCED
        }
    }

    /** The callers held back in the last [REPEAT_MS], older ones dropped. */
    fun recentCallers(raw: String?, now: Long): JSONObject {
        val all = try {
            if (raw == null) JSONObject() else JSONObject(raw)
        } catch (_: Exception) {
            JSONObject()
        }
        val kept = JSONObject()
        for (k in all.keys()) {
            val at = all.optLong(k)
            if (now - at < REPEAT_MS) kept.put(k, at)
        }
        return kept
    }

    fun isRepeat(recent: JSONObject, hashed: String, now: Long): Boolean =
        recent.has(hashed) && now - recent.optLong(hashed) < REPEAT_MS

    /** Only to tell repeat callers apart; the number itself isn't kept. */
    private fun hash(key: String): String =
        MessageDigest.getInstance("SHA-256").digest(key.toByteArray())
            .take(12).joinToString("") { "%02x".format(it) }
}
