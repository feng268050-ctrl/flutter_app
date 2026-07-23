// EdgeDrawing single-frame zero detect JNI. Mirrors zero_point_jni.cpp.
#include "config.h"
#include "edgedrawing_context.h"
#include "edgedrawing_json.h"

#include "opencv_detect_codes.h"
#include "stream_detect/yuv_convert.h"

#include <jni.h>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#ifdef __ANDROID__
#include <android/log.h>
#define ED_LOGI(...) __android_log_print(ANDROID_LOG_INFO, "EdgeDrawingJNI", __VA_ARGS__)
#define ED_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "EdgeDrawingJNI", __VA_ARGS__)
#else
#include <cstdio>
#define ED_LOGI(...) std::printf(__VA_ARGS__)
#define ED_LOGE(...) std::fprintf(stderr, __VA_ARGS__)
#endif

namespace {

jstring newString(JNIEnv* env, const std::string& value) {
    return env->NewStringUTF(value.c_str());
}

std::string getString(JNIEnv* env, jstring value) {
    if (!value) {
        return "";
    }
    const char* chars = env->GetStringUTFChars(value, nullptr);
    if (!chars) {
        return "";
    }
    std::string out(chars);
    env->ReleaseStringUTFChars(value, chars);
    return out;
}

bool directBufferView(JNIEnv* env,
                      jobject buffer,
                      std::size_t required_capacity,
                      const uint8_t*& ptr,
                      std::string& error) {
    if (!buffer) {
        error = "buffer must not be null";
        return false;
    }
    void* base = env->GetDirectBufferAddress(buffer);
    if (!base) {
        error = "buffer must be a direct ByteBuffer";
        return false;
    }
    const jlong capacity = env->GetDirectBufferCapacity(buffer);
    if (capacity < 0 || static_cast<std::size_t>(capacity) < required_capacity) {
        error = "buffer capacity too small";
        return false;
    }
    ptr = reinterpret_cast<const uint8_t*>(base);
    return true;
}

edgedrawing::Context* fromHandle(jlong handle) {
    return reinterpret_cast<edgedrawing::Context*>(handle);
}

std::string detectBgrToJson(edgedrawing::Context* ctx, const cv::Mat& bgr) {
    const edgedrawing::FrameResult result = ctx->detectBgr(bgr);
    return edgedrawing::frameResultToJson(result);
}

}  // namespace

#define JNI_FN(name) Java_com_lasercyber_lws_ai_NativeBridge_##name

