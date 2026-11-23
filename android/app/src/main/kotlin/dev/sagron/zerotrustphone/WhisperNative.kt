// SPDX-License-Identifier: AGPL-3.0-only
package dev.sagron.zerotrustphone

/** The whisper.cpp engine in libzt_whisper.so (see android/whisper, the same as ZT Keyboard). Runs on the device only. */
internal object WhisperNative {
    val available: Boolean = try {
        System.loadLibrary("zt_whisper")
        true
    } catch (e: UnsatisfiedLinkError) {
        false
    }

    /** Loads a model file; 0 when it cannot be read. */
    @JvmStatic external fun open(modelPath: String): Long
    @JvmStatic external fun close(handle: Long)
    @JvmStatic external fun isMultilingual(handle: Long): Boolean

    /** Stops the [transcribe] that is running on another thread, and any later one until [allow]. */
    @JvmStatic external fun cancel(handle: Long)

    /** Takes back a [cancel]. */
    @JvmStatic external fun allow(handle: Long)

    /**
     * @param samples 16 kHz mono, -1..1
     * @param language a Whisper language code, or "auto"
     * @param prompt words the speaker is likely to say, or null
     * @param beamSize guesses followed at once; 1 takes the best guess at every step
     * @param audioContext how much of Whisper's 30 second window to work on, in fiftieths
     *   of a second, or 0 for all of it
     * @return the text as UTF-8, or null when it failed or was cancelled
     */
    @JvmStatic external fun transcribe(
        handle: Long, samples: FloatArray, count: Int, language: String, prompt: String?,
        threads: Int, beamSize: Int, audioContext: Int,
    ): ByteArray?
}
