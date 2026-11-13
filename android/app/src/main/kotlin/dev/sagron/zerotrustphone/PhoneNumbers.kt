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
     * `lookupKey` in lib/util/phone_numbers.dart. Pauses and tones dialled
     * after the number (",,1234#") aren't part of it.
     */
    fun lookupKey(number: String): String {
        val post = number.indexOfFirst { it == ',' || it == ';' }
        val digits = (if (post < 0) number else number.substring(0, post)).filter { it.isDigit() }
        return if (digits.length > 9) digits.takeLast(9) else digits
    }
}

/**
 * The number a call is with, without the hide-my-number code in front
 * (P22) or the pauses and tones after it (P15): what the call screen shows
 * and what a quick reply texts.
 */
fun PhoneNumbers.plain(dialled: String): String {
    var n = dialled.substringBefore(',').substringBefore(';').trim()
    for (code in listOf("#31#", "*31#", "*67")) {
        if (n.startsWith(code) && n.drop(code.length).count { it.isDigit() } >= 5) {
            n = n.drop(code.length)
            break
        }
    }
    return n
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
