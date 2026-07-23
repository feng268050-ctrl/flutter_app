#include "det_postprocess_internal.hpp"

namespace det_postprocess {
namespace internal {

int InferNumFeatures(int d0, int d1) {
  if (d0 >= 5 && (d0 <= d1 || d1 < 5)) {
    return d0;
  }
  if (d1 >= 5) {
    return d1;
  }
  return 0;
}

ResolvedHead ResolveYolov8HeadFormat(int num_features, int num_classes_cfg) {
  ResolvedHead r;
  if (num_features < 5) {
    r.err = "invalid det channel count";
    return r;
  }
  if (num_classes_cfg >= 0) {
    const int nc = num_classes_cfg;
    if (nc < 1) {
      r.err = "num_classes must be >= 1 when specified";
      return r;
    }
    const int dec = 4 + nc;
    if (num_features == dec) {
      r.mode = HeadMode::kDecoded;
      r.nc = nc;
      r.reg_max = 0;
      return r;
    }
    const int box_ch = num_features - nc;
    if (box_ch <= 0 || (box_ch % 4) != 0) {
      r.err = "raw/decoded channel split invalid for given num_classes";
      return r;
    }
    const int rm = box_ch / 4;
    if (num_features == 4 * rm + nc) {
      r.mode = HeadMode::kRawDfl;
      r.nc = nc;
      r.reg_max = rm;
      return r;
    }
    r.err = "num_features does not match decoded or raw DFL for given num_classes";
    return r;
  }
  if (num_features == 84) {
    r.mode = HeadMode::kDecoded;
    r.nc = 80;
    return r;
  }
  if (num_features == 144) {
    r.mode = HeadMode::kRawDfl;
    r.nc = 80;
    r.reg_max = 16;
    return r;
  }
  if (num_features == 128) {
    r.mode = HeadMode::kRawDfl;
    r.nc = 80;
    r.reg_max = 12;
    return r;
  }
  // Lens det_raw_head: nc=1, reg_max=16 → C=65 (not decoded nc=61)
  if (num_features == 5) {
    r.mode = HeadMode::kDecoded;
    r.nc = 1;
    return r;
  }
  if (num_features == 65) {
    r.mode = HeadMode::kRawDfl;
    r.nc = 1;
    r.reg_max = 16;
    return r;
  }
  if (num_features > 8 && ((num_features - 1) % 4) == 0) {
    const int rm = (num_features - 1) / 4;
    if (rm >= 2 && rm <= 32) {
      r.mode = HeadMode::kRawDfl;
      r.nc = 1;
      r.reg_max = rm;
      return r;
    }
  }
  if (num_features <= 8) {
    r.mode = HeadMode::kDecoded;
    r.nc = num_features - 4;
    return r;
  }
  r.mode = HeadMode::kDecoded;
  r.nc = num_features - 4;
  return r;
}

bool MapLayoutToNxC(const float* squeezed, int d0, int d1, int num_features, std::vector<float>& pred_nxc,
                    std::string& err) {
  pred_nxc.clear();
  if (d0 == num_features && d1 == num_features) {
    err = "ambiguous layout: both dimensions equal C";
    return false;
  }
  if (d0 == num_features && d1 != num_features) {
    const int N = d1;
    const int C = num_features;
    pred_nxc.resize(static_cast<std::size_t>(N) * static_cast<std::size_t>(C));
    for (int n = 0; n < N; ++n) {
      for (int c = 0; c < C; ++c) {
        pred_nxc[static_cast<std::size_t>(n) * C + c] = squeezed[static_cast<std::size_t>(c) * N + n];
      }
    }
    return true;
  }
  if (d1 == num_features && d0 != num_features) {
    const int N = d0;
    const int C = num_features;
    pred_nxc.resize(static_cast<std::size_t>(N) * static_cast<std::size_t>(C));
    std::memcpy(pred_nxc.data(), squeezed, sizeof(float) * static_cast<std::size_t>(N) * C);
    return true;
  }
  err = "cannot map layout for tensor shape vs num_features";
  return false;
}

bool IsEnd2EndK6Layout(int d0, int d1) {
  const int small = std::min(d0, d1);
  const int big = std::max(d0, d1);
  if (small != 6) {
    return false;
  }
  return big >= 8 && big < 1000;
}

float PercentileNearest(std::vector<float> v, float q /*0..100*/) {
  if (v.empty()) {
    return 0.0F;
  }
  if (v.size() == 1U) {
    return v[0];
  }
  std::sort(v.begin(), v.end());
  const double pos = (static_cast<double>(v.size() - 1U)) * (static_cast<double>(q) * 0.01);
  const std::size_t i = static_cast<std::size_t>(pos);
  const std::size_t j = (i + 1U < v.size()) ? (i + 1U) : i;
  const double t = pos - static_cast<double>(i);
  return static_cast<float>(static_cast<double>(v[i]) * (1.0 - t) + static_cast<double>(v[j]) * t);
}

int EnvIntOr(const char* name, int defv) {
  const char* v = std::getenv(name);
  if (v == nullptr || *v == '\0') {
    return defv;
  }
  char* end = nullptr;
  const long x = std::strtol(v, &end, 10);
  if (end == v) {
    return defv;
  }
  if (x < static_cast<long>(std::numeric_limits<int>::min())) {
    return std::numeric_limits<int>::min();
  }
  if (x > static_cast<long>(std::numeric_limits<int>::max())) {
    return std::numeric_limits<int>::max();
  }
  return static_cast<int>(x);
}

std::vector<TopKItem> TopKRow(const float* row, int nc, int k) {
  if (row == nullptr || nc <= 0 || k <= 0) {
    return {};
  }
  if (k > nc) {
    k = nc;
  }
  std::vector<TopKItem> out;
  out.reserve(static_cast<std::size_t>(k));
  for (int i = 0; i < k; ++i) {
    out.push_back(TopKItem{i, row[i]});
  }
  auto worse = [](const TopKItem& a, const TopKItem& b) { return a.score > b.score; };  // min-heap by score
  std::make_heap(out.begin(), out.end(), worse);
  for (int c = k; c < nc; ++c) {
    const float sc = row[c];
    if (sc > out.front().score) {
      std::pop_heap(out.begin(), out.end(), worse);
      out.back() = TopKItem{c, sc};
      std::push_heap(out.begin(), out.end(), worse);
    }
  }
  std::sort(out.begin(), out.end(), [](const TopKItem& a, const TopKItem& b) { return a.score > b.score; });
  return out;
}

void DflIntegral(const float* box_raw, int n, int reg_max, std::vector<float>& dist /*n*4*/) {
  dist.resize(static_cast<std::size_t>(n) * 4U);
  std::vector<float> sm;
  for (int i = 0; i < n; ++i) {
    for (int side = 0; side < 4; ++side) {
      const float* z = box_raw + static_cast<std::size_t>(i) * (4 * reg_max) + static_cast<std::size_t>(side) * reg_max;
      sm.assign(reg_max, 0.0F);
      float m = -std::numeric_limits<float>::infinity();
      for (int k = 0; k < reg_max; ++k) {
        m = std::max(m, z[k]);
      }
      double s = 0.0;
      for (int k = 0; k < reg_max; ++k) {
        const float x = std::max(-50.0F, std::min(50.0F, z[k] - m));
        sm[static_cast<std::size_t>(k)] = static_cast<float>(std::exp(static_cast<double>(x)));
        s += sm[static_cast<std::size_t>(k)];
      }
      s = std::max(s, 1e-12);
      float acc = 0.0F;
      for (int k = 0; k < reg_max; ++k) {
        const float p = sm[static_cast<std::size_t>(k)] / static_cast<float>(s);
        acc += p * static_cast<float>(k);
      }
      dist[static_cast<std::size_t>(i) * 4U + static_cast<std::size_t>(side)] = acc;
    }
  }
}

int AnchorCountForStrides(int imgsz, const int strides[3]) {
  int n = 0;
  for (int si = 0; si < 3; ++si) {
    const int st = strides[si];
    const int g = imgsz / st;
    if (g * st != imgsz) {
      return -1;
    }
    n += g * g;
  }
  return n;
}

void BuildAnchorsAndStrides(int imgsz, int n_anchors, std::vector<float>& anchors_xy /*2*N*/,
                            std::vector<float>& stride_per_anchor) {
  static const int kP2P3P4[3] = {4, 8, 16};
  static const int kP3P4P5[3] = {8, 16, 32};
  const int* strides = kP3P4P5;
  if (n_anchors > 0) {
    if (AnchorCountForStrides(imgsz, kP2P3P4) == n_anchors) {
      strides = kP2P3P4;
    } else if (AnchorCountForStrides(imgsz, kP3P4P5) == n_anchors) {
      strides = kP3P4P5;
    }
  }
  anchors_xy.clear();
  stride_per_anchor.clear();
  for (int si = 0; si < 3; ++si) {
    const int st = strides[si];
    const int h = imgsz / st;
    const int w = imgsz / st;
    if (h * st != imgsz) {
      anchors_xy.clear();
      stride_per_anchor.clear();
      return;
    }
    for (int iy = 0; iy < h; ++iy) {
      for (int ix = 0; ix < w; ++ix) {
        const float gx = static_cast<float>(ix) + 0.5F;
        const float gy = static_cast<float>(iy) + 0.5F;
        anchors_xy.push_back(gx);
        anchors_xy.push_back(gy);
        stride_per_anchor.push_back(static_cast<float>(st));
      }
    }
  }
}

void Dist2bboxXywh(const float* dist_n4, int n, const float* anchors_2n, std::vector<float>& xywh_unit) {
  xywh_unit.resize(static_cast<std::size_t>(n) * 4U);
  for (int i = 0; i < n; ++i) {
    const float l = dist_n4[static_cast<std::size_t>(i) * 4U + 0];
    const float t = dist_n4[static_cast<std::size_t>(i) * 4U + 1];
    const float r = dist_n4[static_cast<std::size_t>(i) * 4U + 2];
    const float b = dist_n4[static_cast<std::size_t>(i) * 4U + 3];
    const float ax = anchors_2n[static_cast<std::size_t>(i) * 2U];
    const float ay = anchors_2n[static_cast<std::size_t>(i) * 2U + 1U];
    const float x1 = ax - l;
    const float y1 = ay - t;
    const float x2 = ax + r;
    const float y2 = ay + b;
    const float cx = (x1 + x2) * 0.5F;
    const float cy = (y1 + y2) * 0.5F;
    const float ww = x2 - x1;
    const float hh = y2 - y1;
    xywh_unit[static_cast<std::size_t>(i) * 4U + 0] = cx;
    xywh_unit[static_cast<std::size_t>(i) * 4U + 1] = cy;
    xywh_unit[static_cast<std::size_t>(i) * 4U + 2] = ww;
    xywh_unit[static_cast<std::size_t>(i) * 4U + 3] = hh;
  }
}

void SplitRawDflChannels(const float* pred, int n, int nc, int reg_max, bool cls_first, std::vector<float>& box_raw,
                         std::vector<float>& cls_raw) {
  const int box_ch = 4 * reg_max;
  box_raw.resize(static_cast<std::size_t>(n) * box_ch);
  cls_raw.resize(static_cast<std::size_t>(n) * nc);
  const int C = box_ch + nc;
  for (int i = 0; i < n; ++i) {
    const float* row = pred + static_cast<std::size_t>(i) * C;
    if (!cls_first) {
      std::memcpy(box_raw.data() + static_cast<std::size_t>(i) * box_ch, row, sizeof(float) * box_ch);
      std::memcpy(cls_raw.data() + static_cast<std::size_t>(i) * nc, row + box_ch, sizeof(float) * nc);
    } else {
      std::memcpy(cls_raw.data() + static_cast<std::size_t>(i) * nc, row, sizeof(float) * nc);
      std::memcpy(box_raw.data() + static_cast<std::size_t>(i) * box_ch, row + nc, sizeof(float) * box_ch);
    }
  }
}

float LayoutScoreRawDfl(const float* pred, int n, int nc, int reg_max, int imgsz, bool box_first) {
  std::vector<float> box_raw, cls_raw;
  SplitRawDflChannels(pred, n, nc, reg_max, !box_first, box_raw, cls_raw);
  std::vector<float> dist;
  DflIntegral(box_raw.data(), n, reg_max, dist);
  std::vector<float> anchors_xy, strides;
  BuildAnchorsAndStrides(imgsz, n, anchors_xy, strides);
  if (static_cast<int>(strides.size()) != n || static_cast<int>(anchors_xy.size()) != n * 2) {
    return -1e9F;
  }
  std::vector<float> xywh_unit;
  Dist2bboxXywh(dist.data(), n, anchors_xy.data(), xywh_unit);
  std::vector<float> xywh_px(static_cast<std::size_t>(n) * 4U);
  for (int i = 0; i < n; ++i) {
    const float st = strides[static_cast<std::size_t>(i)];
    for (int k = 0; k < 4; ++k) {
      xywh_px[static_cast<std::size_t>(i) * 4U + k] = xywh_unit[static_cast<std::size_t>(i) * 4U + k] * st;
    }
  }
  const float m = static_cast<float>(imgsz) * 0.25F;
  int sane = 0;
  for (int i = 0; i < n; ++i) {
    const float cx = xywh_px[static_cast<std::size_t>(i) * 4U];
    const float cy = xywh_px[static_cast<std::size_t>(i) * 4U + 1];
    const float w = xywh_px[static_cast<std::size_t>(i) * 4U + 2];
    const float h = xywh_px[static_cast<std::size_t>(i) * 4U + 3];
    if (cx >= -m && cx <= static_cast<float>(imgsz) + m && cy >= -m && cy <= static_cast<float>(imgsz) + m &&
        w > 1.0F && w < static_cast<float>(imgsz) * 2.0F && h > 1.0F && h < static_cast<float>(imgsz) * 2.0F) {
      ++sane;
    }
  }
  std::vector<float> row_max;
  row_max.reserve(static_cast<std::size_t>(n));
  for (int i = 0; i < n; ++i) {
    float mx = 0.0F;
    const float* cr = cls_raw.data() + static_cast<std::size_t>(i) * nc;
    for (int c = 0; c < nc; ++c) {
      mx = std::max(mx, Sigmoid(cr[c]));
    }
    row_max.push_back(mx);
  }
  const float peak = PercentileNearest(row_max, 99.5F);
  const float frac_sane = static_cast<float>(sane) / static_cast<float>(std::max(1, n));
  return peak + 0.05F * frac_sane;
}

bool PickRawChannelOrder(const float* pred, int n, int nc, int reg_max, int imgsz, RawChannelOrder cfg,
                         bool& cls_first_out) {
  if (cfg == RawChannelOrder::BoxFirst) {
    cls_first_out = false;
    return true;
  }
  if (cfg == RawChannelOrder::ClsFirst) {
    cls_first_out = true;
    return true;
  }
  const float q_bf = LayoutScoreRawDfl(pred, n, nc, reg_max, imgsz, true);
  const float q_cf = LayoutScoreRawDfl(pred, n, nc, reg_max, imgsz, false);
  cls_first_out = (q_cf > q_bf + 1e-6F);
  if (cls_first_out) {
    std::vector<float> box_raw;
    std::vector<float> cls_raw;
    SplitRawDflChannels(pred, n, nc, reg_max, true, box_raw, cls_raw);
    int hi = 0;
    for (int i = 0; i < n; ++i) {
      float mx = 0.0F;
      for (int c = 0; c < nc; ++c) {
        const float p = Sigmoid(cls_raw[static_cast<std::size_t>(i) * static_cast<std::size_t>(nc) +
                                              static_cast<std::size_t>(c)]);
        mx = std::max(mx, p);
      }
      if (mx >= 0.65F) {
        ++hi;
      }
    }
    const float frac_hi = static_cast<float>(hi) / static_cast<float>(std::max(1, n));
    if (frac_hi > 0.05F) {
      cls_first_out = false;
    }
  }
  return true;
}

bool DecodeRawHeadToXywh(const float* pred, int n, int nc, int reg_max, int imgsz, RawChannelOrder order,
                         std::vector<float>& xywh_px, std::vector<float>& cls_raw, std::string& err) {
  const int box_ch = 4 * reg_max;
  const int C = box_ch + nc;
  (void)C;
  bool cls_first = false;
  if (!PickRawChannelOrder(pred, n, nc, reg_max, imgsz, order, cls_first)) {
    err = "raw channel order";
    return false;
  }
  std::vector<float> box_raw;
  SplitRawDflChannels(pred, n, nc, reg_max, cls_first, box_raw, cls_raw);
  std::vector<float> dist;
  DflIntegral(box_raw.data(), n, reg_max, dist);
  std::vector<float> anchors_xy, strides;
  BuildAnchorsAndStrides(imgsz, n, anchors_xy, strides);
  if (static_cast<int>(strides.size()) != n) {
    err = "anchor count mismatch; check input_imgsz vs export (P2/P3/P4 expect 33600 anchors at 640)";
    return false;
  }
  std::vector<float> xywh_unit;
  Dist2bboxXywh(dist.data(), n, anchors_xy.data(), xywh_unit);
  xywh_px.resize(static_cast<std::size_t>(n) * 4U);
  for (int i = 0; i < n; ++i) {
    const float st = strides[static_cast<std::size_t>(i)];
    for (int k = 0; k < 4; ++k) {
      xywh_px[static_cast<std::size_t>(i) * 4U + k] = xywh_unit[static_cast<std::size_t>(i) * 4U + k] * st;
    }
  }
  return true;
}

bool ClassChannelsLookLikeProbabilities(const float* cls_raw, int n, int nc) {
  if (n <= 0 || nc <= 0) {
    return false;
  }
  float mn = cls_raw[0];
  float mx = cls_raw[0];
  for (int i = 0; i < n; ++i) {
    for (int c = 0; c < nc; ++c) {
      const float v = cls_raw[static_cast<std::size_t>(i) * nc + c];
      mn = std::min(mn, v);
      mx = std::max(mx, v);
    }
  }
  return mn >= -kClsProbEps && mx <= 1.0F + 1e-3F;
}

void InferClassScores(const float* cls_raw, int n, int nc, bool logits_mode, const DetPostConfig& cfg,
                      std::vector<float>& cls_scores) {
  cls_scores.resize(static_cast<std::size_t>(n) * nc);
  if (!logits_mode) {
    for (std::size_t i = 0; i < cls_scores.size(); ++i) {
      cls_scores[i] = cls_raw[i];
    }
    return;
  }
  if (ClassChannelsLookLikeProbabilities(cls_raw, n, nc)) {
    if (cfg.on_class_prob_hint) {
      cfg.on_class_prob_hint(
          "[det_postprocess] class channels in [0,1]; skipping second sigmoid (matches Python reference).");
    }
    for (std::size_t i = 0; i < cls_scores.size(); ++i) {
      cls_scores[i] = cls_raw[i];
    }
    return;
  }
  for (std::size_t i = 0; i < cls_scores.size(); ++i) {
    cls_scores[i] = Sigmoid(cls_raw[i]);
  }
}

std::string CheckDegenerateCls(const float* cls_raw, int n, int nc, bool logits_mode) {
  if (n <= 0 || nc <= 0) {
    return {};
  }
  float mx = 0.0F;
  double sum_abs = 0.0;
  for (int i = 0; i < n; ++i) {
    for (int c = 0; c < nc; ++c) {
      const float v = std::fabs(cls_raw[static_cast<std::size_t>(i) * nc + c]);
      mx = std::max(mx, v);
      sum_abs += static_cast<double>(v);
    }
  }
  const double mean_abs = sum_abs / static_cast<double>(n * nc);
  if (logits_mode && mx < 1e-3F && mean_abs < 1e-4) {
    return "class logits degenerate (~0); wrong layout or use --score-mode probabilities if ONNX already sigmoid";
  }
  return {};
}

std::string CheckFlatHalfScores(const float* scores, int n, bool logits_mode) {
  if (!logits_mode || n < 100 || n <= 0) {
    return {};
  }
  double s = 0.0;
  for (int i = 0; i < n; ++i) {
    s += static_cast<double>(scores[i]);
  }
  const double sm = s / static_cast<double>(n);
  double v = 0.0;
  for (int i = 0; i < n; ++i) {
    const double d = static_cast<double>(scores[i]) - sm;
    v += d * d;
  }
  const double sd = std::sqrt(v / static_cast<double>(n));
  if (sm > 0.498 && sm < 0.502 && sd < 5e-4) {
    return "best class scores flat ~0.5 with logits mode; wrong layout or double-sigmoid";
  }
  return {};
}

DetPostResult PostprocessDetEnd2EndK6(const float* k6_rowmajor, int K, const DetPostConfig& cfg, const LetterboxInfo& lb) {
  DetPostResult out;
  std::vector<float> xyxy;
  std::vector<float> scores;
  std::vector<int> cls_ids;
  std::vector<int> keep_idx;
  for (int i = 0; i < K; ++i) {
    const float* row = k6_rowmajor + static_cast<std::size_t>(i) * 6U;
    const float x1 = row[0];
    const float y1 = row[1];
    const float x2 = row[2];
    const float y2 = row[3];
    const float sc = row[4];
    const int cid = static_cast<int>(std::lround(static_cast<double>(row[5])));
    if (sc >= cfg.conf && x2 > x1 && y2 > y1) {
      keep_idx.push_back(i);
      xyxy.push_back(x1);
      xyxy.push_back(y1);
      xyxy.push_back(x2);
      xyxy.push_back(y2);
      scores.push_back(sc);
      cls_ids.push_back(cid);
    }
  }
  const int M = static_cast<int>(keep_idx.size());
  if (M == 0) {
    out.ok = true;
    return out;
  }
  for (int j = 0; j < M; ++j) {
    float& x1 = xyxy[static_cast<std::size_t>(j) * 4U];
    float& y1 = xyxy[static_cast<std::size_t>(j) * 4U + 1];
    float& x2 = xyxy[static_cast<std::size_t>(j) * 4U + 2];
    float& y2 = xyxy[static_cast<std::size_t>(j) * 4U + 3];
    RemapClipRoundXyxy(x1, y1, x2, y2, lb, cfg.box_round_policy);
  }
  std::vector<int> post(M);
  for (int j = 0; j < M; ++j) {
    post[static_cast<std::size_t>(j)] = j;
  }
  if (cfg.iou > 0.0F && M > 1) {
    std::map<int, std::vector<int>> by_cls;
    for (int j = 0; j < M; ++j) {
      by_cls[cls_ids[static_cast<std::size_t>(j)]].push_back(j);
    }
    std::vector<int> merged;
    for (auto& kv : by_cls) {
      auto& idx = kv.second;
      std::sort(idx.begin(), idx.end(), [&](int a, int b) { return scores[static_cast<std::size_t>(a)] > scores[static_cast<std::size_t>(b)]; });
      std::vector<int> nms_keep;
      for (int iid : idx) {
        bool ok = true;
        const float ax1 = xyxy[static_cast<std::size_t>(iid) * 4U];
        const float ay1 = xyxy[static_cast<std::size_t>(iid) * 4U + 1];
        const float ax2 = xyxy[static_cast<std::size_t>(iid) * 4U + 2];
        const float ay2 = xyxy[static_cast<std::size_t>(iid) * 4U + 3];
        for (int j : nms_keep) {
          const float iou = IouXyxy(ax1, ay1, ax2, ay2, xyxy[static_cast<std::size_t>(j) * 4U],
                                     xyxy[static_cast<std::size_t>(j) * 4U + 1], xyxy[static_cast<std::size_t>(j) * 4U + 2],
                                     xyxy[static_cast<std::size_t>(j) * 4U + 3]);
          if (iou > cfg.iou) {
            ok = false;
            break;
          }
        }
        if (ok) {
          nms_keep.push_back(iid);
        }
      }
      merged.insert(merged.end(), nms_keep.begin(), nms_keep.end());
    }
    post.swap(merged);
  }
  std::sort(post.begin(), post.end(), [&](int a, int b) { return scores[static_cast<std::size_t>(a)] > scores[static_cast<std::size_t>(b)]; });
  if (cfg.max_det > 0 && static_cast<int>(post.size()) > cfg.max_det) {
    post.resize(static_cast<std::size_t>(cfg.max_det));
  }
  out.ok = true;
  for (int j : post) {
    DetBox b;
    b.class_id = cls_ids[static_cast<std::size_t>(j)];
    b.x1 = xyxy[static_cast<std::size_t>(j) * 4U];
    b.y1 = xyxy[static_cast<std::size_t>(j) * 4U + 1];
    b.x2 = xyxy[static_cast<std::size_t>(j) * 4U + 2];
    b.y2 = xyxy[static_cast<std::size_t>(j) * 4U + 3];
    b.score = scores[static_cast<std::size_t>(j)];
    out.boxes.push_back(b);
  }
  return out;
}

}  // namespace internal
}  // namespace det_postprocess
