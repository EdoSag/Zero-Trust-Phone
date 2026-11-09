package dev.sagron.zerotrustphone

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.ContactsContract

object PhoneNumbers {
    /**
     * The key two spellings of one number share: its last 9 digits, so
     * "+44 7700 900123" and "07700 900123" match. Must stay the same as
     * `lookupKey` in lib/util/phone_numbers.dart.
     */
    fun lookupKey(number: String): String {
        val digits = number.filter { it.isDigit() }
        return if (digits.length > 9) digits.takeLast(9) else digits
    }
}

object SystemContacts {
    /** The name the phone's own contacts give [number], when allowed to read them. */
    fun lookupName(context: Context, number: String): String? {
        if (context.checkSelfPermission(Manifest.permission.READ_CONTACTS) !=
            PackageManager.PERMISSION_GRANTED
        ) return null
        val uri = Uri.withAppendedPath(
            ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(number)
        )
        return try {
            context.contentResolver.query(
                uri, arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME), null, null, null
            )?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
        } catch (_: Exception) {
            null
        }
    }
}
