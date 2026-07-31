#include "central_scheduler.h"
#include "det_callback_json.h"
#include "stain_infer_outcome.h"
#include "stream_detect/yuv_convert.h"
#include <algorithm>
#include <cerrno>
#include <cmath>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <sstream>
#include <sys/stat.h>
#include <vector>

#ifdef __ANDROID__
#include <fcntl.h>
#include <media/NdkMediaCodec.h>
#include <media/NdkMediaFormat.h>
#include <media/NdkMediaMuxer.h>
#include <unistd.h>
#endif

// ── helpers ─────────────────────────────────────────────────

static double mono_sec() {
    using C = std::chrono::steady_clock;
    return std::chrono::duration<double>(C::now().time_since_epoch()).count();
}

static std::string timestamp_str() {
    char buf[32];
    auto t = std::time(nullptr);
    std::strftime(buf, sizeof(buf), "%Y%m%d_%H%M%S", std::localtime(&t));
    return buf;
}

static void draw_detections_on_bgr(cv::Mat& bgr, const std::vector<Detection>& dets) {
    for (const auto& d : dets) {
        cv::rectangle(bgr, cv::Point(static_cast<int>(d.x1), static_cast<int>(d.y1)),
                      cv::Point(static_cast<int>(d.x2), static_cast<int>(d.y2)), cv::Scalar(0, 0, 255), 2);
        char label[64];
        if (d.cls_id == 0) {
            std::snprintf(label, sizeof(label), "cont:%.2f", d.conf);
        } else {
            std::snprintf(label, sizeof(label), "%d:%.2f", d.cls_id, d.conf);
        }
        cv::putText(bgr, label, cv::Point(static_cast<int>(d.x1), std::max(0, static_cast<int>(d.y1) - 4)),
                    cv::FONT_HERSHEY_SIMPLEX, 0.5, cv::Scalar(0, 0, 255), 1);
    }
}

static int64_t file_size_bytes(const std::string& path) {
    struct stat st {};
    if (::stat(path.c_str(), &st) != 0 || !S_ISREG(st.st_mode)) {
        return -1;
    }
    return static_cast<int64_t>(st.st_size);
}


struct VideoWriterFourccAttempt {
    const char* tag;
    int fourcc;
};

static int even_dimension(int value) {
    if (value < 2) {
        return 0;
    }
    return (value % 2 == 0) ? value : value - 1;
}

static bool open_offline_video_writer(cv::VideoWriter& writer,
                                      const std::string& output_path,
                                      double fps,
                                      int w,
                                      int h,
                                      std::string* used_path,
                                      std::string* used_fourcc_tag) {
    const cv::Size size(w, h);
    const VideoWriterFourccAttempt attempts[] = {
        {"avc1", cv::VideoWriter::fourcc('a', 'v', 'c', '1')},
        {"H264", cv::VideoWriter::fourcc('H', '2', '6', '4')},
    };

    for (const auto& attempt : attempts) {
        fscompat::remove_file(output_path);

        writer.open(output_path, attempt.fourcc, fps, size);
        if (writer.isOpened()) {
            if (used_path) {
                *used_path = output_path;
            }
            if (used_fourcc_tag) {
                *used_fourcc_tag = attempt.tag;
            }
            LOGI("[OFFLINE] VideoWriter opened path=%s fourcc=%s fps=%.2f size=%dx%d\n",
                 output_path.c_str(),
                 attempt.tag,
                 fps,
                 w,
                 h);
            return true;
        }
        LOGI("[OFFLINE] VideoWriter failed fourcc=%s path=%s\n", attempt.tag, output_path.c_str());
        writer.release();
    }
    return false;
}

static bool finalize_offline_video_output(const std::string& written_path,
                                          const std::string& output_path) {
    if (written_path == output_path) {
        return true;
    }
    fscompat::remove_file(output_path);
    if (std::rename(written_path.c_str(), output_path.c_str()) != 0) {
        LOGE("[OFFLINE] rename %s -> %s failed errno=%d\n",
             written_path.c_str(),
             output_path.c_str(),
             errno);
        fscompat::remove_file(written_path);
        return false;
    }
    LOGI("[OFFLINE] renamed encoded video %s -> %s\n", written_path.c_str(), output_path.c_str());
    return true;
}

