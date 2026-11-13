package dev.sagron.zerotrustphone

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.CallLog
import org.json.JSONArray
import org.json.JSONObject

/**
 * Private call log mode (P23). Android's Telecom writes every call into the
 * shared call log itself, and no Phone app can stop that. So for contacts
 * marked private, ZT Phone takes the call out of the shared log as soon as
 * Telecom has written it (a few seconds after the call ends) and keeps it,
 * encrypted with a Keystore key, until the unlocked app moves it into the
 * vault ([take]). A sweep on every unlock catches calls missed meanwhile
 * (the phone restarted, a call screened before it rang).
 */
object PrivateCallLog {
    private const val PREFS = "zt_private_calls"
    private const val KEY_QUEUE = "queue"
    private val main = Handler(Looper.getMainLooper())

    /** After a private contact's call ends: look for its row a few times. */
    fun scrubSoon(context: Context, number: String, since: Long) {
        val app = context.applicationContext
        val key = PhoneNumbers.lookupKey(number)
        if (key.isEmpty()) return
        // Telecom logs the call on its own thread after the call is removed.
        for (delay in longArrayOf(1500, 4000, 10000, 30000)) {
            main.postDelayed({
                try {
                    scrub(app, since - 60_000) { PhoneNumbers.lookupKey(it) == key }
                } catch (_: Exception) {
                }
            }, delay)
        }
    }

    /** Moves every row of a private contact still in the shared log. */
    fun sweep(context: Context) {
        val store = ScreeningStore(context)
        if (!store.hasPrivate()) return
        scrub(context, 0) { store.isPrivate(it) }
    }

    /** The calls waiting for the vault, and forgets them here. */
    fun take(context: Context): List<Map<String, Any?>> {
        sweep(context)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val calls = read(prefs.getString(KEY_QUEUE, null))
        prefs.edit().remove(KEY_QUEUE).apply()
        return (0 until calls.length()).map { i ->
            val o = calls.getJSONObject(i)
            mapOf(
                "number" to o.optString("number"),
                "type" to o.optInt("type", CallLog.Calls.INCOMING_TYPE),
                "date" to o.optLong("date"),
                "duration" to o.optLong("duration"),
            )
        }
    }

    /** Signing out: the waiting calls go too. */
    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    @Synchronized
    private fun scrub(context: Context, since: Long, isPrivate: (String) -> Boolean) {
        if (context.checkSelfPermission(Manifest.permission.WRITE_CALL_LOG) !=
            PackageManager.PERMISSION_GRANTED
        ) return
        val found = JSONArray()
        val ids = mutableListOf<String>()
        context.contentResolver.query(
            CallLog.Calls.CONTENT_URI,
            arrayOf(
                CallLog.Calls._ID, CallLog.Calls.NUMBER, CallLog.Calls.TYPE,
                CallLog.Calls.DATE, CallLog.Calls.DURATION,
            ),
            "${CallLog.Calls.DATE} >= ?", arrayOf(since.toString()),
            "${CallLog.Calls.DATE} DESC",
        )?.use { c ->
            while (c.moveToNext()) {
                val number = c.getString(1) ?: continue
                if (number.isBlank() || !isPrivate(number)) continue
                ids.add(c.getLong(0).toString())
                found.put(
                    JSONObject()
                        .put("number", number)
                        .put("type", c.getInt(2))
                        .put("date", c.getLong(3))
                        .put("duration", c.getLong(4))
                )
            }
        }
        if (ids.isEmpty()) return
        // Kept first, then deleted: a failure never loses the call.
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val queue = read(prefs.getString(KEY_QUEUE, null))
        for (i in 0 until found.length()) queue.put(found.get(i))
        prefs.edit().putString(KEY_QUEUE, LocalSealer.seal(queue.toString())).commit()
        for (chunk in ids.chunked(200)) {
            context.contentResolver.delete(
                CallLog.Calls.CONTENT_URI,
                "${CallLog.Calls._ID} IN (${chunk.joinToString(",") { "?" }})",
                chunk.toTypedArray(),
            )
        }
    }

    private fun read(sealed: String?): JSONArray {
        if (sealed == null) return JSONArray()
        val plain = LocalSealer.open(sealed) ?: return JSONArray()
        return try {
            JSONArray(plain)
        } catch (_: Exception) {
            JSONArray()
        }
    }
}
