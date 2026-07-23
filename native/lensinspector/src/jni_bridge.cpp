#include "det_callback_json.h"
#include "handle_access.h"
#include "central_scheduler.h"
#include "stain_infer_outcome.h"
#include <jni.h>
#include <opencv2/imgproc.hpp>
#include <string>
#include <memory>
#include <thread>
#include <cstdlib>

#ifdef __ANDROID__
#include <android/log.h>
#include <sys/system_properties.h>
#define JNI_TAG "LensGuardJNI"
#define JNI_LOGI(...) __android_log_print(ANDROID_LOG_INFO,  JNI_TAG, __VA_ARGS__)
#define JNI_LOGW(...) __android_log_print(ANDROID_LOG_WARN,  JNI_TAG, __VA_ARGS__)
#define JNI_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, JNI_TAG, __VA_ARGS__)
#else
#define JNI_LOGI(...) std::printf(__VA_ARGS__)
#define JNI_LOGW(...) std::printf(__VA_ARGS__)
#define JNI_LOGE(...) std::fprintf(stderr, __VA_ARGS__)
#endif

// ═══════════════════════════════════════════════════════════════
//  Native context — owns the scheduler and its worker thread
// ═══════════════════════════════════════════════════════════════

struct NativeContext {
    AppConfig                          config;
    std::unique_ptr<CentralScheduler>  scheduler;
    std::thread                        run_thread;

    // JNI callback plumbing
    JavaVM*    jvm       = nullptr;
    jobject    listener  = nullptr;   // GlobalRef
    jmethodID  mid_state = nullptr;
    jmethodID  mid_result= nullptr;
};

const AppConfig* lens_app_config_from_handle(long long native_handle) {
    auto* ctx = reinterpret_cast<NativeContext*>(native_handle);
    return ctx ? &ctx->config : nullptr;
}

CentralScheduler* central_scheduler_from_handle(long long native_handle) {
    auto* ctx = reinterpret_cast<NativeContext*>(native_handle);
    if (!ctx || !ctx->scheduler) {
        return nullptr;
    }
    return ctx->scheduler.get();
}

static JavaVM* g_jvm = nullptr;

static const char* invalid_cls_result_json() {
    return "{\"valid\":false,\"classId\":-1,\"className\":\"\",\"score\":0.0,"
           "\"topk\":[],\"timestampMs\":0,\"modelVersion\":\"unknown\",\"source\":\"focus_cls\"}";
}

#ifdef __ANDROID__
static std::string get_system_property(const char* key) {
    char value[PROP_VALUE_MAX] = {0};
    const int n = __system_property_get(key, value);
    if (n <= 0) return "";
    return std::string(value, static_cast<std::size_t>(n));
}

static bool parse_bool_like(const std::string& v, bool fallback) {
    if (v.empty()) return fallback;
    if (v == "1" || v == "true" || v == "TRUE" || v == "on" || v == "ON") return true;
    if (v == "0" || v == "false" || v == "FALSE" || v == "off" || v == "OFF") return false;
    return fallback;
}

static void apply_det_postprocess_debug_env_from_props() {
    // Toggle det_postprocess debug output without changing Java API surface.
    // Example:
    //   adb shell setprop debug.lws.det_postprocess.debug 1
    //   adb shell setprop debug.lws.det_postprocess.topk 3
    //   adb shell setprop debug.lws.det_postprocess.max_anchors 50
    const std::string p_debug = get_system_property("debug.lws.det_postprocess.debug");
    const std::string p_topk = get_system_property("debug.lws.det_postprocess.topk");
    const std::string p_max = get_system_property("debug.lws.det_postprocess.max_anchors");

    if (parse_bool_like(p_debug, false)) {
        setenv("DET_POSTPROCESS_DEBUG", "1", 1);
    } else {
        unsetenv("DET_POSTPROCESS_DEBUG");
    }

    if (!p_topk.empty()) {
        setenv("DET_POSTPROCESS_DEBUG_TOPK", p_topk.c_str(), 1);
    } else {
        unsetenv("DET_POSTPROCESS_DEBUG_TOPK");
    }

    if (!p_max.empty()) {
        setenv("DET_POSTPROCESS_DEBUG_MAX_ANCHORS", p_max.c_str(), 1);
    } else {
        unsetenv("DET_POSTPROCESS_DEBUG_MAX_ANCHORS");
    }

    JNI_LOGI("det-postprocess debug env applied: debug=%s topk=%s max_anchors=%s",
             std::getenv("DET_POSTPROCESS_DEBUG") ? std::getenv("DET_POSTPROCESS_DEBUG") : "<unset>",
             std::getenv("DET_POSTPROCESS_DEBUG_TOPK") ? std::getenv("DET_POSTPROCESS_DEBUG_TOPK") : "<unset>",
             std::getenv("DET_POSTPROCESS_DEBUG_MAX_ANCHORS") ? std::getenv("DET_POSTPROCESS_DEBUG_MAX_ANCHORS") : "<unset>");
}
#endif

