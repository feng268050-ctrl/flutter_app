#pragma once
/* Linux host/cross-compile shim for code that includes <android/log.h>. */

#include <cstdarg>
#include <cstdio>

#ifndef ANDROID_LOG_UNKNOWN
#define ANDROID_LOG_UNKNOWN 0
#define ANDROID_LOG_DEFAULT 1
#define ANDROID_LOG_VERBOSE 2
#define ANDROID_LOG_DEBUG 3
#define ANDROID_LOG_INFO 4
#define ANDROID_LOG_WARN 5
#define ANDROID_LOG_ERROR 6
#define ANDROID_LOG_FATAL 7
#define ANDROID_LOG_SILENT 8
#endif

inline int __android_log_print(int /*prio*/, const char* tag, const char* fmt, ...) {
    std::fputs(tag ? tag : "lws_ai", stderr);
    std::fputc(':', stderr);
    std::fputc(' ', stderr);
    va_list ap;
    va_start(ap, fmt);
    std::vfprintf(stderr, fmt, ap);
    va_end(ap);
    std::fputc('\n', stderr);
    return 0;
}
