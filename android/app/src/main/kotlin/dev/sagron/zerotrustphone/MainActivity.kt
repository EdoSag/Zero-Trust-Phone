package dev.sagron.zerotrustphone

import android.Manifest
import android.app.role.RoleManager
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.BlockedNumberContract
import android.media.RingtoneManager
import android.provider.CallLog
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The dialer: Favorites, Recents, Contacts and the dialpad, behind the
 * shared Zero-Trust sign-in and lock. Talks to Android's phone APIs over
 * the `zt_phone/telecom` channel.
 */
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var pendingRole: MethodChannel.Result? = null
    private var pendingPermissions: MethodChannel.Result? = null

    /** A number from a DIAL / tel: intent, "" for an empty dialpad. */
    private var pendingDial: String? = null

    /** Opened from the missed-call notification. */
    private var pendingRecents = false
    private var pendingRingtone: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingDial = dialNumber(intent)
        pendingRecents = intent?.action == ACTION_SHOW_RECENTS
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == ACTION_SHOW_RECENTS) {
            pendingRecents = true
            channel?.invokeMethod("recentsPending", null)
            return
        }
        // Kept until the unlocked dialer takes it (consumeDial), so a number
        // that arrives while the vault is locked isn't lost.
        pendingDial = dialNumber(intent) ?: return
        channel?.invokeMethod("dialPending", null)
    }

    private fun dialNumber(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_DIAL && intent.action != Intent.ACTION_VIEW) return null
        val data = intent.data ?: return ""
        return if (data.scheme == "tel") Uri.decode(data.schemeSpecificPart) else ""
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zt_phone/telecom")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "isDefaultDialer" -> result.success(isDefaultDialer())
                    "requestDefaultDialer" -> requestDefaultDialer(result)
                    "requestPermissions" -> requestPhonePermissions(result)
                    "callAlertsReady" -> {
                        CallNotifications.createChannels(this)
                        result.success(CallNotifications.alertsReady(this))
                    }
                    "fixCallAlerts" -> {
                        fixCallAlerts()
                        result.success(null)
                    }
                    "hasPermission" -> result.success(
                        has(call.argument<String>("permission") ?: "")
                    )
                    "consumeDial" -> {
                        result.success(pendingDial)
                        pendingDial = null
                    }
                    "placeCall" -> {
                        placeCall(call.argument<String>("number") ?: "", call.argument<String>("account"))
                        result.success(null)
                    }
                    "callVoicemail" -> {
                        callVoicemail()
                        result.success(null)
                    }
                    "consumeShowRecents" -> {
                        result.success(pendingRecents)
                        pendingRecents = false
                    }
                    "phoneAccounts" -> result.success(phoneAccounts())
                    "setScreening" -> {
                        @Suppress("UNCHECKED_CAST")
                        ScreeningStore(this).update(
                            unknownMode = call.argument<String>("unknownMode") ?: "ring",
                            blockHidden = call.argument<Boolean>("blockHidden") ?: false,
                            prefixes = call.argument<List<String>>("prefixes") ?: emptyList(),
                            contactKeys = call.argument<List<String>>("contactKeys") ?: emptyList(),
                            voicemailKeys = call.argument<List<String>>("voicemailKeys") ?: emptyList(),
                            ringtones = call.argument<Map<String, String>>("ringtones") ?: emptyMap(),
                        )
                        result.success(null)
                    }
                    "clearScreeningContacts" -> {
                        ScreeningStore(this).clearContacts()
                        result.success(null)
                    }
                    "insertCalls" -> result.success(
                        insertCalls(call.argument<List<Map<String, Any?>>>("calls") ?: emptyList())
                    )
                    "pickRingtone" -> pickRingtone(call.argument<String>("current"), result)
                    "ringtoneTitle" -> result.success(
                        call.argument<String>("uri")?.let { uri ->
                            try {
                                RingtoneManager.getRingtone(this, Uri.parse(uri))?.getTitle(this)
                            } catch (_: Exception) {
                                null
                            }
                        }
                    )
                    "addContact" -> {
                        startActivity(MissedCallReceiver.addContactIntent(call.argument<String>("number") ?: ""))
                        result.success(null)
                    }
                    "voicemailSettings" -> {
                        startActivity(
                            Intent(TelephonyManager.ACTION_CONFIGURE_VOICEMAIL)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    "callLog" -> result.success(callLog(call.argument<Int>("limit") ?: 500))
                    "deleteCalls" -> result.success(
                        deleteCalls(call.argument<List<Any>>("ids") ?: emptyList())
                    )
                    "deleteCallsBefore" -> result.success(
                        deleteCallsBefore((call.argument<Number>("before") ?: 0).toLong())
                    )
                    "markMissedSeen" -> {
                        markMissedSeen()
                        result.success(null)
                    }
                    "canBlock" -> result.success(
                        BlockedNumberContract.canCurrentUserBlockNumbers(this)
                    )
                    "blockedNumbers" -> result.success(blockedNumbers())
                    "block" -> {
                        block(call.argument<String>("number") ?: "")
                        result.success(null)
                    }
                    "unblock" -> {
                        BlockedNumberContract.unblock(this, call.argument<String>("number") ?: "")
                        result.success(null)
                    }
                    "setVaultNames" -> {
                        @Suppress("UNCHECKED_CAST")
                        CallManager.setVaultNames(call.arguments as? Map<String, String> ?: emptyMap())
                        result.success(null)
                    }
                    "clearVaultNames" -> {
                        CallManager.clearVaultNames()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: SecurityException) {
                result.error("permission", e.message, null)
            } catch (e: Exception) {
                result.error("failed", e.message, null)
            }
        }
    }

    private fun has(permission: String) =
        checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun isDefaultDialer(): Boolean =
        getSystemService(RoleManager::class.java).isRoleHeld(RoleManager.ROLE_DIALER)

    private fun requestDefaultDialer(result: MethodChannel.Result) {
        val roles = getSystemService(RoleManager::class.java)
        if (!roles.isRoleAvailable(RoleManager.ROLE_DIALER)) {
            result.success(false)
            return
        }
        if (roles.isRoleHeld(RoleManager.ROLE_DIALER)) {
            result.success(true)
            return
        }
        pendingRole?.success(false)
        pendingRole = result
        @Suppress("DEPRECATION")
        startActivityForResult(roles.createRequestRoleIntent(RoleManager.ROLE_DIALER), REQUEST_ROLE)
    }

    private val phonePermissions = arrayOf(
        Manifest.permission.CALL_PHONE,
        Manifest.permission.READ_CALL_LOG,
        Manifest.permission.WRITE_CALL_LOG,
        Manifest.permission.READ_PHONE_STATE,
        Manifest.permission.READ_CONTACTS,
    ) + if (android.os.Build.VERSION.SDK_INT >= 33) {
        arrayOf(Manifest.permission.POST_NOTIFICATIONS)
    } else {
        emptyArray()
    }

    /** Opens the screen that turns call notifications back on. */
    private fun fixCallAlerts() {
        val nm = getSystemService(android.app.NotificationManager::class.java)
        val channelBlocked = nm.getNotificationChannel(CallNotifications.INCOMING)
            ?.importance == android.app.NotificationManager.IMPORTANCE_NONE
        val notificationsOn = androidx.core.app.NotificationManagerCompat.from(this)
            .areNotificationsEnabled() && !channelBlocked
        // Only the full-screen permission is missing: open its own screen.
        // Otherwise (app or "Incoming calls" notifications off) open the
        // app's notification settings.
        val intent = if (notificationsOn && android.os.Build.VERSION.SDK_INT >= 34 &&
            !nm.canUseFullScreenIntent()) {
            Intent(android.provider.Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
                .setData(Uri.fromParts("package", packageName, null))
        } else {
            Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
        }
        try {
            startActivity(intent)
        } catch (_: android.content.ActivityNotFoundException) {
            startActivity(
                Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.fromParts("package", packageName, null))
            )
        }
    }

    private fun requestPhonePermissions(result: MethodChannel.Result) {
        val missing = phonePermissions.filterNot { has(it) }
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        pendingPermissions?.success(false)
        pendingPermissions = result
        requestPermissions(missing.toTypedArray(), REQUEST_PERMISSIONS)
    }

    @Deprecated("Deprecated in Java")
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_ROLE) {
            pendingRole?.success(isDefaultDialer())
            pendingRole = null
        }
        if (requestCode == REQUEST_RINGTONE) {
            val picked: Uri? = if (resultCode == RESULT_OK) {
                data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            } else {
                null
            }
            // "" means the phone's default ringtone; null means cancelled.
            pendingRingtone?.success(
                if (resultCode == RESULT_OK) picked?.toString() ?: "" else null
            )
            pendingRingtone = null
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_PERMISSIONS) {
            pendingPermissions?.success(phonePermissions.all { has(it) })
            pendingPermissions = null
        }
    }

    private fun placeCall(number: String, accountId: String? = null) {
        if (number.isBlank()) return
        val uri = Uri.fromParts("tel", number, null)
        if (has(Manifest.permission.CALL_PHONE)) {
            val extras = Bundle()
            // The contact's SIM (P6), when this phone still has it.
            accountFor(accountId)?.let {
                extras.putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, it)
            }
            getSystemService(TelecomManager::class.java).placeCall(uri, extras)
        } else {
            // Without the permission, hand the number to the system dialer.
            startActivity(Intent(Intent.ACTION_DIAL, uri))
        }
    }

    private fun callVoicemail() {
        val uri = Uri.fromParts("voicemail", "", null)
        if (has(Manifest.permission.CALL_PHONE)) {
            getSystemService(TelecomManager::class.java).placeCall(uri, Bundle())
        } else {
            startActivity(Intent(Intent.ACTION_DIAL, uri))
        }
    }

    private fun callAccounts(): List<PhoneAccountHandle> = try {
        getSystemService(TelecomManager::class.java).callCapablePhoneAccounts
    } catch (_: SecurityException) {
        emptyList()
    }

    private fun accountFor(id: String?): PhoneAccountHandle? =
        if (id.isNullOrEmpty()) null else callAccounts().firstOrNull { it.id == id }

    /** The SIMs (and other calling accounts) this phone can call with. */
    private fun phoneAccounts(): List<Map<String, String>> {
        val telecom = getSystemService(TelecomManager::class.java)
        return callAccounts().map { handle ->
            mapOf(
                "id" to handle.id,
                "label" to (telecom.getPhoneAccount(handle)?.label?.toString() ?: "SIM"),
            )
        }
    }

    private fun pickRingtone(current: String?, result: MethodChannel.Result) {
        pendingRingtone?.success(null)
        pendingRingtone = result
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER)
            .putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_RINGTONE)
            .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
        if (!current.isNullOrEmpty()) {
            intent.putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(current))
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_RINGTONE)
    }

    /** Puts backed-up calls into Android's call history, skipping ones it has. */
    private fun insertCalls(rows: List<Map<String, Any?>>): Int {
        if (rows.isEmpty() || !has(Manifest.permission.WRITE_CALL_LOG)) return 0
        val existing = HashSet<String>()
        contentResolver.query(
            CallLog.Calls.CONTENT_URI,
            arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.DATE), null, null, null
        )?.use { c ->
            while (c.moveToNext()) existing.add("${PhoneNumbers.lookupKey(c.getString(0) ?: "")}|${c.getLong(1) / 1000}")
        }
        var added = 0
        for (row in rows) {
            val number = row["number"] as? String ?: continue
            val date = (row["date"] as? Number)?.toLong() ?: continue
            if (!existing.add("${PhoneNumbers.lookupKey(number)}|${date / 1000}")) continue
            val values = ContentValues().apply {
                put(CallLog.Calls.NUMBER, number)
                put(CallLog.Calls.TYPE, (row["type"] as? Number)?.toInt() ?: CallLog.Calls.INCOMING_TYPE)
                put(CallLog.Calls.DATE, date)
                put(CallLog.Calls.DURATION, (row["duration"] as? Number)?.toLong() ?: 0L)
                put(CallLog.Calls.NEW, 0)
                put(CallLog.Calls.IS_READ, 1)
            }
            if (contentResolver.insert(CallLog.Calls.CONTENT_URI, values) != null) added++
        }
        return added
    }

    private fun callLog(limit: Int): List<Map<String, Any?>> {
        if (!has(Manifest.permission.READ_CALL_LOG)) return emptyList()
        val out = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            CallLog.Calls._ID,
            CallLog.Calls.NUMBER,
            CallLog.Calls.TYPE,
            CallLog.Calls.DATE,
            CallLog.Calls.DURATION,
            CallLog.Calls.CACHED_NAME,
            CallLog.Calls.NEW,
        )
        val uri = CallLog.Calls.CONTENT_URI.buildUpon()
            .appendQueryParameter(CallLog.Calls.LIMIT_PARAM_KEY, limit.toString())
            .build()
        contentResolver.query(uri, projection, null, null, "${CallLog.Calls.DATE} DESC")?.use { c ->
            while (c.moveToNext()) {
                out.add(
                    mapOf(
                        "id" to c.getLong(0),
                        "number" to (c.getString(1) ?: ""),
                        "type" to c.getInt(2),
                        "date" to c.getLong(3),
                        "duration" to c.getLong(4),
                        "cachedName" to c.getString(5),
                        "isNew" to (c.getInt(6) == 1),
                    )
                )
            }
        }
        return out
    }

    private fun deleteCalls(ids: List<Any>): Int {
        if (ids.isEmpty() || !has(Manifest.permission.WRITE_CALL_LOG)) return 0
        val list = ids.map { (it as Number).toLong() }
        val placeholders = list.joinToString(",") { "?" }
        return contentResolver.delete(
            CallLog.Calls.CONTENT_URI,
            "${CallLog.Calls._ID} IN ($placeholders)",
            list.map { it.toString() }.toTypedArray()
        )
    }

    private fun deleteCallsBefore(before: Long): Int {
        if (before <= 0 || !has(Manifest.permission.WRITE_CALL_LOG)) return 0
        return contentResolver.delete(
            CallLog.Calls.CONTENT_URI, "${CallLog.Calls.DATE} < ?", arrayOf(before.toString())
        )
    }

    private fun markMissedSeen() {
        if (isDefaultDialer()) {
            try {
                getSystemService(TelecomManager::class.java).cancelMissedCallsNotification()
            } catch (_: SecurityException) {
            }
        }
        if (!has(Manifest.permission.WRITE_CALL_LOG)) return
        val values = ContentValues().apply {
            put(CallLog.Calls.NEW, 0)
            put(CallLog.Calls.IS_READ, 1)
        }
        contentResolver.update(
            CallLog.Calls.CONTENT_URI, values,
            "${CallLog.Calls.TYPE} = ? AND ${CallLog.Calls.NEW} = 1",
            arrayOf(CallLog.Calls.MISSED_TYPE.toString())
        )
    }

    private fun blockedNumbers(): List<String> {
        if (!BlockedNumberContract.canCurrentUserBlockNumbers(this)) return emptyList()
        val out = mutableListOf<String>()
        contentResolver.query(
            BlockedNumberContract.BlockedNumbers.CONTENT_URI,
            arrayOf(BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER),
            null, null, null
        )?.use { c -> while (c.moveToNext()) c.getString(0)?.let { out.add(it) } }
        return out
    }

    private fun block(number: String) {
        if (number.isBlank()) return
        val values = ContentValues().apply {
            put(BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER, number)
        }
        contentResolver.insert(BlockedNumberContract.BlockedNumbers.CONTENT_URI, values)
    }

    companion object {
        private const val REQUEST_ROLE = 3101
        private const val REQUEST_PERMISSIONS = 3102
        private const val REQUEST_RINGTONE = 3103
        const val ACTION_SHOW_RECENTS = "dev.sagron.zerotrustphone.SHOW_RECENTS"
    }
}
