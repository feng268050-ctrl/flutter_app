#include "roi_config.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <fstream>
#include <sstream>
#include <stdexcept>

namespace zero_point {
namespace {

std::string readFile(const std::string& path) {
    std::ifstream in(path);
    if (!in) {
        throw std::runtime_error("failed to read roi json: " + path);
    }
    std::ostringstream buffer;
    buffer << in.rdbuf();
    return buffer.str();
}

std::size_t findKey(const std::string& json, const std::string& key) {
    const std::string quoted = "\"" + key + "\"";
    return json.find(quoted);
}

bool parseIntArrayAfterKey(const std::string& json, const std::string& key, int* out, int count) {
    const std::size_t key_pos = findKey(json, key);
    if (key_pos == std::string::npos) {
        return false;
    }
    const std::size_t bracket = json.find('[', key_pos);
    if (bracket == std::string::npos) {
        return false;
    }
    std::size_t pos = bracket + 1;
    for (int i = 0; i < count; ++i) {
        while (pos < json.size() && (json[pos] == ' ' || json[pos] == '\n' || json[pos] == '\r')) {
            ++pos;
        }
        std::size_t end = pos;
        while (end < json.size() && json[end] != ',' && json[end] != ']') {
            ++end;
        }
        if (pos >= end) {
            return false;
        }
        try {
            out[i] = static_cast<int>(std::lround(std::stod(json.substr(pos, end - pos))));
        } catch (...) {
            return false;
        }
        pos = end + 1;
    }
    return true;
}

bool parseDoubleArrayAfterKey(const std::string& json, const std::string& key, double* out, int count) {
    const std::size_t key_pos = findKey(json, key);
    if (key_pos == std::string::npos) {
        return false;
    }
    const std::size_t bracket = json.find('[', key_pos);
    if (bracket == std::string::npos) {
        return false;
    }
    std::size_t pos = bracket + 1;
    for (int i = 0; i < count; ++i) {
        while (pos < json.size() && (json[pos] == ' ' || json[pos] == '\n' || json[pos] == '\r')) {
            ++pos;
        }
        std::size_t end = pos;
        while (end < json.size() && json[end] != ',' && json[end] != ']') {
            ++end;
        }
        if (pos >= end) {
            return false;
        }
        try {
            out[i] = std::stod(json.substr(pos, end - pos));
        } catch (...) {
            return false;
        }
        pos = end + 1;
    }
    return true;
}

Box expandCenterBox(const Box& box, int margin_px, int frame_width, int frame_height) {
    if (margin_px <= 0) {
        return box;
    }
    const int x1 = std::max(0, box.x - margin_px);
    const int y1 = std::max(0, box.y - margin_px);
    const int x2 = std::min(frame_width, box.x + box.w + margin_px);
    const int y2 = std::min(frame_height, box.y + box.h + margin_px);
    return Box{x1, y1, x2 - x1, y2 - y1};
}

}  // namespace

Box scaleBoxToFrame(const Box& box,
                    int source_width,
                    int source_height,
                    int frame_width,
                    int frame_height) {
    if (source_width <= 0 || source_height <= 0 ||
        (source_width == frame_width && source_height == frame_height)) {
        return box;
    }
    const double sx = static_cast<double>(frame_width) / static_cast<double>(source_width);
    const double sy = static_cast<double>(frame_height) / static_cast<double>(source_height);
    return Box{
        static_cast<int>(std::lround(box.x * sx)),
        static_cast<int>(std::lround(box.y * sy)),
        static_cast<int>(std::lround(box.w * sx)),
        static_cast<int>(std::lround(box.h * sy)),
    };
}

std::optional<Point2d> scaleReferenceZero(const Point2d& ref,
                                          int source_width,
                                          int source_height,
                                          int frame_width,
                                          int frame_height) {
    if (source_width <= 0 || source_height <= 0 ||
        (source_width == frame_width && source_height == frame_height)) {
        return ref;
    }
    const double sx = static_cast<double>(frame_width) / static_cast<double>(source_width);
    const double sy = static_cast<double>(frame_height) / static_cast<double>(source_height);
    return Point2d{ref.x * sx, ref.y * sy};
}

RoiConfig loadRoiConfig(const std::string& roi_json_path, int frame_width, int frame_height) {
    const std::string json = readFile(roi_json_path);

    int box_vals[4] = {0, 0, 0, 0};
    bool has_box = parseIntArrayAfterKey(json, "box_xywh", box_vals, 4);
    if (!has_box) {
        has_box = parseIntArrayAfterKey(json, "yellow_box_xywh", box_vals, 4);
    }
    int expand_px = 0;
    if (!has_box) {
        int base_vals[4] = {0, 0, 0, 0};
        if (parseIntArrayAfterKey(json, "box_xywh_base", base_vals, 4)) {
            const std::size_t expand_key = findKey(json, "center_box_expand_px");
            if (expand_key != std::string::npos) {
                const std::size_t colon = json.find(':', expand_key);
                if (colon != std::string::npos) {
                    try {
                        expand_px = static_cast<int>(std::lround(std::stod(json.substr(colon + 1))));
                    } catch (...) {
                        expand_px = 0;
                    }
                }
            }
            box_vals[0] = base_vals[0];
            box_vals[1] = base_vals[1];
            box_vals[2] = base_vals[2];
            box_vals[3] = base_vals[3];
            has_box = true;
        }
    }

    if (!has_box) {
        throw std::runtime_error("roi json missing box_xywh: " + roi_json_path);
    }

    int source_size[2] = {0, 0};
    const bool has_source = parseIntArrayAfterKey(json, "source_size", source_size, 2);

    Box box{box_vals[0], box_vals[1], box_vals[2], box_vals[3]};
    if (has_source) {
        box = scaleBoxToFrame(box, source_size[0], source_size[1], frame_width, frame_height);
        if (expand_px > 0 && findKey(json, "box_xywh") == std::string::npos) {
            box = expandCenterBox(box, expand_px, frame_width, frame_height);
        }
    }

    RoiConfig config;
    config.center_box = box;
    config.fixed_center_xy = Point2d{
        box.x + box.w / 2.0,
        box.y + box.h / 2.0,
    };
    if (has_source) {
        config.source_width = source_size[0];
        config.source_height = source_size[1];
    }

    double ref_vals[2] = {0.0, 0.0};
    if (parseDoubleArrayAfterKey(json, "reference_zero_xy", ref_vals, 2)) {
        Point2d ref{ref_vals[0], ref_vals[1]};
        if (has_source) {
            config.reference_zero_xy = scaleReferenceZero(
                ref, source_size[0], source_size[1], frame_width, frame_height);
        } else {
            config.reference_zero_xy = ref;
        }
    }

    const std::size_t fixed_key = findKey(json, "fixed_center_xy");
    if (fixed_key != std::string::npos) {
        double fixed_vals[2] = {0.0, 0.0};
        if (parseDoubleArrayAfterKey(json, "fixed_center_xy", fixed_vals, 2)) {
            Point2d fixed{fixed_vals[0], fixed_vals[1]};
            if (has_source) {
                config.fixed_center_xy =
                    *scaleReferenceZero(fixed, source_size[0], source_size[1], frame_width, frame_height);
            } else {
                config.fixed_center_xy = fixed;
            }
        }
    }

    return config;
}

}  // namespace zero_point
