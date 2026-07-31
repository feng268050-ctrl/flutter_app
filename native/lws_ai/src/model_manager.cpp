#include "model_manager.h"
#include "det_raw_concat.h"
#include "embedded_models.h"
#include "rknn_runner.h"
#include "stain_preprocess.h"
#include "yolo_postprocess.hpp"
#include <opencv2/imgproc.hpp>
#include <cstdio>
#include <algorithm>
#include <cstdint>
#include <cmath>
#include <limits>
#include <vector>
#include <atomic>
#include <chrono>
#include <cstdlib>

#ifdef __ANDROID__
#include <android/log.h>
#define MODEL_LOGI(...) __android_log_print(ANDROID_LOG_INFO, "LensGuardModel", __VA_ARGS__)
#else
#define MODEL_LOGI(...) std::printf(__VA_ARGS__)
#endif

namespace {
constexpr int kStainRoiX = stain_preprocess::kRoiX;
constexpr int kStainRoiY = stain_preprocess::kRoiY;
constexpr int kStainRoiSize = stain_preprocess::kRoiSize;
}  // namespace

#if defined(LENS_YOLO_PP_DIAG) && LENS_YOLO_PP_DIAG
#ifdef __ANDROID__
#define YOLO_PP_DIAG_LOG_MGR(...) __android_log_print(ANDROID_LOG_INFO, "YOLO_PP_DIAG", __VA_ARGS__)
#else
#define YOLO_PP_DIAG_LOG_MGR(...) std::fprintf(stderr, __VA_ARGS__)
#endif
#endif

