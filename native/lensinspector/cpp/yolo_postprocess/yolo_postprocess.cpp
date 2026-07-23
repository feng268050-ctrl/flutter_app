#include "yolo_postprocess.hpp"
#include "../postprocess/det_postprocess.hpp"

#include <algorithm>
#include <cmath>
#include <vector>

namespace yolo_postprocess {

DetResult postprocess_det(const float* data, int d0, int d1, const DetConfig& cfg, const LetterboxInfo& letterbox,
                          const StainDetRoiRestore* roi_restore) {
  DetResult r;
  det_postprocess::DetPostConfig ocp;
  ocp.conf = cfg.conf_threshold;
  ocp.iou = cfg.iou_threshold;
  ocp.max_det = cfg.max_det;
  // 0 or unset: same auto head resolution as check/onnx_infer.py (DetPostConfig num_classes = -1).
  ocp.num_classes = (cfg.num_classes >= 1) ? cfg.num_classes : -1;
  ocp.input_imgsz = cfg.input_imgsz;
  ocp.class_scores_are_logits = cfg.class_scores_are_logits;
  ocp.on_class_prob_hint = cfg.on_class_prob_hint;
  switch (cfg.raw_channel_order) {
    case DetConfig::RawChannelOrder::BoxFirst:
      ocp.raw_channel_order = det_postprocess::RawChannelOrder::BoxFirst;
      break;
    case DetConfig::RawChannelOrder::ClsFirst:
      ocp.raw_channel_order = det_postprocess::RawChannelOrder::ClsFirst;
      break;
    default:
      ocp.raw_channel_order = det_postprocess::RawChannelOrder::Auto;
      break;
  }
  switch (cfg.box_round_policy) {
    case DetConfig::BoxRoundPolicy::None:
      ocp.box_round_policy = det_postprocess::BoxRoundPolicy::None;
      break;
    case DetConfig::BoxRoundPolicy::Round:
      ocp.box_round_policy = det_postprocess::BoxRoundPolicy::Round;
      break;
    case DetConfig::BoxRoundPolicy::Floor:
      ocp.box_round_policy = det_postprocess::BoxRoundPolicy::Floor;
      break;
    case DetConfig::BoxRoundPolicy::Ceil:
      ocp.box_round_policy = det_postprocess::BoxRoundPolicy::Ceil;
      break;
  }

  det_postprocess::LetterboxInfo lb;
  lb.scale = letterbox.scale;
  lb.pad_w = letterbox.pad_w;
  lb.pad_h = letterbox.pad_h;
  lb.orig_w = letterbox.orig_w;
  lb.orig_h = letterbox.orig_h;

  auto pr = det_postprocess::PostprocessDetSqueezed2D(data, d0, d1, ocp, lb);
  if (!pr.ok) {
    r.error = std::move(pr.error);
    return r;
  }
  r.ok = true;
  r.boxes.reserve(pr.boxes.size());
  for (const auto& b : pr.boxes) {
    DetBox db;
    db.x1 = b.x1;
    db.y1 = b.y1;
    db.x2 = b.x2;
    db.y2 = b.y2;
    db.class_id = b.class_id;
    db.score = b.score;
    if (roi_restore != nullptr && roi_restore->active && roi_restore->crop_s > 0 && roi_restore->full_w > 0 &&
        roi_restore->full_h > 0) {
      const float k = static_cast<float>(roi_restore->crop_s) / static_cast<float>(letterbox.orig_w);
      db.x1 = static_cast<float>(roi_restore->crop_x0) + db.x1 * k;
      db.x2 = static_cast<float>(roi_restore->crop_x0) + db.x2 * k;
      db.y1 = static_cast<float>(roi_restore->crop_y0) + db.y1 * k;
      db.y2 = static_cast<float>(roi_restore->crop_y0) + db.y2 * k;
      const float max_x = static_cast<float>(roi_restore->full_w - 1);
      const float max_y = static_cast<float>(roi_restore->full_h - 1);
      db.x1 = std::max(0.0F, std::min(db.x1, max_x));
      db.x2 = std::max(0.0F, std::min(db.x2, max_x));
      db.y1 = std::max(0.0F, std::min(db.y1, max_y));
      db.y2 = std::max(0.0F, std::min(db.y2, max_y));
      if (db.x2 < db.x1) {
        std::swap(db.x1, db.x2);
      }
      if (db.y2 < db.y1) {
        std::swap(db.y1, db.y2);
      }
    }
    r.boxes.push_back(db);
  }
  return r;
}

ClsResult postprocess_cls(const float* data, int num_classes, const ClsConfig& cfg) {
  ClsResult r;
  if (num_classes < 1) {
    r.error = "num_classes must be at least 1";
    return r;
  }
  if (data == nullptr) {
    r.error = "null data pointer";
    return r;
  }
  std::vector<float> probs(static_cast<std::size_t>(num_classes));
  float s = 0.0F;
  for (int i = 0; i < num_classes; ++i) {
    s += data[static_cast<std::size_t>(i)];
  }
  const bool is_prob = std::abs(s - 1.0F) < cfg.prob_sum_epsilon;
  if (is_prob) {
    for (int i = 0; i < num_classes; ++i) {
      probs[static_cast<std::size_t>(i)] = data[static_cast<std::size_t>(i)];
    }
  } else {
    float m = data[0];
    for (int i = 1; i < num_classes; ++i) {
      m = std::max(m, data[static_cast<std::size_t>(i)]);
    }
    double esum = 0.0;
    for (int i = 0; i < num_classes; ++i) {
      const double e = std::exp(static_cast<double>(data[static_cast<std::size_t>(i)] - m));
      esum += e;
    }
    if (esum <= 0.0) {
      r.error = "softmax underflow";
      return r;
    }
    for (int i = 0; i < num_classes; ++i) {
      const double e = std::exp(static_cast<double>(data[static_cast<std::size_t>(i)] - m));
      probs[static_cast<std::size_t>(i)] = static_cast<float>(e / esum);
    }
  }

  int k = cfg.topk;
  if (k < 1) {
    k = 1;
  }
  if (k > num_classes) {
    k = num_classes;
  }
  std::vector<int> order(static_cast<std::size_t>(num_classes));
  for (int i = 0; i < num_classes; ++i) {
    order[static_cast<std::size_t>(i)] = i;
  }
  const std::size_t ksz = static_cast<std::size_t>(k);
  std::partial_sort(
      order.begin(), order.begin() + static_cast<std::ptrdiff_t>(ksz), order.end(), [&probs](int a, int b) {
        return probs[static_cast<std::size_t>(a)] > probs[static_cast<std::size_t>(b)];
      });

  r.top.resize(ksz);
  for (std::size_t i = 0; i < ksz; ++i) {
    const int id = order[i];
    r.top[i].class_id = id;
    r.top[i].prob = probs[static_cast<std::size_t>(id)];
  }
  r.ok = true;
  return r;
}

}  // namespace yolo_postprocess
