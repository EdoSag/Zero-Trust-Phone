// SPDX-License-Identifier: AGPL-3.0-only
package dev.sagron.zerotrustphone

import android.content.Context
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/** A speech model that can be downloaded: one line of ZT Keyboard's model list. */
data class SpeechModel(
    val file: String,
    val bytes: Long,
    val sha256: String,
    /** Whisper language codes it's tuned for; empty for every language. */
    val languages: List<String>,
    val labelEn: String,
    val labelHe: String,
)

/**
 * The speech models for call and voicemail transcripts (P20, P21): the same
 * Whisper files ZT Keyboard's voice typing uses, from the keyboard's own
 * "voice-models" release on GitHub (mirrored and listed there with their
 * size and sha256). A file is used only when both match. Kept in ZT
 * Phone's private storage; nothing is sent anywhere.
 */
object SpeechModels {
    const val BASE_URL = "https://github.com/EdoSag/Zero-Trust-Keyboard/releases/download/voice-models/"
    const val LIST_FILE = "voice-models.tsv"
    private const val EXTENSION = ".bin"
    private const val PARTIAL = ".download"
    private const val SPARE_BYTES = 50L shl 20
    private val MAGIC = byteArrayOf(0x6c, 0x6d, 0x67, 0x67)
    private val SHA256 = Regex("[0-9a-f]{64}")
    private val LANGUAGE = Regex("[a-z]{2,3}")

    enum class Result { OK, CANCELLED, NO_CONNECTION, WRONG_FILE, NO_SPACE, FAILED }

    fun directory(context: Context): File =
        File(context.applicationContext.filesDir, "speech").apply { mkdirs() }

    fun installed(context: Context): List<File> =
        directory(context).listFiles { f -> f.isFile && f.name.endsWith(EXTENSION) }
            ?.sortedBy { it.name } ?: emptyList()

    /** ZT Keyboard's list: file, bytes, sha256, languages, English, Hebrew. */
    fun parse(text: String): List<SpeechModel> = text.lineSequence().mapNotNull { line ->
        if (line.startsWith("#")) return@mapNotNull null
        val f = line.trimEnd('\r').split('\t')
        if (f.size < 5) return@mapNotNull null
        val bytes = f[1].toLongOrNull() ?: return@mapNotNull null
        val sha = f[2].lowercase()
        val languages = if (f[3] == "-") emptyList() else f[3].split(',')
        // The name becomes a file here: only plain names pass.
        if (!Regex("[A-Za-z0-9._-]{1,100}\\.bin").matches(f[0]) || f[0].startsWith(".")) return@mapNotNull null
        if (bytes <= 0 || !SHA256.matches(sha) || languages.any { !LANGUAGE.matches(it) }) return@mapNotNull null
        SpeechModel(f[0], bytes, sha, languages, f[4], f.getOrElse(5) { "" })
    }.toList()

    /** "x.he.bin" is tuned for Hebrew; null for a model for every language. */
    fun languageOf(fileName: String): String? {
        val base = fileName.removeSuffix(EXTENSION)
        val last = base.substringAfterLast('.', "")
        return if (last != base && LANGUAGE.matches(last)) last else null
    }

    /** A model tuned for [language] first, then one for every language. */
    fun forLanguage(context: Context, language: String): File? {
        val models = installed(context)
        return models.firstOrNull { languageOf(it.name) == language }
            ?: models.firstOrNull { languageOf(it.name) == null }
            ?: models.firstOrNull()
    }

    fun delete(context: Context, file: String) {
        Transcriber.release()
        File(directory(context), file).takeIf { it.parentFile == directory(context) }?.delete()
        File(directory(context), file + PARTIAL).delete()
    }

    private fun open(url: String, from: Long): Pair<InputStream, Long>? {
        if (!url.startsWith(BASE_URL)) return null
        var c: HttpURLConnection? = null
        return try {
            c = URL(url).openConnection() as HttpURLConnection
            c.connectTimeout = 15_000
            c.readTimeout = 30_000
            c.instanceFollowRedirects = true
            c.setRequestProperty("User-Agent", "ZT-Phone")
            c.setRequestProperty("Accept-Encoding", "identity")
            if (from > 0) c.setRequestProperty("Range", "bytes=$from-")
            when (c.responseCode) {
                HttpURLConnection.HTTP_OK -> c.inputStream to 0L
                HttpURLConnection.HTTP_PARTIAL -> c.inputStream to from
                else -> { c.disconnect(); null }
            }
        } catch (_: Exception) {
            c?.disconnect()
            null
        }
    }

    /** The list of models to download, or null offline. Background thread. */
    fun catalog(): List<SpeechModel>? {
        val (stream, _) = open(BASE_URL + LIST_FILE, 0) ?: return null
        return try {
            stream.use { parse(String(it.readBytes().take(1 shl 20).toByteArray(), Charsets.UTF_8)) }
        } catch (_: IOException) {
            null
        }
    }

    /**
     * Downloads [model], continuing a download that stopped. Background
     * thread. [onProgress] gets the bytes so far.
     */
    fun download(
        context: Context,
        model: SpeechModel,
        cancelled: () -> Boolean,
        onProgress: (Long) -> Unit,
    ): Result {
        val dir = directory(context)
        val target = File(dir, model.file)
        val partial = File(dir, model.file + PARTIAL)
        try {
            var have = if (partial.exists()) partial.length() else 0L
            if (have > model.bytes) { partial.delete(); have = 0 }
            if (dir.usableSpace < model.bytes - have + SPARE_BYTES) return Result.NO_SPACE
            onProgress(have)
            if (have < model.bytes) {
                val (input, startsAt) = open(BASE_URL + model.file, have) ?: return Result.NO_CONNECTION
                input.use {
                    if (startsAt != have) {
                        if (startsAt != 0L) return Result.FAILED
                        have = 0
                    }
                    FileOutputStream(partial, have > 0).use { out ->
                        val buffer = ByteArray(1 shl 16)
                        var lastReport = 0L
                        while (true) {
                            if (cancelled()) return Result.CANCELLED
                            val read = try { input.read(buffer) } catch (_: IOException) {
                                return if (cancelled()) Result.CANCELLED else Result.NO_CONNECTION
                            }
                            if (read < 0) break
                            have += read
                            if (have > model.bytes) {
                                out.close(); partial.delete()
                                return Result.WRONG_FILE
                            }
                            out.write(buffer, 0, read)
                            if (have - lastReport > (1 shl 20)) { lastReport = have; onProgress(have) }
                        }
                    }
                }
                if (have < model.bytes) return if (cancelled()) Result.CANCELLED else Result.NO_CONNECTION
            }
            val sha = sha256(partial, cancelled) ?: return Result.CANCELLED
            val head = ByteArray(4)
            val n = partial.inputStream().use { it.read(head) }
            if (sha != model.sha256 || n < 4 || !MAGIC.indices.all { head[it] == MAGIC[it] }) {
                partial.delete()
                return Result.WRONG_FILE
            }
            target.delete()
            return if (partial.renameTo(target)) Result.OK else Result.FAILED
        } catch (_: IOException) {
            return Result.FAILED
        } catch (_: SecurityException) {
            return Result.FAILED
        }
    }

    private fun sha256(file: File, cancelled: () -> Boolean): String? {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(1 shl 16)
            while (true) {
                if (cancelled()) return null
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