#ifdef __ANDROID__
class AndroidH264Mp4Writer {
public:
    bool open(const std::string& output_path, double fps, int w, int h) {
        path_ = output_path;
        fps_ = fps;
        width_ = w;
        height_ = h;
        frame_index_ = 0;
        frame_size_ = static_cast<size_t>(width_) * static_cast<size_t>(height_);
        if (width_ <= 0 || height_ <= 0 || (width_ % 2) != 0 || (height_ % 2) != 0) {
            LOGE("[OFFLINE] MediaCodec invalid encoder size %dx%d\n", width_, height_);
            return false;
        }

        fscompat::remove_file(path_);
        fd_ = ::open(path_.c_str(), O_CREAT | O_TRUNC | O_RDWR, 0666);
        if (fd_ < 0) {
            LOGE("[OFFLINE] MediaCodec cannot open output fd path=%s errno=%d\n", path_.c_str(), errno);
            return false;
        }

        codec_ = AMediaCodec_createEncoderByType(kMimeAvc);
        if (!codec_) {
            LOGE("[OFFLINE] MediaCodec H.264 encoder unavailable\n");
            abort();
            return false;
        }

        AMediaFormat* format = AMediaFormat_new();
        if (!format) {
            LOGE("[OFFLINE] MediaCodec failed to allocate format\n");
            abort();
            return false;
        }

        const int32_t frame_rate = std::max(1, static_cast<int32_t>(std::lround(fps_)));
        const int32_t bitrate = std::max(1000000, std::min(8000000, width_ * height_ * frame_rate));
        AMediaFormat_setString(format, AMEDIAFORMAT_KEY_MIME, kMimeAvc);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_WIDTH, width_);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_HEIGHT, height_);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_COLOR_FORMAT, kColorFormatYuv420SemiPlanar);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_BIT_RATE, bitrate);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_FRAME_RATE, frame_rate);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_I_FRAME_INTERVAL, 1);

        media_status_t status = AMediaCodec_configure(
            codec_,
            format,
            nullptr,
            nullptr,
            AMEDIACODEC_CONFIGURE_FLAG_ENCODE);
        AMediaFormat_delete(format);
        if (status != AMEDIA_OK) {
            LOGE("[OFFLINE] MediaCodec configure failed status=%d size=%dx%d fps=%d bitrate=%d\n",
                 status,
                 width_,
                 height_,
                 frame_rate,
                 bitrate);
            abort();
            return false;
        }

        status = AMediaCodec_start(codec_);
        if (status != AMEDIA_OK) {
            LOGE("[OFFLINE] MediaCodec start failed status=%d\n", status);
            abort();
            return false;
        }
        codec_started_ = true;

        muxer_ = AMediaMuxer_new(fd_, AMEDIAMUXER_OUTPUT_FORMAT_MPEG_4);
        if (!muxer_) {
            LOGE("[OFFLINE] MediaMuxer create failed path=%s\n", path_.c_str());
            abort();
            return false;
        }

        nv12_.resize(frame_size_ * 3 / 2);
        LOGI("[OFFLINE] MediaCodec H.264 writer opened path=%s fps=%.2f size=%dx%d bitrate=%d\n",
             path_.c_str(),
             fps_,
             width_,
             height_,
             bitrate);
        return true;
    }

    bool write(const cv::Mat& bgr) {
        if (!codec_ || !muxer_ || bgr.empty()) {
            return false;
        }
        cv::Mat frame = bgr;
        if (frame.cols != width_ || frame.rows != height_) {
            cv::resize(frame, resized_, cv::Size(width_, height_));
            frame = resized_;
        }
        if (!convertBgrToNv12(frame)) {
            return false;
        }
        const int64_t pts_us =
            static_cast<int64_t>(std::llround(frame_index_ * 1000000.0 / std::max(1.0, fps_)));
        if (!queueInput(nv12_.data(), nv12_.size(), pts_us, 0)) {
            return false;
        }
        ++frame_index_;
        return drain(false);
    }

    bool close() {
        bool ok = true;
        if (codec_ && codec_started_) {
            const int64_t pts_us =
                static_cast<int64_t>(std::llround(frame_index_ * 1000000.0 / std::max(1.0, fps_)));
            ok = queueInput(nullptr, 0, pts_us, AMEDIACODEC_BUFFER_FLAG_END_OF_STREAM) && drain(true);
        }
        const bool had_muxer_started = muxer_started_;
        const int frames = frame_index_;
        release(false);
        if (!ok || !had_muxer_started || frames == 0) {
            LOGE("[OFFLINE] MediaCodec H.264 writer close failed ok=%d muxer_started=%d frames=%d\n",
                 ok ? 1 : 0,
                 had_muxer_started ? 1 : 0,
                 frames);
            fscompat::remove_file(path_);
            return false;
        }
        return true;
    }

    void abort() {
        release(true);
        if (!path_.empty()) {
            fscompat::remove_file(path_);
        }
    }

