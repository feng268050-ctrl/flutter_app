#include "rknn_runner.h"

#ifdef __ANDROID__
#include <android/log.h>
#endif

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <limits>
#include <stdexcept>
#include <string>
#include <sys/stat.h>
#include <vector>

#ifdef __ANDROID__
constexpr const char* RKNN_LOG_TAG = "RKNNRunner";

#define RKNN_LOGV(...) __android_log_print(ANDROID_LOG_VERBOSE, RKNN_LOG_TAG, __VA_ARGS__)
#define RKNN_LOGI(...) __android_log_print(ANDROID_LOG_INFO, RKNN_LOG_TAG, __VA_ARGS__)
#define RKNN_LOGW(...) __android_log_print(ANDROID_LOG_WARN, RKNN_LOG_TAG, __VA_ARGS__)
#define RKNN_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, RKNN_LOG_TAG, __VA_ARGS__)
#else
#define RKNN_LOGV(...) ((void)0)
#define RKNN_LOGI(...) std::printf(__VA_ARGS__)
#define RKNN_LOGW(...) std::fprintf(stderr, __VA_ARGS__)
#define RKNN_LOGE(...) std::fprintf(stderr, __VA_ARGS__)
#endif

#if defined(LENS_YOLO_PP_DIAG) && LENS_YOLO_PP_DIAG
#ifdef __ANDROID__
#define YOLO_PP_DIAG_LOG(...) __android_log_print(ANDROID_LOG_INFO, "YOLO_PP_DIAG", __VA_ARGS__)
#else
#define YOLO_PP_DIAG_LOG(...) std::fprintf(stderr, __VA_ARGS__)
#endif
#endif

// 所有 RKNN C API 使用统一前缀，便于: adb logcat -s RKNNRunner:I | grep RKNN_API
#define RKNN_LOG_API_BEGIN(name) RKNN_LOGI("[RKNN_API] %s BEGIN", (name))
#define RKNN_LOG_API_END_RET(name, ret) RKNN_LOGI("[RKNN_API] %s END ret=%d", (name), static_cast<int>(ret))

#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
namespace {
inline float rknn_phase_ms(const std::chrono::steady_clock::time_point& a,
                           const std::chrono::steady_clock::time_point& b) {
    return std::chrono::duration<float, std::milli>(b - a).count();
}
}  // namespace
#endif

