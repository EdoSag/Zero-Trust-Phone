package dev.sagron.zerotrustphone

import android.content.Context
import java.io.File

/**
 * The list of reported spam numbers (P24), checked on this phone only:
 * an incoming number is looked up here and nothing is ever sent anywhere.
 *
 * The app downloads the list once a week from ZT Phone's own GitHub
 * releases, checks its signature in Dart (lib/services/spam_list.dart),
 * and only then hands it over with [install]. The screening service and
 * the call screen read it while the vault is locked.
 */
object SpamList {
    private const val FILE = "spam_list.txt"
    private const val PREFS = "zt_spam"
    private const val KEY_MODE = "mode"
    private const val HEADER = "# ZT Phone spam list, format 1."
    private const val MAX_ENTRIES = 300_000

    /** "off", "warn" (label only), "silence" or "voicemail". */
    fun mode(context: Context): String =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_MODE, "warn") ?: "warn"

    fun setMode(context: Context, mode: String) {
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_MODE, mode).apply()
    }

    private class Loaded(
        val stamp: Long,
        val exact: Map<String, Int>,
        val national: Map<String, Int>,
        val date: String?,
    )

    @Volatile private var cache: Loaded? = null

    private fun file(context: Context) = File(context.applicationContext.filesDir, FILE)

    /** Saves a list the app has already verified. False if it isn't one. */
    @Synchronized
    fun install(context: Context, text: String): Boolean {
        if (!text.startsWith(HEADER)) return false
        val target = file(context)
        val tmp = File(target.path + ".tmp")
        tmp.writeText(text)
        if (!tmp.renameTo(target)) {
            tmp.delete()
            return false
        }
        cache = null
        return true
    }

    @Synchronized
    fun clear(context: Context) {
        file(context).delete()
        cache = null
    }

    private fun load(context: Context): Loaded? {
        val f = file(context)
        if (!f.exists()) return null
        val stamp = f.lastModified()
        cache?.let { if (it.stamp == stamp) return it }
        return synchronized(this) {
            cache?.takeIf { it.stamp == stamp } ?: parse(f, stamp).also { cache = it }
        }
    }

    private fun parse(f: File, stamp: Long): Loaded? = try {
        val exact = HashMap<String, Int>()
        val national = HashMap<String, Int>()
        var date: String? = null
        var first = true
        f.bufferedReader().useLines { lines ->
            for (line in lines) {
                if (first) {
                    first = false
                    if (line != HEADER) return null
                    continue
                }
                if (line.startsWith("# list-date: ")) date = line.removePrefix("# list-date: ").trim()
                if (line.isEmpty() || line.startsWith("#")) continue
                if (exact.size >= MAX_ENTRIES) break
                val parts = line.split('\t')
                val number = parts[0].trim()
                if (!number.startsWith("+") || number.length < 8) continue
                val reports = parts.getOrNull(1)?.trim()?.toIntOrNull() ?: 1
                exact[number] = reports
                national[PhoneNumbers.lookupKey(number)] = reports
            }
        }
        Loaded(stamp, exact, national, date)
    } catch (_: Exception) {
        null
    }

    /**
     * How many times [number] was reported, or null when it isn't on the
     * list. A number in international form (+…, 00…) must match exactly;
     * one in local form matches on its last 9 digits.
     */
    fun reports(context: Context, number: String): Int? {
        val list = load(context) ?: return null
        var n = PhoneNumbersPrefix.normalize(PhoneNumbers.plain(number))
        if (n.startsWith("00")) n = "+" + n.drop(2)
        if (n.startsWith("+")) return list.exact[n]
        if (n.length < 7) return null
        return list.national[PhoneNumbers.lookupKey(n)]
    }

    /** For settings: the list's date and size. */
    fun info(context: Context): Map<String, Any?> {
        val list = load(context)
        return mapOf("date" to list?.date, "count" to (list?.exact?.size ?: 0), "mode" to mode(context))
    }
}
