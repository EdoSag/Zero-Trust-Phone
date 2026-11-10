package dev.sagron.zerotrustphone

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.PowerManager
import android.telecom.CallAudioState
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * The in-call screen. Shows over the lock screen, turns the screen on for
 * an incoming call, and turns it off near the ear (proximity) while the
 * call uses the earpiece.
 */
class CallActivity : FlutterActivity() {
    private var proximity: PowerManager.WakeLock? = null
    private val listener = CallManager.Listener { state -> onCallsChanged(state) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        CallEngine.activity = this
        handle(intent)
        CallManager.addListener(listener)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    override fun onDestroy() {
        CallManager.removeListener(listener)
        releaseProximity()
        if (CallEngine.activity === this) CallEngine.activity = null
        super.onDestroy()
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine = CallEngine.ensure(context)

    // The engine outlives the screen, ready for the next call.
    override fun shouldDestroyEngineWithHost(): Boolean = false

    private fun handle(intent: Intent?) {
        if (intent?.action == ACTION_ANSWER) CallManager.answer(null)
    }

    /** Opens the dialpad of the main app, to add a second call. */
    fun addCall() {
        startActivity(
            Intent(this, MainActivity::class.java)
                .setAction(Intent.ACTION_DIAL)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    @Suppress("DEPRECATION")
    private fun onCallsChanged(state: Map<String, Any?>) {
        val calls = state["calls"] as? List<*> ?: emptyList<Any>()
        if (calls.isEmpty()) {
            releaseProximity()
            return
        }
        val earpiece = CallManager.audioState?.route == CallAudioState.ROUTE_EARPIECE
        val live = calls.any { (it as? Map<*, *>)?.get("state") in setOf("active", "dialing", "connecting") }
        if (earpiece && live) acquireProximity() else releaseProximity()
    }

    private fun acquireProximity() {
        if (proximity?.isHeld == true) return
        val pm = getSystemService(PowerManager::class.java)
        if (!pm.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) return
        proximity = pm.newWakeLock(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, "ztphone:proximity")
            .also { it.acquire(4 * 60 * 60 * 1000L) }
    }

    private fun releaseProximity() {
        proximity?.let { if (it.isHeld) it.release() }
        proximity = null
    }

    companion object {
        const val ACTION_ANSWER = "dev.sagron.zerotrustphone.ANSWER"

        fun start(context: Context) {
            context.startActivity(
                Intent(context, CallActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }
}
