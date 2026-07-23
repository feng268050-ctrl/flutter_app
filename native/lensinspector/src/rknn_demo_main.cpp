#include "rknn_runner.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include <algorithm>
#include <cfloat>
#include <cstdio>
#include <cstdlib>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

const char* format_to_string(rknn_tensor_format fmt) {
    switch (fmt) {
    case RKNN_TENSOR_NCHW:
        return "NCHW";
    case RKNN_TENSOR_NHWC:
        return "NHWC";
    default:
        return "UNSPEC";
    }
}

const char* type_to_string(rknn_tensor_type type) {
    switch (type) {
    case RKNN_TENSOR_FLOAT32:
        return "FLOAT32";
    case RKNN_TENSOR_FLOAT16:
        return "FLOAT16";
    case RKNN_TENSOR_INT8:
        return "INT8";
    case RKNN_TENSOR_UINT8:
        return "UINT8";
    case RKNN_TENSOR_INT16:
        return "INT16";
    case RKNN_TENSOR_UINT16:
        return "UINT16";
    case RKNN_TENSOR_INT32:
        return "INT32";
    case RKNN_TENSOR_UINT32:
        return "UINT32";
    default:
        return "UNKNOWN";
    }
}

const char* qnt_to_string(rknn_tensor_qnt_type qnt_type) {
    switch (qnt_type) {
    case RKNN_TENSOR_QNT_NONE:
        return "NONE";
    case RKNN_TENSOR_QNT_DFP:
        return "DFP";
    case RKNN_TENSOR_QNT_AFFINE_ASYMMETRIC:
        return "AFFINE_ASYMMETRIC";
    default:
        return "UNKNOWN";
    }
}

void dump_tensor_attr(const rknn_tensor_attr& attr) {
    std::printf("  index=%u, name=%s, n_dims=%u, dims=[%u, %u, %u, %u], n_elems=%u, size=%u, fmt=%s, type=%s, qnt_type=%s, zp=%d, scale=%f\n",
                attr.index,
                attr.name,
                attr.n_dims,
                attr.dims[0],
                attr.dims[1],
                attr.dims[2],
                attr.dims[3],
                attr.n_elems,
                attr.size,
                format_to_string(attr.fmt),
                type_to_string(attr.type),
                qnt_to_string(attr.qnt_type),
                attr.zp,
                attr.scale);
}

cv::Mat load_input_image(const std::string& image_path, const RKNNRunner::InputShape& shape) {
    cv::Mat image = cv::imread(image_path, cv::IMREAD_UNCHANGED);
    if (image.empty()) {
        throw std::runtime_error("load image failed: " + image_path);
    }

    cv::Mat converted;
    switch (shape.channels) {
    case 1:
        if (image.channels() == 1) {
            converted = image;
        } else if (image.channels() == 3) {
            cv::cvtColor(image, converted, cv::COLOR_BGR2GRAY);
        } else if (image.channels() == 4) {
            cv::cvtColor(image, converted, cv::COLOR_BGRA2GRAY);
        }
        break;
    case 3:
        if (image.channels() == 1) {
            cv::cvtColor(image, converted, cv::COLOR_GRAY2RGB);
        } else if (image.channels() == 3) {
            cv::cvtColor(image, converted, cv::COLOR_BGR2RGB);
        } else if (image.channels() == 4) {
            cv::cvtColor(image, converted, cv::COLOR_BGRA2RGB);
        }
        break;
    case 4:
        if (image.channels() == 1) {
            cv::cvtColor(image, converted, cv::COLOR_GRAY2RGBA);
        } else if (image.channels() == 3) {
            cv::cvtColor(image, converted, cv::COLOR_BGR2RGBA);
        } else if (image.channels() == 4) {
            cv::cvtColor(image, converted, cv::COLOR_BGRA2RGBA);
        }
        break;
    default:
        throw std::runtime_error("unsupported input channel count: " + std::to_string(shape.channels));
    }

    if (converted.empty()) {
        throw std::runtime_error("unsupported source image channels");
    }

    if (converted.rows != static_cast<int>(shape.height) ||
        converted.cols != static_cast<int>(shape.width)) {
        cv::resize(converted, converted,
                   cv::Size(static_cast<int>(shape.width), static_cast<int>(shape.height)));
    }

    return converted;
}

