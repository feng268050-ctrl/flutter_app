#include "video_decoder_factory.h"

#include "platform/android/ndk_media_codec_video_decoder.h"
#include "platform/rockchip/mpp_video_decoder.h"

#ifdef __ANDROID__
#include <android/log.h>
#define VDF_LOGI(...) __android_log_print(ANDROID_LOG_INFO, "StreamDetect", __VA_ARGS__)
#else
#include <cstdio>
#define VDF_LOGI(...) std::fprintf(stderr, __VA_ARGS__)
#endif

namespace stream_detect {

std::unique_ptr<IVideoDecoder> createAvcVideoDecoder(const AvcCodecConfig& config,
                                                     std::string& chosen_backend) {
    chosen_backend.clear();
    if (MppVideoDecoder::isAvailable()) {
        auto mpp = std::make_unique<MppVideoDecoder>();
        if (mpp->configureAvc(config)) {
            chosen_backend = mpp->backendName();
            VDF_LOGI("video_decoder_factory selected backend=%s", chosen_backend.c_str());
            return mpp;
        }
    }
#if defined(LWS_STREAM_DETECT_NDK_FALLBACK) && defined(__ANDROID__)
    if (NdkMediaCodecVideoDecoder::isAvailable()) {
        auto ndk = std::make_unique<NdkMediaCodecVideoDecoder>();
        if (ndk->configureAvc(config)) {
            chosen_backend = ndk->backendName();
            VDF_LOGI("video_decoder_factory selected transitional backend=%s", chosen_backend.c_str());
            return ndk;
        }
    }
#endif
    VDF_LOGI("video_decoder_factory: no AVC decoder available");
    return nullptr;
}

}  // namespace stream_detect