namespace {

#ifdef __ANDROID__
inline void rknn_dump_tensor_attr(android_LogPriority prio, uint32_t idx,
                                  const rknn_tensor_attr& a, const char* label) {
    __android_log_print(prio, RKNN_LOG_TAG,
                        "%s #%u n_dims=%u fmt=%u type=%u quant=%u zp=%d scale=%f "
                        "n_elems=%u size=%zu size_stride=%zu w_stride=%u",
                        label,
                        static_cast<unsigned>(idx),
                        static_cast<unsigned>(a.n_dims),
                        static_cast<unsigned>(a.fmt),
                        static_cast<unsigned>(a.type),
                        static_cast<unsigned>(a.qnt_type),
                        static_cast<int>(a.zp),
                        static_cast<double>(a.scale),
                        static_cast<unsigned>(a.n_elems),
                        static_cast<size_t>(a.size),
                        static_cast<size_t>(a.size_with_stride),
                        static_cast<unsigned>(a.w_stride));
}
#endif

std::vector<uint8_t> read_model_file(const std::string& path) {
    std::ifstream f(path, std::ios::binary | std::ios::ate);
    if (!f) {
        throw std::runtime_error("Cannot open model: " + path);
    }

    const auto sz = f.tellg();
    if (sz <= 0) {
        throw std::runtime_error("Model file is empty: " + path);
    }

    f.seekg(0);
    std::vector<uint8_t> buf(static_cast<size_t>(sz));
    if (!f.read(reinterpret_cast<char*>(buf.data()), sz)) {
        throw std::runtime_error("Failed to read model: " + path);
    }
    return buf;
}

uint32_t tensor_num_elements(const rknn_tensor_attr& attr) {
    uint32_t elems = 1;
    for (uint32_t i = 0; i < attr.n_dims; ++i) {
        elems *= attr.dims[i];
    }
    return elems;
}

void copy_output_mem_to_float(const rknn_tensor_attr& attr, const void* mem, std::vector<float>& out) {
    const uint32_t elem_count = tensor_num_elements(attr);
    if (out.size() != elem_count) {
        out.resize(elem_count);
    }
    if (mem == nullptr) {
        throw std::runtime_error("RKNN output mem virt_addr is null");
    }
    if (attr.type == RKNN_TENSOR_FLOAT32) {
        const auto* fp = static_cast<const float*>(mem);
        std::memcpy(out.data(), fp, static_cast<std::size_t>(elem_count) * sizeof(float));
        return;
    }
    if (attr.type == RKNN_TENSOR_INT8 &&
        attr.qnt_type == RKNN_TENSOR_QNT_AFFINE_ASYMMETRIC && attr.scale != 0.0F) {
        const auto* q = static_cast<const std::int8_t*>(mem);
        const float scale = attr.scale;
        const float zp = static_cast<float>(attr.zp);
        for (uint32_t i = 0; i < elem_count; ++i) {
            out[i] = (static_cast<float>(q[i]) - zp) * scale;
        }
        return;
    }
    if (attr.type == RKNN_TENSOR_UINT8 &&
        attr.qnt_type == RKNN_TENSOR_QNT_AFFINE_ASYMMETRIC && attr.scale != 0.0F) {
        const auto* q = static_cast<const std::uint8_t*>(mem);
        const float scale = attr.scale;
        const float zp = static_cast<float>(attr.zp);
        for (uint32_t i = 0; i < elem_count; ++i) {
            out[i] = (static_cast<float>(q[i]) - zp) * scale;
        }
        return;
    }
    const auto* fp = static_cast<const float*>(mem);
    std::memcpy(out.data(), fp, static_cast<std::size_t>(elem_count) * sizeof(float));
}

std::runtime_error rknn_error(const char* stage, int ret) {
    return std::runtime_error(std::string(stage) + " failed: " + std::to_string(ret));
}

} // namespace

