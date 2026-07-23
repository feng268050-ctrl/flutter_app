#pragma once

#include <functional>
#include <string>

#ifdef __ANDROID__
#include <jni.h>
#endif

namespace stream_detect {

/** Optional process-local sink (AI daemon evt publish). Takes precedence over JNI. */
void setStreamDetectEventSink(std::function<void(const std::string& jsonLine)> sink);
void clearStreamDetectEventSink();

void publishStreamDetectEvent(const std::string& jsonLine);

#ifdef __ANDROID__
void setStreamDetectListener(JNIEnv* env, jobject listener);
void clearStreamDetectListener(JNIEnv* env);
#endif

}  // namespace stream_detect
