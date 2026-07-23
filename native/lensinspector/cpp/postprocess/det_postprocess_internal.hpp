// Shared internals for det_decode.cpp and det_nms.cpp (not part of the public API).
#pragma once

#include "det_postprocess.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <limits>
#include <map>
#include <string>
#include <vector>

#ifdef __ANDROID__
#include <android/log.h>
#define DET_PP_LOG(...) __android_log_print(ANDROID_LOG_INFO, "DetPostprocess", __VA_ARGS__)
/** Always-on one-line stats (threshold / NMS); does not depend on DET_POSTPROCESS_DEBUG. */
#define DET_PP_SUMMARY(...) __android_log_print(ANDROID_LOG_INFO, "DetPostprocess", __VA_ARGS__)
#define DET_PP_TIMING(...) __android_log_print(ANDROID_LOG_INFO, "DetPostprocess", __VA_ARGS__)
#else
#define DET_PP_LOG(...) std::fprintf(stderr, __VA_ARGS__)
#define DET_PP_SUMMARY(...) std::fprintf(stderr, __VA_ARGS__)
#define DET_PP_TIMING(...) std::fprintf(stderr, __VA_ARGS__)
#endif

#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
#define DET_PP_TIMING_ENABLED 1
#else
#define DET_PP_TIMING_ENABLED 0
#endif

#if DET_PP_TIMING_ENABLED
namespace det_postprocess {
namespace internal {
using DetPpClock = std::chrono::steady_clock;
inline float DetPpMs(const DetPpClock::time_point& a, const DetPpClock::time_point& b) {
  return std::chrono::duration<float, std::milli>(b - a).count();
}
}  // namespace internal
}  // namespace det_postprocess
#define DET_PP_TIMING_NOOP() ((void)0)
#else
#define DET_PP_TIMING_NOOP() ((void)0)
#endif

