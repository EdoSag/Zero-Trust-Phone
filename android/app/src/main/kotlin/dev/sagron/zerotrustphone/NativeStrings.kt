package dev.sagron.zerotrustphone

import android.content.Context

/**
 * Words ZT Phone shows outside Flutter (notifications, channels), in the
 * language picked in the app's settings. The app sends them on start and
 * on every language change (Telecom.setNativeStrings in Dart); until then
 * strings.xml gives the phone's own language.
 */
object NativeStrings {
    private const val FILE = "zt_native_strings"

    fun set(context: Context, strings: Map<String, String>) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().apply {
            clear()
            strings.forEach { (k, v) -> putString(k, v) }
        }.apply()
    }

    fun get(context: Context, key: String, fallback: Int): String =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getString(key, null)
            ?: context.getString(fallback)

    /** [get] with %s / %d filled in. */
    fun format(context: Context, key: String, fallback: Int, vararg args: Any): String =
        String.format(get(context, key, fallback), *args)
}
