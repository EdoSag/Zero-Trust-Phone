package dev.sagron.zerotrustphone

import android.content.Intent

/** When the in-call screen should come back to the front by itself. */
object CallScreenRules {
    /**
     * Unlocking during any call reopens the call screen. The screen turning
     * on (still locked) only does while a call rings: the call screen shows
     * over the lock screen, and a call in progress keeps its own screen.
     */
    fun reopenOn(action: String?, hasCalls: Boolean, ringing: Boolean): Boolean = when (action) {
        Intent.ACTION_USER_PRESENT -> hasCalls
        Intent.ACTION_SCREEN_ON -> ringing
        else -> false
    }
}