// ═══════════════════════════════════════════════════════════════
//  JNI_OnLoad — cache the JavaVM pointer
// ═══════════════════════════════════════════════════════════════

JNIEXPORT jint JNI_OnLoad(JavaVM* vm, void* /*reserved*/) {
    g_jvm = vm;
    JNI_LOGI("JNI_OnLoad: libai loaded\n");
    return JNI_VERSION_1_6;
}

JNIEXPORT void JNI_OnUnload(JavaVM* /*vm*/, void* /*reserved*/) {
    JNI_LOGI("JNI_OnUnload: libai unloaded\n");
    g_jvm = nullptr;
}

// ═══════════════════════════════════════════════════════════════
//  JNI helper — attach current thread to JVM if needed
// ═══════════════════════════════════════════════════════════════

struct JNIScope {
    JNIEnv* env   = nullptr;
    bool detach   = false;

    explicit JNIScope(JavaVM* vm) {
        if (!vm) return;
        int st = vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
        if (st == JNI_EDETACHED) {
            if (vm->AttachCurrentThread(&env, nullptr) == JNI_OK)
                detach = true;
            else
                env = nullptr;
        }
    }
    ~JNIScope() {
        if (detach && g_jvm) g_jvm->DetachCurrentThread();
    }
    explicit operator bool() const { return env != nullptr; }
};

// ═══════════════════════════════════════════════════════════════
//  Wire scheduler callbacks → JNI listener
// ═══════════════════════════════════════════════════════════════

static void setup_callbacks(NativeContext* ctx) {
    if (!ctx->listener) return;

    ctx->scheduler->setCallbacks({
        // on_state_changed
        [ctx](int state) {
            JNIScope s(ctx->jvm);
            if (!s || !ctx->listener || !ctx->mid_state) return;
            s.env->CallVoidMethod(ctx->listener, ctx->mid_state, (jint)state);
            if (s.env->ExceptionCheck()) s.env->ExceptionClear();
        },
        // on_check_result
        [ctx](int level, const std::string& status, const std::string& message) {
            JNIScope s(ctx->jvm);
            if (!s || !ctx->listener || !ctx->mid_result) return;
            jstring js = s.env->NewStringUTF(status.c_str());
            jstring jm = s.env->NewStringUTF(message.c_str());
            s.env->CallVoidMethod(ctx->listener, ctx->mid_result, (jint)level, js, jm);
            if (s.env->ExceptionCheck()) s.env->ExceptionClear();
            s.env->DeleteLocalRef(js);
            s.env->DeleteLocalRef(jm);
        }
    });
}

// ═══════════════════════════════════════════════════════════════
//  JNI exported functions
//  Java class: com.lasercyber.lws.ai.NativeBridge
// ═══════════════════════════════════════════════════════════════

#define JNI_FN(name) Java_com_lasercyber_lws_ai_NativeBridge_##name

// TODO(camera-type): branch on RED_LIGHT (2) for model/ROI selection when red-light path ships.
static void ignore_camera_type(jint cameraType) {
    (void)cameraType;
}