void get_top_n(const std::vector<float>& probs,
               uint32_t top_num,
               std::vector<float>& top_probs,
               std::vector<uint32_t>& top_classes) {
    const uint32_t top_count = std::min<uint32_t>(static_cast<uint32_t>(probs.size()), top_num);
    top_probs.assign(top_count, -FLT_MAX);
    top_classes.assign(top_count, 0);

    std::vector<bool> used(probs.size(), false);
    for (uint32_t j = 0; j < top_count; ++j) {
        for (uint32_t i = 0; i < probs.size(); ++i) {
            if (used[i]) {
                continue;
            }
            if (probs[i] > top_probs[j]) {
                top_probs[j] = probs[i];
                top_classes[j] = i;
            }
        }
        if (top_probs[j] > -FLT_MAX) {
            used[top_classes[j]] = true;
        }
    }
}

int parse_loop_count(const char* arg) {
    const int loop_count = std::atoi(arg);
    if (loop_count <= 0) {
        throw std::runtime_error("loop_count must be a positive integer");
    }
    return loop_count;
}

} // namespace

int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::printf("Usage:%s model_path input_path [loop_count] [--no-io-mem] [--init-only]\n", argv[0]);
        return 1;
    }

    try {
        const std::string model_path = argv[1];
        const std::string input_path = argv[2];
        int loop_count = 1;
        bool use_io_mem = true;
        bool init_only = false;
        for (int i = 3; i < argc; ++i) {
            const std::string arg = argv[i];
            if (arg == "--no-io-mem") {
                use_io_mem = false;
            } else if (arg == "--init-only") {
                init_only = true;
            } else {
                loop_count = parse_loop_count(argv[i]);
            }
        }

        std::printf("[MINIMAL_MODE] %s\n", init_only ? "ON" : "OFF");
        std::printf("[IO_MODE] %s\n", use_io_mem ? "IO_MEM" : "LEGACY_IO");
        RKNNRunner runner(model_path, RKNN_NPU_CORE_0, use_io_mem);

        std::printf("rknn_api/rknnrt version: %s, driver version: %s\n",
                    runner.sdk_version().api_version,
                    runner.sdk_version().drv_version);
        std::printf("model input num: %d, output num: %d\n",
                    runner.input_count(), runner.output_count());

        std::printf("input tensors:\n");
        for (const auto& attr : runner.input_attrs()) {
            dump_tensor_attr(attr);
        }

        std::printf("output tensors:\n");
        for (const auto& attr : runner.output_attrs()) {
            dump_tensor_attr(attr);
        }

        std::printf("custom string: %s\n",
                    runner.custom_string().empty() ? "" : runner.custom_string().c_str());

        if (init_only) {
            std::printf("[MINIMAL_MODE] init/query complete, skip inference.\n");
            return 0;
        }

        const RKNNRunner::InputShape shape = runner.input_shape();
        cv::Mat input = load_input_image(input_path, shape);

        std::vector<float> elapsed_ms;
        std::printf("Begin perf ...\n");
        const auto outputs = runner.inference(
            input.data,
            static_cast<uint32_t>(input.total() * input.elemSize()),
            loop_count,
            &elapsed_ms);

        for (size_t i = 0; i < elapsed_ms.size(); ++i) {
            const float elapsed = elapsed_ms[i];
            const float fps = elapsed > 0.0f ? 1000.0f / elapsed : 0.0f;
            std::printf("%4zu: Elapse Time = %.2fms, FPS = %.2f\n", i, elapsed, fps);
        }

        constexpr uint32_t kTopNum = 5;
        for (const auto& output : outputs) {
            std::vector<float> top_probs;
            std::vector<uint32_t> top_classes;
            get_top_n(output.data, kTopNum, top_probs, top_classes);

            std::printf("---- Top%zu ----\n", top_probs.size());
            for (size_t i = 0; i < top_probs.size(); ++i) {
                std::printf("%8.6f - %u\n", top_probs[i], top_classes[i]);
            }
        }
        return 0;
    } catch (const std::exception& ex) {
        std::fprintf(stderr, "[ERR] %s\n", ex.what());
        return 1;
    }
}