namespace {

int infer_yolo_feature_count(int dim0, int dim1) {
    if (dim0 >= 5 && (dim0 <= dim1 || dim1 < 5))
        return dim0;
    if (dim1 >= 5)
        return dim1;
    return 0;
}

bool is_stain_logits_mode(const AlgorithmConfig& cfg) {
    const std::string& mode = cfg.stain_score_mode;
    return mode != "probabilities";
}

void log_class_prob_hint_once(const char* msg) {
    static std::atomic<bool> logged{false};
    bool expected = false;
    if (logged.compare_exchange_strong(expected, true) && msg && msg[0]) {
        MODEL_LOGI("%s", msg);
    }
}

#if defined(LENS_YOLO_PP_DIAG) && LENS_YOLO_PP_DIAG
static std::atomic<int> g_stain_diag_frames{0};

static int stain_diag_interval_frames() {
    const char* env = std::getenv("LENS_STAIN_DIAG_INTERVAL_FRAMES");
    if (!env || !*env) {
        return 300;
    }
    return std::max(1, std::atoi(env));
}

static bool should_emit_stain_diag() {
    const int n = ++g_stain_diag_frames;
    if (n == 1) {
        return true;
    }
    const int interval = stain_diag_interval_frames();
    return (n % interval) == 0;
}
#endif

static void warn_high_candidate_count_once(int n_candidates) {
    static std::atomic<bool> warned{false};
    if (n_candidates <= 500) {
        return;
    }
    bool expected = false;
    if (warned.compare_exchange_strong(expected, true)) {
        MODEL_LOGI("[ModelManager] stain det candidates=%d (>500); check stain_score_mode/conf_thresh", n_candidates);
    }
}

float pct_from_sorted(const std::vector<float>& sorted, double q) {
    if (sorted.empty()) return 0.0f;
    if (sorted.size() == 1U) return sorted[0];
    const double x = (static_cast<double>(sorted.size() - 1U) * q);
    const std::size_t i = static_cast<std::size_t>(x);
    const std::size_t j = (i + 1U < sorted.size()) ? (i + 1U) : i;
    const double t = x - static_cast<double>(i);
    return static_cast<float>(static_cast<double>(sorted[i]) * (1.0 - t) + static_cast<double>(sorted[j]) * t);
}

#if defined(LENS_YOLO_PP_DIAG) && LENS_YOLO_PP_DIAG
void log_stain_output_stats_before_postprocess(const float* data,
                                               int dim0,
                                               int dim1,
                                               int num_features,
                                               const std::vector<rknn_tensor_attr>& out_attrs) {
    if (!data || dim0 <= 0 || dim1 <= 0 || num_features < 5) return;
    const int n_candidates = (dim0 == num_features) ? dim1 : dim0;
    const bool feature_first = (dim0 == num_features);
    const int n_classes = num_features - 4;
    if (n_candidates <= 0 || n_classes <= 0) return;

    auto get_feat = [data, n_candidates, num_features, feature_first](int n, int f) -> float {
        if (feature_first) {
            return data[static_cast<std::size_t>(f) * static_cast<std::size_t>(n_candidates) + static_cast<std::size_t>(n)];
        }
        return data[static_cast<std::size_t>(n) * static_cast<std::size_t>(num_features) + static_cast<std::size_t>(f)];
    };

    std::vector<float> best_raw;
    std::vector<float> best_sigmoid;
    best_raw.reserve(static_cast<std::size_t>(n_candidates));
    best_sigmoid.reserve(static_cast<std::size_t>(n_candidates));

    for (int n = 0; n < n_candidates; ++n) {
        float br = -std::numeric_limits<float>::infinity();
        for (int c = 0; c < n_classes; ++c) {
            const float v = get_feat(n, 4 + c);
            if (v > br) br = v;
        }
        float bs = 1.0f / (1.0f + std::exp(-std::max(-60.0f, std::min(br, 60.0f))));
        best_raw.push_back(br);
        best_sigmoid.push_back(bs);
    }

    std::sort(best_raw.begin(), best_raw.end());
    std::sort(best_sigmoid.begin(), best_sigmoid.end());

    const float raw_min = best_raw.front();
    const float raw_p50 = pct_from_sorted(best_raw, 0.5);
    const float raw_p90 = pct_from_sorted(best_raw, 0.9);
    const float raw_max = best_raw.back();
    const float sig_min = best_sigmoid.front();
    const float sig_p50 = pct_from_sorted(best_sigmoid, 0.5);
    const float sig_p90 = pct_from_sorted(best_sigmoid, 0.9);
    const float sig_max = best_sigmoid.back();

    int qnt_type = -1;
    int zp = 0;
    float scale = 0.0f;
    if (!out_attrs.empty()) {
        qnt_type = static_cast<int>(out_attrs[0].qnt_type);
        zp = out_attrs[0].zp;
        scale = out_attrs[0].scale;
    }

    // YOLOv8 style output is usually [4+nc, N] without explicit obj channel.
    MODEL_LOGI("[YOLO_PP_DIAG] class_raw min=%.6f p50=%.6f p90=%.6f max=%.6f", raw_min, raw_p50, raw_p90, raw_max);
    MODEL_LOGI("[YOLO_PP_DIAG] class_sigmoid min=%.6f p50=%.6f p90=%.6f max=%.6f", sig_min, sig_p50, sig_p90, sig_max);
    MODEL_LOGI("[YOLO_PP_DIAG] obj_raw n/a (layout has no dedicated obj channel)");
    MODEL_LOGI("[YOLO_PP_DIAG] output_attr qnt_type=%d scale=%.8f zp=%d", qnt_type, scale, zp);
}
#endif

#if defined(LENS_YOLO_PP_DIAG) && LENS_YOLO_PP_DIAG
/** Same tensor: C_N index = f*n_cand+n vs N_C index = n*num_features+f (class f in [4, num_features)). */
void log_yolo_layout_dual_read(const float* data,
                               int n_cand,
                               int num_features,
                               int n_classes,
                               int det_out_idx) {
    if (!data || n_cand <= 0 || n_classes <= 0 || num_features < 5) {
        return;
    }
    const size_t total = static_cast<size_t>(n_cand) * static_cast<size_t>(n_classes);
    std::vector<float> cn;
    std::vector<float> nc;
    cn.reserve(total);
    nc.reserve(total);
    for (int n = 0; n < n_cand; ++n) {
        for (int ci = 0; ci < n_classes; ++ci) {
            const int f = 4 + ci;
            cn.push_back(data[static_cast<size_t>(f) * static_cast<size_t>(n_cand) +
                              static_cast<size_t>(n)]);
            nc.push_back(data[static_cast<size_t>(n) * static_cast<size_t>(num_features) +
                              static_cast<size_t>(f)]);
        }
    }
    std::sort(cn.begin(), cn.end());
    std::sort(nc.begin(), nc.end());
    const float cn_min = cn.front();
    const float cn_p50 = pct_from_sorted(cn, 0.5);
    const float cn_max = cn.back();
    const float nc_min = nc.front();
    const float nc_p50 = pct_from_sorted(nc, 0.5);
    const float nc_max = nc.back();
    YOLO_PP_DIAG_LOG_MGR(
        "[YOLO_PP_DIAG] layout_dual_read det_out_idx=%d C_N(f*n_cand+anchor) n_cand=%d num_features=%d "
        "class_logits min=%.6f p50=%.6f max=%.6f",
        det_out_idx,
        n_cand,
        num_features,
        cn_min,
        cn_p50,
        cn_max);
    YOLO_PP_DIAG_LOG_MGR(
        "[YOLO_PP_DIAG] layout_dual_read det_out_idx=%d N_C(anchor*num_features+class_ch) n_cand=%d "
        "num_features=%d class_logits min=%.6f p50=%.6f max=%.6f",
        det_out_idx,
        n_cand,
        num_features,
        nc_min,
        nc_p50,
        nc_max);
}
#endif

std::vector<Detection> to_detections(const yolo_postprocess::DetResult& result) {
    std::vector<Detection> out;
    out.reserve(result.boxes.size());
    for (const auto& b : result.boxes) {
        out.push_back({b.x1, b.y1, b.x2, b.y2, b.score, b.class_id});
    }
    return out;
}

} // namespace