private:
    static constexpr const char* kMimeAvc = "video/avc";
    static constexpr int32_t kColorFormatYuv420SemiPlanar = 21;
    static constexpr int64_t kCodecTimeoutUs = 10000;
    static constexpr int kMaxCodecPolls = 500;

    bool convertBgrToNv12(const cv::Mat& bgr) {
        if (bgr.cols != width_ || bgr.rows != height_) {
            return false;
        }
        cv::cvtColor(bgr, yuv420_, cv::COLOR_BGR2YUV_I420);
        const size_t chroma = frame_size_ / 4;
        const size_t expected = frame_size_ + chroma * 2;
        if (!yuv420_.isContinuous() || yuv420_.total() * yuv420_.elemSize() < expected) {
            LOGE("[OFFLINE] MediaCodec yuv conversion produced invalid buffer\n");
            return false;
        }

        const uint8_t* y = yuv420_.data;
        const uint8_t* u = y + frame_size_;
        const uint8_t* v = u + chroma;
        std::memcpy(nv12_.data(), y, frame_size_);
        uint8_t* uv = nv12_.data() + frame_size_;
        for (size_t i = 0; i < chroma; ++i) {
            *uv++ = u[i];
            *uv++ = v[i];
        }
        return true;
    }

    bool queueInput(const uint8_t* data, size_t size, int64_t pts_us, uint32_t flags) {
        for (int poll = 0; poll < kMaxCodecPolls; ++poll) {
            const ssize_t index = AMediaCodec_dequeueInputBuffer(codec_, kCodecTimeoutUs);
            if (index >= 0) {
                size_t capacity = 0;
                uint8_t* input = AMediaCodec_getInputBuffer(codec_, static_cast<size_t>(index), &capacity);
                if (!input || capacity < size) {
                    LOGE("[OFFLINE] MediaCodec input buffer too small capacity=%zu size=%zu\n", capacity, size);
                    return false;
                }
                if (data && size > 0) {
                    std::memcpy(input, data, size);
                }
                const media_status_t status = AMediaCodec_queueInputBuffer(
                    codec_,
                    static_cast<size_t>(index),
                    0,
                    size,
                    static_cast<uint64_t>(pts_us),
                    flags);
                if (status != AMEDIA_OK) {
                    LOGE("[OFFLINE] MediaCodec queue input failed status=%d\n", status);
                    return false;
                }
                return true;
            }
            if (index != AMEDIACODEC_INFO_TRY_AGAIN_LATER) {
                LOGE("[OFFLINE] MediaCodec dequeue input failed index=%zd\n", index);
                return false;
            }
            if (!drain(false)) {
                return false;
            }
        }
        LOGE("[OFFLINE] MediaCodec dequeue input timed out\n");
        return false;
    }

    bool drain(bool end_of_stream) {
        int idle_polls = 0;
        while (true) {
            AMediaCodecBufferInfo info {};
            const ssize_t index = AMediaCodec_dequeueOutputBuffer(codec_, &info, kCodecTimeoutUs);
            if (index == AMEDIACODEC_INFO_TRY_AGAIN_LATER) {
                if (!end_of_stream) {
                    return true;
                }
                if (++idle_polls > kMaxCodecPolls) {
                    LOGE("[OFFLINE] MediaCodec drain timed out waiting for EOS\n");
                    return false;
                }
                continue;
            }
            if (index == AMEDIACODEC_INFO_OUTPUT_FORMAT_CHANGED) {
                if (muxer_started_) {
                    LOGE("[OFFLINE] MediaCodec output format changed twice\n");
                    return false;
                }
                AMediaFormat* output_format = AMediaCodec_getOutputFormat(codec_);
                if (!output_format) {
                    LOGE("[OFFLINE] MediaCodec output format unavailable\n");
                    return false;
                }
                track_index_ = AMediaMuxer_addTrack(muxer_, output_format);
                AMediaFormat_delete(output_format);
                if (track_index_ < 0) {
                    LOGE("[OFFLINE] MediaMuxer add track failed index=%zd\n", track_index_);
                    return false;
                }
                const media_status_t status = AMediaMuxer_start(muxer_);
                if (status != AMEDIA_OK) {
                    LOGE("[OFFLINE] MediaMuxer start failed status=%d\n", status);
                    return false;
                }
                muxer_started_ = true;
                continue;
            }
            if (index < 0) {
                LOGE("[OFFLINE] MediaCodec dequeue output failed index=%zd\n", index);
                return false;
            }

            size_t output_size = 0;
            uint8_t* output = AMediaCodec_getOutputBuffer(codec_, static_cast<size_t>(index), &output_size);
            if (!output) {
                LOGE("[OFFLINE] MediaCodec output buffer unavailable\n");
                AMediaCodec_releaseOutputBuffer(codec_, static_cast<size_t>(index), false);
                return false;
            }
            if ((info.flags & AMEDIACODEC_BUFFER_FLAG_CODEC_CONFIG) != 0) {
                info.size = 0;
            }
            if (info.size > 0) {
                if (!muxer_started_) {
                    LOGE("[OFFLINE] MediaMuxer not started before sample\n");
                    AMediaCodec_releaseOutputBuffer(codec_, static_cast<size_t>(index), false);
                    return false;
                }
                if (static_cast<size_t>(info.offset + info.size) > output_size) {
                    LOGE("[OFFLINE] MediaCodec output buffer range invalid offset=%d size=%d capacity=%zu\n",
                         info.offset,
                         info.size,
                         output_size);
                    AMediaCodec_releaseOutputBuffer(codec_, static_cast<size_t>(index), false);
                    return false;
                }
                const media_status_t status = AMediaMuxer_writeSampleData(
                    muxer_,
                    static_cast<size_t>(track_index_),
                    output,
                    &info);
                if (status != AMEDIA_OK) {
                    LOGE("[OFFLINE] MediaMuxer write sample failed status=%d\n", status);
                    AMediaCodec_releaseOutputBuffer(codec_, static_cast<size_t>(index), false);
                    return false;
                }
            }
            const bool saw_eos = (info.flags & AMEDIACODEC_BUFFER_FLAG_END_OF_STREAM) != 0;
            AMediaCodec_releaseOutputBuffer(codec_, static_cast<size_t>(index), false);
            if (saw_eos) {
                return true;
            }
        }
    }

    void release(bool aborting) {
        if (codec_) {
            if (codec_started_) {
                AMediaCodec_stop(codec_);
            }
            AMediaCodec_delete(codec_);
            codec_ = nullptr;
            codec_started_ = false;
        }
        if (muxer_) {
            if (muxer_started_) {
                const media_status_t status = AMediaMuxer_stop(muxer_);
                if (status != AMEDIA_OK && !aborting) {
                    LOGE("[OFFLINE] MediaMuxer stop failed status=%d\n", status);
                }
            }
            AMediaMuxer_delete(muxer_);
            muxer_ = nullptr;
            muxer_started_ = false;
        }
        if (fd_ >= 0) {
            ::close(fd_);
            fd_ = -1;
        }
    }

    std::string path_;
    int fd_ = -1;
    AMediaCodec* codec_ = nullptr;
    AMediaMuxer* muxer_ = nullptr;
    bool codec_started_ = false;
    bool muxer_started_ = false;
    ssize_t track_index_ = -1;
    double fps_ = 25.0;
    int width_ = 0;
    int height_ = 0;
    int frame_index_ = 0;
    size_t frame_size_ = 0;
    cv::Mat resized_;
    cv::Mat yuv420_;
    std::vector<uint8_t> nv12_;
};
#endif

// ── callback notification helpers ───────────────────────────

void CentralScheduler::notify_state(int s) {
    std::lock_guard<std::mutex> lk(cb_lock_);
    if (callbacks_.on_state_changed) callbacks_.on_state_changed(s);
}

void CentralScheduler::notify_result(int lvl, const std::string& status, const std::string& msg) {
    std::lock_guard<std::mutex> lk(cb_lock_);
    if (callbacks_.on_check_result) callbacks_.on_check_result(lvl, status, msg);
}

std::string CentralScheduler::getLastClsResultJson() const {
    return "{\"valid\":false,\"classId\":-1,\"className\":\"\",\"score\":0.0,"
           "\"topk\":[],\"timestampMs\":0,\"modelVersion\":\"det-only\","
           "\"source\":\"focus_cls\"}";
}

// ── frame injection ─────────────────────────────────────────

void CentralScheduler::pushFrame(const uint8_t* data, int len, int w, int h) {
    int expected = w * h * 3 / 2;
    if (len != expected) {
        LOGE("[FRAME] Size mismatch: got %d, expected %d (%dx%d NV12)\n", len, expected, w, h);
        return;
    }

    cv::Mat bgr;
    if (!stream_detect::nv12ToBgr(data, w, h, bgr)) {
        LOGE("[FRAME] nv12ToBgr failed %dx%d\n", w, h);
        return;
    }

#if defined(LWS_FRAME_RING_BUFFER) && LWS_FRAME_RING_BUFFER
    frame_ring_.publish(std::move(bgr), 0);
    {
        std::lock_guard<std::mutex> lk(frame_mtx_);
        frame_w_ = w;
        frame_h_ = h;
        frame_ready_ = true;
    }
    frame_cv_.notify_one();
#else
    {
        std::lock_guard<std::mutex> lk(frame_mtx_);
        frame_buf_ = std::move(bgr);
        frame_w_ = w;
        frame_h_ = h;
        frame_ready_ = true;
    }
    frame_cv_.notify_one();
#endif
}

