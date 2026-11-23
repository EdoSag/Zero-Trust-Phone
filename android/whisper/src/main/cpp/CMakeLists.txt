# SPDX-License-Identifier: AGPL-3.0-only
# Builds libzt_whisper.so: whisper.cpp and ggml (both MIT) linked statically behind a small
# JNI layer. CPU only, no network code.
cmake_minimum_required(VERSION 3.22.1)
# Always optimised, also in debug builds of the app: unoptimised speech recognition is
# many times too slow to use.
set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
project(zt_whisper C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# whisper.cpp release, fetched at build time. To take a newer release change the tag and
# the hash together (sha256 of the tag's source archive). A build stops when the archive differs.
set(ZT_WHISPER_TAG "v1.8.3")
set(ZT_WHISPER_SHA256 "870ba21409cdf66697dc4db15ebdb13bc67037d76c7cc63756c81471d8f1731a")

include(FetchContent)
FetchContent_Declare(whisper
    URL "https://github.com/ggml-org/whisper.cpp/archive/refs/tags/${ZT_WHISPER_TAG}.tar.gz"
    URL_HASH "SHA256=${ZT_WHISPER_SHA256}")

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(WHISPER_ALL_WARNINGS OFF CACHE BOOL "" FORCE)
# ggml's own thread pool; OpenMP would need libomp.so in the APK.
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
# One build must run on every phone of the ABI, so no -march=native.
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(whisper)

add_library(zt_whisper SHARED zt_whisper_jni.cpp)
target_link_libraries(zt_whisper PRIVATE whisper log)
target_compile_options(zt_whisper PRIVATE -fvisibility=hidden -ffunction-sections -fdata-sections)
target_link_options(zt_whisper PRIVATE -Wl,--gc-sections -Wl,--exclude-libs,ALL)