ModelManager::ModelManager(const AppConfig& cfg)
    : cfg_(cfg)
    , det_enabled_(cfg.models.det_enabled) {
    if (det_enabled_) {
        MODEL_LOGI("modelPath=%s", "<embedded:det.rknn>");
        MODEL_LOGI("model exists=%d size=%ld",
                   rknn_stain_det_model_data() != nullptr,
                   static_cast<long>(rknn_stain_det_model_size()));
        MODEL_LOGI("before load model file");
        stain_runner_ = std::make_unique<RKNNRunner>(
            rknn_stain_det_model_data(), rknn_stain_det_model_size(), RKNN_NPU_CORE_0, cfg_.algorithm.use_rknn_io_mem);
        MODEL_LOGI("after load model file, buffer=%p size=%zu",
                   static_cast<const void*>(rknn_stain_det_model_data()),
                   static_cast<size_t>(rknn_stain_det_model_size()));
    } else {
        MODEL_LOGI("det model slot disabled (models.det.enabled=false)");
    }
#if defined(LENS_YOLO_PP_DIAG) && LENS_YOLO_PP_DIAG
    if (stain_runner_) {
        stain_runner_->log_output_attrs_yolo_pp_diag("det");
    }
#endif
}

ModelManager::~ModelManager() = default;