extern "C" {

// ── nativeCreate(configPath, projectRoot, cameraType) → handle ──────────

JNIEXPORT jlong JNICALL
JNI_FN(nativeCreate)(JNIEnv* env, jclass /*clazz*/, jstring configPath, jstring projectRoot, jint cameraType) {
    ignore_camera_type(cameraType);
    JNI_LOGI("nativeCreate enter");
#ifdef __ANDROID__
    apply_det_postprocess_debug_env_from_props();
#endif
    const char* cPath = env->GetStringUTFChars(configPath, nullptr);
    const char* cRoot = env->GetStringUTFChars(projectRoot, nullptr);
    JNI_LOGI("configPath=%s", cPath ? cPath : "<null>");
    JNI_LOGI("projectRoot=%s", cRoot ? cRoot : "<null>");

    auto ctx = new (std::nothrow) NativeContext();
    if (!ctx) {
        if (cPath) env->ReleaseStringUTFChars(configPath, cPath);
        if (cRoot) env->ReleaseStringUTFChars(projectRoot, cRoot);
        JNI_LOGE("nativeCreate: OOM\n");
        return 0;
    }
    ctx->jvm = g_jvm;

    try {
        JNI_LOGI("before parse config");
        ctx->config = load_config(std::string(cPath), std::string(cRoot));
        JNI_LOGI("after parse config");
        JNI_LOGI("before create scheduler");
        ctx->scheduler = std::make_unique<CentralScheduler>(ctx->config);
        JNI_LOGI("after create scheduler");
        JNI_LOGI("nativeCreate: OK\n");
    } catch (const std::exception& e) {
        JNI_LOGE("nativeCreate failed: %s\n", e.what());
        delete ctx;
        ctx = nullptr;
    }

    if (cPath) env->ReleaseStringUTFChars(configPath, cPath);
    if (cRoot) env->ReleaseStringUTFChars(projectRoot, cRoot);
    return reinterpret_cast<jlong>(ctx);
}

// ── nativeStart(handle) ─────────────────────────────────────

JNIEXPORT void JNICALL
JNI_FN(nativeStart)(JNIEnv* /*env*/, jclass /*clazz*/, jlong handle) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx || !ctx->scheduler) return;

    if (ctx->run_thread.joinable()) {
        JNI_LOGW("nativeStart: already running\n");
        return;
    }

    ctx->scheduler->running.store(true);
    ctx->run_thread = std::thread([ctx]() {
        JNI_LOGI("Worker thread started\n");
        try {
            ctx->scheduler->run();
        } catch (const std::exception& e) {
            JNI_LOGE("Scheduler run() exception: %s\n", e.what());
        }
        JNI_LOGI("Worker thread finished\n");
    });
}

// ── nativeStop(handle) ──────────────────────────────────────

JNIEXPORT void JNICALL
JNI_FN(nativeStop)(JNIEnv* /*env*/, jclass /*clazz*/, jlong handle) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx || !ctx->scheduler) return;

    ctx->scheduler->stop();

    if (ctx->run_thread.joinable())
        ctx->run_thread.join();

    JNI_LOGI("nativeStop: OK\n");
}

// ── nativeDestroy(handle) ───────────────────────────────────

JNIEXPORT void JNICALL
JNI_FN(nativeDestroy)(JNIEnv* env, jclass /*clazz*/, jlong handle) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx) return;

    if (ctx->scheduler && ctx->scheduler->running.load()) {
        ctx->scheduler->stop();
        if (ctx->run_thread.joinable()) ctx->run_thread.join();
    }

    if (ctx->listener) {
        env->DeleteGlobalRef(ctx->listener);
        ctx->listener = nullptr;
    }

    delete ctx;
    JNI_LOGI("nativeDestroy: OK\n");
}

// ── state queries ───────────────────────────────────────────

JNIEXPORT jint JNICALL
JNI_FN(nativeGetState)(JNIEnv* /*env*/, jclass /*clazz*/, jlong handle) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    return ctx && ctx->scheduler ? ctx->scheduler->getState() : -1;
}

JNIEXPORT jint JNICALL
JNI_FN(nativeGetStainLevel)(JNIEnv* /*env*/, jclass /*clazz*/, jlong handle) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    return ctx && ctx->scheduler ? ctx->scheduler->getStainLevel() : -1;
}

JNIEXPORT jboolean JNICALL
JNI_FN(nativeIsLensDirty)(JNIEnv* /*env*/, jclass /*clazz*/, jlong handle) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    return ctx && ctx->scheduler ? ctx->scheduler->isLensDirty() : JNI_FALSE;
}

JNIEXPORT jstring JNICALL
JNI_FN(nativeGetLastClsResult)(JNIEnv* env, jclass /*clazz*/, jlong handle) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx || !ctx->scheduler) {
        return env->NewStringUTF(invalid_cls_result_json());
    }

    try {
        const std::string json = ctx->scheduler->getLastClsResultJson();
        return env->NewStringUTF(json.empty() ? invalid_cls_result_json() : json.c_str());
    } catch (const std::exception& e) {
        JNI_LOGE("nativeGetLastClsResult failed: %s\n", e.what());
        return env->NewStringUTF(invalid_cls_result_json());
    }
}

} // extern "C"

