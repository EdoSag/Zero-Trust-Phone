// SPDX-License-Identifier: AGPL-3.0-only
package dev.sagron.zerotrustphone

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.EOFException
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlin.math.abs

/**
 * Recorded calls (P19), on this phone only and never uploaded.
 *
 * The sound is written as it's recorded, in pieces of two seconds, each
 * sealed with AES-GCM under a key that never leaves Android's Keystore, so
 * a recording is never on the phone unencrypted, even mid-call while ZT
 * Phone is locked. The list (number, time, length) is sealed the same way.
 *
 * What can be recorded is up to Android: during a call ordinary apps,
 * dialers included, usually get silence. [CallRecorder] listens for that
 * and stops, so the user is told instead of keeping an empty file.
 */
object Recordings {
    private const val PREFS = "zt_recordings"
    private const val KEY_INDEX = "index"
    private const val ALIAS = "zt_phone_recordings_aes"

    data class Info(
        val id: String,
        val number: String,
        val name: String?,
        val startedAt: Long,
        val millis: Long,
        val transcribed: Boolean,
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "id" to id, "number" to number, "name" to name, "startedAt" to startedAt,
            "millis" to millis, "transcribed" to transcribed,
        )
    }

    fun directory(context: Context): File =
        File(context.applicationContext.noBackupFilesDir, "recordings").apply { mkdirs() }

    private fun file(context: Context, id: String) = File(directory(context), "$id.zrec")

    @Synchronized
    fun list(context: Context): List<Info> {
        val sealed = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_INDEX, null) ?: return emptyList()
        val json = LocalSealer.open(sealed) ?: return emptyList()
        return try {
            val arr = JSONArray(json)
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.optJSONObject(i) ?: return@mapNotNull null
                Info(
                    o.getString("id"), o.optString("number"), o.optString("name").ifEmpty { null },
                    o.optLong("startedAt"), o.optLong("millis"), o.optBoolean("transcribed"),
                )
            }.filter { file(context, it.id).exists() }
        } catch (_: Exception) {
            emptyList()
        }
    }

    @Synchronized
    private fun save(context: Context, items: List<Info>) {
        val arr = JSONArray()
        for (r in items) arr.put(
            JSONObject().put("id", r.id).put("number", r.number).put("name", r.name ?: "")
                .put("startedAt", r.startedAt).put("millis", r.millis).put("transcribed", r.transcribed)
        )
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_INDEX, LocalSealer.seal(arr.toString())).apply()
    }

    @Synchronized
    fun add(context: Context, info: Info) = save(context, list(context).filter { it.id != info.id } + info)

    @Synchronized
    fun markTranscribed(context: Context, id: String) =
        save(context, list(context).map { if (it.id == id) it.copy(transcribed = true) else it })

    @Synchronized
    fun delete(context: Context, id: String) {
        file(context, id).delete()
        save(context, list(context).filter { it.id != id })
    }

    fun newId(): String = UUID.randomUUID().toString().replace("-", "")

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return gen.generateKey()
    }

    /** Appends sealed pieces: [length][iv(12)][ciphertext + tag]. */
    class Writer(context: Context, id: String) {
        private val out = DataOutputStream(FileOutputStream(file(context, id)).buffered())
        private val key = key()

        fun write(samples: ShortArray, count: Int) {
            val bytes = ByteArray(count * 2)
            for (i in 0 until count) {
                bytes[2 * i] = (samples[i].toInt() and 0xff).toByte()
                bytes[2 * i + 1] = (samples[i].toInt() shr 8).toByte()
            }
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, key)
            val sealed = cipher.doFinal(bytes)
            out.writeInt(sealed.size)
            out.write(cipher.iv)
            out.write(sealed)
        }

        fun close() = out.close()
    }

    /** Opens a recording piece by piece (PCM16 mono, 16 kHz). */
    fun read(context: Context, id: String, onPiece: (ShortArray) -> Boolean) {
        val key = key()
        DataInputStream(FileInputStream(file(context, id)).buffered()).use { input ->
            while (true) {
                val size = try { input.readInt() } catch (_: EOFException) { return }
                if (size <= 16 || size > (1 shl 22)) return
                val iv = ByteArray(12)
                input.readFully(iv)
                val sealed = ByteArray(size)
                input.readFully(sealed)
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, iv))
                val bytes = cipher.doFinal(sealed)
                val samples = ShortArray(bytes.size / 2) {
                    ((bytes[2 * it].toInt() and 0xff) or (bytes[2 * it + 1].toInt() shl 8)).toShort()
                }
                if (!onPiece(samples)) return
            }
        }
    }

    /** A whole recording as Whisper wants it. */
    fun samples(context: Context, id: String): FloatArray {
        val pieces = ArrayList<ShortArray>()
        read(context, id) { pieces.add(it); true }
        val out = FloatArray(pieces.sumOf { it.size })
        var at = 0
        for (p in pieces) for (s in p) out[at++] = s / 32768f
        return out
    }
}

