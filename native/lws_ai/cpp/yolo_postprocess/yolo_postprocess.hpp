// Detection post-processing delegates to `cpp/postprocess/det_postprocess` (float tensor decode + NMS).
// Classification remains here. No Ultralytics, ONNX Runtime, or RKNN SDK in this TU.

#pragma once

#include <cstddef>
#include <functional>
#include <string>
#include <vector>

namespace yolo_postprocess {

struct LetterboxInfo {
  float scale = 1.0F;
  int pad_w = 0;
  int pad_h = 0;
  int orig_w = 0;
  int orig_h = 0;
};

/// Stain **detection** only: map model-input xyxy (640) → ROI canvas (crop_s) → full frame (+ crop_x0/y0).
struct StainDetRoiRestore {
  bool active = false;
  int crop_x0 = 0;
  int crop_y0 = 0;
  int crop_s = 0;
  int full_w = 0;
  int full_h = 0;
};

struct DetConfig {
  enum class BoxRoundPolicy { None, Round, Floor, Ceil };
  enum class RawChannelOrder { Auto, BoxFirst, ClsFirst };
  /// 0 = auto (decoded vs raw DFL from tensor C, same as Python default). >=1 = fixed class count.
  int num_classes = 0;
  /// Raw DFL channel layout (det_raw_head: BoxFirst = 64 DFL + 1 cls).
  RawChannelOrder raw_channel_order = RawChannelOrder::BoxFirst;
  float conf_threshold = 0.25F;
  float iou_threshold = 0.45F;
  /// Upper bound on returned boxes after NMS; 0 means no cap.
  int max_det = 0;
  /// Square model input side (stain det letterbox target, default 640); forwarded to shared det post-process (DFL decode).
  int input_imgsz = 640;
  /// Apply sigmoid to class scores before thresholding when model outputs logits.
  bool class_scores_are_logits = false;
  /// One-shot hint when logits mode skips a second sigmoid (see det_postprocess).
  std::function<void(const char* msg)> on_class_prob_hint = nullptr;
  /// Coordinate rounding policy after remap+clip to source frame.
  BoxRoundPolicy box_round_policy = BoxRoundPolicy::None;
};

struct ClsConfig {
  int topk = 5;
  /// If sum of outputs is within this tolerance of 1.0, treat as probabilities.
  float prob_sum_epsilon = 0.01F;
};

struct DetBox {
  float x1 = 0.0F;
  float y1 = 0.0F;
  float x2 = 0.0F;
  float y2 = 0.0F;
  int class_id = 0;
  float score = 0.0F;
};

struct ClsItem {
  int class_id = 0;
  float prob = 0.0F;
};

struct DetResult {
  bool ok = false;
  std::string error;
  std::vector<DetBox> boxes;
};

struct ClsResult {
  bool ok = false;
  std::string error;
  std::vector<ClsItem> top;
};

// --- Detection ---

// Raw output after NCHW batch=1 squeeze: [d0, d1] in row-major float.
// One side MUST be 4+nc: [C, N] when d0=4+nc, or [N, C] when d1=4+nc. Matches check/detect_onnx_infer layout handling.
// `roi_restore`: when non-null and active, boxes are remapped from ROI space to full frame after model-space remap.
DetResult postprocess_det(const float* data, int d0, int d1, const DetConfig& cfg, const LetterboxInfo& letterbox,
                          const StainDetRoiRestore* roi_restore = nullptr);

// --- Classification ---

// data length must be num_classes. Applies softmax if outputs are not already a probability simplex.
ClsResult postprocess_cls(const float* data, int num_classes, const ClsConfig& cfg);

}  // namespace yolo_postprocess