namespace {

bool nv12_direct_buffer_view(JNIEnv* env,
                            jobject nv12_buffer,
                            jint width,
                            jint height,
                            const uint8_t*& out_ptr,
                            int& out_len,
                            std::string& err) {
    if (!nv12_buffer) {
        err = "NV12 buffer must not be null";
        return false;
    }
    if (width <= 0 || height <= 0) {
        err = "invalid width or height";
        return false;
    }
    void* base = env->GetDirectBufferAddress(nv12_buffer);
    if (!base) {
        err = "NV12 buffer must be a direct ByteBuffer";
        return false;
    }
    const jlong capacity = env->GetDirectBufferCapacity(nv12_buffer);
    const int expected = width * height * 3 / 2;
    if (capacity < expected) {
        err = "NV12 buffer capacity too small for frame";
        return false;
    }
    out_ptr = reinterpret_cast<const uint8_t*>(base);
    out_len = expected;
    return true;
}

}  // namespace

extern "C" {

// ── nativeRknnStainDetectFromStream(handle, nv12, width, height, cameraType) ────────────
// App passes the decoder direct NV12 ByteBuffer (no byte[] copy).

JNIEXPORT void JNICALL
JNI_FN(nativeRknnStainDetectFromStream)(JNIEnv* env, jclass /*clazz*/, jlong handle, jobject nv12, jint width,
                       jint height, jint cameraType) {
    ignore_camera_type(cameraType);
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx || !ctx->scheduler) return;

    const uint8_t* ptr = nullptr;
    int len = 0;
    std::string err;
    if (!nv12_direct_buffer_view(env, nv12, width, height, ptr, len, err)) {
        JNI_LOGE("nativeRknnStainDetectFromStream: %s\n", err.c_str());
        return;
    }

    ctx->scheduler->pushFrame(ptr, len, width, height);
}

// ── nativeRknnStainDetectFromJpgAndSave(handle, imagePath, outputPath) ───
// Diagnostic single-image inference. 0 = success (see NativeBridge javadoc);
// -1 = parameter/handle; -2/-3/-4 from native (read, infer, save).

JNIEXPORT jint JNICALL
JNI_FN(nativeRknnStainDetectFromJpgAndSave)(JNIEnv* env, jclass /*clazz*/, jlong handle,
                                jstring imagePath, jstring outputPath, jint cameraType) {
    ignore_camera_type(cameraType);
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx || !ctx->scheduler) {
        JNI_LOGE("nativeRknnStainDetectFromJpgAndSave: invalid handle\n");
        return -1;
    }
    if (!imagePath || !outputPath) {
        JNI_LOGE("nativeRknnStainDetectFromJpgAndSave: imagePath/outputPath must not be null\n");
        return -1;
    }

    const char* cImagePath = env->GetStringUTFChars(imagePath, nullptr);
    const char* cOutputPath = env->GetStringUTFChars(outputPath, nullptr);
    if (!cImagePath || !cOutputPath) {
        JNI_LOGE("nativeRknnStainDetectFromJpgAndSave: failed to acquire Java strings\n");
        if (cImagePath) env->ReleaseStringUTFChars(imagePath, cImagePath);
        if (cOutputPath) env->ReleaseStringUTFChars(outputPath, cOutputPath);
        return -1;
    }

    if (cImagePath[0] == '\0' || cOutputPath[0] == '\0') {
        env->ReleaseStringUTFChars(imagePath, cImagePath);
        env->ReleaseStringUTFChars(outputPath, cOutputPath);
        JNI_LOGE("nativeRknnStainDetectFromJpgAndSave: empty path\n");
        return -1;
    }

    JNI_LOGI("nativeRknnStainDetectFromJpgAndSave: input=%s output=%s\n", cImagePath, cOutputPath);
    const int code = ctx->scheduler->inferImageAndSave(cImagePath, cOutputPath);
    JNI_LOGI("nativeRknnStainDetectFromJpgAndSave: result=%d\n", code);

    env->ReleaseStringUTFChars(imagePath, cImagePath);
    env->ReleaseStringUTFChars(outputPath, cOutputPath);
    return code;
}

// ── nativeRknnStainDetectFromVideoAndSave(handle, inputVideoPath, outputVideoPath) ──
// Offline saved recording → annotated video. Does not emit per-frame onCheckResult.
// 0=ok; -1=params; -2=open input; -3=infer; -4=create output; -5=no frames.