void RKNNRunner::init_context(rknn_core_mask core, const char* tag) {
    if (model_data_.empty()) {
        throw std::runtime_error("rknn_init: invalid model buffer");
    }

    try {
        RKNN_LOGI("[RKNN] init begin model=%s bytes=%zu",
                  tag ? tag : "<null>", static_cast<size_t>(model_data_.size()));

        RKNN_LOG_API_BEGIN("rknn_init");
        int ret = rknn_init(&ctx_, model_data_.data(),
                            static_cast<uint32_t>(model_data_.size()), 0, nullptr);
        RKNN_LOG_API_END_RET("rknn_init", ret);
        RKNN_LOGI("after rknn_init ret=%d ctx=%llu",
                  ret, static_cast<unsigned long long>(ctx_));
        if (ret != RKNN_SUCC) {
            throw std::runtime_error(std::string("rknn_init failed (") +
                                     std::to_string(ret) + "): " + tag);
        }

        RKNN_LOGI("[RKNN_API] rknn_set_core_mask BEGIN core_mask=0x%x",
                  static_cast<unsigned>(core));
        ret = rknn_set_core_mask(ctx_, core);
        RKNN_LOG_API_END_RET("rknn_set_core_mask", ret);
        if (ret != RKNN_SUCC) {
            RKNN_LOGW("[RKNN] set_core_mask non-success ret=%d (continuing)", ret);
        }

        RKNN_LOG_API_BEGIN("rknn_query(RKNN_QUERY_SDK_VERSION)");
        ret = rknn_query(ctx_, RKNN_QUERY_SDK_VERSION, &sdk_ver_, sizeof(sdk_ver_));
        RKNN_LOG_API_END_RET("rknn_query(RKNN_QUERY_SDK_VERSION)", ret);
        if (ret != RKNN_SUCC) {
            throw rknn_error("rknn_query SDK_VERSION", ret);
        }
        RKNN_LOGI("[RKNN] sdk api=%s drv=%s",
                  sdk_ver_.api_version, sdk_ver_.drv_version);

        RKNN_LOG_API_BEGIN("rknn_query(RKNN_QUERY_IN_OUT_NUM)");
        ret = rknn_query(ctx_, RKNN_QUERY_IN_OUT_NUM, &io_num_, sizeof(io_num_));
        RKNN_LOGI("[RKNN_API] rknn_query(RKNN_QUERY_IN_OUT_NUM) END ret=%d in=%u out=%u",
                  ret,
                  static_cast<unsigned>(io_num_.n_input),
                  static_cast<unsigned>(io_num_.n_output));
        if (ret != RKNN_SUCC) {
            throw rknn_error("rknn_query IN_OUT_NUM", ret);
        }

        input_attrs_.resize(io_num_.n_input);
        for (uint32_t i = 0; i < io_num_.n_input; ++i) {
            std::memset(&input_attrs_[i], 0, sizeof(rknn_tensor_attr));
            input_attrs_[i].index = i;
            RKNN_LOGI("[RKNN_API] rknn_query(RKNN_QUERY_INPUT_ATTR) BEGIN i=%u",
                      static_cast<unsigned>(i));
            ret = rknn_query(ctx_, RKNN_QUERY_INPUT_ATTR, &input_attrs_[i], sizeof(rknn_tensor_attr));
            RKNN_LOGI("[RKNN_API] rknn_query(RKNN_QUERY_INPUT_ATTR) END i=%u ret=%d",
                      static_cast<unsigned>(i), ret);
            if (ret != RKNN_SUCC) {
                throw rknn_error("rknn_query INPUT_ATTR", ret);
            }
#ifdef __ANDROID__
            rknn_dump_tensor_attr(ANDROID_LOG_INFO, i, input_attrs_[i], "IN");
#endif
        }

        output_attrs_.resize(io_num_.n_output);
        for (uint32_t i = 0; i < io_num_.n_output; ++i) {
            std::memset(&output_attrs_[i], 0, sizeof(rknn_tensor_attr));
            output_attrs_[i].index = i;
            RKNN_LOGI("[RKNN_API] rknn_query(RKNN_QUERY_OUTPUT_ATTR) BEGIN i=%u",
                      static_cast<unsigned>(i));
            ret = rknn_query(ctx_, RKNN_QUERY_OUTPUT_ATTR, &output_attrs_[i], sizeof(rknn_tensor_attr));
            RKNN_LOGI("[RKNN_API] rknn_query(RKNN_QUERY_OUTPUT_ATTR) END i=%u ret=%d",
                      static_cast<unsigned>(i), ret);
            if (ret != RKNN_SUCC) {
                throw rknn_error("rknn_query OUTPUT_ATTR", ret);
            }
#ifdef __ANDROID__
            rknn_dump_tensor_attr(ANDROID_LOG_INFO, i, output_attrs_[i], "OUT");
#endif
        }

        rknn_custom_string custom{};
        RKNN_LOG_API_BEGIN("rknn_query(RKNN_QUERY_CUSTOM_STRING)");
        ret = rknn_query(ctx_, RKNN_QUERY_CUSTOM_STRING, &custom, sizeof(custom));
        RKNN_LOG_API_END_RET("rknn_query(RKNN_QUERY_CUSTOM_STRING)", ret);
        if (ret == RKNN_SUCC) {
            custom_string_ = custom.string;
        } else {
            custom_string_.clear();
        }

        RKNN_LOGI("[RKNN] allocate_io_memory begin");
        allocate_io_memory();
        RKNN_LOGI("[RKNN] allocate_io_memory end");

        RKNN_LOGI("[RKNN] loaded model=%s inputs=%u outputs=%u",
                  tag, io_num_.n_input, io_num_.n_output);
    } catch (...) {
        for (auto* mem : input_mems_) {
            if (mem) {
                RKNN_LOG_API_BEGIN("rknn_destroy_mem(input cleanup)");
                const int dret = rknn_destroy_mem(ctx_, mem);
                RKNN_LOG_API_END_RET("rknn_destroy_mem(input cleanup)", dret);
            }
        }
        input_mems_.clear();

        for (auto* mem : output_mems_) {
            if (mem) {
                RKNN_LOG_API_BEGIN("rknn_destroy_mem(output cleanup)");
                const int dret = rknn_destroy_mem(ctx_, mem);
                RKNN_LOG_API_END_RET("rknn_destroy_mem(output cleanup)", dret);
            }
        }
        output_mems_.clear();

        if (ctx_) {
            RKNN_LOG_API_BEGIN("rknn_destroy(error path)");
            const int dret = rknn_destroy(ctx_);
            RKNN_LOG_API_END_RET("rknn_destroy(error path)", dret);
            ctx_ = 0;
        }
        throw;
    }
}

