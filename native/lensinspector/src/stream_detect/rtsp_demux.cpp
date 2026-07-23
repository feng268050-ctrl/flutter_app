#include "rtsp_demux.h"

#include "sps_dimensions.h"
#include "yuv_convert.h"

#include <opencv2/imgproc.hpp>
#include <opencv2/videoio.hpp>

#ifdef __ANDROID__
#include <android/log.h>
#define SD_LOGI(...) __android_log_print(ANDROID_LOG_INFO, "StreamDetect", __VA_ARGS__)
#define SD_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "StreamDetect", __VA_ARGS__)
#else
#include <cstdio>
#define SD_LOGI(...) std::fprintf(stderr, __VA_ARGS__)
#define SD_LOGE(...) std::fprintf(stderr, __VA_ARGS__)
#endif

namespace stream_detect {

bool RtspDemux::openHardPath(const std::string& url) {
#ifndef __ANDROID__
    (void)url;
    return false;
#else
    if (!tcp_session_.open(url)) {
        return false;
    }
    const int width = tcp_session_.nominalWidth() > 0 ? tcp_session_.nominalWidth() : 1920;
    const int height = tcp_session_.nominalHeight() > 0 ? tcp_session_.nominalHeight() : 1080;
    int configuredWidth = width;
    int configuredHeight = height;
    clampPlausibleVideoDimensions(configuredWidth, configuredHeight);
    if (configuredWidth != width || configuredHeight != height) {
        SD_LOGI("RtspDemux clamped implausible SPS size %dx%d -> %dx%d",
                width,
                height,
                configuredWidth,
                configuredHeight);
    }
    AvcCodecConfig config;
    config.width = configuredWidth;
    config.height = configuredHeight;
    config.sps = tcp_session_.sps();
    config.pps = tcp_session_.pps();
    decoder_ = createAvcVideoDecoder(config, decoder_backend_);
    if (!decoder_) {
        SD_LOGE("RtspDemux injectable decoder create failed");
        tcp_session_.close();
        return false;
    }
    SD_LOGI("RtspDemux hard path open ok url=%s %dx%d backend=%s",
            url.c_str(), configuredWidth, configuredHeight, decoder_backend_.c_str());
    return true;
#endif
}

bool RtspDemux::openOpenCvFallback(const std::string& url) {
#ifndef __ANDROID__
    (void)url;
    return false;
#else
    if (!capture_.open(url, cv::CAP_FFMPEG)) {
        capture_.open(url);
    }
    if (!capture_.isOpened()) {
        return false;
    }
    SD_LOGI("RtspDemux opencv fallback open ok url=%s", url.c_str());
    return true;
#endif
}

bool RtspDemux::open(const std::string& url) {
    url_ = url;
    close();
#ifndef __ANDROID__
    (void)url;
    SD_LOGE("RtspDemux: Android only");
    return false;
#else
    if (openHardPath(url)) {
        backend_ = Backend::InjectableHard;
        open_ = true;
        return true;
    }
    SD_LOGI("RtspDemux hard path failed; trying opencv fallback url=%s", url.c_str());
    if (openOpenCvFallback(url)) {
        backend_ = Backend::OpenCvFallback;
        open_ = true;
        return true;
    }
    SD_LOGE("RtspDemux open failed url=%s", url.c_str());
    return false;
#endif
}

void RtspDemux::close() {
    open_ = false;
    backend_ = Backend::None;
#ifdef __ANDROID__
    if (decoder_) {
        decoder_->release();
        decoder_.reset();
    }
    decoder_backend_.clear();
    tcp_session_.close();
    if (capture_.isOpened()) {
        capture_.release();
    }
#endif
    url_.clear();
}

bool RtspDemux::readBgrHardPath(cv::Mat& bgrOut) {
#ifndef __ANDROID__
    (void)bgrOut;
    return false;
#else
    if (!decoder_) {
        return false;
    }
    std::vector<uint8_t> annexB;
    int64_t ptsUs = 0;
    if (!tcp_session_.readNextAccessUnit(annexB, ptsUs)) {
        return false;
    }
    frame_pts_us_ = ptsUs;
    const bool isKeyFrame = annexB.size() >= 5 && (annexB[4] & 0x1F) == 5;
    if (!decoder_->queueAccessUnit(annexB.data(), annexB.size(), ptsUs, isKeyFrame)) {
        SD_LOGE("readBgrHardPath: queueAccessUnit failed au_bytes=%zu key=%d",
                annexB.size(),
                isKeyFrame ? 1 : 0);
        return false;
    }
    DecodedFrame frame;
    for (int i = 0; i < 8; ++i) {
        if (decoder_->tryReceiveFrame(frame, 50000)) {
            return bgr_converter_.toBgr(frame, bgrOut);
        }
    }
    SD_LOGE("readBgrHardPath: decode produced no frame au_bytes=%zu key=%d backend=%s",
            annexB.size(),
            isKeyFrame ? 1 : 0,
            decoder_backend_.c_str());
    return false;
#endif
}

bool RtspDemux::readBgrOpenCv(cv::Mat& bgrOut) {
#ifndef __ANDROID__
    (void)bgrOut;
    return false;
#else
    if (!capture_.isOpened()) {
        return false;
    }
    cv::Mat bgr;
    if (!capture_.read(bgr) || bgr.empty()) {
        return false;
    }
    bgrOut = bgr;
    return true;
#endif
}

bool RtspDemux::readBgrFrame(cv::Mat& bgrOut) {
#ifndef __ANDROID__
    (void)bgrOut;
    return false;
#else
    switch (backend_) {
        case Backend::InjectableHard:
            return readBgrHardPath(bgrOut);
        case Backend::OpenCvFallback:
            return readBgrOpenCv(bgrOut);
        default:
            return false;
    }
#endif
}

bool RtspDemux::reopen() {
    if (url_.empty()) {
        return false;
    }
    const std::string url = url_;
    close();
    return open(url);
}

}  // namespace stream_detect
