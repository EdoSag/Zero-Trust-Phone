// SPDX-License-Identifier: AGPL-3.0-only
package dev.sagron.zerotrustphone

import android.content.ContentUris
import android.content.Context
import android.media.AudioAttributes
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaPlayer
import android.net.Uri
import android.provider.VoicemailContract
import java.nio.ByteOrder

/**
 * Visual voicemail (P21): the messages Android keeps in its voicemail
 * store, which the default Phone app may read. They're there only when the
 * carrier offers visual voicemail and its client on the phone saves them
 * (many carriers don't; then voicemail stays a number to call).
 * Transcripts are made on the phone with [Transcriber]; nothing is sent.
 */
object Voicemails {
    fun list(context: Context): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        try {
            context.contentResolver.query(
                VoicemailContract.Voicemails.CONTENT_URI,
                arrayOf(
                    VoicemailContract.Voicemails._ID,
                    VoicemailContract.Voicemails.NUMBER,
                    VoicemailContract.Voicemails.DATE,
                    VoicemailContract.Voicemails.DURATION,
                    VoicemailContract.Voicemails.HAS_CONTENT,
                    VoicemailContract.Voicemails.IS_READ,
                    VoicemailContract.Voicemails.TRANSCRIPTION,
                ),
                "${VoicemailContract.Voicemails.DELETED} = 0",
                null,
                "${VoicemailContract.Voicemails.DATE} DESC",
            )?.use { c ->
                while (c.moveToNext() && out.size < 200) {
                    val number = c.getString(1) ?: ""
                    out.add(
                        mapOf(
                            "id" to c.getLong(0),
                            "number" to number,
                            "name" to number.takeIf { it.isNotBlank() }?.let { CallManager.nameFor(context, it) },
                            "date" to c.getLong(2),
                            "seconds" to c.getLong(3),
                            "hasAudio" to (c.getInt(4) == 1),
                            "read" to (c.getInt(5) == 1),
                            "carrierText" to c.getString(6),
                        )
                    )
                }
            }
        } catch (_: Exception) {
            // No voicemail store, or not the default Phone app.
        }
        return out
    }

    private fun uri(id: Long): Uri = ContentUris.withAppendedId(VoicemailContract.Voicemails.CONTENT_URI, id)

    private var player: MediaPlayer? = null

    fun play(context: Context, id: Long, onDone: () -> Unit): Boolean {
        stop()
        return try {
            val p = MediaPlayer()
            p.setAudioAttributes(
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
            )
            p.setDataSource(context, uri(id))
            p.setOnCompletionListener { stop(); onDone() }
            p.prepare()
            p.start()
            player = p
            markRead(context, id)
            true
        } catch (_: Exception) {
            stop()
            false
        }
    }

    fun stop() {
        player?.let { try { it.stop() } catch (_: Exception) {}; it.release() }
        player = null
    }

    private fun markRead(context: Context, id: Long) {
        try {
            context.contentResolver.update(
                uri(id),
                android.content.ContentValues().apply { put(VoicemailContract.Voicemails.IS_READ, 1) },
                null, null,
            )
        } catch (_: Exception) {
        }
    }

    /** The message as Whisper wants it (16 kHz mono), or null. Background thread. */
    fun samples(context: Context, id: Long): FloatArray? = try {
        context.contentResolver.openFileDescriptor(uri(id), "r")?.use { fd ->
            val extractor = MediaExtractor()
            try {
                extractor.setDataSource(fd.fileDescriptor)
                decode(extractor)
            } finally {
                extractor.release()
            }
        }
    } catch (_: Exception) {
        null
    }

    /** Decodes the first audio track to mono PCM and resamples it to 16 kHz. */
    private fun decode(extractor: MediaExtractor): FloatArray? {
        val track = (0 until extractor.trackCount).firstOrNull {
            extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
        } ?: return null
        extractor.selectTrack(track)
        val format = extractor.getTrackFormat(track)
        val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
        codec.configure(format, null, null, 0)
        codec.start()
        var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        var mono = FloatArray(1 shl 16)
        var count = 0
        val info = MediaCodec.BufferInfo()
        var inputDone = false
        try {
            while (true) {
                if (!inputDone) {
                    val i = codec.dequeueInputBuffer(10_000)
                    if (i >= 0) {
                        val n = extractor.readSampleData(codec.getInputBuffer(i)!!, 0)
                        if (n < 0) {
                            codec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(i, 0, n, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val o = codec.dequeueOutputBuffer(info, 10_000)
                if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val f = codec.outputFormat
                    rate = f.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    channels = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                } else if (o >= 0) {
                    val buf = codec.getOutputBuffer(o)!!.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                    val frames = buf.remaining() / channels
                    for (f in 0 until frames) {
                        var sum = 0f
                        for (ch in 0 until channels) sum += buf.get(f * channels + ch) / 32768f
                        if (count == mono.size) mono = mono.copyOf(mono.size * 2)
                        mono[count++] = sum / channels
                    }
                    codec.releaseOutputBuffer(o, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                    if (count > rate * 60 * 10) break // 10 minutes is plenty for a message.
                }
            }
        } finally {
            codec.stop()
            codec.release()
        }
        return resample(mono.copyOf(count), rate, Transcriber.SAMPLE_RATE)
    }

    /** Linear resampling; voicemail is narrowband speech, so this is enough. */
    fun resample(input: FloatArray, from: Int, to: Int): FloatArray {
        if (from == to || input.isEmpty()) return input
        val out = FloatArray((input.size.toLong() * to / from).toInt())
        for (i in out.indices) {
            val pos = i.toDouble() * from / to
            val a = pos.toInt().coerceAtMost(input.size - 1)
            val b = (a + 1).coerceAtMost(input.size - 1)
            val t = (pos - a).toFloat()
            out[i] = input[a] * (1 - t) + input[b] * t
        }
        return out
    }
}
