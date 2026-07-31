#pragma once

#include "decoded_frame.h"
#include "iframe_converter.h"
#include "ivideo_decoder.h"
#include "portable_bgr_converter.h"
#include "rtsp_tcp_session.h"
#include "video_decoder_factory.h"

#include <opencv2/core.hpp>
#include <opencv2/videoio.hpp>

#include <memory>
#include <string>

namespace stream_detect {

/**
 * RTSP video source: RTSP/TCP demux → H.264 AU → IVideoDecoder (MPP preferred) → NV12 → BGR.
 * Falls back to OpenCV VideoCapture when the injectable hard path fails.
 */
class RtspDemux {
public:
    bool open(const std::string& url);
    void close();
    bool isOpen() const { return open_; }

    bool readBgrFrame(cv::Mat& bgrOut);
    bool reopen();

private:
    enum class Backend { None, InjectableHard, OpenCvFallback };

    bool openHardPath(const std::string& url);
    bool openOpenCvFallback(const std::string& url);
    bool readBgrHardPath(cv::Mat& bgrOut);
    bool readBgrOpenCv(cv::Mat& bgrOut);

    bool open_ = false;
    Backend backend_ = Backend::None;
    std::string url_;
    std::string decoder_backend_;
#ifdef __ANDROID__
    RtspTcpSession tcp_session_;
    std::unique_ptr<IVideoDecoder> decoder_;
    PortableBgrConverter bgr_converter_;
    cv::VideoCapture capture_;
    int64_t frame_pts_us_ = 0;
#endif
};

}  // namespace stream_detect
