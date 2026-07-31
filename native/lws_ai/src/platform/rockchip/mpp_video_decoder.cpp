#include "mpp_video_decoder.h"

#include <algorithm>
#include <cstring>
#include <vector>

#ifdef LWS_HAVE_ROCKCHIP_MPP
#include "mpp_buffer.h"
#include "mpp_frame.h"
#include "mpp_packet.h"
#include "rk_mpi.h"
#endif

#ifdef __ANDROID__
#include <android/log.h>
#define MPP_LOGI(...) __android_log_print(ANDROID_LOG_INFO, "StreamDetect", __VA_ARGS__)
#define MPP_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "StreamDetect", __VA_ARGS__)
#else
#include <cstdio>
#define MPP_LOGI(...) std::fprintf(stderr, __VA_ARGS__)
#define MPP_LOGE(...) std::fprintf(stderr, __VA_ARGS__)
#endif

namespace stream_detect {

namespace {

void appendAnnexBStartCode(std::vector<uint8_t>& out) {
    out.push_back(0);
    out.push_back(0);
    out.push_back(0);
    out.push_back(1);
}

#ifdef LWS_HAVE_ROCKCHIP_MPP
bool drainMppInfoChange(MppCtx ctx, MppApi* mpi, int& width, int& height, int max_frames) {
    if (!ctx || !mpi) {
        return false;
    }
    for (int i = 0; i < max_frames; ++i) {
        MppFrame frame = nullptr;
        const MPP_RET ret = mpi->decode_get_frame(ctx, &frame);
        if (ret == MPP_ERR_TIMEOUT) {
            break;
        }
        if (ret != MPP_OK || !frame) {
            continue;
        }
        if (mpp_frame_get_info_change(frame)) {
            const RK_U32 w = mpp_frame_get_width(frame);
            const RK_U32 h = mpp_frame_get_height(frame);
            if (w > 0) {
                width = static_cast<int>(w);
            }
            if (h > 0) {
                height = static_cast<int>(h);
            }
            MPP_LOGI("MppVideoDecoder info_change %dx%d", width, height);
            mpi->control(ctx, MPP_DEC_SET_INFO_CHANGE_READY, nullptr);
            mpp_frame_deinit(&frame);
            continue;
        }
        mpp_frame_deinit(&frame);
        break;
    }
    return true;
}
#endif  // LWS_HAVE_ROCKCHIP_MPP

}  // namespace

struct MppVideoDecoder::Impl {
#ifdef LWS_HAVE_ROCKCHIP_MPP
    MppCtx ctx = nullptr;
    MppApi* mpi = nullptr;
#endif
    int width = 0;
    int height = 0;
};

MppVideoDecoder::MppVideoDecoder() : impl_(new Impl()) {}

MppVideoDecoder::~MppVideoDecoder() {
    release();
    delete impl_;
    impl_ = nullptr;
}

bool MppVideoDecoder::isAvailable() {
#ifdef LWS_HAVE_ROCKCHIP_MPP
    return true;
#else
    return false;
#endif
}

bool MppVideoDecoder::configureAvc(const AvcCodecConfig& config) {
    release();
#ifndef LWS_HAVE_ROCKCHIP_MPP
    (void)config;
    return false;
#else
    impl_->width = config.width > 0 ? config.width : 1920;
    impl_->height = config.height > 0 ? config.height : 1080;
    MPP_RET     ret = mpp_create(&impl_->ctx, &impl_->mpi);
    if (ret != MPP_OK || !impl_->ctx || !impl_->mpi) {
        MPP_LOGE("MppVideoDecoder mpp_create failed ret=%d", ret);
        release();
        return false;
    }
    RK_U32 split_parse = 1;
    ret = impl_->mpi->control(impl_->ctx, MPP_DEC_SET_PARSER_SPLIT_MODE, &split_parse);
    if (ret != MPP_OK) {
        MPP_LOGE("MppVideoDecoder split mode failed ret=%d", ret);
    }
    ret = mpp_init(impl_->ctx, MPP_CTX_DEC, MPP_VIDEO_CodingAVC);
    if (ret != MPP_OK) {
        MPP_LOGE("MppVideoDecoder mpp_init failed ret=%d", ret);
        release();
        return false;
    }
    if (!config.sps.empty() && !config.pps.empty()) {
        std::vector<uint8_t> extra;
        extra.reserve(config.sps.size() + config.pps.size() + 8);
        appendAnnexBStartCode(extra);
        extra.insert(extra.end(), config.sps.begin(), config.sps.end());
        appendAnnexBStartCode(extra);
        extra.insert(extra.end(), config.pps.begin(), config.pps.end());
        MppPacket packet = nullptr;
        mpp_packet_init(&packet, extra.data(), extra.size());
        mpp_packet_set_extra_data(packet);
        impl_->mpi->decode_put_packet(impl_->ctx, packet);
        mpp_packet_deinit(&packet);
        drainMppInfoChange(impl_->ctx, impl_->mpi, impl_->width, impl_->height, 16);
    }
    MPP_LOGI("MppVideoDecoder configured %dx%d", impl_->width, impl_->height);
    return true;
#endif
}

void MppVideoDecoder::release() {
#ifndef LWS_HAVE_ROCKCHIP_MPP
    return;
#else
    if (impl_->ctx) {
        impl_->mpi->reset(impl_->ctx);
        mpp_destroy(impl_->ctx);
        impl_->ctx = nullptr;
        impl_->mpi = nullptr;
    }
#endif
}

bool MppVideoDecoder::queueAccessUnit(const uint8_t* data,
                                      size_t size,
                                      int64_t pts_us,
                                      bool key_frame) {
#ifndef LWS_HAVE_ROCKCHIP_MPP
    (void)data;
    (void)size;
    (void)pts_us;
    (void)key_frame;
    return false;
#else
    if (!impl_->ctx || !impl_->mpi || !data || size == 0) {
        return false;
    }
    MppPacket packet = nullptr;
    MppPacket copy = nullptr;
    MPP_RET ret = mpp_packet_init(&packet, const_cast<void*>(static_cast<const void*>(data)), size);
    if (ret != MPP_OK) {
        return false;
    }
    mpp_packet_set_pts(packet, pts_us);
    ret = mpp_packet_copy_init(&copy, packet);
    mpp_packet_deinit(&packet);
    if (ret != MPP_OK || !copy) {
        MPP_LOGE("MppVideoDecoder packet copy failed ret=%d", ret);
        return false;
    }
    (void)key_frame;
    ret = impl_->mpi->decode_put_packet(impl_->ctx, copy);
    mpp_packet_deinit(&copy);
    if (ret != MPP_OK) {
        MPP_LOGE("MppVideoDecoder decode_put_packet failed ret=%d size=%zu", ret, size);
        return false;
    }
    return true;
#endif
}

bool MppVideoDecoder::tryReceiveFrame(DecodedFrame& out, int timeout_us) {
#ifndef LWS_HAVE_ROCKCHIP_MPP
    (void)out;
    (void)timeout_us;
    return false;
#else
    if (!impl_->ctx || !impl_->mpi) {
        return false;
    }
    MppFrame frame = nullptr;
    const int max_polls = timeout_us > 0 ? std::max(32, timeout_us / 500) : 1;
    MPP_RET last_ret = MPP_OK;
    for (int i = 0; i < max_polls; ++i) {
        frame = nullptr;
        MPP_RET ret = impl_->mpi->decode_get_frame(impl_->ctx, &frame);
        last_ret = ret;
        if (ret == MPP_ERR_TIMEOUT) {
            continue;
        }
        if (ret != MPP_OK || !frame) {
            continue;
        }
        if (mpp_frame_get_info_change(frame)) {
            RK_U32 w = mpp_frame_get_width(frame);
            RK_U32 h = mpp_frame_get_height(frame);
            if (w > 0) {
                impl_->width = static_cast<int>(w);
            }
            if (h > 0) {
                impl_->height = static_cast<int>(h);
            }
            MPP_LOGI("MppVideoDecoder runtime info_change %dx%d", impl_->width, impl_->height);
            impl_->mpi->control(impl_->ctx, MPP_DEC_SET_INFO_CHANGE_READY, nullptr);
            mpp_frame_deinit(&frame);
            frame = nullptr;
            continue;
        }
        if (mpp_frame_get_eos(frame)) {
            mpp_frame_deinit(&frame);
            return false;
        }
        MppBuffer buffer = mpp_frame_get_buffer(frame);
        if (!buffer) {
            mpp_frame_deinit(&frame);
            continue;
        }
        uint8_t* ptr = static_cast<uint8_t*>(mpp_buffer_get_ptr(buffer));
        if (!ptr) {
            mpp_frame_deinit(&frame);
            continue;
        }
        const RK_U32 hor_stride = mpp_frame_get_hor_stride(frame);
        const RK_U32 ver_stride = mpp_frame_get_ver_stride(frame);
        const RK_U32 width = mpp_frame_get_width(frame);
        const RK_U32 height = mpp_frame_get_height(frame);
        if (width == 0 || height == 0 || hor_stride == 0 || ver_stride == 0) {
            mpp_frame_deinit(&frame);
            continue;
        }
        const size_t packed_y = static_cast<size_t>(width) * static_cast<size_t>(height);
        const size_t packed_uv = packed_y / 2;
        out.data.resize(packed_y + packed_uv);
        for (RK_U32 row = 0; row < height; ++row) {
            memcpy(out.data.data() + static_cast<size_t>(row) * width,
                   ptr + static_cast<size_t>(row) * hor_stride,
                   width);
        }
        const uint8_t* src_uv = ptr + static_cast<size_t>(hor_stride) * ver_stride;
        uint8_t* dst_uv = out.data.data() + packed_y;
        for (RK_U32 row = 0; row < height / 2; ++row) {
            memcpy(dst_uv + static_cast<size_t>(row) * width,
                   src_uv + static_cast<size_t>(row) * hor_stride,
                   width);
        }
        out.width = static_cast<int>(width);
        out.height = static_cast<int>(height);
        out.stride = static_cast<int>(width);
        out.slice_height = static_cast<int>(height);
        out.format = PixelFormat::NV12;
        out.pts_us = mpp_frame_get_pts(frame);
        mpp_frame_deinit(&frame);
        return true;
    }
    MPP_LOGE("MppVideoDecoder decode_get_frame exhausted polls=%d last_ret=%d", max_polls, last_ret);
    return false;
#endif
}

}  // namespace stream_detect