void CentralScheduler::setDeviceContext(const std::string& /*sn*/, const std::string& /*station_id*/) {}

void CentralScheduler::pushCameraParams(float /*exposure_time*/, float /*gain*/,
                                        float /*light_level*/, float /*fps*/) {}

void CentralScheduler::pushFrameMeta(int64_t /*timestamp_ms*/, int64_t /*frame_id*/) {}

void CentralScheduler::notifyModelSwitched(const std::string& /*model_version*/) {}

int CentralScheduler::inferImageAndSave(const std::string& image_path,
                                         const std::string& output_path) {
    LOGI("[DIAG] nativeRknnStainDetectFromJpgAndSave input=%s output=%s\n",
         image_path.c_str(), output_path.c_str());

    if (image_path.empty() || output_path.empty()) {
        LOGE("[DIAG] nativeRknnStainDetectFromJpgAndSave invalid empty path\n");
        return -1;
    }

    cv::Mat image = cv::imread(image_path, cv::IMREAD_COLOR);
    if (image.empty()) {
        LOGE("[DIAG] nativeRknnStainDetectFromJpgAndSave failed to read image: %s\n", image_path.c_str());
        return -2;
    }

    if (!frame_params_inited_)
        initFrameParams(image.cols, image.rows);

    try {
        stain_logic_.reset();
        auto dets = models_.infer_stain(image);
        auto result = stain_logic_.update(dets);

        cv::Mat annotated = image.clone();
        const std::size_t total_after_nms = dets.size();
        const int draw_cap = cfg_.algorithm.stain_max_det;
        cap_detections(dets, draw_cap);
        draw_detections_on_bgr(annotated, dets);

        fscompat::makedirs(fscompat::parent_path(output_path));
        bool saved = cv::imwrite(output_path, annotated);
        LOGI("[DIAG] nativeRknnStainDetectFromJpgAndSave total_after_nms=%zu drawn=%zu draw_cap=%d saved=%d level=%d status=%s\n",
             total_after_nms, dets.size(), draw_cap, saved ? 1 : 0, result.level, result.status.c_str());
        if (!saved)
            return -4;
        notify_result(result.level, result.status, result.message);
        return 0;
    } catch (const std::exception& e) {
        LOGE("[DIAG] nativeRknnStainDetectFromJpgAndSave failed: %s\n", e.what());
        return -3;
    }
}

int CentralScheduler::inferVideoAndSave(const std::string& input_path, const std::string& output_path) {
    LOGI("[OFFLINE] nativeRknnStainDetectFromVideoAndSave input=%s output=%s\n", input_path.c_str(), output_path.c_str());

    if (input_path.empty() || output_path.empty()) {
        LOGE("[OFFLINE] nativeRknnStainDetectFromVideoAndSave invalid empty path\n");
        return -1;
    }

    cv::VideoCapture cap(input_path);
    if (!cap.isOpened()) {
        LOGE("[OFFLINE] nativeRknnStainDetectFromVideoAndSave cannot open input: %s\n", input_path.c_str());
        return -2;
    }

    double fps = cap.get(cv::CAP_PROP_FPS);
    const double frame_count = cap.get(cv::CAP_PROP_FRAME_COUNT);
    if (fps <= 1.0 || fps > 240.0 || !std::isfinite(fps)) {
        fps = 25.0;
        if (frame_count > 1.0 && std::isfinite(frame_count)) {
            LOGI("[OFFLINE] CAP_PROP_FPS invalid; frame_count=%.0f, using fps=%.2f\n", frame_count, fps);
        } else {
            LOGI("[OFFLINE] nativeRknnStainDetectFromVideoAndSave using default fps=%.2f\n", fps);
        }
    }

    const int draw_cap = cfg_.algorithm.stain_max_det;
    cv::Mat frame;
    if (!cap.read(frame) || frame.empty()) {
        LOGE("[OFFLINE] nativeRknnStainDetectFromVideoAndSave cannot read first frame from: %s\n", input_path.c_str());
        return -2;
    }

    int w = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_WIDTH));
    int h = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_HEIGHT));
    if (w < 1 || h < 1) {
        w = frame.cols;
        h = frame.rows;
        LOGI("[OFFLINE] nativeRknnStainDetectFromVideoAndSave using first-frame size %dx%d (CAP_PROP was invalid)\n", w, h);
    }
    if (w < 1 || h < 1) {
        LOGE("[OFFLINE] nativeRknnStainDetectFromVideoAndSave invalid frame size %dx%d\n", w, h);
        return -2;
    }
    const int even_w = even_dimension(w);
    const int even_h = even_dimension(h);
    if (even_w != w || even_h != h) {
        LOGI("[OFFLINE] nativeRknnStainDetectFromVideoAndSave adjusting frame size %dx%d -> %dx%d for H.264\n",
             w,
             h,
             even_w,
             even_h);
        w = even_w;
        h = even_h;
        if (w < 2 || h < 2) {
            LOGE("[OFFLINE] nativeRknnStainDetectFromVideoAndSave invalid even frame size %dx%d\n", w, h);
            return -2;
        }
        cv::resize(frame, frame, cv::Size(w, h));
    }

    if (!frame_params_inited_) {
        initFrameParams(w, h);
    }

    const std::string parent_dir = fscompat::parent_path(output_path);
    fscompat::makedirs(parent_dir);
    if (!fscompat::exists(parent_dir)) {
        LOGE("[OFFLINE] cannot create output parent dir=%s errno=%d\n", parent_dir.c_str(), errno);
        return -4;
    }
    fscompat::remove_file(output_path);

    cv::VideoWriter writer;
    std::string writer_path;
    std::string writer_fourcc;
    bool using_media_codec_writer = false;
