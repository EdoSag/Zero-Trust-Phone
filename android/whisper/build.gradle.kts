// The speech recognition engine for call and voicemail transcripts (P20,
// P21): whisper.cpp (MIT) built for Android as libzt_whisper.so, the same
// module as ZT Keyboard's voice typing. Native code only; the Kotlin side is
// dev.sagron.zerotrustphone.WhisperNative. Everything runs on the device.
plugins {
    id("com.android.library")
}

android {
    namespace = "dev.sagron.zerotrustphone.whisper"
    compileSdk = 36
    ndkVersion = "28.0.13004108"

    defaultConfig {
        minSdk = 29
        ndk {
            // The ABIs Flutter builds the app for.
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86_64"))
        }
        externalNativeBuild {
            cmake {
                arguments += listOf("-DANDROID_STL=c++_static")
            }
        }
    }

    buildTypes {
        // The Flutter plugin gives the app a "profile" build type.
        create("profile")
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}