JNIEXPORT jint JNICALL
JNI_FN(nativeRknnStainDetectFromVideoAndSave)(JNIEnv* env, jclass /*clazz*/, jlong handle, jstring inputVideoPath,
                                jstring outputVideoPath, jint cameraType) {
    ignore_camera_type(cameraType);
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx || !ctx->scheduler) {
        JNI_LOGE("nativeRknnStainDetectFromVideoAndSave: invalid handle\n");
        return -1;
    }
    if (!inputVideoPath || !outputVideoPath) {
        JNI_LOGE("nativeRknnStainDetectFromVideoAndSave: paths must not be null\n");
        return -1;
    }

    const char* cIn = env->GetStringUTFChars(inputVideoPath, nullptr);
    const char* cOut = env->GetStringUTFChars(outputVideoPath, nullptr);
    if (!cIn || !cOut) {
        if (cIn) env->ReleaseStringUTFChars(inputVideoPath, cIn);
        if (cOut) env->ReleaseStringUTFChars(outputVideoPath, cOut);
        JNI_LOGE("nativeRknnStainDetectFromVideoAndSave: failed to acquire Java strings\n");
        return -1;
    }

    if (cIn[0] == '\0' || cOut[0] == '\0') {
        env->ReleaseStringUTFChars(inputVideoPath, cIn);
        env->ReleaseStringUTFChars(outputVideoPath, cOut);
        JNI_LOGE("nativeRknnStainDetectFromVideoAndSave: empty path\n");
        return -1;
    }

    JNI_LOGI("nativeRknnStainDetectFromVideoAndSave: input=%s output=%s\n", cIn, cOut);
    const int code = ctx->scheduler->inferVideoAndSave(cIn, cOut);
    JNI_LOGI("nativeRknnStainDetectFromVideoAndSave: result=%d\n", code);

    env->ReleaseStringUTFChars(inputVideoPath, cIn);
    env->ReleaseStringUTFChars(outputVideoPath, cOut);
    return code;
}

} // extern "C"

namespace infer_jni {

std::string make_err_json(int code, const std::string& message) {
    return "{\"code\":" + std::to_string(code) + ",\"message\":\"" + json_escape(message) + "\"}";
}

int parse_json_code(const std::string& json, int fallback) {
    const std::string key = "\"code\":";
    const std::size_t p = json.find(key);
    if (p == std::string::npos) return fallback;
    std::size_t i = p + key.size();
    while (i < json.size() && (json[i] == ' ' || json[i] == '\t')) ++i;
    bool neg = false;
    if (i < json.size() && json[i] == '-') {
        neg = true;
        ++i;
    }
    bool has_digit = false;
    int value = 0;
    while (i < json.size() && json[i] >= '0' && json[i] <= '9') {
        has_digit = true;
        value = value * 10 + (json[i] - '0');
        ++i;
    }
    if (!has_digit) return fallback;
    return neg ? -value : value;
}

struct JniStainMarshalling {
    jclass box_cls = nullptr;
    jmethodID box_ctor = nullptr;
    jclass outcome_cls = nullptr;
    jmethodID outcome_ctor = nullptr;
};

JniStainMarshalling& jni_stain_marshalling(JNIEnv* env) {
    static JniStainMarshalling cache;
    if (cache.outcome_cls) return cache;
    jclass local_box = env->FindClass("com/lasercyber/lws/ai/NativeBridge$StainBox");
    jclass local_outcome = env->FindClass("com/lasercyber/lws/ai/NativeBridge$StainInferOutcome");
    if (!local_box || !local_outcome) return cache;
    cache.box_cls = static_cast<jclass>(env->NewGlobalRef(local_box));
    cache.outcome_cls = static_cast<jclass>(env->NewGlobalRef(local_outcome));
    env->DeleteLocalRef(local_box);
    env->DeleteLocalRef(local_outcome);
    cache.box_ctor = env->GetMethodID(cache.box_cls, "<init>", "(FFFFIF)V");
    cache.outcome_ctor = env->GetMethodID(
        cache.outcome_cls,
        "<init>",
        "(ILjava/lang/String;Ljava/lang/String;ILjava/lang/String;Ljava/lang/String;II"
        "[Lcom/lasercyber/lws/ai/NativeBridge$StainBox;ZI)V");
    return cache;
}

jstring to_jstring(JNIEnv* env, const std::string& s) {
    return env->NewStringUTF(s.c_str());
}

jobject make_stain_box(JNIEnv* env, const JniStainMarshalling& cache, const Detection& d) {
    return env->NewObject(cache.box_cls,
                          cache.box_ctor,
                          d.x1,
                          d.y1,
                          d.x2,
                          d.y2,
                          static_cast<jint>(d.cls_id),
                          d.conf);
}

jobject make_stain_infer_outcome(JNIEnv* env, const StainInferOutcome& outcome) {
    JniStainMarshalling& cache = jni_stain_marshalling(env);
    if (!cache.outcome_cls || !cache.outcome_ctor) return nullptr;

    jstring j_error = to_jstring(env, outcome.error_message);
    jstring j_source = outcome.code == 0 ? to_jstring(env, outcome.source) : nullptr;
    jstring j_status = outcome.code == 0 ? to_jstring(env, outcome.status) : nullptr;
    jstring j_detail = outcome.code == 0 ? to_jstring(env, outcome.detail_message) : nullptr;

    jobjectArray j_boxes = nullptr;
    if (outcome.code == 0 && !outcome.boxes.empty()) {
        j_boxes = env->NewObjectArray(static_cast<jsize>(outcome.boxes.size()),
                                      cache.box_cls,
                                      nullptr);
        if (j_boxes) {
            for (jsize i = 0; i < static_cast<jsize>(outcome.boxes.size()); ++i) {
                jobject box = make_stain_box(env, cache, outcome.boxes[static_cast<std::size_t>(i)]);
                env->SetObjectArrayElement(j_boxes, i, box);
                env->DeleteLocalRef(box);
            }
        }
    }

    jobject obj = env->NewObject(cache.outcome_cls,
                                 cache.outcome_ctor,
                                 static_cast<jint>(outcome.code),
                                 j_error,
                                 j_source,
                                 static_cast<jint>(outcome.level),
                                 j_status,
                                 j_detail,
                                 static_cast<jint>(outcome.image_width),
                                 static_cast<jint>(outcome.image_height),
                                 j_boxes,
                                 outcome.boxes_truncated ? JNI_TRUE : JNI_FALSE,
                                 static_cast<jint>(outcome.boxes_total));
    if (j_boxes) env->DeleteLocalRef(j_boxes);
    env->DeleteLocalRef(j_error);
    if (j_source) env->DeleteLocalRef(j_source);
    if (j_status) env->DeleteLocalRef(j_status);
    if (j_detail) env->DeleteLocalRef(j_detail);
    return obj;
}

CentralScheduler* scheduler_from_handle(jlong handle) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx || !ctx->scheduler) return nullptr;
    return ctx->scheduler.get();
}

