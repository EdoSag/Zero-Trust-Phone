package dev.sagron.zerotrustphone

import android.os.Handler
import android.os.Looper
import android.telecom.Call
import io.flutter.plugin.common.EventChannel
import java.io.IOException

/**
 * Real-time text (RTT, P12): the other person's typing arrives a few
 * letters at a time on [Call.RttCall]. Each RTT stream gets a reader
 * thread that hands the text to the call screen over `zt_phone/rtt_text`.
 * Text is never written to disk; it lives only in the call screen.
 */
object RttSessions {
    private val main = Handler(Looper.getMainLooper())
    private val readers = mutableMapOf<Call.RttCall, Thread>()
    private var sink: EventChannel.EventSink? = null

    /** Text that arrived while the call screen wasn't listening. */
    private val pending = ArrayDeque<Map<String, Any?>>()

    fun setSink(events: EventChannel.EventSink?) {
        sink = events
        if (events != null) {
            while (pending.isNotEmpty()) events.success(pending.removeFirst())
        }
    }

    /** Starts reading [call]'s RTT stream, once per stream. */
    fun start(call: Call, id: String) {
        val rtt = call.rttCall ?: return
        if (readers.containsKey(rtt)) return
        val reader = Thread({
            try {
                while (true) {
                    // Blocks until text arrives; null once the stream closes.
                    val text = rtt.read() ?: break
                    main.post { emit(id, text) }
                }
            } catch (_: IOException) {
            } catch (_: RuntimeException) {
            } finally {
                main.post { readers.remove(rtt) }
            }
        }, "zt-rtt-$id")
        reader.isDaemon = true
        readers[rtt] = reader
        reader.start()
    }

    /** Sends [text] (letters, "\b" to erase, "\n" to end a line) as typed. */
    fun write(call: Call, text: String): Boolean {
        val rtt = call.rttCall ?: return false
        return try {
            rtt.write(text)
            true
        } catch (_: IOException) {
            false
        }
    }

    private fun emit(id: String, text: String) {
        val event = mapOf("id" to id, "text" to text)
        val out = sink
        if (out != null) {
            out.success(event)
        } else {
            pending.addLast(event)
            while (pending.size > 2000) pending.removeFirst()
        }
    }

    /** The call ended: drop text nobody read. */
    fun clear(id: String) {
        pending.removeAll { it["id"] == id }
    }
}