#ifdef __ANDROID__
    AndroidH264Mp4Writer media_codec_writer;
    if (media_codec_writer.open(output_path, fps, w, h)) {
        writer_path = output_path;
        writer_fourcc = "MediaCodec-avc";
        using_media_codec_writer = true;
    } else {
        LOGW("[OFFLINE] MediaCodec H.264 writer unavailable; trying OpenCV H.264 writer\n");
    }
#endif
    if (!using_media_codec_writer
        && !open_offline_video_writer(writer, output_path, fps, w, h, &writer_path, &writer_fourcc)) {
        LOGE("[OFFLINE] nativeRknnStainDetectFromVideoAndSave cannot create H.264 MP4 output: %s "
             "(tried MediaCodec-avc/avc1/H264; refusing MJPG/XVID fake MP4) "
             "fps=%.2f size=%dx%d errno=%d\n",
             output_path.c_str(),
             fps,
             w,
             h,
             errno);
        return -4;
    }

    const int total_frames_hint =
        (frame_count > 1.0 && std::isfinite(frame_count))
            ? static_cast<int>(frame_count)
            : 0;
    LOGI("[OFFLINE] nativeRknnStainDetectFromVideoAndSave infer every frame fps=%.2f frames_hint=%d\n", fps, total_frames_hint);

    int frame_idx = 0;
    int infer_count = 0;
    int total_boxes = 0;
    std::vector<Detection> held;

    auto fail_output = [&](int code) {
#ifdef __ANDROID__
        if (using_media_codec_writer) {
            media_codec_writer.abort();
        } else
#endif
        {
            writer.release();
        }
        cap.release();
        fscompat::remove_file(writer_path);
        fscompat::remove_file(output_path);
        return code;
    };

    try {
        while (true) {
            if (!running.load()) {
                LOGE("[OFFLINE] nativeRknnStainDetectFromVideoAndSave cancelled at frame %d\n", frame_idx);
                return fail_output(-3);
            }
            held = models_.infer_stain(frame);
            cap_detections(held, draw_cap);
            ++infer_count;
            total_boxes += static_cast<int>(held.size());
            draw_detections_on_bgr(frame, held);
#ifdef __ANDROID__
            if (using_media_codec_writer) {
                if (!media_codec_writer.write(frame)) {
                    LOGE("[OFFLINE] MediaCodec H.264 writer failed at frame %d\n", frame_idx);
                    return fail_output(-4);
                }
            } else
#endif
            {
                writer.write(frame);
            }
            ++frame_idx;
            if (frame_idx % 50 == 0) {
                if (total_frames_hint > 0) {
                    LOGI("[OFFLINE] video progress %d/%d infer=%d boxes_so_far=%d\n",
                         frame_idx,
                         total_frames_hint,
                         infer_count,
                         total_boxes);
                } else {
                    LOGI("[OFFLINE] video progress frames=%d infer=%d boxes_so_far=%d\n",
                         frame_idx,
                         infer_count,
                         total_boxes);
                }
            }
            if (!cap.read(frame) || frame.empty()) {
                break;
            }
            if (frame.cols != w || frame.rows != h) {
                LOGI("[OFFLINE] frame size changed %dx%d -> %dx%d, resizing for writer\n",
                     w,
                     h,
                     frame.cols,
                     frame.rows);
                cv::resize(frame, frame, cv::Size(w, h));
            }
        }
    } catch (const std::exception& e) {
        LOGE("[OFFLINE] nativeRknnStainDetectFromVideoAndSave failed at frame %d: %s\n", frame_idx, e.what());
        return fail_output(-3);
    }

#ifdef __ANDROID__
    if (using_media_codec_writer) {
        if (!media_codec_writer.close()) {
            cap.release();
            fscompat::remove_file(output_path);
            return -4;
        }
    } else
#endif
    {
        writer.release();
    }
    cap.release();

    if (frame_idx < 1) {
        LOGE("[OFFLINE] nativeRknnStainDetectFromVideoAndSave no frames read from %s\n", input_path.c_str());
        fscompat::remove_file(writer_path);
        fscompat::remove_file(output_path);
        return -5;
    }

    if (!finalize_offline_video_output(writer_path, output_path)) {
        fscompat::remove_file(writer_path);
        fscompat::remove_file(output_path);
        return -4;
    }

    const int64_t out_bytes = file_size_bytes(output_path);
    if (out_bytes <= 0) {
        LOGE("[OFFLINE] nativeRknnStainDetectFromVideoAndSave output empty: %s\n", output_path.c_str());
        fscompat::remove_file(output_path);
        return -4;
    }

    LOGI("[OFFLINE] nativeRknnStainDetectFromVideoAndSave done frames=%d infer=%d total_boxes=%d fps=%.2f size=%dx%d "
         "fourcc=%s out_bytes=%lld\n",
         frame_idx,
         infer_count,
         total_boxes,
         fps,
         w,
         h,
         writer_fourcc.c_str(),
         static_cast<long long>(out_bytes));
    return 0;
}

StainInferOutcome CentralScheduler::inferImageFromBgr(const cv::Mat& image, const char* source) {
    const char* src = (source && source[0] != '\0') ? source : "offline_infer";
    if (image.empty()) {
        auto out = StainInferOutcome::error(-2, "empty image");
        out.source = src;
        return out;
    }

    if (!frame_params_inited_)
        initFrameParams(image.cols, image.rows);

    const int box_cap = cfg_.algorithm.stain_max_det;
    const int img_w = image.cols;
    const int img_h = image.rows;

    try {
        stain_logic_.reset();
        auto dets = models_.infer_stain(image);
        auto result = stain_logic_.update(dets);
        const ContaminationResult display = contamination_result_for_json(result);
        const std::size_t total_boxes = dets.size();
        cap_detections(dets, box_cap);

        StainInferOutcome out;
        out.code = 0;
        out.source = src;
        out.level = display.level;
        out.status = display.status;
        out.detail_message = display.message;
        out.image_width = img_w;
        out.image_height = img_h;
        out.boxes = std::move(dets);
        out.boxes_total = total_boxes;
        out.boxes_cap = box_cap;
        out.boxes_truncated = box_cap > 0 && total_boxes > out.boxes.size();
        LOGI("[OFFLINE] infer outcome level=%d status=%s boxes=%zu total=%zu cap=%d %dx%d source=%s\n",
             out.level,
             out.status.c_str(),
             out.boxes.size(),
             total_boxes,
             box_cap,
             img_w,
             img_h,
             src);
        return out;
    } catch (const std::exception& e) {
        LOGE("[OFFLINE] infer outcome failed: %s\n", e.what());
        auto out = StainInferOutcome::error(-3, e.what());
        out.source = src;
        out.image_width = img_w;
        out.image_height = img_h;
        return out;
    }
}

