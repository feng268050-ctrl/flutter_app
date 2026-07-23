#include "media_codec_decoder.h"

#include <cstring>

#ifdef __ANDROID__
#include <android/log.h>
#include <media/NdkMediaCodec.h>
#include <media/NdkMediaFormat.h>
#define SD_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "StreamDetect", __VA_ARGS__)
#else
#define SD_LOGE(...) ((void)0)
#endif

namespace stream_detect {

struct MediaCodecDecoder::Impl {
#ifdef __ANDROID__
    AMediaCodec* codec = nullptr;
#endif
    int width = 0;
    int height = 0;
};

MediaCodecDecoder::MediaCodecDecoder() : impl_(new Impl()) {}

MediaCodecDecoder::~MediaCodecDecoder() {
    release();
    delete impl_;
    impl_ = nullptr;
}

bool MediaCodecDecoder::configure(const std::string& mime, int width, int height) {
    release();
#ifndef __ANDROID__
    (void)mime;
    (void)width;
    (void)height;
    return false;
#else
    impl_->width = width;
    impl_->height = height;
    impl_->codec = AMediaCodec_createDecoderByType(mime.c_str());
    if (!impl_->codec) {
        SD_LOGE("decoder create failed mime=%s", mime.c_str());
        return false;
    }
    AMediaFormat* format = AMediaFormat_new();
    AMediaFormat_setString(format, AMEDIAFORMAT_KEY_MIME, mime.c_str());
    AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_WIDTH, width);
    AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_HEIGHT, height);
    media_status_t status = AMediaCodec_configure(
        impl_->codec, format, nullptr, nullptr, 0);
    AMediaFormat_delete(format);
    if (status != AMEDIA_OK) {
        SD_LOGE("decoder configure failed status=%d", status);
        release();
        return false;
    }
    status = AMediaCodec_start(impl_->codec);
    if (status != AMEDIA_OK) {
        SD_LOGE("decoder start failed status=%d", status);
        release();
        return false;
    }
    return true;
#endif
}

bool MediaCodecDecoder::configureAvc(int width,
                                     int height,
                                     const std::vector<uint8_t>& sps,
                                     const std::vector<uint8_t>& pps) {
#ifndef __ANDROID__
    (void)width;
    (void)height;
    (void)sps;
    (void)pps;
    return false;
#else
    release();
    impl_->width = width;
    impl_->height = height;
    impl_->codec = AMediaCodec_createDecoderByType("video/avc");
    if (!impl_->codec) {
        SD_LOGE("decoder create failed mime=video/avc");
        return false;
    }
    AMediaFormat* format = AMediaFormat_new();
    AMediaFormat_setString(format, AMEDIAFORMAT_KEY_MIME, "video/avc");
    AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_WIDTH, width);
    AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_HEIGHT, height);
    if (!sps.empty()) {
        AMediaFormat_setBuffer(format, "csd-0", const_cast<uint8_t*>(sps.data()), sps.size());
    }
    if (!pps.empty()) {
        AMediaFormat_setBuffer(format, "csd-1", const_cast<uint8_t*>(pps.data()), pps.size());
    }
    const media_status_t status = AMediaCodec_configure(
        impl_->codec, format, nullptr, nullptr, 0);
    AMediaFormat_delete(format);
    if (status != AMEDIA_OK) {
        SD_LOGE("decoder configureAvc failed status=%d", status);
        release();
        return false;
    }
    if (AMediaCodec_start(impl_->codec) != AMEDIA_OK) {
        SD_LOGE("decoder start failed");
        release();
        return false;
    }
    return true;
#endif
}

void MediaCodecDecoder::release() {
#ifdef __ANDROID__
    if (impl_->codec) {
        AMediaCodec_stop(impl_->codec);
        AMediaCodec_delete(impl_->codec);
        impl_->codec = nullptr;
    }
#endif
}

bool MediaCodecDecoder::queueNal(const uint8_t* data, size_t size, int64_t ptsUs) {
    return queueAccessUnit(data, size, ptsUs, false);
}

bool MediaCodecDecoder::queueAccessUnit(const uint8_t* data,
                                      size_t size,
                                      int64_t ptsUs,
                                      bool keyFrame) {
#ifndef __ANDROID__
    (void)data;
    (void)size;
    (void)ptsUs;
    (void)keyFrame;
    return false;
#else
    if (!impl_->codec || !data || size == 0) {
        return false;
    }
    ssize_t index = AMediaCodec_dequeueInputBuffer(impl_->codec, 5000);
    if (index < 0) {
        return false;
    }
    size_t capacity = 0;
    uint8_t* buf = AMediaCodec_getInputBuffer(impl_->codec, static_cast<size_t>(index), &capacity);
    if (!buf || capacity < size) {
        AMediaCodec_queueInputBuffer(impl_->codec, static_cast<size_t>(index), 0, 0, ptsUs, 0);
        return false;
    }
    memcpy(buf, data, size);
    AMediaCodec_queueInputBuffer(
        impl_->codec, static_cast<size_t>(index), 0, size, ptsUs, 0);
    (void)keyFrame;
    return true;
#endif
}

bool MediaCodecDecoder::tryDequeueOutput(std::vector<uint8_t>& nv12Out,
                                         int& width,
                                         int& height,
                                         int64_t& ptsUs,
                                         int timeoutUs) {
#ifndef __ANDROID__
    (void)nv12Out;
    width = height = 0;
    ptsUs = 0;
    (void)timeoutUs;
    return false;
#else
    if (!impl_->codec) {
        return false;
    }
    AMediaCodecBufferInfo info{};
    const ssize_t index = AMediaCodec_dequeueOutputBuffer(impl_->codec, &info, timeoutUs);
    if (index == AMEDIACODEC_INFO_TRY_AGAIN_LATER) {
        return false;
    }
    if (index == AMEDIACODEC_INFO_OUTPUT_FORMAT_CHANGED) {
        AMediaFormat* format = AMediaCodec_getOutputFormat(impl_->codec);
        if (format) {
            int32_t w = 0;
            int32_t h = 0;
            if (AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_WIDTH, &w) && w > 0) {
                impl_->width = w;
            }
            if (AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_HEIGHT, &h) && h > 0) {
                impl_->height = h;
            }
            AMediaFormat_delete(format);
        }
        return false;
    }
    if (index < 0) {
        return false;
    }
    size_t capacity = 0;
    uint8_t* out = AMediaCodec_getOutputBuffer(impl_->codec, static_cast<size_t>(index), &capacity);
    if (!out || info.size <= 0) {
        AMediaCodec_releaseOutputBuffer(impl_->codec, static_cast<size_t>(index), false);
        return false;
    }
    nv12Out.assign(out + info.offset, out + info.offset + info.size);
    width = impl_->width;
    height = impl_->height;
    ptsUs = info.presentationTimeUs;
    AMediaCodec_releaseOutputBuffer(impl_->codec, static_cast<size_t>(index), false);
    return !nv12Out.empty() && width > 0 && height > 0;
#endif
}

bool MediaCodecDecoder::dequeueOutput(std::vector<uint8_t>& nv12Out,
                                      int& width,
                                      int& height,
                                      int64_t& ptsUs) {
    return tryDequeueOutput(nv12Out, width, height, ptsUs, 0);
}

}  // namespace stream_detect
