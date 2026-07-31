#include "yolo_postprocess.hpp"

#include <cstdlib>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace {

bool next_arg(int& i, int argc, char** argv, std::string& out) {
  if (i + 1 >= argc) return false;
  out = argv[++i];
  return true;
}

}  // namespace

int main(int argc, char** argv) {
  std::string tensor_path;
  std::string out_path;
  int d0 = 0, d1 = 0, num_classes = 0;
  int orig_w = 0, orig_h = 0, pad_w = 0, pad_h = 0;
  float scale = 0.0F, conf = 0.25F, iou = 0.45F;
  bool logits = false;

  for (int i = 1; i < argc; ++i) {
    std::string arg = argv[i];
    std::string val;
    if (arg == "--tensor" && next_arg(i, argc, argv, val)) tensor_path = val;
    else if (arg == "--out" && next_arg(i, argc, argv, val)) out_path = val;
    else if (arg == "--d0" && next_arg(i, argc, argv, val)) d0 = std::atoi(val.c_str());
    else if (arg == "--d1" && next_arg(i, argc, argv, val)) d1 = std::atoi(val.c_str());
    else if (arg == "--num-classes" && next_arg(i, argc, argv, val)) num_classes = std::atoi(val.c_str());
    else if (arg == "--orig-w" && next_arg(i, argc, argv, val)) orig_w = std::atoi(val.c_str());
    else if (arg == "--orig-h" && next_arg(i, argc, argv, val)) orig_h = std::atoi(val.c_str());
    else if (arg == "--scale" && next_arg(i, argc, argv, val)) scale = static_cast<float>(std::atof(val.c_str()));
    else if (arg == "--pad-w" && next_arg(i, argc, argv, val)) pad_w = std::atoi(val.c_str());
    else if (arg == "--pad-h" && next_arg(i, argc, argv, val)) pad_h = std::atoi(val.c_str());
    else if (arg == "--conf" && next_arg(i, argc, argv, val)) conf = static_cast<float>(std::atof(val.c_str()));
    else if (arg == "--iou" && next_arg(i, argc, argv, val)) iou = static_cast<float>(std::atof(val.c_str()));
    else if (arg == "--logits") logits = true;
  }

  if (tensor_path.empty() || out_path.empty() || d0 <= 0 || d1 <= 0 || num_classes <= 0 || orig_w <= 0 ||
      orig_h <= 0 || scale <= 0.0F) {
    std::cerr << "Usage: run_det_postprocess --tensor tensor.bin --out boxes.txt --d0 <int> --d1 <int> "
                 "--num-classes <int> --orig-w <int> --orig-h <int> --scale <float> --pad-w <int> --pad-h <int> "
                 "[--conf <float>] [--iou <float>] [--logits]\n";
    return 2;
  }

  const std::size_t n = static_cast<std::size_t>(d0) * static_cast<std::size_t>(d1);
  std::vector<float> data(n);
  {
    std::ifstream in(tensor_path, std::ios::binary);
    if (!in) {
      std::cerr << "Cannot open tensor file: " << tensor_path << "\n";
      return 3;
    }
    in.read(reinterpret_cast<char*>(data.data()), static_cast<std::streamsize>(n * sizeof(float)));
    if (in.gcount() != static_cast<std::streamsize>(n * sizeof(float))) {
      std::cerr << "Tensor file size mismatch for d0*d1 floats.\n";
      return 4;
    }
  }

  yolo_postprocess::DetConfig cfg;
  cfg.num_classes = num_classes;
  cfg.conf_threshold = conf;
  cfg.iou_threshold = iou;
  cfg.class_scores_are_logits = logits;

  yolo_postprocess::LetterboxInfo lb;
  lb.scale = scale;
  lb.pad_w = pad_w;
  lb.pad_h = pad_h;
  lb.orig_w = orig_w;
  lb.orig_h = orig_h;

  auto r = yolo_postprocess::postprocess_det(data.data(), d0, d1, cfg, lb, nullptr);
  if (!r.ok) {
    std::cerr << "postprocess failed: " << r.error << "\n";
    return 5;
  }

  std::ofstream out(out_path, std::ios::binary);
  if (!out) {
    std::cerr << "Cannot write output file: " << out_path << "\n";
    return 6;
  }

  for (const auto& b : r.boxes) {
    out << b.class_id << " " << b.x1 << " " << b.y1 << " " << b.x2 << " " << b.y2 << " " << b.score << "\n";
  }
  return 0;
}
