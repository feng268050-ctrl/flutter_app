// Simple self-checks (assert). Run: test_postprocess
#include "yolo_postprocess.hpp"

#include <cmath>
#include <cstdlib>
#include <iostream>

int main() {
  using yolo_postprocess::ClsConfig;
  using yolo_postprocess::DetConfig;
  using yolo_postprocess::DetResult;
  using yolo_postprocess::LetterboxInfo;
  using yolo_postprocess::postprocess_cls;
  using yolo_postprocess::postprocess_det;

  // --- 4.1 / 2.1: [C, N] layout, N=10, nc=1 -> C=5, d0=5, d1=10
  {
    const int n_candidates = 10;
    // [5,10] in row-major: index = f*N + n
    float d[5 * n_candidates] = {};
    d[0 * n_candidates + 0] = 10;    // n0
    d[1 * n_candidates + 0] = 10;
    d[2 * n_candidates + 0] = 5;     // w,h
    d[3 * n_candidates + 0] = 5;
    d[4 * n_candidates + 0] = 0.1F;  // conf

    d[0 * n_candidates + 1] = 100.0F;
    d[1 * n_candidates + 1] = 100.0F;
    d[2 * n_candidates + 1] = 20.0F;
    d[3 * n_candidates + 1] = 20.0F;
    d[4 * n_candidates + 1] = 0.9F;

    d[0 * n_candidates + 2] = 102.0F;
    d[1 * n_candidates + 2] = 100.0F;
    d[2 * n_candidates + 2] = 20.0F;
    d[3 * n_candidates + 2] = 20.0F;
    d[4 * n_candidates + 2] = 0.95F;

    DetConfig cfg;
    cfg.num_classes = 1;
    cfg.conf_threshold = 0.25F;
    cfg.iou_threshold = 0.45F;
    cfg.max_det = 100;
    LetterboxInfo lb{1.0F, 0, 0, 640, 480};
    DetResult r = postprocess_det(d, 5, n_candidates, cfg, lb, nullptr);
    if (!r.ok) {
      std::cerr << "det failed: " << r.error << "\n";
      return 1;
    }
    if (r.boxes.size() != 1U) {
      std::cerr << "expected 1 after NMS, got " << r.boxes.size() << "\n";
      return 1;
    }
  }
  // Training parity NMS iou=0.35, decoded [5,N] single-class
  {
    const int n_candidates = 10;
    float d[5 * n_candidates] = {};
    d[0 * n_candidates + 0] = 100.0F;
    d[1 * n_candidates + 0] = 100.0F;
    d[2 * n_candidates + 0] = 20.0F;
    d[3 * n_candidates + 0] = 20.0F;
    d[4 * n_candidates + 0] = 0.9F;
    d[0 * n_candidates + 1] = 102.0F;
    d[1 * n_candidates + 1] = 100.0F;
    d[2 * n_candidates + 1] = 20.0F;
    d[3 * n_candidates + 1] = 20.0F;
    d[4 * n_candidates + 1] = 0.95F;
    DetConfig cfg;
    cfg.num_classes = 1;
    cfg.conf_threshold = 0.25F;
    cfg.iou_threshold = 0.35F;
    cfg.class_scores_are_logits = false;
    LetterboxInfo lb{1.0F, 0, 0, 640, 480};
    DetResult r = postprocess_det(d, 5, n_candidates, cfg, lb, nullptr);
    if (!r.ok || r.boxes.size() != 1U) {
      std::cerr << "training parity NMS iou=0.35 mismatch\n";
      return 1;
    }
  }
  // [N, C] layout, N=10, nc=1 -> C=5, d0=10, d1=5
  {
    const int n_candidates = 10;
    float d[n_candidates * 5] = {};
    d[0 * 5 + 0] = 100.0F;
    d[0 * 5 + 1] = 100.0F;
    d[0 * 5 + 2] = 20.0F;
    d[0 * 5 + 3] = 20.0F;
    d[0 * 5 + 4] = 0.9F;
    d[1 * 5 + 0] = 102.0F;
    d[1 * 5 + 1] = 100.0F;
    d[1 * 5 + 2] = 20.0F;
    d[1 * 5 + 3] = 20.0F;
    d[1 * 5 + 4] = 0.95F;

    DetConfig cfg;
    cfg.num_classes = 1;
    cfg.conf_threshold = 0.25F;
    cfg.iou_threshold = 0.45F;
    LetterboxInfo lb{1.0F, 0, 0, 640, 480};
    DetResult r = postprocess_det(d, n_candidates, 5, cfg, lb, nullptr);
    if (!r.ok || r.boxes.size() != 1U) {
      std::cerr << "candidate-first layout mismatch\n";
      return 1;
    }
  }
  // Logit scores: sigmoid(0) = 0.5, sigmoid(-4) below threshold
  {
    float d[2 * 5] = {
        32.0F, 32.0F, 16.0F, 16.0F, -4.0F,
        48.0F, 48.0F, 16.0F, 16.0F, 0.0F,
    };
    DetConfig cfg;
    cfg.num_classes = 1;
    cfg.conf_threshold = 0.5F;
    cfg.class_scores_are_logits = true;
    LetterboxInfo lb{1.0F, 0, 0, 64, 64};
    DetResult r = postprocess_det(d, 2, 5, cfg, lb, nullptr);
    if (!r.ok || r.boxes.size() != 1U || std::abs(r.boxes[0].score - 0.5F) > 0.001F) {
      std::cerr << "logit score handling mismatch\n";
      return 1;
    }
  }
  // Cross-class overlap: two boxes same position, class 0 and 1 -> both keep
  {
    float d[2 * 6] = {};
    for (int n = 0; n < 2; ++n) {
      d[n * 6 + 0] = 32.0F;
      d[n * 6 + 1] = 32.0F;
      d[n * 6 + 2] = 32.0F;
      d[n * 6 + 3] = 32.0F;
    }
    d[0 * 6 + 4] = 0.9F;  // class 0
    d[0 * 6 + 5] = 0.1F;
    d[1 * 6 + 4] = 0.1F;  // class 1
    d[1 * 6 + 5] = 0.9F;
    DetConfig cfg;
    cfg.num_classes = 2;
    cfg.conf_threshold = 0.25F;
    cfg.iou_threshold = 0.1F;
    LetterboxInfo lb{1.0F, 0, 0, 64, 64};
    DetResult r = postprocess_det(d, 2, 6, cfg, lb, nullptr);
    if (r.boxes.size() != 2U) {
      std::cerr << "cross-class: expected 2, got " << r.boxes.size() << "\n";
      return 1;
    }
  }
  // Bad shape: [3, 100] -> neither dim is 4+2=6
  {
    float dummy[3 * 100] = {};
    DetConfig cfg;
    cfg.num_classes = 2;
    LetterboxInfo lb{1, 0, 0, 10, 10};
    DetResult r = postprocess_det(dummy, 3, 100, cfg, lb, nullptr);
    if (r.ok) {
      std::cerr << "expected failure for bad shape\n";
      return 1;
    }
  }
  // coordinate restore: scale 0.5, padding
  {
    // One box in letterbox space at (100,100) 20x20, scale=0.5, pad 10,10 -> in input 640 space before scale inverse?
    // Python: (x - pad) / scale. Model outputs in letterbox pixel coords. orig 300x200, letterbox 640, scale=min(640/200,640/300)=2.0?
    // Simpler: orig 100x100, model 640, scale=6.4, no pad, box at center 320, 320, 64x64 in 640x640
    // orig coords: (320-0)/6.4 = 50, width 64/6.4=10 -> 45-55 on 0..99
    float d[5] = {320, 320, 64, 64, 0.99F};
    DetConfig cfg;
    cfg.num_classes = 1;
    cfg.conf_threshold = 0.5F;
    LetterboxInfo lb{6.4F, 0, 0, 100, 100};
    DetResult r = postprocess_det(d, 1, 5, cfg, lb, nullptr);
    if (!r.ok) {
      std::cerr << "det restore: " << r.error << "\n";
      return 1;
    }
    if (r.boxes.empty() || std::abs(r.boxes[0].x1 - 45.0F) > 0.1F) {
      std::cerr << "restore math mismatch\n";
      return 1;
    }
  }

  // --- 3.x / 4.2: cls
  {
    const float logits[3] = {1.0F, 2.0F, 0.5F};
    ClsConfig ccfg;
    ccfg.topk = 2;
    auto cr = postprocess_cls(logits, 3, ccfg);
    if (!cr.ok || cr.top.size() != 2U) {
      std::cerr << "cls logits\n";
      return 1;
    }
  }
  {
    const float p[2] = {0.2F, 0.8F};
    auto cr = postprocess_cls(p, 2, ClsConfig{5, 0.01F});
    if (!cr.ok || cr.top[0].class_id != 1) {
      std::cerr << "cls prob\n";
      return 1;
    }
  }
  {
    const float p[2] = {0.2F, 0.8F};
    ClsConfig ccfg;
    ccfg.topk = 10;
    auto cr = postprocess_cls(p, 2, ccfg);
    if (!cr.ok || cr.top.size() != 2U) {
      std::cerr << "topk cap\n";
      return 1;
    }
  }

  std::cout << "all tests passed\n";
  return 0;
}
