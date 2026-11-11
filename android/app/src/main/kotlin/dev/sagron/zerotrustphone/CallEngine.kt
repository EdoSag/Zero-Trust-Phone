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
        // Carrier video calls draw into textures of this engine.
        VideoSessions.textures = engine.renderer
        EventChannel(messenger, "zt_phone/rtt_text").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    RttSessions.setSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    RttSessions.setSink(null)
                }
            }
        )
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
            if (call.method == "requestCamera") {
                val screen = activity
                if (screen == null) result.success(false) else screen.requestCamera(result)
                return@setMethodCallHandler
            }
            when (call.method) {
                "answer" -> CallManager.answer(id)
                "answerVideo" -> CallManager.answerVideo(id)
                "rttRequest" -> CallManager.rttRequest(id)
                "rttRespond" -> CallManager.rttRespond(id, call.argument<Boolean>("accept") ?: false)
                "rttStop" -> CallManager.rttStop(id)
                "rttWrite" -> CallManager.rttWrite(id, call.argument<String>("text") ?: "")
                "videoRequest" -> CallManager.videoRequest(id)
                "videoStop" -> CallManager.videoStop(id)
                "videoCamera" -> CallManager.videoCamera(id, call.argument<Boolean>("on") ?: true)
                "videoSwitchCamera" -> CallManager.videoSwitchCamera(id)
                "videoRespond" -> CallManager.videoRespond(id, call.argument<Boolean>("accept") ?: false)
                "reject" -> CallManager.reject(id)
                "rejectWithMessage" -> CallManager.rejectWithMessage(id, call.argument<String>("message") ?: "")
                "endAndAnswer" -> CallManager.endAndAnswer(id)
                "hangUp" -> CallManager.hangUp(id)
                "hold" -> CallManager.hold(id, call.argument<Boolean>("on") ?: true)
                "swap" -> CallManager.swap()
                "merge" -> CallManager.merge()
                "dtmf" -> call.argument<String>("digit")?.firstOrNull()?.let { CallManager.dtmf(it) }
                "mute" -> CallManager.setMuted(call.argument<Boolean>("on") ?: false)
                "route" -> CallManager.setRoute(call.argument<Int>("route") ?: 0)
                "selectAccount" -> CallManager.selectAccount(id, call.argument<Int>("index") ?: 0)
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
