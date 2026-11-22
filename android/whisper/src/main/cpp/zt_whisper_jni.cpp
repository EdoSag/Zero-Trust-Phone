// SPDX-License-Identifier: AGPL-3.0-only
// JNI layer between dev.sagron.zerotrustphone.WhisperNative and whisper.cpp.
#include <jni.h>
#include <android/log.h>
#include <atomic>
#include <string>

#include "whisper.h"

#define TAG "ZtWhisper"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, TAG, __VA_ARGS__)

namespace {

struct Engine {
    whisper_context *context = nullptr;
    std::atomic<bool> cancelled{false};
};

// whisper.cpp logs every model detail at load; keep warnings and errors only.
void logCallback(enum ggml_log_level level, const char *text, void *) {
    if (level == GGML_LOG_LEVEL_ERROR) {
        __android_log_print(ANDROID_LOG_ERROR, TAG, "%s", text);
    } else if (level == GGML_LOG_LEVEL_WARN) {
        __android_log_print(ANDROID_LOG_WARN, TAG, "%s", text);
    }
}

bool abortCallback(void *data) {
    return static_cast<Engine *>(data)->cancelled.load();
}

} // namespace

extern "C" {

JNIEXPORT jlong JNICALL
Java_dev_sagron_zerotrustphone_WhisperNative_open(JNIEnv *env, jclass, jstring modelPath) {
    whisper_log_set(logCallback, nullptr);
    const char *path = env->GetStringUTFChars(modelPath, nullptr);
    whisper_context_params params = whisper_context_default_params();
    params.use_gpu = false;
    whisper_context *context = whisper_init_from_file_with_params(path, params);
    env->ReleaseStringUTFChars(modelPath, path);
    if (context == nullptr) {
        LOGW("could not load the model");
        return 0;
    }
    auto *engine = new Engine();
    engine->context = context;
    return reinterpret_cast<jlong>(engine);
}

JNIEXPORT void JNICALL
Java_dev_sagron_zerotrustphone_WhisperNative_close(JNIEnv *, jclass, jlong handle) {
    auto *engine = reinterpret_cast<Engine *>(handle);
    if (engine == nullptr) return;
    whisper_free(engine->context);
    delete engine;
}

JNIEXPORT jboolean JNICALL
Java_dev_sagron_zerotrustphone_WhisperNative_isMultilingual(JNIEnv *, jclass, jlong handle) {
    auto *engine = reinterpret_cast<Engine *>(handle);
    return engine != nullptr && whisper_is_multilingual(engine->context) != 0;
}

// Stops the transcription that is running on another thread, and any later one until allow().
JNIEXPORT void JNICALL
Java_dev_sagron_zerotrustphone_WhisperNative_cancel(JNIEnv *, jclass, jlong handle) {
    auto *engine = reinterpret_cast<Engine *>(handle);
    if (engine != nullptr) engine->cancelled.store(true);
}

// Takes back a cancel, before a new transcription.
JNIEXPORT void JNICALL
Java_dev_sagron_zerotrustphone_WhisperNative_allow(JNIEnv *, jclass, jlong handle) {
    auto *engine = reinterpret_cast<Engine *>(handle);
    if (engine != nullptr) engine->cancelled.store(false);
}

// Returns the text as UTF-8 bytes, or null when it failed or was cancelled.
// samples: 16 kHz mono, -1..1. language: a whisper language code, or "auto".
JNIEXPORT jbyteArray JNICALL
Java_dev_sagron_zerotrustphone_WhisperNative_transcribe(
        JNIEnv *env, jclass, jlong handle, jfloatArray samples, jint count, jstring language,
        jstring prompt, jint threads, jint beamSize, jint audioContext) {
    auto *engine = reinterpret_cast<Engine *>(handle);
    if (engine == nullptr || count <= 0) return nullptr;

    const char *languageChars = env->GetStringUTFChars(language, nullptr);
    std::string languageCode(languageChars);
    env->ReleaseStringUTFChars(language, languageChars);
    if (languageCode != "auto" && whisper_lang_id(languageCode.c_str()) < 0) languageCode = "auto";

    std::string promptText;
    if (prompt != nullptr) {
        const char *promptChars = env->GetStringUTFChars(prompt, nullptr);
        promptText = promptChars;
        env->ReleaseStringUTFChars(prompt, promptChars);
    }

    whisper_full_params params = whisper_full_default_params(
            beamSize > 1 ? WHISPER_SAMPLING_BEAM_SEARCH : WHISPER_SAMPLING_GREEDY);
    if (beamSize > 1) {
        params.beam_search.beam_size = beamSize;
    } else {
        params.greedy.best_of = 1;
    }
    // Whisper always works on a 30 second window. For a short sentence most of it is
    // silence, and listening to only the part that holds speech is several times faster.
    const int fullContext = whisper_n_audio_ctx(engine->context);
    if (audioContext > 0 && audioContext < fullContext) {
        params.audio_ctx = audioContext;
        params.single_segment = true;
    }
    params.n_threads = threads > 0 ? threads : 4;
    params.translate = false;
    params.no_context = true;
    params.no_timestamps = true;
    params.print_special = false;
    params.print_progress = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.suppress_blank = true;
    params.suppress_nst = true;
    params.language = languageCode.c_str();
    params.detect_language = false;
    params.initial_prompt = promptText.empty() ? nullptr : promptText.c_str();
    params.abort_callback = abortCallback;
    params.abort_callback_user_data = engine;

    jfloat *data = env->GetFloatArrayElements(samples, nullptr);
    const int result = whisper_full(engine->context, params, data, count);
    env->ReleaseFloatArrayElements(samples, data, JNI_ABORT);
    if (result != 0 || engine->cancelled.load()) return nullptr;

    std::string text;
    const int segments = whisper_full_n_segments(engine->context);
    for (int i = 0; i < segments; i++) {
        const char *segment = whisper_full_get_segment_text(engine->context, i);
        if (segment != nullptr) text += segment;
    }
    jbyteArray bytes = env->NewByteArray(static_cast<jsize>(text.size()));
    if (bytes == nullptr) return nullptr;
    env->SetByteArrayRegion(bytes, 0, static_cast<jsize>(text.size()),
                            reinterpret_cast<const jbyte *>(text.data()));
    return bytes;
}

} // extern "C"