namespace det_postprocess {
namespace internal {

constexpr float kClsProbEps = 1e-6F;

inline float Sigmoid(float x) {
  x = std::max(-60.0F, std::min(60.0F, x));
  return 1.0F / (1.0F + std::exp(-x));
}

inline void XywhToXyxy(float cx, float cy, float w, float h, float& x1, float& y1, float& x2, float& y2) {
  x1 = cx - w * 0.5F;
  y1 = cy - h * 0.5F;
  x2 = cx + w * 0.5F;
  y2 = cy + h * 0.5F;
}

inline float IouXyxy(float ax1, float ay1, float ax2, float ay2, float bx1, float by1, float bx2, float by2) {
  const float xx1 = std::max(ax1, bx1);
  const float yy1 = std::max(ay1, by1);
  const float xx2 = std::min(ax2, bx2);
  const float yy2 = std::min(ay2, by2);
  const float inter = std::max(0.0F, xx2 - xx1) * std::max(0.0F, yy2 - yy1);
  const float w1 = std::max(0.0F, ax2 - ax1);
  const float h1 = std::max(0.0F, ay2 - ay1);
  const float w2 = std::max(0.0F, bx2 - bx1);
  const float h2 = std::max(0.0F, by2 - by1);
  const float u = w1 * h1 + w2 * h2 - inter;
  return (u > 0.0F) ? (inter / u) : 0.0F;
}

inline float ApplyRoundPolicy(float v, BoxRoundPolicy policy) {
  switch (policy) {
    case BoxRoundPolicy::None:
      return v;
    case BoxRoundPolicy::Round:
      return std::round(v);
    case BoxRoundPolicy::Floor:
      return std::floor(v);
    case BoxRoundPolicy::Ceil:
      return std::ceil(v);
  }
  return v;
}

inline void RemapClipRoundXyxy(float& x1, float& y1, float& x2, float& y2, const LetterboxInfo& lb,
                               BoxRoundPolicy round_policy) {
  const float oxf = static_cast<float>(lb.orig_w - 1);
  const float oyf = static_cast<float>(lb.orig_h - 1);
  x1 = (x1 - static_cast<float>(lb.pad_w)) / lb.scale;
  x2 = (x2 - static_cast<float>(lb.pad_w)) / lb.scale;
  y1 = (y1 - static_cast<float>(lb.pad_h)) / lb.scale;
  y2 = (y2 - static_cast<float>(lb.pad_h)) / lb.scale;

  x1 = std::max(0.0F, std::min(x1, oxf));
  x2 = std::max(0.0F, std::min(x2, oxf));
  y1 = std::max(0.0F, std::min(y1, oyf));
  y2 = std::max(0.0F, std::min(y2, oyf));

  x1 = ApplyRoundPolicy(x1, round_policy);
  x2 = ApplyRoundPolicy(x2, round_policy);
  y1 = ApplyRoundPolicy(y1, round_policy);
  y2 = ApplyRoundPolicy(y2, round_policy);

  if (x2 < x1) {
    std::swap(x1, x2);
  }
  if (y2 < y1) {
    std::swap(y1, y2);
  }
}

enum class HeadMode { kDecoded, kRawDfl };

struct ResolvedHead {
  HeadMode mode = HeadMode::kDecoded;
  int nc = 80;
  int reg_max = 0;
  std::string err;
};

struct TopKItem {
  int cls = 0;
  float score = 0.0F;
};

// Decode / layout (det_decode.cpp)
int InferNumFeatures(int d0, int d1);
ResolvedHead ResolveYolov8HeadFormat(int num_features, int num_classes_cfg);
bool MapLayoutToNxC(const float* squeezed, int d0, int d1, int num_features, std::vector<float>& pred_nxc,
                    std::string& err);
bool IsEnd2EndK6Layout(int d0, int d1);
float PercentileNearest(std::vector<float> v, float q);
int EnvIntOr(const char* name, int defv);
std::vector<TopKItem> TopKRow(const float* row, int nc, int k);
void DflIntegral(const float* box_raw, int n, int reg_max, std::vector<float>& dist);
int AnchorCountForStrides(int imgsz, const int strides[3]);
void BuildAnchorsAndStrides(int imgsz, int n_anchors, std::vector<float>& anchors_xy, std::vector<float>& stride_per_anchor);
void Dist2bboxXywh(const float* dist_n4, int n, const float* anchors_2n, std::vector<float>& xywh_unit);
void SplitRawDflChannels(const float* pred, int n, int nc, int reg_max, bool cls_first, std::vector<float>& box_raw,
                           std::vector<float>& cls_raw);
float LayoutScoreRawDfl(const float* pred, int n, int nc, int reg_max, int imgsz, bool box_first);
bool PickRawChannelOrder(const float* pred, int n, int nc, int reg_max, int imgsz, RawChannelOrder cfg,
                         bool& cls_first_out);
bool DecodeRawHeadToXywh(const float* pred, int n, int nc, int reg_max, int imgsz, RawChannelOrder order,
                         std::vector<float>& xywh_px, std::vector<float>& cls_raw, std::string& err);
bool ClassChannelsLookLikeProbabilities(const float* cls_raw, int n, int nc);
void InferClassScores(const float* cls_raw, int n, int nc, bool logits_mode, const DetPostConfig& cfg,
                      std::vector<float>& cls_scores);
std::string CheckDegenerateCls(const float* cls_raw, int n, int nc, bool logits_mode);
std::string CheckFlatHalfScores(const float* scores, int n, bool logits_mode);
DetPostResult PostprocessDetEnd2EndK6(const float* k6_rowmajor, int K, const DetPostConfig& cfg, const LetterboxInfo& lb);

// NMS (det_nms.cpp)
std::vector<int> ClassAwareNmsIndices(const std::vector<float>& xyxy, const std::vector<float>& scores,
                                      const std::vector<int>& cls_id, const std::vector<int>& indices, float iou_thr);

}  // namespace internal
}  // namespace det_postprocess
