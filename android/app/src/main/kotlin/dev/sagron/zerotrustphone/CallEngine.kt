package dev.sagron.zerotrustphone

import android.content.Context
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * The in-call screen's Flutter engine. It runs `callMain` in
 * lib/main.dart, a small app with only the call screen: no account, no
 * vault, so it opens straight away over the lock screen.
 */
object CallEngine {
    private const val ID = "zt_call_engine"
    var activity: CallActivity? = null

    fun ensure(context: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(ID)?.let { return it }
        val engine = FlutterEngine(context.applicationContext)
        val loader = FlutterInjector.instance().flutterLoader()
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "callMain")
        )
        wire(engine)
        FlutterEngineCache.getInstance().put(ID, engine)
        return engine
    }

    private fun wire(engine: FlutterEngine) {
        val messenger = engine.dartExecutor.binaryMessenger
        EventChannel(messenger, "zt_phone/call_state").setStreamHandler(
            object : EventChannel.StreamHandler {
                private var listener: CallManager.Listener? = null
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    val l = CallManager.Listener { state -> events.success(state) }
                    listener = l
                    CallManager.addListener(l)
                }

                override fun onCancel(arguments: Any?) {
                    listener?.let { CallManager.removeListener(it) }
                    listener = null
                }
            }
        )
        MethodChannel(messenger, "zt_phone/call_control").setMethodCallHandler { call, result ->
            val id = call.argument<String>("id")
            when (call.method) {
                "answer" -> CallManager.answer(id)
                "reject" -> CallManager.reject(id)
                "hangUp" -> CallManager.hangUp(id)
                "hold" -> CallManager.hold(id, call.argument<Boolean>("on") ?: true)
                "swap" -> CallManager.swap()
                "merge" -> CallManager.merge()
                "dtmf" -> call.argument<String>("digit")?.firstOrNull()?.let { CallManager.dtmf(it) }
                "mute" -> CallManager.setMuted(call.argument<Boolean>("on") ?: false)
                "route" -> CallManager.setRoute(call.argument<Int>("route") ?: 0)
                "close" -> activity?.finishAndRemoveTask()
                "addCall" -> activity?.addCall()
                else -> {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
            }
            result.success(null)
        }
    }
}