StainInferOutcome infer_image_path_outcome(CentralScheduler* sched, const char* path) {
    if (!path || path[0] == '\0') return StainInferOutcome::error(-1, "empty image path");
    return sched->inferImageFromPath(path);
}

StainInferOutcome infer_nv12_buffer(JNIEnv* env,
                                    CentralScheduler* sched,
                                    jobject nv12,
                                    jint width,
                                    jint height) {
    const uint8_t* ptr = nullptr;
    int len = 0;
    std::string err;
    if (!nv12_direct_buffer_view(env, nv12, width, height, ptr, len, err))
        return StainInferOutcome::error(-1, err);
    return sched->inferNv12Frame(ptr, len, width, height);
}

bool rgba_direct_buffer_to_bgr(JNIEnv* env,
                               jobject rgb_buffer,
                               jint width,
                               jint height,
                               jint row_stride_bytes,
                               cv::Mat& out_bgr,
                               std::string& err) {
    if (!rgb_buffer) {
        err = "rgb buffer must not be null";
        return false;
    }
    if (width <= 0 || height <= 0) {
        err = "invalid width or height";
        return false;
    }
    void* base = env->GetDirectBufferAddress(rgb_buffer);
    if (!base) {
        err = "rgb buffer must be a direct ByteBuffer";
        return false;
    }
    const jlong capacity = env->GetDirectBufferCapacity(rgb_buffer);
    const int stride = (row_stride_bytes > 0) ? row_stride_bytes : (width * 4);
    if (stride < width * 4) {
        err = "rowStrideBytes smaller than width*4";
        return false;
    }
    const std::size_t need =
        static_cast<std::size_t>(stride) * static_cast<std::size_t>(height - 1) +
        static_cast<std::size_t>(width) * 4U;
    if (capacity < 0 || static_cast<std::size_t>(capacity) < need) {
        err = "rgb buffer capacity too small for frame";
        return false;
    }
    const cv::Mat rgba(height, width, CV_8UC4, base, static_cast<std::size_t>(stride));
    cv::cvtColor(rgba, out_bgr, cv::COLOR_RGBA2BGR);
    return true;
}