void RKNNRunner::allocate_io_memory() {
    if (!use_io_mem_) {
        if (io_num_.n_input < 1) {
            throw std::runtime_error("legacy IO requires at least one model input");
        }
        legacy_input_buf_.resize(input_attrs_[0].size_with_stride);
        return;
    }

    bound_input_attrs_ = input_attrs_;
    input_mems_.resize(io_num_.n_input, nullptr);
    for (uint32_t i = 0; i < io_num_.n_input; ++i) {
        bound_input_attrs_[i].type = RKNN_TENSOR_UINT8;
        bound_input_attrs_[i].fmt = RKNN_TENSOR_NHWC;
        const uint32_t in_size = input_attrs_[i].size_with_stride;
        RKNN_LOGI("[RKNN_API] rknn_create_mem(input) BEGIN i=%u size=%u",
                    static_cast<unsigned>(i), static_cast<unsigned>(in_size));
        input_mems_[i] = rknn_create_mem(ctx_, in_size);
        RKNN_LOGI("[RKNN_API] rknn_create_mem(input) END i=%u ptr=%p ok=%d",
                  static_cast<unsigned>(i),
                  static_cast<void*>(input_mems_[i]),
                  input_mems_[i] != nullptr);
        if (!input_mems_[i]) {
            throw std::runtime_error("rknn_create_mem input failed");
        }

        RKNN_LOGI("[RKNN_API] rknn_set_io_mem(input) BEGIN i=%u", static_cast<unsigned>(i));
        const int ret = rknn_set_io_mem(ctx_, input_mems_[i], &bound_input_attrs_[i]);
        RKNN_LOGI("[RKNN_API] rknn_set_io_mem(input) END i=%u ret=%d", static_cast<unsigned>(i), ret);
        if (ret != RKNN_SUCC) {
            throw rknn_error("rknn_set_io_mem input", ret);
        }
    }

    bound_output_attrs_ = output_attrs_;
    output_mems_.resize(io_num_.n_output, nullptr);
    for (uint32_t i = 0; i < io_num_.n_output; ++i) {
        const int output_size = static_cast<int>(output_attrs_[i].n_elems * sizeof(float));
        RKNN_LOGI("[RKNN_API] rknn_create_mem(output) BEGIN i=%u size=%d n_elems=%u",
                  static_cast<unsigned>(i),
                  output_size,
                  static_cast<unsigned>(output_attrs_[i].n_elems));
        output_mems_[i] = rknn_create_mem(ctx_, output_size);
        RKNN_LOGI("[RKNN_API] rknn_create_mem(output) END i=%u ptr=%p ok=%d",
                  static_cast<unsigned>(i),
                  static_cast<void*>(output_mems_[i]),
                  output_mems_[i] != nullptr);
        if (!output_mems_[i]) {
            throw std::runtime_error("rknn_create_mem output failed");
        }

        bound_output_attrs_[i].type = RKNN_TENSOR_FLOAT32;
        RKNN_LOGI("[RKNN_API] rknn_set_io_mem(output) BEGIN i=%u", static_cast<unsigned>(i));
        const int ret = rknn_set_io_mem(ctx_, output_mems_[i], &bound_output_attrs_[i]);
        RKNN_LOGI("[RKNN_API] rknn_set_io_mem(output) END i=%u ret=%d", static_cast<unsigned>(i), ret);
        if (ret != RKNN_SUCC) {
            throw rknn_error("rknn_set_io_mem output", ret);
        }
    }
}

RKNNRunner::RKNNRunner(const std::string& model_path, rknn_core_mask core, bool use_io_mem)
    : use_io_mem_(use_io_mem) {
    struct stat st {};
    const int exists = (::stat(model_path.c_str(), &st) == 0);
    const long fileSize = exists ? static_cast<long>(st.st_size) : -1L;
    RKNN_LOGI("modelPath=%s", model_path.c_str());
    RKNN_LOGI("model exists=%d size=%ld", exists, fileSize);
    RKNN_LOGI("before load model file");
    model_data_ = read_model_file(model_path);
    RKNN_LOGI("after load model file, buffer=%p size=%zu",
              static_cast<const void*>(model_data_.data()), model_data_.size());
    init_context(core, model_path.c_str());
}