extern "C" {

JNIEXPORT jlong JNICALL
JNI_FN(nativeCreateOpencvEdgeDrawingDetector)(JNIEnv* env,
                                              jclass /*clazz*/,
                                              jstring roiJsonPath,
                                              jfloat tolerancePx) {
    const std::string path = getString(env, roiJsonPath);
    try {
        apply_opencv_detect_red_frame_gate_near(path);
        auto* ctx = new edgedrawing::Context(
            path,
            tolerancePx > 0.0f ? static_cast<double>(tolerancePx) : 10.0);
        return reinterpret_cast<jlong>(ctx);
    } catch (const std::exception& ex) {
        ED_LOGE("nativeCreateOpencvEdgeDrawingDetector failed: %s\n", ex.what());
        return 0;
    }
}

JNIEXPORT void JNICALL
JNI_FN(nativeDestroyOpencvEdgeDrawingDetector)(JNIEnv* /*env*/, jclass /*clazz*/, jlong handle) {
    delete fromHandle(handle);
}

JNIEXPORT jstring JNICALL
JNI_FN(nativeOpencvEdgeDrawingDetectFromJpg)(JNIEnv* env,
                                             jclass /*clazz*/,
                                             jlong handle,
                                             jstring imagePath) {
    edgedrawing::Context* ctx = fromHandle(handle);
    if (!ctx) {
        return newString(env, edgedrawing::errorJson(opencv_detect::kInvalidHandle,
                                                     opencv_detect::kReasonInvalidDetectorHandle));
    }
    const std::string path = getString(env, imagePath);
    if (path.empty()) {
        return newString(env, edgedrawing::errorJson(opencv_detect::kInvalidInput,
                                                    opencv_detect::kReasonEmptyImagePath));
    }
    cv::Mat bgr = cv::imread(path, cv::IMREAD_COLOR);
    if (bgr.empty()) {
        return newString(env, edgedrawing::errorJson(opencv_detect::kIoError,
                                                    opencv_detect::kReasonFailedToReadImage));
    }
    return newString(env, detectBgrToJson(ctx, bgr));
}

JNIEXPORT jstring JNICALL
JNI_FN(nativeOpencvEdgeDrawingDetectFromRgb)(JNIEnv* env,
                                             jclass /*clazz*/,
                                             jlong handle,
                                             jobject rgba,
                                             jint width,
                                             jint height,
                                             jint rowStrideBytes) {
    edgedrawing::Context* ctx = fromHandle(handle);
    if (!ctx) {
        return newString(env, edgedrawing::errorJson(opencv_detect::kInvalidHandle,
                                                     opencv_detect::kReasonInvalidDetectorHandle));
    }
    if (width <= 0 || height <= 0) {
        return newString(env, edgedrawing::errorJson(opencv_detect::kInvalidInput,
                                                     opencv_detect::kReasonInvalidRgbDimensions));
    }
    const int stride = rowStrideBytes > 0 ? rowStrideBytes : width * 4;
    const std::size_t required =
        static_cast<std::size_t>(stride) * static_cast<std::size_t>(height - 1) +
        static_cast<std::size_t>(width) * 4U;
    const uint8_t* ptr = nullptr;
    std::string error;
    if (!directBufferView(env, rgba, required, ptr, error)) {
        return newString(env, edgedrawing::errorJson(opencv_detect::kInvalidInput,
                                                     opencv_detect::kReasonInvalidDirectBuffer));
    }

    cv::Mat rgba_mat;
    if (stride == width * 4) {
        rgba_mat = cv::Mat(height, width, CV_8UC4, const_cast<uint8_t*>(ptr));
    } else {
        rgba_mat.create(height, width, CV_8UC4);
        for (int y = 0; y < height; ++y) {
            std::memcpy(rgba_mat.ptr(y), ptr + static_cast<std::size_t>(y) * stride, width * 4U);
        }
    }
    cv::Mat bgr;
    cv::cvtColor(rgba_mat, bgr, cv::COLOR_RGBA2BGR);
    return newString(env, detectBgrToJson(ctx, bgr));
}

JNIEXPORT jstring JNICALL
JNI_FN(nativeOpencvEdgeDrawingDetectFromNv12)(JNIEnv* env,
                                              jclass /*clazz*/,
                                              jlong handle,
                                              jobject nv12,
                                              jint width,
                                              jint height) {
    edgedrawing::Context* ctx = fromHandle(handle);
    if (!ctx) {
        return newString(env, edgedrawing::errorJson(opencv_detect::kInvalidHandle,
                                                     opencv_detect::kReasonInvalidDetectorHandle));
    }
    if (width <= 0 || height <= 0) {
        return newString(env, edgedrawing::errorJson(opencv_detect::kInvalidInput,
                                                     opencv_detect::kReasonInvalidI420Dimensions));
    }
    const std::size_t expected =
        static_cast<std::size_t>(width) * static_cast<std::size_t>(height) * 3U / 2U;
    const uint8_t* ptr = nullptr;
    std::string error;
    if (!directBufferView(env, nv12, expected, ptr, error)) {
        return newString(env, edgedrawing::errorJson(opencv_detect::kInvalidInput,
                                                     opencv_detect::kReasonInvalidDirectBuffer));
    }
    cv::Mat bgr;
    if (!stream_detect::nv12ToBgr(ptr, width, height, bgr)) {
        return newString(env, edgedrawing::errorJson(opencv_detect::kInvalidInput,
                                                     opencv_detect::kReasonInvalidDirectBuffer));
    }
    return newString(env, detectBgrToJson(ctx, bgr));
}

}  // extern "C"
