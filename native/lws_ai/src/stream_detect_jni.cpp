#include "stream_detect/stream_detect_config.h"
#include "stream_detect/stream_detect_event.h"
#include "stream_detect/stream_detect_pipeline.h"
#include "stream_detect/detect_runner.h"
#include "central_scheduler.h"
#include "handle_access.h"
#include "stain_infer_outcome.h"

#include <mutex>

#ifdef __ANDROID__
#include <jni.h>
#endif

namespace {

std::mutex g_mutex;
std::unique_ptr<stream_detect::StreamDetectPipeline> g_pipeline;
stream_detect::SessionConfig g_config;
bool g_rknn_hook_registered = false;

void jniRknnStreamInfer(const cv::Mat& bgr,
                        int64_t rknn_session_handle,
                        const char* source,
                        std::string* out_summary_json,
                        int* out_code,
                        bool* out_ok) {
    CentralScheduler* scheduler = central_scheduler_from_handle(rknn_session_handle);
    if (!scheduler) {
        *out_ok = false;
        *out_code = -1;
        *out_summary_json = stain_infer_outcome_to_json(
                StainInferOutcome::error(-1, "invalid rknn session handle"));
        return;
    }
    const StainInferOutcome result =
            scheduler->inferImageFromBgr(bgr, source != nullptr ? source : "live_infer");
    *out_summary_json = stain_infer_outcome_to_json(result);
    *out_ok = result.code == 0;
    *out_code = result.code;
}

void ensureRknnHook() {
    if (g_rknn_hook_registered) {
        return;
    }
    stream_detect::setRknnStreamInferHook(&jniRknnStreamInfer);
    g_rknn_hook_registered = true;
}

stream_detect::StreamDetectPipeline* pipeline() {
    std::lock_guard<std::mutex> lock(g_mutex);
    ensureRknnHook();
    if (!g_pipeline) {
        g_pipeline = std::make_unique<stream_detect::StreamDetectPipeline>();
    }
    return g_pipeline.get();
}

}  // namespace

extern "C" {

JNIEXPORT void JNICALL
Java_com_lasercyber_lws_ai_NativeBridge_nativeSetStreamDetectListener(JNIEnv* env,
                                                                      jclass /*clazz*/,
                                                                      jobject listener) {
    if (listener) {
        stream_detect::setStreamDetectListener(env, listener);
    } else {
        stream_detect::clearStreamDetectListener(env);
    }
}

JNIEXPORT void JNICALL
Java_com_lasercyber_lws_ai_NativeBridge_nativeConfigureStreamDetect(
    JNIEnv* env,
    jclass /*clazz*/,
    jlong opencvStainHandle,
    jstring jOutputDir,
    jint cameraType,
    jboolean lensDetEnabled,
    jboolean rknnStreamEnabled,
    jlong rknnSessionHandle,
    jlong zeroPointHandle,
    jboolean zeroPointEnabled,
    jlong edgeDrawingHandle,
    jboolean edgeDrawingEnabled,
    jstring jSessionSource) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_config.opencv_stain_session_handle = opencvStainHandle;
    g_config.rknn_session_handle = rknnSessionHandle;
    g_config.zero_point_handle = zeroPointHandle;
    g_config.edgedrawing_handle = edgeDrawingHandle;
    g_config.camera_type = cameraType;
    g_config.lens_det_enabled = lensDetEnabled == JNI_TRUE;
    g_config.zero_point_enabled = zeroPointEnabled == JNI_TRUE;
    g_config.edgedrawing_enabled = edgeDrawingEnabled == JNI_TRUE;
    g_config.rknn_stream_enabled = rknnStreamEnabled == JNI_TRUE;
    g_config.output_dir.clear();
    g_config.session_source = "live_stain_detect";
    if (jOutputDir) {
        const char* dir = env->GetStringUTFChars(jOutputDir, nullptr);
        if (dir) {
            g_config.output_dir = dir;
            env->ReleaseStringUTFChars(jOutputDir, dir);
        }
    }
    if (jSessionSource) {
        const char* source = env->GetStringUTFChars(jSessionSource, nullptr);
        if (source) {
            g_config.session_source = source;
            env->ReleaseStringUTFChars(jSessionSource, source);
        }
    }
    if (g_pipeline) {
        g_pipeline->updateConfig(g_config);
    }
}

JNIEXPORT jboolean JNICALL
Java_com_lasercyber_lws_ai_NativeBridge_nativeStartStreamDetect(JNIEnv* env,
                                                                jclass /*clazz*/,
                                                                jstring jRtspUrl) {
    if (!jRtspUrl) {
        return JNI_FALSE;
    }
    const char* urlChars = env->GetStringUTFChars(jRtspUrl, nullptr);
    if (!urlChars) {
        return JNI_FALSE;
    }
    const bool ok = pipeline()->start(urlChars, g_config);
    env->ReleaseStringUTFChars(jRtspUrl, urlChars);
    return ok ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_lasercyber_lws_ai_NativeBridge_nativeStopStreamDetect(JNIEnv* /*env*/, jclass /*clazz*/) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_pipeline) {
        g_pipeline->stop();
    }
}

JNIEXPORT void JNICALL
Java_com_lasercyber_lws_ai_NativeBridge_nativeSetStreamDetectLaserOn(JNIEnv* /*env*/,
                                                                    jclass /*clazz*/,
                                                                    jboolean on) {
    pipeline()->setLaserOn(on == JNI_TRUE);
}

JNIEXPORT void JNICALL
Java_com_lasercyber_lws_ai_NativeBridge_nativeSetStreamDetectBurstMode(JNIEnv* /*env*/,
                                                                       jclass /*clazz*/,
                                                                       jboolean burst) {
    pipeline()->setBurstMode(burst == JNI_TRUE);
}

JNIEXPORT void JNICALL
Java_com_lasercyber_lws_ai_NativeBridge_nativeSetStreamDetectZeroPointTargetMode(
    JNIEnv* /*env*/,
    jclass /*clazz*/,
    jint targetMode) {
    pipeline()->setZeroPointTargetMode(targetMode);
}

JNIEXPORT jboolean JNICALL
Java_com_lasercyber_lws_ai_NativeBridge_nativeIsStreamDetectRunning(JNIEnv* /*env*/,
                                                                    jclass /*clazz*/) {
    return pipeline()->isRunning() ? JNI_TRUE : JNI_FALSE;
}

}  // extern "C"