RKNNRunner::RKNNRunner(const uint8_t* data, size_t size, rknn_core_mask core, bool use_io_mem)
    : use_io_mem_(use_io_mem) {
    if (!data || size == 0) {
        throw std::runtime_error("rknn_init: invalid model buffer (null or empty)");
    }
    RKNN_LOGI("before load model file");
    model_data_.assign(data, data + size);
    RKNN_LOGI("after load model file, buffer=%p size=%zu",
              static_cast<const void*>(model_data_.data()), model_data_.size());
    init_context(core, "<embedded>");
}

RKNNRunner::~RKNNRunner() {
    if (use_io_mem_) {
        for (auto* mem : input_mems_) {
            if (mem) {
                RKNN_LOG_API_BEGIN("rknn_destroy_mem(input)");
                const int r = rknn_destroy_mem(ctx_, mem);
                RKNN_LOG_API_END_RET("rknn_destroy_mem(input)", r);
            }
        }
        for (auto* mem : output_mems_) {
            if (mem) {
                RKNN_LOG_API_BEGIN("rknn_destroy_mem(output)");
                const int r = rknn_destroy_mem(ctx_, mem);
                RKNN_LOG_API_END_RET("rknn_destroy_mem(output)", r);
            }
        }
    }
    if (ctx_) {
        RKNN_LOG_API_BEGIN("rknn_destroy");
        const int r = rknn_destroy(ctx_);
        RKNN_LOG_API_END_RET("rknn_destroy", r);
    }
}

RKNNRunner::InputShape RKNNRunner::input_shape(uint32_t index) const {
    if (index >= input_attrs_.size()) {
        throw std::out_of_range("input_shape index out of range");
    }

    const auto& attr = input_attrs_[index];
    if (attr.n_dims < 4) {
        throw std::runtime_error("Unsupported input dims: " + std::to_string(attr.n_dims));
    }

    if (attr.fmt == RKNN_TENSOR_NCHW) {
        return {attr.dims[2], attr.dims[3], attr.dims[1]};
    }

    return {attr.dims[1], attr.dims[2], attr.dims[3]};
}

void RKNNRunner::copy_input_with_stride(uint32_t index, const void* input_data, uint32_t input_bytes) {
    if (!input_data) {
        throw std::runtime_error("input buffer is null");
    }

    const InputShape shape = input_shape(index);
    const uint32_t expected_bytes = shape.width * shape.height * shape.channels;
    if (input_bytes != expected_bytes) {
        throw std::runtime_error("input size mismatch: got " + std::to_string(input_bytes) +
                                 ", expected " + std::to_string(expected_bytes));
    }

    uint8_t* dst = nullptr;
    if (use_io_mem_) {
        if (index >= input_mems_.size()) {
            throw std::out_of_range("copy_input_with_stride index out of range");
        }
        dst = static_cast<uint8_t*>(input_mems_[index]->virt_addr);
    } else {
        if (index != 0 || legacy_input_buf_.empty()) {
            throw std::out_of_range("copy_input_with_stride (legacy) index out of range");
        }
        dst = legacy_input_buf_.data();
    }
    const auto* src = static_cast<const uint8_t*>(input_data);
    const uint32_t stride = input_attrs_[index].w_stride > 0 ? input_attrs_[index].w_stride : shape.width;

    std::memset(dst, 0, static_cast<size_t>(input_attrs_[index].size_with_stride));
    if (stride == shape.width) {
        std::memcpy(dst, src, expected_bytes);
        return;
    }

    const uint32_t src_row_bytes = shape.width * shape.channels;
    const uint32_t dst_row_bytes = stride * shape.channels;
    for (uint32_t h = 0; h < shape.height; ++h) {
        std::memcpy(dst, src, src_row_bytes);
        src += src_row_bytes;
        dst += dst_row_bytes;
    }
}

