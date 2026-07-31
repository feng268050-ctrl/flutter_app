// Native float-tensor detection post-process (decode / DFL / NMS / letterbox undo).
// Behavior matches the Python reference in `check/onnx_infer.py` (math only; no ONNX Runtime here).
// Canonical sources: cpp/postprocess/ (linked into libai via yolo_postprocess wrapper).
//
// Standalone tools:
//   cd check && cmake -S . -B build && cmake --build build
//
#pragma once

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

namespace det_postprocess {

struct LetterboxInfo {
  float scale = 1.0F;
  int pad_w = 0;
  int pad_h = 0;
  int orig_w = 0;
  int orig_h = 0;
};

enum class RawChannelOrder { Auto, BoxFirst, ClsFirst };
enum class BoxRoundPolicy { None, Round, Floor, Ceil };

struct DetPostConfig {
  float conf = 0.25F;
  float iou = 0.45F;
  int max_det = 0;
  /// -1 = same heuristics as Python (84→80 decoded, 144→raw DFL, …).
  int num_classes = -1;
  int input_imgsz = 640;
  /// true = logits (apply sigmoid unless values already look like probabilities in [0,1]).
  bool class_scores_are_logits = true;
  RawChannelOrder raw_channel_order = RawChannelOrder::BoxFirst;
  /// Coordinate rounding policy after remap+clip to source frame.
  BoxRoundPolicy box_round_policy = BoxRoundPolicy::None;
  /// If non-null, one-shot hint when logits mode skips a second sigmoid (matches Python stderr).
  std::function<void(const char* msg)> on_class_prob_hint = nullptr;
};

struct DetBox {
  int class_id = 0;
  float x1 = 0.0F;
  float y1 = 0.0F;
  float x2 = 0.0F;
  float y2 = 0.0F;
  float score = 0.0F;
};

struct DetPostResult {
  bool ok = false;
  std::string error;
  std::vector<DetBox> boxes;
};

/// Remove size-1 dimensions (NumPy squeeze semantics) until rank 2 or fail.
/// On success, `out` holds a contiguous row-major copy when a reshape was required; otherwise may be empty
/// and `out_ptr` aliases `in`.
bool SqueezeTo2D(const float* in, const std::vector<std::int64_t>& shape, std::vector<float>& out,
                 const float*& out_ptr, int& d0, int& d1, std::string& err);

/// Same as det `postprocess_det` in `check/onnx_infer.py` after squeeze to 2D [d0,d1], row-major float32.
DetPostResult PostprocessDetSqueezed2D(const float* squeezed, int d0, int d1, const DetPostConfig& cfg,
                                     const LetterboxInfo& letterbox);

}  // namespace det_postprocess