/**
 * Records the call in progress when the user taps Record (P19). Tries the
 * call's own audio first (only Android's privileged apps get it), then the
 * microphone. After a few seconds of nothing but silence it stops,
 * deletes the file, and the call screen says so.
 */
object CallRecorder {
    private const val TAG = "CallRecorder"
    private const val PIECE = Transcriber.SAMPLE_RATE * 2
    private const val SILENCE_CHECK_MILLIS = 8_000L
    private const val SILENCE_LEVEL = 40

    @Volatile private var running: Thread? = null
    @Volatile var startedAt: Long = 0L
        private set
    @Volatile private var stopRequested = false
    private val main = Handler(Looper.getMainLooper())

    val isRecording: Boolean get() = running != null

    /** False when it can't start (no microphone permission, busy). */
    @SuppressLint("MissingPermission")
    fun start(context: Context, number: String, name: String?, onSilent: () -> Unit): Boolean {
        if (running != null) return false
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) return false
        val app = context.applicationContext
        val record = open() ?: return false
        val id = Recordings.newId()
        val writer = try { Recordings.Writer(app, id) } catch (e: Exception) { record.release(); return false }
        stopRequested = false
        startedAt = System.currentTimeMillis()
        val thread = Thread({
            var heard = false
            var silent = false
            val buffer = ShortArray(PIECE)
            try {
                record.startRecording()
                while (!stopRequested) {
                    var filled = 0
                    while (filled < PIECE && !stopRequested) {
                        val n = record.read(buffer, filled, PIECE - filled)
                        if (n <= 0) break
                        filled += n
                    }
                    if (filled <= 0) break
                    if (!heard) heard = (0 until filled).any { abs(buffer[it].toInt()) > SILENCE_LEVEL }
                    writer.write(buffer, filled)
                    if (!heard && System.currentTimeMillis() - startedAt > SILENCE_CHECK_MILLIS) {
                        silent = true
                        break
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "recording stopped", e)
            } finally {
                try { record.stop() } catch (_: Exception) {}
                record.release()
                writer.close()
                val millis = System.currentTimeMillis() - startedAt
                if (silent || !heard) {
                    Recordings.delete(app, id)
                    main.post(onSilent)
                } else {
                    Recordings.add(app, Recordings.Info(id, number, name, startedAt, millis, false))
                }
                running = null
                startedAt = 0L
                main.post { CallManager.notifyChanged() }
            }
        }, "CallRecorder")
        running = thread
        thread.start()
        return true
    }

    fun stop() {
        stopRequested = true
    }

    @SuppressLint("MissingPermission")
    private fun open(): AudioRecord? {
        val size = maxOf(
            AudioRecord.getMinBufferSize(Transcriber.SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT),
            PIECE * 2,
        )
        for (source in intArrayOf(
            MediaRecorder.AudioSource.VOICE_CALL,
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            MediaRecorder.AudioSource.MIC,
        )) {
            try {
                val r = AudioRecord(source, Transcriber.SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, size)
                if (r.state == AudioRecord.STATE_INITIALIZED) return r
                r.release()
            } catch (_: Exception) {
                // Not allowed for this app: try the next source.
            }
        }
        return null
    }
}

/** Plays a recording, decrypting it piece by piece; no plain copy is written. */
object RecordingPlayer {
    @Volatile private var playing: Thread? = null
    @Volatile private var stop = false

    fun play(context: Context, id: String, onDone: () -> Unit) {
        stopNow()
        val app = context.applicationContext
        stop = false
        val t = Thread({
            val track = AudioTrack.Builder()
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                .setAudioFormat(AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(Transcriber.SAMPLE_RATE).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                .setTransferMode(AudioTrack.MODE_STREAM)
                .setBufferSizeInBytes(Transcriber.SAMPLE_RATE * 2)
                .build()
            try {
                track.play()
                Recordings.read(app, id) { piece -> track.write(piece, 0, piece.size); !stop }
            } catch (_: Exception) {
            } finally {
                try { track.stop() } catch (_: Exception) {}
                track.release()
                Handler(Looper.getMainLooper()).post(onDone)
            }
        }, "RecordingPlayer")
        playing = t
        t.start()
    }

    fun stopNow() {
        stop = true
        playing = null
    }
}