std::vector<RKNNRunner::OutputTensor> RKNNRunner::collect_outputs_from_io_mem() {
    std::vector<OutputTensor> result(io_num_.n_output);
    if (output_buffers_.size() < io_num_.n_output) {
        output_buffers_.resize(io_num_.n_output);
    }
    for (uint32_t i = 0; i < io_num_.n_output; ++i) {
        if (i >= output_attrs_.size() || i >= bound_output_attrs_.size() ||
            i >= output_mems_.size() || output_mems_[i] == nullptr) {
            throw std::runtime_error("RKNN output memory state is inconsistent");
        }
        const auto& shape_attr = output_attrs_[i];
        const auto& read_attr = bound_output_attrs_[i];
        auto& out = result[i];
        out.n_dims = shape_attr.n_dims;
        out.shape.assign(shape_attr.dims, shape_attr.dims + shape_attr.n_dims);

        copy_output_mem_to_float(read_attr, output_mems_[i]->virt_addr, output_buffers_[i]);
        out.data = output_buffers_[i];
    }
    return result;
}

std::vector<RKNNRunner::OutputTensor> RKNNRunner::collect_outputs_from_legacy_io() {
    std::vector<rknn_output> wr(io_num_.n_output);
    for (uint32_t i = 0; i < io_num_.n_output; ++i) {
        std::memset(&wr[i], 0, sizeof(rknn_output));
        wr[i].want_float  = 1;
        wr[i].is_prealloc = 0;
        wr[i].index       = i;
    }
    int ret = rknn_outputs_get(ctx_, io_num_.n_output, wr.data(), nullptr);
    if (ret != RKNN_SUCC) {
        for (uint32_t j = 0; j < io_num_.n_output; ++j) {
            wr[j].buf = nullptr;
        }
        throw rknn_error("rknn_outputs_get", ret);
    }

    std::vector<OutputTensor> result;
    result.reserve(io_num_.n_output);
    for (uint32_t i = 0; i < io_num_.n_output; ++i) {
        const auto& attr = output_attrs_[i];
        OutputTensor out;
        out.n_dims = attr.n_dims;
        out.shape.assign(attr.dims, attr.dims + attr.n_dims);
        const uint32_t elem_count = tensor_num_elements(attr);
        if (!wr[i].buf) {
            rknn_outputs_release(ctx_, io_num_.n_output, wr.data());
            throw std::runtime_error("rknn_outputs_get returned null output buffer");
        }
        const auto* fp = static_cast<const float*>(wr[i].buf);
        out.data.assign(fp, fp + elem_count);
        result.push_back(std::move(out));
    }
    ret = rknn_outputs_release(ctx_, io_num_.n_output, wr.data());
    if (ret != RKNN_SUCC) {
        RKNN_LOGW("[RKNN] rknn_outputs_release non-success ret=%d", ret);
    }
    return result;
}