StainInferOutcome infer_rgba_buffer_outcome(JNIEnv* env,
                                            CentralScheduler* sched,
                                            jobject rgb_buffer,
                                            jint width,
                                            jint height,
                                            jint row_stride_bytes) {
    cv::Mat bgr;
    std::string err;
    if (!rgba_direct_buffer_to_bgr(env, rgb_buffer, width, height, row_stride_bytes, bgr, err))
        return StainInferOutcome::error(-1, err);
    return sched->inferImageFromBgr(bgr, "offline_infer");
}

}  // namespace infer_jni

using infer_jni::infer_nv12_buffer;
using infer_jni::infer_image_path_outcome;
using infer_jni::infer_rgba_buffer_outcome;
using infer_jni::make_err_json;
using infer_jni::make_stain_infer_outcome;
using infer_jni::parse_json_code;
using infer_jni::scheduler_from_handle;

extern "C" {

// ── nativeRknnStainDetectFromJpg ───────────────────────

JNIEXPORT jobject JNICALL
JNI_FN(nativeRknnStainDetectFromJpg)(JNIEnv* env, jclass /*clazz*/, jlong handle, jstring imagePath, jint cameraType) {
    ignore_camera_type(cameraType);
    CentralScheduler* sched = scheduler_from_handle(handle);
    if (!sched) return make_stain_infer_outcome(env, StainInferOutcome::error(-1, "invalid handle"));
    if (!imagePath)
        return make_stain_infer_outcome(env, StainInferOutcome::error(-1, "imagePath must not be null"));
    const char* cImagePath = env->GetStringUTFChars(imagePath, nullptr);
    if (!cImagePath)
        return make_stain_infer_outcome(env, StainInferOutcome::error(-1, "failed to read imagePath"));
    const StainInferOutcome outcome = infer_image_path_outcome(sched, cImagePath);
    env->ReleaseStringUTFChars(imagePath, cImagePath);
    return make_stain_infer_outcome(env, outcome);
}

// ── nativeRknnStainDetectFromNv12 ─────────────────────────

JNIEXPORT jobject JNICALL
JNI_FN(nativeRknnStainDetectFromNv12)(JNIEnv* env, jclass /*clazz*/, jlong handle, jobject nv12, jint width,
                        jint height, jint cameraType) {
    ignore_camera_type(cameraType);
    CentralScheduler* sched = scheduler_from_handle(handle);
    if (!sched) return make_stain_infer_outcome(env, StainInferOutcome::error(-1, "invalid handle"));
    const StainInferOutcome outcome = infer_nv12_buffer(env, sched, nv12, width, height);
    return make_stain_infer_outcome(env, outcome);
}

// ── nativeRknnStainDetectFromRgb ───────────────────────────

JNIEXPORT jobject JNICALL
JNI_FN(nativeRknnStainDetectFromRgb)(JNIEnv* env, jclass /*clazz*/, jlong handle, jobject rgbBuffer, jint width,
                       jint height, jint rowStrideBytes, jint cameraType) {
    ignore_camera_type(cameraType);
    CentralScheduler* sched = scheduler_from_handle(handle);
    if (!sched) return make_stain_infer_outcome(env, StainInferOutcome::error(-1, "invalid handle"));
    const StainInferOutcome outcome =
        infer_rgba_buffer_outcome(env, sched, rgbBuffer, width, height, rowStrideBytes);
    return make_stain_infer_outcome(env, outcome);
}

// ── nativeSetLaserOn(handle, on) ─────────────────────────────
// 机器端 App 监听 CacheKey.DEVICE_STATUS_KEY 获取 DeviceStatus.isLaserOn()，
// 状态变化时调用此方法推送给 C++ 检测引擎。

JNIEXPORT void JNICALL
JNI_FN(nativeSetLaserOn)(JNIEnv* /*env*/, jclass /*clazz*/, jlong handle, jboolean on) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx || !ctx->scheduler) return;
    ctx->scheduler->setLaserOn(on == JNI_TRUE);
}

// ── nativeSetAiVisionPreviewClassificationEnabled(handle, enabled) ──
// AI Vision preview may request classification while the real laser is OFF.
// This does not enter MONITORING and does not mutate the welding state machine.

