#include "det_postprocess_internal.hpp"

namespace det_postprocess {
namespace internal {

std::vector<int> ClassAwareNmsIndices(const std::vector<float>& xyxy, const std::vector<float>& scores,
                                      const std::vector<int>& cls_id, const std::vector<int>& indices, float iou_thr) {
  std::map<int, std::vector<int>> by_cls;
  for (int i : indices) {
    by_cls[cls_id[static_cast<std::size_t>(i)]].push_back(i);
  }
  std::vector<int> all;
  for (auto& kv : by_cls) {
    auto& idx = kv.second;
    std::sort(idx.begin(), idx.end(),
              [&](int a, int b) { return scores[static_cast<std::size_t>(a)] > scores[static_cast<std::size_t>(b)]; });
    std::vector<int> keep;
    for (int iid : idx) {
      bool ok = true;
      const float ax1 = xyxy[static_cast<std::size_t>(iid) * 4U];
      const float ay1 = xyxy[static_cast<std::size_t>(iid) * 4U + 1];
      const float ax2 = xyxy[static_cast<std::size_t>(iid) * 4U + 2];
      const float ay2 = xyxy[static_cast<std::size_t>(iid) * 4U + 3];
      for (int j : keep) {
        const float iou = IouXyxy(ax1, ay1, ax2, ay2, xyxy[static_cast<std::size_t>(j) * 4U],
                                  xyxy[static_cast<std::size_t>(j) * 4U + 1], xyxy[static_cast<std::size_t>(j) * 4U + 2],
                                  xyxy[static_cast<std::size_t>(j) * 4U + 3]);
        if (iou > iou_thr) {
          ok = false;
          break;
        }
      }
      if (ok) {
        keep.push_back(iid);
      }
    }
    all.insert(all.end(), keep.begin(), keep.end());
  }
  std::sort(all.begin(), all.end(),
            [&](int a, int b) { return scores[static_cast<std::size_t>(a)] > scores[static_cast<std::size_t>(b)]; });
  return all;
}

}  // namespace internal

bool SqueezeTo2D(const float* in, const std::vector<std::int64_t>& shape, std::vector<float>& out, const float*& out_ptr,
                 int& d0, int& d1, std::string& err) {
  out.clear();
  out_ptr = in;
  std::vector<std::int64_t> d;
  d.reserve(shape.size());
  for (auto s : shape) {
    if (s != 1) {
      d.push_back(s);
    }
  }
  if (d.empty()) {
    err = "squeeze: empty shape";
    return false;
  }
  if (d.size() == 1U) {
    d.insert(d.begin(), 1);
  }
  if (d.size() != 2U) {
    err = "squeeze: expected rank 2 after removing ones";
    return false;
  }
  d0 = static_cast<int>(d[0]);
  d1 = static_cast<int>(d[1]);
  return true;
}

DetPostResult PostprocessDetSqueezed2D(const float* squeezed, int d0, int d1, const DetPostConfig& cfg,
                                     const LetterboxInfo& lb) {
  using namespace internal;

  DetPostResult r;
  if (squeezed == nullptr) {
    r.error = "null tensor";
    return r;
  }
  if (lb.orig_w < 1 || lb.orig_h < 1) {
    r.error = "orig_w/orig_h must be positive";
    return r;
  }
  if (IsEnd2EndK6Layout(d0, d1)) {
    if (d1 == 6) {
      return PostprocessDetEnd2EndK6(squeezed, d0, cfg, lb);
    }
    const int K = d1;
    std::vector<float> buf(static_cast<std::size_t>(K) * 6U);
    for (int n = 0; n < K; ++n) {
      for (int f = 0; f < 6; ++f) {
        buf[static_cast<std::size_t>(n) * 6U + f] = squeezed[static_cast<std::size_t>(f) * K + n];
      }
    }
    return PostprocessDetEnd2EndK6(buf.data(), K, cfg, lb);
  }

  const int nf = InferNumFeatures(d0, d1);
  if (nf < 5) {
    r.error = "invalid det output shape";
    return r;
  }
  const ResolvedHead rh = ResolveYolov8HeadFormat(nf, cfg.num_classes);
  if (!rh.err.empty()) {
    r.error = rh.err;
    return r;
  }
#if DET_PP_TIMING_ENABLED
  const auto t_pp0 = DetPpClock::now();
  auto t_phase = t_pp0;
  float layout_ms = 0.0F;
  float decode_ms = 0.0F;
  float score_ms = 0.0F;
  float cand_ms = 0.0F;
  float nms_ms = 0.0F;
  float pack_ms = 0.0F;
#endif
  std::vector<float> pred;
  std::string e2;
  if (!MapLayoutToNxC(squeezed, d0, d1, nf, pred, e2)) {
    r.error = e2;
    return r;
  }
#if DET_PP_TIMING_ENABLED
  {
    const auto t_now = DetPpClock::now();
    layout_ms = DetPpMs(t_phase, t_now);
    t_phase = t_now;
  }
#endif
  const int n = static_cast<int>(pred.size()) / nf;
  const int nc = rh.nc;

  std::vector<float> xywh(static_cast<std::size_t>(n) * 4U);
  std::vector<float> cls_raw(static_cast<std::size_t>(n) * nc);

  if (rh.mode == HeadMode::kRawDfl) {
    std::string e3;
    if (!DecodeRawHeadToXywh(pred.data(), n, nc, rh.reg_max, cfg.input_imgsz, cfg.raw_channel_order, xywh, cls_raw, e3)) {
      r.error = e3;
      return r;
    }
  } else {
    if (nf != 4 + nc) {
      r.error = "decoded layout: channel mismatch";
      return r;
    }
    for (int i = 0; i < n; ++i) {
      const float* row = pred.data() + static_cast<std::size_t>(i) * nf;
      for (int k = 0; k < 4; ++k) {
        xywh[static_cast<std::size_t>(i) * 4U + k] = row[k];
      }
      for (int c = 0; c < nc; ++c) {
        cls_raw[static_cast<std::size_t>(i) * nc + c] = row[4 + c];
      }
    }
  }
#if DET_PP_TIMING_ENABLED
  {
    const auto t_now = DetPpClock::now();
    decode_ms = DetPpMs(t_phase, t_now);
    t_phase = t_now;
  }
#endif

  {
    const std::string e = CheckDegenerateCls(cls_raw.data(), n, nc, cfg.class_scores_are_logits);
    if (!e.empty()) {
      r.error = e;
      return r;
    }
  }

  std::vector<float> cls_scores;
  InferClassScores(cls_raw.data(), n, nc, cfg.class_scores_are_logits, cfg, cls_scores);

  const bool dbg = (std::getenv("DET_POSTPROCESS_DEBUG") != nullptr);
  const int dbg_topk = EnvIntOr("DET_POSTPROCESS_DEBUG_TOPK", 3);
  const int dbg_max_anchors = EnvIntOr("DET_POSTPROCESS_DEBUG_MAX_ANCHORS", 0);  // 0=all, <0=none
  if (dbg) {
    DET_PP_LOG("[det_postprocess][debug] begin: shape=[%d,%d] nf=%d n=%d nc=%d conf=%.6f iou=%.6f imgsz=%d logits=%d",
               d0, d1, nf, n, nc, cfg.conf, cfg.iou, cfg.input_imgsz, cfg.class_scores_are_logits ? 1 : 0);
  }

  std::vector<int> cls_id(static_cast<std::size_t>(n));
  std::vector<float> best_score(static_cast<std::size_t>(n));
  for (int i = 0; i < n; ++i) {
    int best = 0;
    float bs = cls_scores[static_cast<std::size_t>(i) * nc];
    for (int c = 1; c < nc; ++c) {
      const float v = cls_scores[static_cast<std::size_t>(i) * nc + c];
      if (v > bs) {
        bs = v;
        best = c;
      }
    }
    cls_id[static_cast<std::size_t>(i)] = best;
    best_score[static_cast<std::size_t>(i)] = bs;
  }
#if DET_PP_TIMING_ENABLED
  {
    const auto t_now = DetPpClock::now();
    score_ms = DetPpMs(t_phase, t_now);
    t_phase = t_now;
  }
#endif

  float max_best_score = 0.0F;
  for (int i = 0; i < n; ++i) {
    max_best_score = std::max(max_best_score, best_score[static_cast<std::size_t>(i)]);
  }
  const char* head_tag = (rh.mode == HeadMode::kRawDfl) ? "raw_dfl" : "decoded";

  if (dbg && dbg_topk > 0 && dbg_max_anchors >= 0) {
    const int limit = (dbg_max_anchors == 0) ? n : std::min(n, dbg_max_anchors);
    for (int i = 0; i < limit; ++i) {
      const float* row = cls_scores.data() + static_cast<std::size_t>(i) * nc;
      const auto tk = TopKRow(row, nc, dbg_topk);
      std::string topk_text;
      for (std::size_t j = 0; j < tk.size(); ++j) {
        char buf[64] = {0};
        std::snprintf(buf, sizeof(buf), "%s%d:%.6f", (j == 0 ? "" : ","), tk[j].cls, tk[j].score);
        topk_text += buf;
      }
      DET_PP_LOG("[det_postprocess][debug] anchor=%d best_cls=%d best=%.6f topk=%s",
                 i,
                 cls_id[static_cast<std::size_t>(i)],
                 best_score[static_cast<std::size_t>(i)],
                 topk_text.c_str());
    }
    if (limit < n) {
      DET_PP_LOG("[det_postprocess][debug] anchor print truncated: %d/%d (set DET_POSTPROCESS_DEBUG_MAX_ANCHORS=0 for all)",
                 limit, n);
    }
  }

  {
    const std::string e = CheckFlatHalfScores(best_score.data(), n, cfg.class_scores_are_logits);
    if (!e.empty()) {
      r.error = e;
      return r;
    }
  }

  std::vector<int> cand;
  cand.reserve(static_cast<std::size_t>(n));
  int num_wh_positive = 0;
  for (int i = 0; i < n; ++i) {
    const float w = xywh[static_cast<std::size_t>(i) * 4U + 2];
    const float h = xywh[static_cast<std::size_t>(i) * 4U + 3];
    if (w > 0.0F && h > 0.0F) {
      ++num_wh_positive;
      if (best_score[static_cast<std::size_t>(i)] >= cfg.conf) {
        cand.push_back(i);
      }
    }
  }
  if (dbg) {
    DET_PP_LOG("[det_postprocess][debug] threshold counts: total=%d wh_positive=%d score>=conf=%d (conf=%.6f)",
               n, num_wh_positive, static_cast<int>(cand.size()), cfg.conf);
  }
#if DET_PP_TIMING_ENABLED
  {
    const auto t_now = DetPpClock::now();
    cand_ms = DetPpMs(t_phase, t_now);
    t_phase = t_now;
    DET_PP_TIMING(
        "[det_postprocess][timing] layout=%.2f decode=%.2f score=%.2f thresh=%.2f pre_summary=%.2f "
        "n=%d cand_in=%d (DFL/decode; thresh=conf filter)",
        layout_ms,
        decode_ms,
        score_ms,
        cand_ms,
        DetPpMs(t_pp0, t_now),
        n,
        static_cast<int>(cand.size()));
  }
#endif
  DET_PP_SUMMARY(
      "[det_postprocess][summary] shape=[%d,%d] nf=%d head=%s n=%d nc=%d conf=%.6f logits=%d "
      "max_best_score=%.6f wh_positive=%d score_ge_conf=%d",
      d0,
      d1,
      nf,
      head_tag,
      n,
      nc,
      cfg.conf,
      cfg.class_scores_are_logits ? 1 : 0,
      max_best_score,
      num_wh_positive,
      static_cast<int>(cand.size()));
  if (cand.empty()) {
    DET_PP_SUMMARY("[det_postprocess][summary] early_exit cand_empty (no NMS); see counts above");
#if DET_PP_TIMING_ENABLED
    DET_PP_TIMING("[det_postprocess][timing] total=%.2f nms=0.00 pack=0.00 (early_exit)",
                  DetPpMs(t_pp0, DetPpClock::now()));
#endif
    r.ok = true;
    return r;
  }

  std::vector<float> xyxy(static_cast<std::size_t>(cand.size()) * 4U);
  std::vector<float> scores;
  std::vector<int> cls_out;
  scores.reserve(cand.size());
  cls_out.reserve(cand.size());
  for (std::size_t j = 0; j < cand.size(); ++j) {
    const int i = cand[j];
    const float cx = xywh[static_cast<std::size_t>(i) * 4U];
    const float cy = xywh[static_cast<std::size_t>(i) * 4U + 1];
    const float w = xywh[static_cast<std::size_t>(i) * 4U + 2];
    const float hh = xywh[static_cast<std::size_t>(i) * 4U + 3];
    float x1, y1, x2, y2;
    XywhToXyxy(cx, cy, w, hh, x1, y1, x2, y2);
    xyxy[j * 4U + 0] = x1;
    xyxy[j * 4U + 1] = y1;
    xyxy[j * 4U + 2] = x2;
    xyxy[j * 4U + 3] = y2;
    scores.push_back(best_score[static_cast<std::size_t>(i)]);
    cls_out.push_back(cls_id[static_cast<std::size_t>(i)]);
  }

  for (std::size_t j = 0; j < cand.size(); ++j) {
    float& x1 = xyxy[j * 4U + 0];
    float& y1 = xyxy[j * 4U + 1];
    float& x2 = xyxy[j * 4U + 2];
    float& y2 = xyxy[j * 4U + 3];
    RemapClipRoundXyxy(x1, y1, x2, y2, lb, cfg.box_round_policy);
  }

  std::vector<int> remap(cand.size());
  for (std::size_t j = 0; j < cand.size(); ++j) {
    remap[j] = static_cast<int>(j);
  }
  std::vector<int> keep = ClassAwareNmsIndices(xyxy, scores, cls_out, remap, cfg.iou);
#if DET_PP_TIMING_ENABLED
  {
    const auto t_now = DetPpClock::now();
    nms_ms = DetPpMs(t_phase, t_now);
    t_phase = t_now;
  }
#endif
  if (dbg) {
    DET_PP_LOG("[det_postprocess][debug] after NMS: before=%d keep=%d iou=%.6f",
               static_cast<int>(cand.size()), static_cast<int>(keep.size()), cfg.iou);
  }
  DET_PP_SUMMARY("[det_postprocess][summary] nms cand_in=%d keep_after_nms=%d iou=%.6f max_det=%d",
                 static_cast<int>(cand.size()),
                 static_cast<int>(keep.size()),
                 cfg.iou,
                 cfg.max_det);

  if (cfg.max_det > 0 && static_cast<int>(keep.size()) > cfg.max_det) {
    keep.resize(static_cast<std::size_t>(cfg.max_det));
  }
  if (dbg) {
    DET_PP_LOG("[det_postprocess][debug] after max_det: keep=%d max_det=%d",
               static_cast<int>(keep.size()), cfg.max_det);
  }
  DET_PP_SUMMARY("[det_postprocess][summary] final_boxes=%d", static_cast<int>(keep.size()));

  r.ok = true;
#if DET_PP_TIMING_ENABLED
  const auto t_pack0 = DetPpClock::now();
#endif
  for (int j : keep) {
    DetBox b;
    b.class_id = cls_out[static_cast<std::size_t>(j)];
    b.x1 = xyxy[static_cast<std::size_t>(j) * 4U + 0];
    b.y1 = xyxy[static_cast<std::size_t>(j) * 4U + 1];
    b.x2 = xyxy[static_cast<std::size_t>(j) * 4U + 2];
    b.y2 = xyxy[static_cast<std::size_t>(j) * 4U + 3];
    b.score = scores[static_cast<std::size_t>(j)];
    r.boxes.push_back(b);
  }
#if DET_PP_TIMING_ENABLED
  {
    const auto t_pp1 = DetPpClock::now();
    pack_ms = DetPpMs(t_pack0, t_pp1);
    DET_PP_TIMING(
        "[det_postprocess][timing] layout=%.2f decode=%.2f score=%.2f thresh=%.2f nms=%.2f pack=%.2f "
        "total=%.2f n=%d cand_in=%d keep=%d",
        layout_ms,
        decode_ms,
        score_ms,
        cand_ms,
        nms_ms,
        pack_ms,
        DetPpMs(t_pp0, t_pp1),
        n,
        static_cast<int>(cand.size()),
        static_cast<int>(keep.size()));
  }
#endif
  return r;
}

}  // namespace det_postprocess
