#include "stream_detect_event.h"

#include <functional>
#include <mutex>

#ifdef __ANDROID__
#include <android/log.h>
#include <jni.h>

#define SD_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "StreamDetectEvent", __VA_ARGS__)
#endif

namespace {

std::mutex g_sink_mutex;
std::function<void(const std::string&)> g_event_sink;

#ifdef __ANDROID__
std::mutex g_listener_mutex;
JavaVM* g_jvm = nullptr;
jobject g_listener_global = nullptr;
jmethodID g_on_event_mid = nullptr;

class JniScope {
public:
    explicit JniScope(JavaVM* vm) : vm_(vm), env_(nullptr), attached_(false) {
        if (!vm_) {
            return;
        }
        if (vm_->GetEnv(reinterpret_cast<void**>(&env_), JNI_VERSION_1_6) == JNI_OK) {
            return;
        }
        if (vm_->AttachCurrentThread(&env_, nullptr) == JNI_OK) {
            attached_ = true;
        }
    }
    ~JniScope() {
        if (attached_ && vm_) {
            vm_->DetachCurrentThread();
        }
    }
    JNIEnv* env() const { return env_; }

private:
    JavaVM* vm_;
    JNIEnv* env_;
    bool attached_;
};
#endif

}  // namespace

namespace stream_detect {

void setStreamDetectEventSink(std::function<void(const std::string& jsonLine)> sink) {
    std::lock_guard<std::mutex> lock(g_sink_mutex);
    g_event_sink = std::move(sink);
}

void clearStreamDetectEventSink() {
    std::lock_guard<std::mutex> lock(g_sink_mutex);
    g_event_sink = nullptr;
}

#ifdef __ANDROID__

void setStreamDetectListener(JNIEnv* env, jobject listener) {
    std::lock_guard<std::mutex> lock(g_listener_mutex);
    if (g_listener_global) {
        env->DeleteGlobalRef(g_listener_global);
        g_listener_global = nullptr;
        g_on_event_mid = nullptr;
    }
    if (!listener) {
        return;
    }
    env->GetJavaVM(&g_jvm);
    g_listener_global = env->NewGlobalRef(listener);
    jclass cls = env->GetObjectClass(listener);
    g_on_event_mid = env->GetMethodID(cls, "onStreamDetectEvent", "(Ljava/lang/String;)V");
    env->DeleteLocalRef(cls);
}

void clearStreamDetectListener(JNIEnv* env) {
    setStreamDetectListener(env, nullptr);
}

void publishStreamDetectEvent(const std::string& jsonLine) {
    {
        std::lock_guard<std::mutex> lock(g_sink_mutex);
        if (g_event_sink) {
            g_event_sink(jsonLine);
            return;
        }
    }
    std::lock_guard<std::mutex> lock(g_listener_mutex);
    if (!g_jvm || !g_listener_global || !g_on_event_mid) {
        return;
    }
    JniScope scope(g_jvm);
    JNIEnv* env = scope.env();
    if (!env) {
        SD_LOGE("publish: no JNIEnv");
        return;
    }
    jstring jline = env->NewStringUTF(jsonLine.c_str());
    if (!jline) {
        return;
    }
    env->CallVoidMethod(g_listener_global, g_on_event_mid, jline);
    env->DeleteLocalRef(jline);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        SD_LOGE("publish: Java callback threw");
    }
}

#else

void publishStreamDetectEvent(const std::string& jsonLine) {
    std::lock_guard<std::mutex> lock(g_sink_mutex);
    if (g_event_sink) {
        g_event_sink(jsonLine);
    }
}

#endif

}  // namespace stream_detect
