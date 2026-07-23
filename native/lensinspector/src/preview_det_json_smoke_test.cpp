#include "det_callback_json.h"

#include <iostream>
#include <stdexcept>
#include <string>

static void require_contains(const std::string& haystack, const char* needle, const char* msg) {
    if (haystack.find(needle) == std::string::npos) {
        throw std::runtime_error(msg);
    }
}

int main() {
    ContaminationResult cr{2, "HEAVY", "立即更换 (mask 内检出)"};
    std::vector<Detection> dets;
    dets.push_back({100.0f, 200.0f, 150.0f, 250.0f, 0.88f, 0});

    const std::string json = build_preview_det_json(cr, dets, 100, dets.size(), 1920, 1080);
    require_contains(json, "\"code\":0", "missing code");
    require_contains(json, "\"source\":\"preview_det\"", "missing source");
    require_contains(json, "\"level\":2", "missing level");
    require_contains(json, "\"status\":\"HEAVY\"", "missing status");
    require_contains(json, "\"imageWidth\":1920", "missing imageWidth");
    require_contains(json, "\"imageHeight\":1080", "missing imageHeight");
    require_contains(json, "\"boxes\":[", "missing boxes array");
    require_contains(json, "\"x1\":100", "missing box x1");
    require_contains(json, "\"confidence\":0.88", "missing box confidence");
    require_contains(json, "\"maxConfidence\":0.88", "missing maxConfidence");

    const std::string offline = build_offline_infer_json(0, "", &cr, &dets, 100, dets.size(), 1280, 720, "offline_infer");
    require_contains(offline, "\"confidence\":0.88", "offline missing confidence");
    require_contains(offline, "\"source\":\"offline_infer\"", "offline missing source");
    require_contains(offline, "\"imageWidth\":1280", "offline missing imageWidth");

    std::vector<Detection> many(3);
    for (int i = 0; i < 3; ++i) {
        many[static_cast<std::size_t>(i)] = {static_cast<float>(i), 0, 10, 10, 0.5f, 0};
    }
    const std::size_t total_boxes = many.size();
    cap_detections(many, 2);
    const std::string capped = build_preview_det_json(cr, many, 2, total_boxes, 640, 480);
    require_contains(capped, "\"boxesTruncated\":true", "missing truncation flag");
    require_contains(capped, "\"boxesTotal\":3", "missing boxesTotal");

    std::cout << "preview_det_json_smoke_test passed\n";
    return 0;
}