std::vector<Detection>
ModelManager::infer_stain(const cv::Mat& img_bgr) {
    if (!det_enabled_ || !stain_runner_) {
        return {};
    }

    const int orig_h = img_bgr.rows;
    const int orig_w = img_bgr.cols;
    const int kStainDetInputSide = cfg_.algorithm.stain_input_size[0];
    const int kStainDetInputH = cfg_.algorithm.stain_input_size[1];
    if (kStainDetInputSide < 1 || kStainDetInputSide != kStainDetInputH) {
        std::fprintf(stderr,
                     "[ModelManager] infer_stain: stain_input_size must be square [N,N], got [%d,%d]\n",
                     kStainDetInputSide,
                     kStainDetInputH);
        return {};
    }

    if (orig_w < kStainRoiX + kStainRoiSize || orig_h < kStainRoiY + kStainRoiSize) {
        std::fprintf(stderr,
                     "[ModelManager] infer_stain: input %dx%d smaller than fixed ROI %d,%d %dx%d\n",
                     orig_w,
                     orig_h,
                     kStainRoiX,
                     kStainRoiY,
                     kStainRoiSize,
                     kStainRoiSize);
        return {};
    }

    const int crop_x0 = kStainRoiX;
    const int crop_y0 = kStainRoiY;
    yolo_postprocess::StainDetRoiRestore roi_restore{};
    roi_restore.active = true;
    roi_restore.crop_x0 = crop_x0;
    roi_restore.crop_y0 = crop_y0;
    roi_restore.crop_s = kStainRoiSize;
    roi_restore.full_w = orig_w;
    roi_restore.full_h = orig_h;

    stain_preprocess::Output prep;
    std::string prep_err;
#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
    const auto t_infer0 = std::chrono::steady_clock::now();
#endif
    if (!stain_preprocess::PreprocessRoiResize(img_bgr, kStainDetInputSide, prep, prep_err)) {
        std::fprintf(stderr, "[ModelManager] preprocess failed: %s\n", prep_err.c_str());
        return {};
    }
#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
    const auto t_after_pre = std::chrono::steady_clock::now();
#endif

#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
    std::vector<float> rknn_run_ms;
    RKNNRunner::InferencePhases rknn_phases{};
    const auto t_rknn0 = std::chrono::steady_clock::now();
    auto outputs = stain_runner_->inference(prep.rgb_u8.data,
                                            static_cast<uint32_t>(prep.rgb_u8.total() * prep.rgb_u8.elemSize()),
                                            1,
                                            &rknn_run_ms,
                                            &rknn_phases);
    const auto t_after_rknn = std::chrono::steady_clock::now();
#else
    auto outputs = stain_runner_->inference(prep.rgb_u8.data,
                                            static_cast<uint32_t>(prep.rgb_u8.total() * prep.rgb_u8.elemSize()));
#endif
#if defined(LENS_YOLO_PP_DIAG) && LENS_YOLO_PP_DIAG
    stain_runner_->log_output_buffers_yolo_pp_diag("det");
#endif

    std::vector<float> merged_raw;
    const float* det_ptr = nullptr;
    int dim0 = 1;
    int dim1 = 1;

#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
    const auto t_parse0 = std::chrono::steady_clock::now();
    auto t_concat0 = t_parse0;
#endif
    if (outputs.size() == 3U) {
#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
        t_concat0 = std::chrono::steady_clock::now();
#endif
        if (rknn_det_raw::ConcatDetRawP2P3P4(outputs, merged_raw, dim0, dim1)) {
            det_ptr = merged_raw.data();
        }
    } else if (outputs.size() == 1U) {
        const auto& o = outputs[0];
        if (o.n_dims == 3U) {
            dim0 = static_cast<int>(o.shape[1]);
            dim1 = static_cast<int>(o.shape[2]);
            det_ptr = o.data.data();
        } else if (o.n_dims == 2U) {
            dim0 = static_cast<int>(o.shape[0]);
            dim1 = static_cast<int>(o.shape[1]);
            det_ptr = o.data.data();
        } else {
            std::fprintf(stderr, "[ModelManager] unsupported det output dims: %u\n", o.n_dims);
            return {};
        }
    } else {
        std::fprintf(stderr,
                     "[ModelManager] expected 1 decoded det output or 3 raw P2/P3/P4 outputs, got %zu\n",
                     outputs.size());
        return {};
    }

    if (det_ptr == nullptr) {
        return {};
    }

    const int num_features = infer_yolo_feature_count(dim0, dim1);
    if (num_features < 5) {
        std::fprintf(stderr, "[ModelManager] invalid det output shape: [%d, %d]\n", dim0, dim1);
        return {};
    }
    const int n_candidates = (dim0 == num_features) ? dim1 : dim0;
    warn_high_candidate_count_once(n_candidates);

#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
    const auto t_parse1 = std::chrono::steady_clock::now();
#endif

#if defined(LENS_YOLO_PP_DIAG) && LENS_YOLO_PP_DIAG
    if (should_emit_stain_diag()) {
        log_stain_output_stats_before_postprocess(det_ptr, dim0, dim1, num_features, stain_runner_->output_attrs());
    }
#endif

    yolo_postprocess::DetConfig det_cfg;
    // auto: nf=65 -> raw DFL (det_raw_head); nf=5 -> decoded. stain_score_mode: logits for raw head.
    det_cfg.num_classes = 0;
    det_cfg.raw_channel_order = yolo_postprocess::DetConfig::RawChannelOrder::BoxFirst;
    det_cfg.conf_threshold = cfg_.algorithm.stain_conf_thresh;
    det_cfg.iou_threshold = cfg_.algorithm.stain_nms_thresh;
    det_cfg.max_det = cfg_.algorithm.stain_max_det;
    det_cfg.input_imgsz = kStainDetInputSide;
    det_cfg.class_scores_are_logits = is_stain_logits_mode(cfg_.algorithm);
    det_cfg.on_class_prob_hint = [](const char* msg) { log_class_prob_hint_once(msg); };
#if defined(LENS_YOLO_PP_DIAG) && LENS_YOLO_PP_DIAG
    if (should_emit_stain_diag()) {
        MODEL_LOGI("[YOLO_PP_DIAG] model_manager score_mode=%s conf_thresh=%.3f nms_iou=%.3f max_det=%d dims=[%d,%d]",
                   det_cfg.class_scores_are_logits ? "logits" : "probabilities",
                   det_cfg.conf_threshold, det_cfg.iou_threshold, det_cfg.max_det, dim0, dim1);
        log_yolo_layout_dual_read(det_ptr,
                                  n_candidates,
                                  num_features,
                                  num_features - 4,
                                  /*det_out_idx=*/0);
    }
#endif

    const yolo_postprocess::LetterboxInfo ylb{
        1.0f, 0, 0, kStainDetInputSide, kStainDetInputSide};
#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
    const auto t_post0 = t_parse1;
#endif
    auto det = yolo_postprocess::postprocess_det(det_ptr, dim0, dim1, det_cfg, ylb, &roi_restore);
#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
    const auto t_infer1 = std::chrono::steady_clock::now();
    const auto ms = [](const auto& a, const auto& b) {
        return std::chrono::duration<float, std::milli>(b - a).count();
    };
    const float pre_ms = ms(t_infer0, t_after_pre);
    const float rknn_run_only_ms = rknn_phases.rknn_run_ms;
    const float input_copy_ms = rknn_phases.input_copy_ms;
    const float outputs_get_ms = rknn_phases.outputs_get_ms;
    const float parse_ms = ms(t_parse0, t_concat0);
    const float concat_ms = ms(t_concat0, t_parse1);
    const float post_det_ms = ms(t_post0, t_infer1);
    const float post_ms = ms(t_after_rknn, t_infer1);
    const float total_ms = ms(t_infer0, t_infer1);
    MODEL_LOGI(
        "[infer_stain][timing] pre=%.2f input_copy=%.2f rknn_run=%.2f outputs_get=%.2f "
        "parse=%.2f concat=%.2f post_det=%.2f post=%.2f total=%.2f boxes=%zu "
        "(see DetPostprocess [det_postprocess][timing] for DFL/score/thresh/nms)\n",
        pre_ms,
        input_copy_ms,
        rknn_run_only_ms,
        outputs_get_ms,
        parse_ms,
        concat_ms,
        post_det_ms,
        post_ms,
        total_ms,
        det.ok ? det.boxes.size() : 0U);
#endif
    if (!det.ok) {
        std::fprintf(stderr, "[ModelManager] det postprocess failed: %s\n", det.error.c_str());
        return {};
    }
    return to_detections(det);
}

void ModelManager::release() {
    stain_runner_.reset();
}