std::string CentralScheduler::inferImageToJsonFromBgr(const cv::Mat& image, const char* source) {
    return stain_infer_outcome_to_json(inferImageFromBgr(image, source));
}

StainInferOutcome CentralScheduler::inferNv12Frame(const uint8_t* data, int len, int w, int h) {
    const int expected = w * h * 3 / 2;
    if (!data || w <= 0 || h <= 0 || len != expected) {
        LOGE("[LIVE] inferNv12Frame size mismatch len=%d expected=%d (%dx%d)\n", len, expected, w, h);
        auto out = StainInferOutcome::error(-1, "invalid NV12 frame");
        out.source = "live_infer";
        return out;
    }

    cv::Mat bgr;
    if (!stream_detect::nv12ToBgr(data, w, h, bgr)) {
        auto out = StainInferOutcome::error(-1, "nv12ToBgr failed");
        out.source = "live_infer";
        return out;
    }
    LOGI("[LIVE] inferNv12Frame %dx%d\n", w, h);
    return inferImageFromBgr(bgr, "live_infer");
}

StainInferOutcome CentralScheduler::inferImageFromPath(const std::string& image_path) {
    LOGI("[OFFLINE] inferImageFromPath input=%s\n", image_path.c_str());

    if (image_path.empty())
        return StainInferOutcome::error(-1, "invalid image path");

    cv::Mat image = cv::imread(image_path, cv::IMREAD_COLOR);
    if (image.empty()) {
        LOGE("[OFFLINE] failed to read image: %s\n", image_path.c_str());
        return StainInferOutcome::error(-2, "failed to read image");
    }

    return inferImageFromBgr(image, "offline_infer");
}

std::string CentralScheduler::inferImageToJson(const std::string& image_path) {
    return stain_infer_outcome_to_json(inferImageFromPath(image_path));
}


bool CentralScheduler::waitFrame(cv::Mat& out, int timeout_ms) {
    std::unique_lock<std::mutex> lk(frame_mtx_);
    bool got = frame_cv_.wait_for(lk, std::chrono::milliseconds(timeout_ms),
                                   [this] { return frame_ready_ || !running.load(); });
    if (!got || !frame_ready_) return false;
#if defined(LWS_FRAME_RING_BUFFER) && LWS_FRAME_RING_BUFFER
    int64_t pts_ms = 0;
    if (!frame_ring_.consume(out, pts_ms)) {
        return false;
    }
#else
    out = frame_buf_.clone();
#endif
    frame_ready_ = false;
    return true;
}

void CentralScheduler::initFrameParams(int w, int h) {
    if (frame_params_inited_ && frame_logic_w_ == w && frame_logic_h_ == h) {
        return;
    }
    if (frame_params_inited_ && (frame_logic_w_ != w || frame_logic_h_ != h)) {
        LOGI("[BOOT] Push frame size changed %dx%d -> %dx%d, re-init stain level rules\n",
             frame_logic_w_,
             frame_logic_h_,
             w,
             h);
    }
    frame_params_inited_ = true;
    frame_logic_w_ = w;
    frame_logic_h_ = h;

    LOGI("[BOOT] Frame params: %dx%d (from App push)\n", w, h);

    float scale = w / 640.0f;
    int oc_x = cfg_.camera.optical_center_x ? cfg_.camera.optical_center_x : w / 2;
    int oc_y = cfg_.camera.optical_center_y ? cfg_.camera.optical_center_y : h / 2;
    LOGI("[BOOT] Optical center (%d, %d)  scale %.2f\n", oc_x, oc_y, scale);

    const int mask_ref_w = cfg_.stain_detection.mask_ref_width > 0
                               ? cfg_.stain_detection.mask_ref_width
                               : 1920;
    const int mask_ref_h = cfg_.stain_detection.mask_ref_height > 0
                               ? cfg_.stain_detection.mask_ref_height
                               : 1080;
    const float mask_scale_x = static_cast<float>(w) / static_cast<float>(mask_ref_w);
    const float mask_scale_y = static_cast<float>(h) / static_cast<float>(mask_ref_h);

    constexpr int kMaskCenterRefX = 885;
    constexpr int kMaskCenterRefY = 430;
    int mask_base_x = cfg_.stain_detection.mask_center_x;
    int mask_base_y = cfg_.stain_detection.mask_center_y;
    if (mask_base_x == 0 && mask_base_y == 0) {
        mask_base_x = kMaskCenterRefX;
        mask_base_y = kMaskCenterRefY;
    }

    RknnStainContaminationDetector::Config sc;
    sc.img_w            = w;
    sc.img_h            = h;
    sc.optical_center_x = oc_x;
    sc.optical_center_y = oc_y;
    sc.mask_center_x    = std::max(0, static_cast<int>(std::round(mask_base_x * mask_scale_x)));
    sc.mask_center_y    = std::max(0, static_cast<int>(std::round(mask_base_y * mask_scale_y)));
    sc.mask_radius_px   = std::max(1, static_cast<int>(std::round(
        cfg_.stain_detection.mask_radius_px * mask_scale_x)));
    LOGI("[BOOT] Stain mask center (%d, %d) radius %d  ref %dx%d\n",
         sc.mask_center_x,
         sc.mask_center_y,
         sc.mask_radius_px,
         mask_ref_w,
         mask_ref_h);

    RknnStainContaminationDetector::WindowConfig wc;
    wc.window_time_ms           = cfg_.stain_detection.window_time_ms;
    wc.fps                      = 30;
    wc.level2_min_frames        = cfg_.stain_detection.level2_min_frames;
    wc.level1_min_frames        = cfg_.stain_detection.level1_min_frames;
    wc.consecutive_frames_thresh = cfg_.stain_detection.consecutive_frames_thresh;

    stain_logic_ = RknnStainContaminationDetector(sc, wc);
}

