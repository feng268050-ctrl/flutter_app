#pragma once
#if defined(LENS_USE_REAL_RKNN_API) && defined(__has_include) && __has_include(<rknn_api.h>)
#include <rknn_api.h>
#else
// Lightweight declarations for IDE parsing when the RKNN SDK include path is not configured.
// Real builds still require rknn_api.h via RKNN_RT_PATH.
using rknn_context = unsigned int;
using rknn_core_mask = int;
constexpr rknn_core_mask RKNN_NPU_CORE_0 = 1;
struct rknn_sdk_version {};
struct rknn_input_output_num {
    unsigned int n_input = 0;
    unsigned int n_output = 0;
};
struct rknn_tensor_attr {
    int qnt_type = 0;
    int zp = 0;
    float scale = 0.0f;
};
struct rknn_tensor_mem {};
#endif
#include <string>
#include <vector>
#include <cstdint>

class RKNNRunner {
public:
    struct InputShape {
        uint32_t height;
        uint32_t width;
        uint32_t channels;
    };

    struct OutputTensor {
        std::vector<float> data;
        std::vector<uint32_t> shape;
        uint32_t n_dims;
    };

    /** Filled when `LENS_INFER_TIMING` is enabled and the optional `phases` arg is non-null. */
    struct InferencePhases {
        float input_copy_ms = 0.0F;
        float inputs_set_ms = 0.0F;
        float rknn_run_ms = 0.0F;
        float outputs_get_ms = 0.0F;
    };

    explicit RKNNRunner(const std::string& model_path,
                        rknn_core_mask core = RKNN_NPU_CORE_0,
                        bool use_io_mem = true);
    RKNNRunner(const uint8_t* data, size_t size,
               rknn_core_mask core = RKNN_NPU_CORE_0,
               bool use_io_mem = true);
    ~RKNNRunner();

    RKNNRunner(const RKNNRunner&)            = delete;
    RKNNRunner& operator=(const RKNNRunner&) = delete;

    std::vector<OutputTensor> inference(const void* input_data,
                                        uint32_t input_bytes,
                                        int loop_count = 1,
                                        std::vector<float>* elapsed_ms = nullptr,
                                        InferencePhases* phases = nullptr);

    int output_count() const { return static_cast<int>(io_num_.n_output); }
    int input_count() const { return static_cast<int>(io_num_.n_input); }

    const rknn_sdk_version& sdk_version() const { return sdk_ver_; }
    const std::string& custom_string() const { return custom_string_; }
    const std::vector<rknn_tensor_attr>& input_attrs() const { return input_attrs_; }
    const std::vector<rknn_tensor_attr>& output_attrs() const { return output_attrs_; }
    InputShape input_shape(uint32_t index = 0) const;

#if defined(LENS_YOLO_PP_DIAG) && LENS_YOLO_PP_DIAG
    /** Log full rknn_query OUTPUT_ATTR fields for every output (tag YOLO_PP_DIAG). */
    void log_output_attrs_yolo_pp_diag(const char* model_tag) const;
    /** After rknn_run, log per-output float-buffer stats (IO mem is float). */
    void log_output_buffers_yolo_pp_diag(const char* model_tag) const;
#endif

private:
    void init_context(rknn_core_mask core, const char* tag);
    void allocate_io_memory();
    void dump_io_summary(const char* tag) const;
    void copy_input_with_stride(uint32_t index, const void* input_data, uint32_t input_bytes);
    std::vector<OutputTensor> collect_outputs_from_io_mem();
    std::vector<OutputTensor> collect_outputs_from_legacy_io();

    rknn_context ctx_ = 0;
    rknn_sdk_version sdk_ver_{};
    rknn_input_output_num io_num_{};
    std::string custom_string_;
    std::vector<uint8_t> model_data_;
    std::vector<rknn_tensor_attr> input_attrs_;
    std::vector<rknn_tensor_attr> bound_input_attrs_;
    std::vector<rknn_tensor_attr> output_attrs_;
    std::vector<rknn_tensor_attr> bound_output_attrs_;
    std::vector<rknn_tensor_mem*> input_mems_;
    std::vector<rknn_tensor_mem*> output_mems_;
    std::vector<uint8_t> legacy_input_buf_;
    mutable std::vector<std::vector<float>> output_buffers_;
    bool use_io_mem_ = true;
};
