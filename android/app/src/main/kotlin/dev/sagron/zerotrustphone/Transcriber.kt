// SPDX-License-Identifier: AGPL-3.0-only
package dev.sagron.zerotrustphone

import android.util.Log
import java.io.File
import kotlin.math.abs

/**
 * Turns a recorded call or a voicemail into text on the phone (P20, P21),
 * with whisper.cpp and a model from [SpeechModels]. Long audio is cut into
 * pieces of under 30 seconds (Whisper's window) at the quietest moment near
 * each cut, so words aren't split. One transcript at a time.
 */
object Transcriber {
    private const val TAG = "Transcriber"
    const val SAMPLE_RATE = 16_000
    private const val PIECE = 28 * SAMPLE_RATE
    private const val LOOK_BACK = 4 * SAMPLE_RATE
    private const val STEP = SAMPLE_RATE / 10

    private val lock = Any()
    private var handle = 0L
    private var loadedPath: String? = null
    @Volatile private var cancelled = false

    val available: Boolean get() = WhisperNative.available

    /** Where to cut [samples] after [from]: the quietest tenth of a second
     *  in the last few seconds before a full piece. */
    fun cutAfter(samples: FloatArray, from: Int): Int {
        val end = from + PIECE
        if (end >= samples.size) return samples.size
        var best = end
        var bestLevel = Float.MAX_VALUE
        var at = end - LOOK_BACK
        while (at + STEP <= end) {
            var sum = 0f
            for (i in at until at + STEP) sum += abs(samples[i])
            if (sum < bestLevel) { bestLevel = sum; best = at + STEP / 2 }
            at += STEP
        }
        return best
    }

    /**
     * The text of [samples] (16 kHz mono, -1..1) in [language] (a Whisper
     * code, or "auto"), or null when there's no model, it failed or was
     * cancelled. Background thread; [onProgress] gets 0..100.
     */
    fun transcribe(model: File, samples: FloatArray, language: String, onProgress: (Int) -> Unit = {}): String? =
        synchronized(lock) {
            if (!available) return null
            cancelled = false
            try {
                if (handle == 0L || loadedPath != model.path) {
                    close()
                    handle = WhisperNative.open(model.path)
                    if (handle == 0L) return null
                    loadedPath = model.path
                }
                WhisperNative.allow(handle)
                val code = if (WhisperNative.isMultilingual(handle)) language else "en"
                val threads = (Runtime.getRuntime().availableProcessors() / 2).coerceIn(2, 6)
                val out = StringBuilder()
                var from = 0
                while (from < samples.size) {
                    if (cancelled) return null
                    val to = cutAfter(samples, from)
                    val piece = samples.copyOfRange(from, to)
                    // A silent piece (hold music stopped, a pause) isn't sent to Whisper,
                    // which makes words up for silence.
                    if (piece.any { abs(it) > 0.01f }) {
                        val bytes = WhisperNative.transcribe(handle, piece, piece.size, code, null, threads, 1, 0)
                            ?: return null
                        val text = clean(bytes.toString(Charsets.UTF_8))
                        if (text.isNotEmpty()) {
                            if (out.isNotEmpty()) out.append(' ')
                            out.append(text)
                        }
                    }
                    from = to
                    onProgress((from * 100L / samples.size).toInt())
                }
                out.toString()
            } catch (t: Throwable) {
                Log.w(TAG, "transcription failed", t)
                null
            }
        }

    /** Stops the transcript that's running. */
    fun cancel() {
        cancelled = true
        val h = handle
        if (h != 0L) WhisperNative.cancel(h)
    }

    /** Frees the model (hundreds of MB), e.g. before it's deleted. */
    fun release() {
        cancel()
        synchronized(lock) { close() }
    }

    private fun close() {
        if (handle != 0L) WhisperNative.close(handle)
        handle = 0L
        loadedPath = null
    }

    private val NOISE = Regex("""\[[^\]]*]|\([^)]*\)|♪+""")

    /** Without Whisper's notes about sounds ("[BLANK_AUDIO]", "(music)"). */
    fun clean(heard: String): String = heard.replace(NOISE, " ").replace(Regex("""\s+"""), " ").trim()

    /** PCM16 to Whisper's floats. */
    fun toFloats(samples: ShortArray, count: Int = samples.size): FloatArray =
        FloatArray(count) { samples[it] / 32768f }
}
