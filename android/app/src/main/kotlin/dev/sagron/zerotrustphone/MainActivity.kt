package dev.sagron.zerotrustphone

import android.Manifest
import android.app.role.RoleManager
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.BlockedNumberContract
import android.provider.CallLog
import android.telecom.TelecomManager
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingDial = dialNumber(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val number = dialNumber(intent) ?: return
        val ch = channel
        if (ch != null) ch.invokeMethod("dial", number) else pendingDial = number
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
                    "hasPermission" -> result.success(
                        has(call.argument<String>("permission") ?: "")
                    )
                    "consumeDial" -> {
                        result.success(pendingDial)
                        pendingDial = null
                    }
                    "placeCall" -> {
                        placeCall(call.argument<String>("number") ?: "")
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

    private fun placeCall(number: String) {
        if (number.isBlank()) return
        val uri = Uri.fromParts("tel", number, null)
        if (has(Manifest.permission.CALL_PHONE)) {
            getSystemService(TelecomManager::class.java).placeCall(uri, Bundle())
        } else {
            // Without the permission, hand the number to the system dialer.
            startActivity(Intent(Intent.ACTION_DIAL, uri))
        }
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
    }
}