JNIEXPORT void JNICALL
JNI_FN(nativeSetAiVisionPreviewClassificationEnabled)(JNIEnv* /*env*/, jclass /*clazz*/,
                                                      jlong handle, jboolean enabled) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx || !ctx->scheduler) return;
    ctx->scheduler->setAiVisionPreviewClassificationEnabled(enabled == JNI_TRUE);
    JNI_LOGI("nativeSetAiVisionPreviewClassificationEnabled: %d", enabled == JNI_TRUE ? 1 : 0);
}

// ── nativeSetAiVisionPreviewDetectionEnabled(handle, enabled) ───────
// AI Vision preview may request low-rate side-effect-free stain detection while
// the real laser is OFF. Results are emitted with message.source=preview_det.

JNIEXPORT void JNICALL
JNI_FN(nativeSetAiVisionPreviewDetectionEnabled)(JNIEnv* /*env*/, jclass /*clazz*/,
                                                 jlong handle, jboolean enabled) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx || !ctx->scheduler) return;
    ctx->scheduler->setAiVisionPreviewDetectionEnabled(enabled == JNI_TRUE);
    JNI_LOGI("nativeSetAiVisionPreviewDetectionEnabled: %d", enabled == JNI_TRUE ? 1 : 0);
}

// ── nativeSetDeviceContext(handle, sn, stationId) ───────────
JNIEXPORT void JNICALL
JNI_FN(nativeSetDeviceContext)(JNIEnv* env, jclass /*clazz*/, jlong handle,
                               jstring sn, jstring stationId) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx || !ctx->scheduler) return;
    const char* cSn = sn ? env->GetStringUTFChars(sn, nullptr) : "";
    const char* cStation = stationId ? env->GetStringUTFChars(stationId, nullptr) : "";
    ctx->scheduler->setDeviceContext(cSn ? cSn : "", cStation ? cStation : "");
    if (sn && cSn) env->ReleaseStringUTFChars(sn, cSn);
    if (stationId && cStation) env->ReleaseStringUTFChars(stationId, cStation);
}

// ── nativePushCameraParams(handle, exposure, gain, light, fps) ──
JNIEXPORT void JNICALL
JNI_FN(nativePushCameraParams)(JNIEnv* /*env*/, jclass /*clazz*/, jlong handle,
                               jfloat exposureTime, jfloat gain, jfloat lightLevel, jfloat fps) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx || !ctx->scheduler) return;
    ctx->scheduler->pushCameraParams(exposureTime, gain, lightLevel, fps);
}

// ── nativePushFrameMeta(handle, timestampMs, frameId) ────────
JNIEXPORT void JNICALL
JNI_FN(nativePushFrameMeta)(JNIEnv* /*env*/, jclass /*clazz*/, jlong handle,
                            jlong timestampMs, jlong frameId) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx || !ctx->scheduler) return;
    ctx->scheduler->pushFrameMeta(timestampMs, frameId);
}

// ── nativeNotifyModelSwitched(handle, modelVersion) ──────────
JNIEXPORT void JNICALL
JNI_FN(nativeNotifyModelSwitched)(JNIEnv* env, jclass /*clazz*/, jlong handle, jstring modelVersion) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx || !ctx->scheduler) return;
    const char* cModel = modelVersion ? env->GetStringUTFChars(modelVersion, nullptr) : "";
    ctx->scheduler->notifyModelSwitched(cModel ? cModel : "");
    if (modelVersion && cModel) env->ReleaseStringUTFChars(modelVersion, cModel);
}

// ── nativeSetListener(handle, listener) ─────────────────────

JNIEXPORT void JNICALL
JNI_FN(nativeSetListener)(JNIEnv* env, jclass /*clazz*/, jlong handle, jobject listener) {
    auto* ctx = reinterpret_cast<NativeContext*>(handle);
    if (!ctx || !ctx->scheduler) return;

    // Release old global ref
    if (ctx->listener) {
        env->DeleteGlobalRef(ctx->listener);
        ctx->listener = nullptr;
    }

    if (!listener) {
        ctx->scheduler->setCallbacks({});
        return;
    }

    ctx->listener = env->NewGlobalRef(listener);

    jclass cls = env->GetObjectClass(listener);
    ctx->mid_state  = env->GetMethodID(cls, "onStateChanged",  "(I)V");
    ctx->mid_result = env->GetMethodID(cls, "onCheckResult",   "(ILjava/lang/String;Ljava/lang/String;)V");

    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        JNI_LOGE("nativeSetListener: method lookup failed\n");
    }

    setup_callbacks(ctx);
    JNI_LOGI("nativeSetListener: OK\n");
}

} // extern "C"