std::vector<RKNNRunner::OutputTensor> RKNNRunner::inference(
    const void* input_data,
    uint32_t input_bytes,
    int loop_count,
    std::vector<float>* elapsed_ms,
    InferencePhases* phases) {
    if (use_io_mem_) {
        if (input_mems_.empty()) {
            throw std::runtime_error("No RKNN input memory allocated");
        }
    } else {
        if (legacy_input_buf_.empty()) {
            throw std::runtime_error("No legacy input buffer allocated");
        }
    }
    if (loop_count <= 0) {
        throw std::runtime_error("loop_count must be positive");
    }

    if (elapsed_ms) {
        elapsed_ms->clear();
        elapsed_ms->reserve(loop_count);
    }
#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
    InferencePhases local_phases{};
    if (!phases) {
        phases = &local_phases;
    }
    const auto t_infer0 = std::chrono::steady_clock::now();
#endif

    copy_input_with_stride(0, input_data, input_bytes);
#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
    const auto t_after_input = std::chrono::steady_clock::now();
    phases->input_copy_ms = rknn_phase_ms(t_infer0, t_after_input);
#endif
    if (!use_io_mem_) {
        rknn_input in{};
        in.index        = 0;
        in.buf          = legacy_input_buf_.data();
        in.size         = input_attrs_[0].size_with_stride;
        in.pass_through = 1;
#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
        const auto t_set0 = std::chrono::steady_clock::now();
#endif
        RKNN_LOGI("[RKNN_API] rknn_inputs_set BEGIN (legacy) size=%u", in.size);
        const int sret = rknn_inputs_set(ctx_, 1, &in);
        RKNN_LOGI("[RKNN_API] rknn_inputs_set END (legacy) ret=%d", sret);
#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
        phases->inputs_set_ms = rknn_phase_ms(t_set0, std::chrono::steady_clock::now());
#endif
        if (sret != RKNN_SUCC) {
            throw rknn_error("rknn_inputs_set", sret);
        }
    }

    float rknn_run_sum_ms = 0.0F;
    for (int i = 0; i < loop_count; ++i) {
        const auto start = std::chrono::steady_clock::now();
        RKNN_LOGI("[RKNN_API] rknn_run BEGIN iter=%d/%d", i + 1, loop_count);
        const int ret = rknn_run(ctx_, nullptr);
        RKNN_LOGI("[RKNN_API] rknn_run END iter=%d/%d ret=%d", i + 1, loop_count, ret);
        const auto end = std::chrono::steady_clock::now();
        if (ret != RKNN_SUCC) {
            throw rknn_error("rknn_run", ret);
        }

        const float iter_ms = std::chrono::duration<float, std::milli>(end - start).count();
        rknn_run_sum_ms += iter_ms;
        if (elapsed_ms) {
            elapsed_ms->push_back(iter_ms);
        }
    }
#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
    phases->rknn_run_ms = rknn_run_sum_ms;
    const auto t_before_outputs = std::chrono::steady_clock::now();
#endif

    std::vector<OutputTensor> result;
    if (use_io_mem_) {
        result = collect_outputs_from_io_mem();
    } else {
        result = collect_outputs_from_legacy_io();
    }
#if defined(LENS_INFER_TIMING) && LENS_INFER_TIMING
    const auto t_after_outputs = std::chrono::steady_clock::now();
    phases->outputs_get_ms = rknn_phase_ms(t_before_outputs, t_after_outputs);
    RKNN_LOGI(
        "[RKNN][timing] input_copy=%.2f inputs_set=%.2f rknn_run=%.2f outputs_get=%.2f "
        "path=%s io_mem=%d\n",
        phases->input_copy_ms,
        phases->inputs_set_ms,
        phases->rknn_run_ms,
        phases->outputs_get_ms,
        use_io_mem_ ? "io_mem" : "legacy_outputs_get",
        use_io_mem_ ? 1 : 0);
#endif
    return result;
}

#if defined(LENS_YOLO_PP_DIAG) && LENS_YOLO_PP_DIAG

namespace {

std::string rknn_dims_string(const rknn_tensor_attr& a) {
    std::string s = "[";
    for (uint32_t i = 0; i < a.n_dims; ++i) {
        if (i > 0) {
            s += ',';
        }
        s += std::to_string(a.dims[i]);
    }
    s += ']';
    return s;
}

float median_nth_element(std::vector<float>* v) {
    if (!v || v->empty()) {
        return 0.0f;
    }
    const auto mid = v->begin() + (v->size() - 1U) / 2U;
    std::nth_element(v->begin(), mid, v->end());
    return *mid;
}

int median_nth_element_int(std::vector<int>* v) {
    if (!v || v->empty()) {
        return 0;
    }
    const auto mid = v->begin() + (v->size() - 1U) / 2U;
    std::nth_element(v->begin(), mid, v->end());
    return *mid;
}

} // namespace

void RKNNRunner::log_output_attrs_yolo_pp_diag(const char* model_tag) const {
    for (uint32_t i = 0; i < output_attrs_.size(); ++i) {
        const auto& a = output_attrs_[i];
        const std::string ds = rknn_dims_string(a);
        YOLO_PP_DIAG_LOG(
            "[YOLO_PP_DIAG] rknn_output_attr model=%s idx=%u name=%s n_dims=%u dims=%s "
            "n_elems=%u size=%u type=%u fmt=%u qnt_type=%u scale=%.8f zp=%d",
            model_tag ? model_tag : "?",
            static_cast<unsigned>(i),
            a.name,
            static_cast<unsigned>(a.n_dims),
            ds.c_str(),
            static_cast<unsigned>(a.n_elems),
            static_cast<unsigned>(a.size),
            static_cast<unsigned>(a.type),
            static_cast<unsigned>(a.fmt),
            static_cast<unsigned>(a.qnt_type),
            static_cast<double>(a.scale),
            static_cast<int>(a.zp));
    }
}