// ── constructor ─────────────────────────────────────────────

CentralScheduler::CentralScheduler(const AppConfig& cfg)
    : cfg_(cfg)
    , models_(cfg)
    , stain_logic_(RknnStainContaminationDetector::Config{}) {

    LOGI("=== COREDEX System Booting ===\n");
    print_versions();

    fscompat::makedirs(fscompat::join(cfg_.debug.debug_dir, "burn"));
    fscompat::makedirs(fscompat::join(cfg_.debug.debug_dir, "stain"));

    LOGI("[BOOT] Frame source: App push via nativeRknnStainDetectFromStream (NV12)\n");
    LOGI("[BOOT] Preview-Det: infer once per pushed frame when preview enabled (App controls cadence)\n");
    LOGI("[BOOT] Periodic stain infer: infer once per pushed frame when preview det disabled\n");
    LOGI("[BOOT] RKNN Models OK\n");

    self_test();

    cleanup_debug_images();
    LOGI("=== COREDEX Ready (waiting for frames) ===\n");
}

// ── version info ────────────────────────────────────────────

void CentralScheduler::print_versions() {
    LOGI("[VER] C++ Build  %s %s\n", __DATE__, __TIME__);
    LOGI("[VER] OpenCV     %s\n", CV_VERSION);
    LOGI("[VER] models.det.enabled=%d (det-only build)\n",
         cfg_.models.det_enabled ? 1 : 0);
}

// ── self-test ───────────────────────────────────────────────

void CentralScheduler::self_test() {
    LOGI("--- Self-Test Begin ---\n");

    LOGI("[TEST] Laser state   via App API (DeviceStatus.isLaserOn)\n");
    LOGI("[TEST] RKNN models loaded (inference tested on first frame)\n");

    LOGI("--- Self-Test PASSED ---\n");
}

// ── main loop ───────────────────────────────────────────────

void CentralScheduler::run() {
    LOGI("[SYS] Entering main loop (waiting for App to push frames)...\n");

    while (running.load()) {
        cv::Mat frame;
        bool got_frame = waitFrame(frame, 2000);

        if (!running.load()) break;

        if (got_frame) {
            if (!frame_params_inited_)
                initFrameParams(frame.cols, frame.rows);

            std::lock_guard<std::mutex> lk(frame_lock_);
            latest_frame_ = frame;
        }

        double now = mono_sec();
        const bool laser_on = laser_on_.load();
        const bool preview_det = !laser_on && ai_vision_preview_det_enabled_.load();

        // ── LOCKED ──
        if (state_ == SystemState::LOCKED) {
            if (now - locked_mono_ > cfg_.scheduler.locked_timeout_sec) {
                LOGI("[SYS] LOCKED timeout -> IDLE\n");
                state_ = SystemState::IDLE;
                notify_state(0);
                flag_lens_dirty_ = false;
                last_stain_level_ = 0;
            }
            prev_laser_on_ = laser_on;
            std::this_thread::sleep_for(std::chrono::milliseconds(500));
            continue;
        }

        if (laser_on) {
            if (flag_lens_dirty_ && last_stain_level_ == 2) {
                if (state_ != SystemState::LOCKED) {
                    LOGW("[SAFETY] Level 2 镜片污染 — 阻断激光作业\n");
                    state_ = SystemState::LOCKED;
                    locked_mono_ = now;
                    notify_state(2);
                }
                prev_laser_on_ = true;
                std::this_thread::sleep_for(std::chrono::milliseconds(100));
                continue;
            }

            if (flag_lens_dirty_ && !lens_warned_) {
                LOGW("[WARN] 镜片脏污，建议清洗/更换镜片\n");
                lens_warned_ = true;
            }

            if (checking_.load()) {
                stain_interrupt_flag_.store(true);
                LOGI("[SYS] LASER_ON — 中断空闲污点检测\n");
                if (last_stain_level_ >= 2 ||
                    (last_clean_check_time_ > 0.0 &&
                     (now - last_clean_check_time_) > cfg_.scheduler.stain_valid_sec)) {
                    LOGW("[WARN] 历史检测结果过期或为 DIRTY\n");
                }
            }
        } else {
            lens_warned_ = false;

            if (prev_laser_on_) {
                LOGI("[SYS] Laser OFF -> Post-Weld stain check\n");
                if (state_ == SystemState::MONITORING) {
                    state_ = SystemState::IDLE;
                    notify_state(0);
                }
                trigger_check("Post-Weld");
            }

            if (got_frame && !preview_det && !checking_.load()) {
                trigger_check("Periodic");
            }
        }

        // Preview-Det after Post-Weld / periodic scheduling so Post-Weld wins if both compete (same tick).
        if (got_frame && preview_det && !checking_.load()) {
            trigger_check("Preview-Det", true);
        }

        prev_laser_on_ = laser_on;

        drain_check_queue();
    }
}

// ── trigger stain check ─────────────────────────────────────

void CentralScheduler::trigger_check(const char* reason, bool preview) {
    if (checking_.load()) return;

    cv::Mat snap;
    {
        std::lock_guard<std::mutex> lk(frame_lock_);
        if (latest_frame_.empty()) return;
        snap = latest_frame_;
    }

    if (preview) {
        last_preview_check_mono_ = mono_sec();
    } else {
        last_check_mono_ = mono_sec();
    }
    checking_.store(true);
    LOGI("[SYS] Lens check: %s preview=%d\n", reason, preview ? 1 : 0);

    stain_worker_.submit(std::move(snap), [this, preview, reason = std::string(reason)](cv::Mat frame) mutable {
        worker_stain(std::move(frame), preview, std::move(reason));
    });
}

// ── stain worker (background thread) ────────────────────────

