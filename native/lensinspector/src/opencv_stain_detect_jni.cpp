#include "opencv_stain_detect_session.h"
#include "opencv_stain_detect/opencv_stain_detect_analyzer.h"

#include "opencv_detect_codes.h"
#include "stream_detect/yuv_convert.h"

#include <jni.h>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include <cstdint>
#include <cstring>
#include <string>

#ifdef __ANDROID__
#include <android/log.h>
#define LD_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "OpencvStainDetectJNI", __VA_ARGS__)
#else
#include <cstdio>
#define LD_LOGE(...) std::fprintf(stderr, __VA_ARGS__)
#endif

namespace {

opencv_stain_detect::Session* fromHandle(jlong handle) {
    return reinterpret_cast<opencv_stain_detect::Session*>(handle);
}

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

std::string analyzeBgr(const cv::Mat& bgr, opencv_stain_detect::Session* session, const std::string& output_dir) {
    if (!session) {
        return opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kInvalidHandle, opencv_detect::kReasonInvalidSessionHandle));
    }
    return opencv_stain_detect::summaryToJson(
        opencv_stain_detect::analyzeOpencvStainDetectBgr(
            bgr,
            session->options(),
            output_dir,
            &session->islandSlotSession()));
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

}  // namespace

#define JNI_FN(name) Java_com_lasercyber_lws_ai_NativeBridge_##name

// TODO(camera-type): branch on RED_LIGHT (2) for model/ROI selection when red-light path ships.
static void ignore_camera_type(jint cameraType) {
    (void)cameraType;
}

extern "C" {

JNIEXPORT jlong JNICALL
JNI_FN(nativeCreateOpencvStainDetectSession)(JNIEnv* env,
                                         jclass /*clazz*/,
                                         jstring configYamlPath,
                                         jstring projectRoot,
                                         jint cameraType) {
    ignore_camera_type(cameraType);
    const std::string config_path = getString(env, configYamlPath);
    const std::string root = getString(env, projectRoot);
    if (config_path.empty()) {
        LD_LOGE("nativeCreateOpencvStainDetectSession: empty config path\n");
        return 0;
    }
    try {
        auto* session = new opencv_stain_detect::Session(config_path, root);
        return reinterpret_cast<jlong>(session);
    } catch (const std::exception& ex) {
        LD_LOGE("nativeCreateOpencvStainDetectSession failed: %s\n", ex.what());
        return 0;
    }
}

JNIEXPORT void JNICALL
JNI_FN(nativeDestroyOpencvStainDetectSession)(JNIEnv* /*env*/, jclass /*clazz*/, jlong opencvStainDetectHandle) {
    delete fromHandle(opencvStainDetectHandle);
}

JNIEXPORT jstring JNICALL
JNI_FN(nativeOpencvStainDetectFromJpg)(JNIEnv* env,
                                 jclass /*clazz*/,
                                 jlong opencvStainDetectHandle,
                                 jstring imagePath,
                                 jstring outputDir,
                                 jint cameraType) {
    ignore_camera_type(cameraType);
    opencv_stain_detect::Session* session = fromHandle(opencvStainDetectHandle);
    if (!session) {
        return newString(env, opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kInvalidHandle, opencv_detect::kReasonInvalidSessionHandle)));
    }
    const std::string path = getString(env, imagePath);
    const std::string out_dir = getString(env, outputDir);
    if (path.empty()) {
        return newString(env, opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kInvalidInput, opencv_detect::kReasonEmptyImagePath)));
    }
    if (out_dir.empty()) {
        return newString(env, opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kInvalidInput, opencv_detect::kReasonEmptyOutputDir)));
    }
    cv::Mat bgr = cv::imread(path, cv::IMREAD_COLOR);
    if (bgr.empty()) {
        return newString(env, opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kIoError, opencv_detect::kReasonFailedToReadImage)));
    }
    return newString(env, analyzeBgr(bgr, session, out_dir));
}

JNIEXPORT jstring JNICALL
JNI_FN(nativeOpencvStainDetectFromRgb)(JNIEnv* env,
                               jclass /*clazz*/,
                               jlong opencvStainDetectHandle,
                               jobject rgba,
                               jint width,
                               jint height,
                               jint rowStrideBytes,
                               jstring outputDir,
                               jint cameraType) {
    ignore_camera_type(cameraType);
    opencv_stain_detect::Session* session = fromHandle(opencvStainDetectHandle);
    if (!session) {
        return newString(env, opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kInvalidHandle, opencv_detect::kReasonInvalidSessionHandle)));
    }
    const std::string out_dir = getString(env, outputDir);
    if (out_dir.empty()) {
        return newString(env, opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kInvalidInput, opencv_detect::kReasonEmptyOutputDir)));
    }
    if (width <= 0 || height <= 0) {
        return newString(env, opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kInvalidInput, opencv_detect::kReasonInvalidRgbDimensions)));
    }
    const int stride = rowStrideBytes > 0 ? rowStrideBytes : width * 4;
    if (stride < width * 4) {
        return newString(env, opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kInvalidInput, opencv_detect::kReasonInvalidRgbStride)));
    }
    const std::size_t required =
        static_cast<std::size_t>(stride) * static_cast<std::size_t>(height - 1) +
        static_cast<std::size_t>(width) * 4U;
    const uint8_t* ptr = nullptr;
    std::string error;
    if (!directBufferView(env, rgba, required, ptr, error)) {
        return newString(env, opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kInvalidInput, opencv_detect::kReasonInvalidDirectBuffer)));
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
    return newString(env, analyzeBgr(bgr, session, out_dir));
}

JNIEXPORT jstring JNICALL
JNI_FN(nativeOpencvStainDetectFromNv12)(JNIEnv* env,
                                jclass /*clazz*/,
                                jlong opencvStainDetectHandle,
                                jobject nv12,
                                jint width,
                                jint height,
                                jstring outputDir,
                                jint cameraType) {
    ignore_camera_type(cameraType);
    opencv_stain_detect::Session* session = fromHandle(opencvStainDetectHandle);
    if (!session) {
        return newString(env, opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kInvalidHandle, opencv_detect::kReasonInvalidSessionHandle)));
    }
    const std::string out_dir = getString(env, outputDir);
    if (out_dir.empty()) {
        return newString(env, opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kInvalidInput, opencv_detect::kReasonEmptyOutputDir)));
    }
    if (width <= 0 || height <= 0) {
        return newString(env, opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kInvalidInput, opencv_detect::kReasonInvalidI420Dimensions)));
    }
    const std::size_t expected =
        static_cast<std::size_t>(width) * static_cast<std::size_t>(height) * 3U / 2U;
    const uint8_t* ptr = nullptr;
    std::string error;
    if (!directBufferView(env, nv12, expected, ptr, error)) {
        return newString(env, opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kInvalidInput, opencv_detect::kReasonInvalidDirectBuffer)));
    }

    cv::Mat bgr;
    if (!stream_detect::nv12ToBgr(ptr, width, height, bgr)) {
        return newString(env, opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kInvalidInput, opencv_detect::kReasonInvalidDirectBuffer)));
    }
    return newString(env, analyzeBgr(bgr, session, out_dir));
}

}  // extern "C"