void RKNNRunner::log_output_buffers_yolo_pp_diag(const char* model_tag) const {
    if (!use_io_mem_ || output_mems_.size() != output_attrs_.size()) {
        YOLO_PP_DIAG_LOG(
            "[YOLO_PP_DIAG] output_buffer_stats model=%s skipped (legacy IO or mem/output count mismatch)",
            model_tag ? model_tag : "?");
        return;
    }
    for (uint32_t i = 0; i < output_attrs_.size(); ++i) {
        const auto& a = output_attrs_[i];
        rknn_tensor_mem* mem = output_mems_[i];
        if (!mem || !mem->virt_addr) {
            continue;
        }
        const auto* fp = static_cast<const float*>(mem->virt_addr);
        const size_t n = static_cast<size_t>(a.n_elems);
        if (n == 0U) {
            continue;
        }

        float fmin = std::numeric_limits<float>::infinity();
        float fmax = -std::numeric_limits<float>::infinity();
        for (size_t k = 0; k < n; ++k) {
            const float v = fp[k];
            if (v < fmin) {
                fmin = v;
            }
            if (v > fmax) {
                fmax = v;
            }
        }
        std::vector<float> tmp(fp, fp + n);
        const float fp50 = median_nth_element(&tmp);

        std::string head = "first20=";
        const size_t n20 = std::min<size_t>(20U, n);
        for (size_t j = 0; j < n20; ++j) {
            if (j > 0U) {
                head += ',';
            }
            head += std::to_string(static_cast<double>(fp[j]));
        }

        YOLO_PP_DIAG_LOG(
            "[YOLO_PP_DIAG] output_buffer model=%s idx=%u float_min=%.8f float_max=%.8f float_p50=%.8f %s "
            "(io_mem=FLOAT32 after NPU; compare qnt_type/zp/scale from rknn_output_attr)",
            model_tag ? model_tag : "?",
            static_cast<unsigned>(i),
            static_cast<double>(fmin),
            static_cast<double>(fmax),
            static_cast<double>(fp50),
            head.c_str());

        if (a.qnt_type == RKNN_TENSOR_QNT_AFFINE_ASYMMETRIC) {
            if (a.scale == 0.0f) {
                YOLO_PP_DIAG_LOG(
                    "[YOLO_PP_DIAG] output_buffer model=%s idx=%u recon_int8 skipped (scale=0)",
                    model_tag ? model_tag : "?",
                    static_cast<unsigned>(i));
                continue;
            }
            int iqmin = 127;
            int iqmax = -128;
            std::vector<int> iq;
            iq.reserve(n);
            const double inv_scale = 1.0 / static_cast<double>(a.scale);
            const double zpd = static_cast<double>(a.zp);
            for (size_t k = 0; k < n; ++k) {
                // float ~= (q - zp) * scale  =>  q = round(float / scale + zp)
                const int q = static_cast<int>(std::lround(static_cast<double>(fp[k]) * inv_scale + zpd));
                const int clamped = q < -128 ? -128 : (q > 127 ? 127 : q);
                iq.push_back(clamped);
                if (clamped < iqmin) {
                    iqmin = clamped;
                }
                if (clamped > iqmax) {
                    iqmax = clamped;
                }
            }
            const int ip50 = median_nth_element_int(&iq);
            YOLO_PP_DIAG_LOG(
                "[YOLO_PP_DIAG] output_buffer model=%s idx=%u recon_int8_from_float min=%d max=%d p50=%d "
                "(inverse of dequant; use to spot zp plateaus vs varying buffer)",
                model_tag ? model_tag : "?",
                static_cast<unsigned>(i),
                iqmin,
                iqmax,
                ip50);
        } else {
            YOLO_PP_DIAG_LOG(
                "[YOLO_PP_DIAG] output_buffer model=%s idx=%u recon_int8 skipped qnt_type=%u (use float stats only)",
                model_tag ? model_tag : "?",
                static_cast<unsigned>(i),
                static_cast<unsigned>(a.qnt_type));
        }
    }
}

#endif // LENS_YOLO_PP_DIAG