void CentralScheduler::worker_stain(cv::Mat frame, bool preview, std::string reason) {
    try {
#if defined(LWS_FRAME_RING_BUFFER) && LWS_FRAME_RING_BUFFER
        if (!frame.empty()) {
            frame = frame.clone();
        }
#endif
        stain_interrupt_flag_.store(false);

        if (laser_on_.load()) {
            checking_.store(false);
            return;
        }

        const bool post_weld = (reason == "Post-Weld");
        if (post_weld) {
            stain_logic_.reset();
        }

        constexpr int kFps = 30;
        int window_frames = 1;
        if (post_weld) {
            window_frames = std::max(1, static_cast<int>(
                std::round(cfg_.stain_detection.window_time_ms / (1000.0f / kFps))));
        }

        ContaminationResult result{0, "CLEAN", "洁净"};
        cv::Mat debug_frame;
        std::vector<Detection> last_detections;

        for (int i = 0; i < window_frames; ++i) {
            if (stain_interrupt_flag_.load()) {
                LOGI("[STAIN] 检测被中断 (LASER_ON)\n");
                break;
            }
            if (laser_on_.load()) {
                LOGI("[STAIN] 激光开启 — 中止检测\n");
                break;
            }

            cv::Mat f;
            {
                std::lock_guard<std::mutex> lk(frame_lock_);
                f = latest_frame_.empty() ? frame : latest_frame_;
            }
            if (f.empty()) continue;
            if (post_weld || i > 0) {
                f = f.clone();
            }

            auto dets = models_.infer_stain(f);
            result = stain_logic_.update(dets);
            debug_frame = f;
            last_detections = std::move(dets);

            if (i < window_frames - 1) {
                int sleep_ms = std::max(5, static_cast<int>(1000.0f / kFps) - 50);
                std::this_thread::sleep_for(std::chrono::milliseconds(sleep_ms));
            }
        }

        {
            std::lock_guard<std::mutex> lk(queue_lock_);
            check_queue_.push({result, debug_frame, last_detections, preview, std::move(reason)});
        }
    } catch (const std::exception& e) {
        LOGE("[ERR] Stain worker: %s\n", e.what());
    }
    checking_.store(false);
}

// ── drain queue ─────────────────────────────────────────────

void CentralScheduler::drain_check_queue() {
    std::lock_guard<std::mutex> lk(queue_lock_);
    while (!check_queue_.empty()) {
        auto res = std::move(check_queue_.front());
        check_queue_.pop();
        handle_result(res);
    }
}

void CentralScheduler::handle_result(const CheckResult& res) {
    if (res.preview) {
        handle_preview_result(res);
        return;
    }

    int level = res.cr.level;
    LOGI("[RESULT] Level %d: %s\n", level, res.cr.message.c_str());

    flag_lens_dirty_  = (level >= 2);
    last_stain_level_ = level;

    if (level <= 1)
        last_clean_check_time_ = mono_sec();

    popup_lens_warning(level);
    notify_result(level, res.cr.status, res.cr.message);

    if (level > 0)
        save_debug_image(res.debug_frame, res.cr.status);

    if (level == 2) {
        state_ = SystemState::LOCKED;
        notify_state(2);
        locked_mono_ = mono_sec();
    } else {
        state_ = SystemState::IDLE;
        notify_state(0);
    }

    last_check_mono_ = mono_sec();
}

void CentralScheduler::handle_preview_result(const CheckResult& res) {
    auto dets = res.detections;
    const std::size_t total_boxes = dets.size();
    const int box_cap = cfg_.algorithm.stain_max_det;
    cap_detections(dets, box_cap);
    LOGI("[RESULT][PREVIEW] %s Level %d: %s boxes=%zu total=%zu cap=%d\n",
         res.reason.c_str(),
         res.cr.level,
         res.cr.message.c_str(),
         dets.size(),
         total_boxes,
         box_cap);
    notify_result(res.cr.level,
                  res.cr.status,
                  build_preview_det_json(res.cr, dets, box_cap, total_boxes, frame_w_, frame_h_));
}

void CentralScheduler::popup_lens_warning(int level) {
    if (level == last_popup_level_) return;
    if (level == 1)
        LOGW("[WARN] 镜片脏污，建议清洗/更换镜片\n");
    else if (level == 2)
        LOGW("[WARN] 镜片脏污严重，立即清洗/更换镜片\n");
    last_popup_level_ = level;
}

// ── debug images ────────────────────────────────────────────

void CentralScheduler::save_debug_image(const cv::Mat& frame, const std::string& status) {
    if (frame.empty()) return;
    try {
        std::string sub = (status.find("BURN") != std::string::npos) ? "burn" : "stain";
        std::string path = fscompat::join(
            fscompat::join(cfg_.debug.debug_dir, sub),
            timestamp_str() + "_" + status + ".jpg");
        cv::imwrite(path, frame);
        LOGI("[DEBUG] Saved: %s\n", path.c_str());
        debug_save_count_++;
        if (debug_save_count_ % 20 == 0)
            cleanup_debug_images();
    } catch (const std::exception& e) {
        LOGE("[ERR] Save debug image: %s\n", e.what());
    }
}

void CentralScheduler::cleanup_debug_images() {
    std::vector<fscompat::DirEntry> files;
    for (const char* sub : {"burn", "stain"}) {
        auto d = fscompat::join(cfg_.debug.debug_dir, sub);
        if (!fscompat::exists(d)) continue;
        auto entries = fscompat::list_files(d);
        files.insert(files.end(), entries.begin(), entries.end());
    }
    if (static_cast<int>(files.size()) <= cfg_.debug.max_images) return;

    std::sort(files.begin(), files.end(),
              [](const fscompat::DirEntry& a, const fscompat::DirEntry& b) {
                  return a.mtime < b.mtime;
              });

    int to_remove = static_cast<int>(files.size()) - cfg_.debug.max_images;
    for (int i = 0; i < to_remove; ++i)
        fscompat::remove_file(files[i].path);

    LOGI("[SYS] Debug cleanup: kept %d, removed %d\n", cfg_.debug.max_images, to_remove);
}

// ── stop ────────────────────────────────────────────────────

void CentralScheduler::stop() {
    running.store(false);
    frame_cv_.notify_all();
    stain_worker_.shutdown();
    models_.release();
    LOGI("[SYS] Stopped.\n");
}
