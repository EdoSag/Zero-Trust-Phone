package dev.sagron.zerotrustphone

import android.Manifest
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.CallLog
import android.view.View
import android.widget.RemoteViews
import androidx.core.widget.RemoteViewsCompat
import org.json.JSONObject
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Recent calls on the home screen (W11): the latest calls from Android's
 * call log, or only the missed ones (tap the title to switch; each widget
 * remembers its choice). Tapping a call opens the dialpad with its number,
 * so a call never starts by accident; the dialpad button opens it empty.
 *
 * Off by default, like every Zero-Trust widget: until "Show details on the
 * home screen" is on in ZT Phone's settings, the widget shows a lock and
 * the number of new missed calls, nothing else. While it's on, the names
 * of ZT Contacts the app sends ([setDetails]) are kept unencrypted on this
 * phone for the widget; turning it off deletes them. Private contacts
 * (P23) never show.
 */
object RecentCallsWidget {
    private const val PREFS = "zt_recents_widget"
    private const val DETAILS = "details"
    private const val NAMES = "names"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun detailsOn(context: Context): Boolean = prefs(context).getBoolean(DETAILS, false)

    /** The switch in settings; [names] are lookup key -> contact name. */
    fun setDetails(context: Context, on: Boolean, names: Map<String, String>) {
        prefs(context).edit().apply {
            putBoolean(DETAILS, on)
            if (on) putString(NAMES, JSONObject(names).toString()) else remove(NAMES)
        }.apply()
        refresh(context)
    }

    internal fun names(context: Context): Map<String, String> {
        val raw = prefs(context).getString(NAMES, null) ?: return emptyMap()
        return try {
            val json = JSONObject(raw)
            json.keys().asSequence().associateWith { json.optString(it) }
        } catch (_: Exception) {
            emptyMap()
        }
    }

    internal fun missedOnly(context: Context, widgetId: Int): Boolean =
        prefs(context).getBoolean("missed_$widgetId", false)

    internal fun toggleMissed(context: Context, widgetId: Int) {
        prefs(context).edit().putBoolean("missed_$widgetId", !missedOnly(context, widgetId)).apply()
    }

    internal fun forget(context: Context, widgetIds: IntArray) {
        prefs(context).edit().apply { widgetIds.forEach { remove("missed_$it") } }.apply()
    }

    /** Redraws every recent calls widget (no-op when there are none). */
    fun refresh(context: Context) {
        val app = context.applicationContext
        val manager = AppWidgetManager.getInstance(app) ?: return
        val ids = manager.getAppWidgetIds(ComponentName(app, RecentCallsWidgetProvider::class.java))
        if (ids.isEmpty()) return
        ids.forEach { RecentCallsWidgetProvider.update(app, manager, it) }
    }

    /** After a call: Android writes the call log a moment after it ends. */
    fun refreshSoon(context: Context) {
        val app = context.applicationContext
        Handler(Looper.getMainLooper()).postDelayed({ refresh(app) }, 2500)
    }
}

class RecentCallsWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        newOptions: Bundle,
    ) {
        update(context, manager, widgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_SWITCH) {
            val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
            RecentCallsWidget.toggleMissed(context, id)
            update(context, AppWidgetManager.getInstance(context), id)
            return
        }
        super.onReceive(context, intent)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        super.onDeleted(context, ids)
        RecentCallsWidget.forget(context, ids)
    }

    /** One call log row as the widget needs it. */
    private data class Row(
        val id: Long,
        val number: String,
        val cachedName: String?,
        val type: Int,
        val date: Long,
        val hidden: Boolean,
    )

    companion object {
        const val ACTION_SWITCH = "dev.sagron.zerotrustphone.RECENTS_WIDGET_SWITCH"

        private fun text(context: Context, key: String, fallback: Int) =
            NativeStrings.get(context, key, fallback)

        private fun canRead(context: Context) =
            context.checkSelfPermission(Manifest.permission.READ_CALL_LOG) ==
                PackageManager.PERMISSION_GRANTED

        private fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
            context, 40,
            Intent(context, MainActivity::class.java)
                .setAction(MainActivity.ACTION_SHOW_RECENTS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        private fun openDialpad(context: Context): PendingIntent = PendingIntent.getActivity(
            context, 41,
            Intent(context, MainActivity::class.java)
                .setAction(Intent.ACTION_DIAL)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        /** Rows fill in their tel: number; mutable so they can. */
        private fun rowTemplate(context: Context, widgetId: Int): PendingIntent = PendingIntent.getActivity(
            context, 1000 + widgetId,
            Intent(context, MainActivity::class.java)
                .setAction(Intent.ACTION_DIAL)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )

        private fun newMissed(context: Context): Int {
            if (!canRead(context)) return 0
            return try {
                context.contentResolver.query(
                    CallLog.Calls.CONTENT_URI, arrayOf(CallLog.Calls._ID),
                    "${CallLog.Calls.TYPE} = ? AND ${CallLog.Calls.NEW} = 1",
                    arrayOf(CallLog.Calls.MISSED_TYPE.toString()), null,
                )?.use { it.count } ?: 0
            } catch (_: Exception) {
                0
            }
        }

        private fun calls(context: Context, missedOnly: Boolean): List<Row> {
            if (!canRead(context)) return emptyList()
            val store = ScreeningStore(context)
            val out = ArrayList<Row>()
            try {
                context.contentResolver.query(
                    CallLog.Calls.CONTENT_URI,
                    arrayOf(
                        CallLog.Calls._ID, CallLog.Calls.NUMBER, CallLog.Calls.CACHED_NAME,
                        CallLog.Calls.TYPE, CallLog.Calls.DATE, CallLog.Calls.NUMBER_PRESENTATION,
                    ),
                    if (missedOnly) "${CallLog.Calls.TYPE} = ?" else null,
                    if (missedOnly) arrayOf(CallLog.Calls.MISSED_TYPE.toString()) else null,
                    "${CallLog.Calls.DATE} DESC",
                )?.use { c ->
                    while (c.moveToNext() && out.size < RecentCallsWidgetRows.MAX) {
                        val number = c.getString(1) ?: ""
                        // A private contact's call (P23) is about to leave
                        // the call log; it never shows here.
                        if (number.isNotBlank() && store.isPrivate(number)) continue
                        out.add(
                            Row(
                                id = c.getLong(0),
                                number = number,
                                cachedName = c.getString(2),
                                type = c.getInt(3),
                                date = c.getLong(4),
                                hidden = c.getInt(5) != CallLog.Calls.PRESENTATION_ALLOWED,
                            )
                        )
                    }
                }
            } catch (_: Exception) {
                // No call log (permission taken away): an empty list.
            }
            return out
        }

        /** "14:05", "Yesterday", "3 Nov", in the app's language. */
        private fun whenText(context: Context, at: Long, now: Calendar): String {
            val then = Calendar.getInstance().apply { timeInMillis = at }
            val locale = NativeStrings.get(context, "widgetLocale", R.string.widget_locale)
                .let { Locale.forLanguageTag(it.replace('_', '-')) }
            val sameYear = then.get(Calendar.YEAR) == now.get(Calendar.YEAR)
            val days = now.get(Calendar.DAY_OF_YEAR) - then.get(Calendar.DAY_OF_YEAR)
            return when {
                sameYear && days == 0 -> DateFormat.getTimeInstance(DateFormat.SHORT, locale).format(then.time)
                sameYear && days == 1 -> text(context, "widgetYesterday", R.string.widget_yesterday)
                sameYear -> SimpleDateFormat("d MMM", locale).format(then.time)
                else -> DateFormat.getDateInstance(DateFormat.SHORT, locale).format(then.time)
            }
        }

        fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val missedOnly = RecentCallsWidget.missedOnly(context, widgetId)
            val detailsOn = RecentCallsWidget.detailsOn(context)
            val views = RemoteViews(context.packageName, R.layout.widget_recent_calls)

            views.setTextViewText(
                R.id.recents_title,
                if (missedOnly) text(context, "widgetMissed", R.string.widget_missed)
                else text(context, "widgetRecents", R.string.widget_recents),
            )
            views.setContentDescription(R.id.recents_switch, text(context, "widgetSwitchView", R.string.widget_switch_view))
            views.setContentDescription(R.id.recents_dialpad, text(context, "widgetDialpad", R.string.widget_dialpad))
            views.setOnClickPendingIntent(R.id.recents_app_icon, openApp(context))
            views.setOnClickPendingIntent(R.id.recents_dialpad, openDialpad(context))
            views.setOnClickPendingIntent(
                R.id.recents_switch,
                PendingIntent.getBroadcast(
                    context, widgetId,
                    Intent(context, RecentCallsWidgetProvider::class.java).apply {
                        action = ACTION_SWITCH
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        data = Uri.parse("ztphone://widget/$widgetId/switch")
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )

            if (!detailsOn) {
                views.setViewVisibility(R.id.recents_list, View.GONE)
                views.setViewVisibility(R.id.recents_empty, View.GONE)
                views.setViewVisibility(R.id.recents_locked, View.VISIBLE)
                val missed = newMissed(context)
                views.setViewVisibility(R.id.recents_missed_count, if (missed > 0) View.VISIBLE else View.GONE)
                views.setTextViewText(
                    R.id.recents_missed_count,
                    if (missed == 1) text(context, "nativeMissedCall", R.string.missed_call)
                    else NativeStrings.format(context, "nativeMissedCalls", R.string.missed_calls, missed),
                )
                views.setTextViewText(
                    R.id.recents_locked_text,
                    text(context, "widgetRecentsHidden", R.string.widget_recents_hidden),
                )
                views.setOnClickPendingIntent(R.id.recents_locked, openApp(context))
                // Drop rows an earlier update gave the list.
                RemoteViewsCompat.setRemoteAdapter(
                    context, views, widgetId, R.id.recents_list,
                    RemoteViewsCompat.RemoteCollectionItems.Builder().build(),
                )
                manager.updateAppWidget(widgetId, views)
                return
            }

            views.setViewVisibility(R.id.recents_locked, View.GONE)
            views.setViewVisibility(R.id.recents_list, View.VISIBLE)
            views.setTextViewText(
                R.id.recents_empty,
                if (!canRead(context)) text(context, "widgetOpenToAllow", R.string.widget_open_to_allow)
                else if (missedOnly) text(context, "widgetNoMissed", R.string.widget_no_missed)
                else text(context, "widgetNoCalls", R.string.widget_no_calls),
            )
            views.setEmptyView(R.id.recents_list, R.id.recents_empty)
            views.setPendingIntentTemplate(R.id.recents_list, rowTemplate(context, widgetId))

            val names = RecentCallsWidget.names(context)
            val privateNumber = text(context, "nativePrivateNumber", R.string.private_number)
            val now = Calendar.getInstance()
            val items = RemoteViewsCompat.RemoteCollectionItems.Builder()
                .setHasStableIds(true)
                .setViewTypeCount(1)
            for (call in calls(context, missedOnly)) {
                val missed = call.type == CallLog.Calls.MISSED_TYPE
                val shown = when {
                    call.hidden || call.number.isBlank() -> privateNumber
                    else -> names[PhoneNumbers.lookupKey(call.number)]
                        ?: call.cachedName?.takeIf { it.isNotBlank() }
                        ?: call.number
                }
                val row = RemoteViews(context.packageName, R.layout.widget_recent_calls_item).apply {
                    setImageViewResource(
                        R.id.call_row_type,
                        when (call.type) {
                            CallLog.Calls.OUTGOING_TYPE -> R.drawable.ic_widget_call_made
                            CallLog.Calls.INCOMING_TYPE, CallLog.Calls.ANSWERED_EXTERNALLY_TYPE,
                            CallLog.Calls.VOICEMAIL_TYPE -> R.drawable.ic_widget_call_received
                            else -> R.drawable.ic_widget_call_missed
                        },
                    )
                    if (missed) {
                        setInt(R.id.call_row_type, "setColorFilter", context.getColor(R.color.widget_missed))
                        setTextColor(R.id.call_row_name, context.getColor(R.color.widget_missed))
                    }
                    setTextViewText(R.id.call_row_name, shown)
                    setTextViewText(R.id.call_row_when, whenText(context, call.date, now))
                    if (!call.hidden && call.number.isNotBlank()) {
                        setOnClickFillInIntent(
                            R.id.call_row,
                            Intent().setData(Uri.fromParts("tel", call.number, null)),
                        )
                    }
                }
                items.addItem(call.id, row)
            }
            RemoteViewsCompat.setRemoteAdapter(context, views, widgetId, R.id.recents_list, items.build())
            manager.updateAppWidget(widgetId, views)
        }
    }
}

/** How many calls the widget lists. */
private object RecentCallsWidgetRows {
    const val MAX = 40
}
