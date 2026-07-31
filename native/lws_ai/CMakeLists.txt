cmake_minimum_required(VERSION 3.14)
project(ai LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Linux cross/native: provide <android/log.h> shim used by daemon + stream_detect sources.
if(NOT ANDROID)
    include_directories(BEFORE "${CMAKE_CURRENT_SOURCE_DIR}/cmake/linux_compat")
endif()

# ── Library version (required) ────────────────────────────────
set(LIB_VERSION "" CACHE STRING "Library version string (e.g. v1.0.0). Required.")
if(NOT LIB_VERSION)
    message(FATAL_ERROR
        "LIB_VERSION is required. Pass -DLIB_VERSION=v1.0.0 to cmake.\n"
        "  Local build: set LIB_VERSION=v1.0.0 before running build_android.bat\n"
        "  CI build:    -DLIB_VERSION=\${CI_COMMIT_TAG}")
endif()
message(STATUS "Building libai.so (LIB_VERSION=${LIB_VERSION} for build metadata)")

# ── RKNN Runtime SDK ─────────────────────────────────────────
# Linux layout:   <arch>/include + <arch>/lib/librknnrt.so
# Android layout: <abi>/include + <abi>/librknnrt.so (often no lib/ subdir)
set(RKNN_RT_PATH "" CACHE PATH "RKNPU2 runtime SDK root (contains include/ and librknnrt.so)")
if(NOT RKNN_RT_PATH)
    message(FATAL_ERROR
        "Set -DRKNN_RT_PATH=<path> to the RKNPU2 runtime SDK directory.\n"
        "  e.g. -DRKNN_RT_PATH=/path/to/rknpu2/runtime/Linux/librknn_api/aarch64")
endif()

set(RKNN_RT_LIB "" CACHE FILEPATH "Optional: full path to librknnrt.so (auto-detected if empty)")
if(RKNN_RT_LIB AND EXISTS "${RKNN_RT_LIB}")
    # use explicit path
elseif(EXISTS "${RKNN_RT_PATH}/lib/librknnrt.so")
    set(RKNN_RT_LIB "${RKNN_RT_PATH}/lib/librknnrt.so")
elseif(EXISTS "${RKNN_RT_PATH}/librknnrt.so")
    set(RKNN_RT_LIB "${RKNN_RT_PATH}/librknnrt.so")
else()
    message(FATAL_ERROR
        "Could not find librknnrt.so under:\n  ${RKNN_RT_PATH}\n"
        "Expected ${RKNN_RT_PATH}/lib/librknnrt.so or ${RKNN_RT_PATH}/librknnrt.so\n"
        "Or set -DRKNN_RT_LIB=<full/path/to/librknnrt.so>")
endif()

set(RKNN_RT_INCLUDE "${RKNN_RT_PATH}/include")
if(NOT EXISTS "${RKNN_RT_INCLUDE}/rknn_api.h")
    if(EXISTS "${RKNN_RT_PATH}/../include/rknn_api.h")
        get_filename_component(RKNN_RT_INCLUDE "${RKNN_RT_PATH}/../include" ABSOLUTE)
    endif()
endif()
if(NOT EXISTS "${RKNN_RT_INCLUDE}/rknn_api.h")
    message(FATAL_ERROR
        "Could not find rknn_api.h under ${RKNN_RT_PATH}/include (or sibling ../include).")
endif()

# ── OpenCV ───────────────────────────────────────────────────
# OPENCV_PATH: dir with OpenCVConfig.cmake (Android SDK jni/ or Linux install lib/cmake/opencv4).
set(OPENCV_PATH "" CACHE PATH "Directory containing OpenCVConfig.cmake")
if(NOT OPENCV_PATH)
    set(_opencv_defaults
        "${CMAKE_CURRENT_SOURCE_DIR}/../../prebuilt/opencv/linux-arm64/lib/cmake/opencv4"
        "${CMAKE_CURRENT_SOURCE_DIR}/../toolchains/opencv/sdk/native/jni"
    )
    foreach(_cand IN LISTS _opencv_defaults)
        if(EXISTS "${_cand}/OpenCVConfig.cmake")
            set(OPENCV_PATH "${_cand}")
            break()
        endif()
    endforeach()
endif()
if(NOT OPENCV_PATH OR NOT EXISTS "${OPENCV_PATH}/OpenCVConfig.cmake")
    message(FATAL_ERROR
        "OpenCV not found. Run 'make build-opencv' (Linux) or pass\n"
        "  -DOPENCV_PATH=<dir containing OpenCVConfig.cmake>")
endif()
set(OpenCV_DIR "${OPENCV_PATH}" CACHE PATH "OpenCV config directory" FORCE)
find_package(OpenCV REQUIRED COMPONENTS core imgproc imgcodecs videoio dnn)
message(STATUS "OpenCV ${OpenCV_VERSION} from ${OPENCV_PATH}")

# ── yaml-cpp (auto-download) ────────────────────────────────
include(FetchContent)
FetchContent_Declare(yaml-cpp
    GIT_REPOSITORY https://github.com/jbeder/yaml-cpp.git
    GIT_TAG        0.8.0
)
set(YAML_CPP_BUILD_TESTS   OFF CACHE BOOL "" FORCE)
set(YAML_CPP_BUILD_TOOLS   OFF CACHE BOOL "" FORCE)
set(YAML_CPP_INSTALL       OFF CACHE BOOL "" FORCE)
# Reuse host FetchContent checkout when present (avoids re-clone; safe across repo path moves).
set(_YAML_CPP_LOCAL "${CMAKE_CURRENT_SOURCE_DIR}/build-host/_deps/yaml-cpp-src")
if(EXISTS "${_YAML_CPP_LOCAL}/CMakeLists.txt")
    set(FETCHCONTENT_SOURCE_DIR_YAML-CPP "${_YAML_CPP_LOCAL}" CACHE PATH "" FORCE)
    set(FETCHCONTENT_UPDATES_DISCONNECTED_YAML-CPP ON CACHE BOOL "" FORCE)
    message(STATUS "yaml-cpp: using local source ${_YAML_CPP_LOCAL}")
endif()
FetchContent_MakeAvailable(yaml-cpp)

# ── Embed RKNN DET model via objcopy ──────────────────────────
set(MODEL_DIR "${CMAKE_SOURCE_DIR}/assets/models")
file(GLOB _RKNN_ALL LIST_DIRECTORIES false CONFIGURE_DEPENDS "${MODEL_DIR}/*.rknn")

set(_DET_CANDIDATES v8_rknn_stain_det_i8.rknn det_raw_head.rknn det.rknn v8_lens_det_i8.rknn det_non_decode.rknn)

set(MODEL_DET "")
foreach(_cand IN LISTS _DET_CANDIDATES)
    if(EXISTS "${MODEL_DIR}/${_cand}")
        set(MODEL_DET "${MODEL_DIR}/${_cand}")
        break()
    endif()
endforeach()

if(NOT MODEL_DET)
    string(REPLACE ";" "\n  " _RKNN_LISTING "${_RKNN_ALL}")
    string(REPLACE ";" ", " _DET_CANDIDATES_STR "${_DET_CANDIDATES}")
    message(FATAL_ERROR
        "Missing embedded RKNN DET in ${MODEL_DIR}.\n"
        "  DET (need one of: ${_DET_CANDIDATES_STR}): ${MODEL_DET}\n"
        "  All *.rknn present:\n  ${_RKNN_LISTING}")
endif()

foreach(_rknn IN LISTS _RKNN_ALL)
    if(NOT _rknn STREQUAL MODEL_DET)
        get_filename_component(_extra_name "${_rknn}" NAME)
        message(WARNING "Extra RKNN in ${MODEL_DIR} (not embedded): ${_extra_name}")
    endif()
endforeach()

message(STATUS "Embedded RKNN DET=${MODEL_DET}")
get_filename_component(_RKNN_EMBED_DET_NAME "${MODEL_DET}" NAME)
message(STATUS "RKNN embedded into libai.so — DET: ${_RKNN_EMBED_DET_NAME}")

set(MODEL_DET_ALIAS "v8_rknn_stain_det_i8.rknn")
set(MODEL_DET_STAGE "${CMAKE_CURRENT_BINARY_DIR}/${MODEL_DET_ALIAS}")
set(MODEL_DET_OBJ "${CMAKE_CURRENT_BINARY_DIR}/v8_rknn_stain_det_i8_rknn.o")

# Prefer GNU objcopy from the NDK GCC toolchain for binary embedding.
# Older NDK r18b llvm-objcopy variants in Linux CI reject both GNU short and long
# option spellings for raw binary -> ELF wrapping, while aarch64-linux-android-objcopy
# handles the classic syntax reliably on both local and CI environments.
set(EMBED_OBJCOPY "${CMAKE_OBJCOPY}")
if(DEFINED ANDROID_NDK AND EXISTS "${ANDROID_NDK}/toolchains/aarch64-linux-android-4.9/prebuilt")
    file(GLOB _OBJCOPY_CANDIDATES
        "${ANDROID_NDK}/toolchains/aarch64-linux-android-4.9/prebuilt/*/bin/aarch64-linux-android-objcopy*"
    )
    list(LENGTH _OBJCOPY_CANDIDATES _OBJCOPY_COUNT)
    if(_OBJCOPY_COUNT GREATER 0)
        list(GET _OBJCOPY_CANDIDATES 0 EMBED_OBJCOPY)
    endif()
endif()

set(MODEL_EMBED_OBJECTS "${MODEL_DET_OBJ}")

add_custom_command(OUTPUT "${MODEL_DET_OBJ}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${MODEL_DET}" "${MODEL_DET_STAGE}"
    COMMAND "${EMBED_OBJCOPY}"
        -I binary
        -O elf64-littleaarch64
        -B aarch64
        "${MODEL_DET_ALIAS}" "${MODEL_DET_OBJ}"
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    DEPENDS "${MODEL_DET}"
    COMMENT "Embedding ${MODEL_DET_ALIAS} into object file"
)

# ── Shared OpenCV detect error codes / JSON helpers ──
add_library(opencv_detect_common STATIC
    src/opencv_detect/json_escape.cpp
    src/opencv_detect/opencv_detect_json.cpp
    src/opencv_detect/red_frame_validator.cpp
)
set_target_properties(opencv_detect_common PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(opencv_detect_common PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src/opencv_detect
)
target_link_libraries(opencv_detect_common PUBLIC ${OpenCV_LIBS})

# ── OpenCV stain detect (single-frame, same libai.so as RKNN stack) ──
add_library(opencv_stain_detect_core STATIC
    src/opencv_stain_detect/opencv_stain_detect_analyzer.cpp
    src/opencv_stain_detect/fixed_roi_pipeline.cpp
    src/opencv_stain_detect/fixed_roi_red_path.cpp
    src/opencv_stain_detect/fixed_roi_global_erode_path.cpp
    src/opencv_stain_detect/red_bright_region.cpp
    src/opencv_stain_detect/halo_spread_metrics.cpp
)
set_target_properties(opencv_stain_detect_core PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(opencv_stain_detect_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src/opencv_stain_detect
    ${CMAKE_CURRENT_SOURCE_DIR}/src/opencv_detect
)
target_link_libraries(opencv_stain_detect_core PUBLIC opencv_detect_common ${OpenCV_LIBS})

# ── Shared ROI config (linked once by zero_point_core and edgedrawing_core) ──
add_library(roi_config_common STATIC
    src/zero_point/roi_config.cpp
)
set_target_properties(roi_config_common PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(roi_config_common PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src/zero_point
    ${CMAKE_CURRENT_SOURCE_DIR}/src/opencv_detect
)

# ── Zero-point (single-frame brightest peak in ROI) ──
add_library(zero_point_core STATIC
    src/zero_point/roi_preprocess.cpp
    src/zero_point/brightest_in_box.cpp
    src/zero_point/brightest_line_in_box.cpp
    src/zero_point/zero_point_util.cpp
    src/zero_point/zero_point_json.cpp
    src/zero_point/zero_point_detector.cpp
    src/zero_point/zero_point_context.cpp
)
set_target_properties(zero_point_core PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(zero_point_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src/zero_point
    ${CMAKE_CURRENT_SOURCE_DIR}/src/opencv_detect
)
target_link_libraries(zero_point_core PUBLIC roi_config_common opencv_detect_common ${OpenCV_LIBS})

# ── Vendored OpenCV contrib EdgeDrawing (ximgproc) ──
option(ENABLE_EDGEDRAWING "Include EdgeDrawing module in libai.so" ON)
option(ENABLE_RKNN_STAIN_STREAM "Include RKNN stain path in stream_detect runner" ON)

set(OPENCV_XIMGPROC_ED_DIR "" CACHE PATH "Vendored OpenCV ximgproc EdgeDrawing sources")
if(NOT OPENCV_XIMGPROC_ED_DIR)
    set(_ximg_defaults
        "${CMAKE_CURRENT_SOURCE_DIR}/../../.cache/opencv/ximgproc-ed"
        "${CMAKE_CURRENT_SOURCE_DIR}/../toolchains/opencv-ximgproc-ed"
    )
    foreach(_cand IN LISTS _ximg_defaults)
        if(EXISTS "${_cand}/src/edge_drawing.cpp")
            set(OPENCV_XIMGPROC_ED_DIR "${_cand}")
            break()
        endif()
    endforeach()
endif()
if(ENABLE_EDGEDRAWING)
if(NOT EXISTS "${OPENCV_XIMGPROC_ED_DIR}/src/edge_drawing.cpp")
    message(FATAL_ERROR
        "Missing EdgeDrawing sources. Run: make fetch-opencv-ximgproc\n"
        "  (expected under .cache/opencv/ximgproc-ed)")
endif()
add_library(opencv_ximgproc_ed STATIC
    ${OPENCV_XIMGPROC_ED_DIR}/src/edge_drawing.cpp
)
set_target_properties(opencv_ximgproc_ed PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(opencv_ximgproc_ed PUBLIC
    ${OPENCV_XIMGPROC_ED_DIR}/include
    ${OPENCV_XIMGPROC_ED_DIR}/src
)
target_link_libraries(opencv_ximgproc_ed PUBLIC ${OpenCV_LIBS})

# ── EdgeDrawing zero-point detect ──
add_library(edgedrawing_core STATIC
    src/edgedrawing/radial_scan_core.cpp
    src/edgedrawing/radial_scan_debug.cpp
    src/edgedrawing/edgedrawing_util.cpp
    src/edgedrawing/edgedrawing_json.cpp
    src/edgedrawing/edgedrawing_detector.cpp
    src/edgedrawing/edgedrawing_context.cpp
)
set_target_properties(edgedrawing_core PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(edgedrawing_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src/edgedrawing
    ${CMAKE_CURRENT_SOURCE_DIR}/src/zero_point
    ${CMAKE_CURRENT_SOURCE_DIR}/src/opencv_detect
    ${OPENCV_XIMGPROC_ED_DIR}/include
)
target_link_libraries(edgedrawing_core PUBLIC
    roi_config_common
    opencv_detect_common
    opencv_ximgproc_ed
    ${OpenCV_LIBS}
)
endif()

# ── Native RTSP stream detect pipeline ──
option(ENABLE_ROCKCHIP_MPP "Rockchip MPP decoder for stream_detect (RK3566 BSP)" OFF)
if(ANDROID)
    option(ENABLE_STREAM_DETECT_NDK_FALLBACK "NdkMediaCodec fallback when MPP unavailable" ON)
else()
    option(ENABLE_STREAM_DETECT_NDK_FALLBACK "NdkMediaCodec fallback when MPP unavailable" OFF)
endif()

set(STREAM_DETECT_CORE_SOURCES
    src/stream_detect/frame_scheduler.cpp
    src/stream_detect/yuv_convert.cpp
    src/stream_detect/rtsp_util.cpp
    src/stream_detect/sps_dimensions.cpp
    src/stream_detect/rtsp_tcp_session.cpp
    src/stream_detect/rtsp_demux.cpp
    src/stream_detect/portable_bgr_converter.cpp
    src/stream_detect/video_decoder_factory.cpp
    src/stream_detect/stream_detect_pipeline.cpp
    src/stream_detect/stream_detect_event.cpp
    src/stream_detect/detect_runner.cpp
    src/platform/rockchip/mpp_video_decoder.cpp
)
if(ANDROID)
    list(APPEND STREAM_DETECT_CORE_SOURCES
        src/stream_detect/media_codec_decoder.cpp
        src/platform/android/ndk_media_codec_video_decoder.cpp
    )
endif()

add_library(stream_detect_core STATIC ${STREAM_DETECT_CORE_SOURCES})
set_target_properties(stream_detect_core PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(stream_detect_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/stream_detect
    ${CMAKE_CURRENT_SOURCE_DIR}/src/zero_point
    ${CMAKE_CURRENT_SOURCE_DIR}/src/edgedrawing
)
if(ENABLE_STREAM_DETECT_NDK_FALLBACK)
    target_compile_definitions(stream_detect_core PUBLIC LWS_STREAM_DETECT_NDK_FALLBACK=1)
endif()
if(ENABLE_ROCKCHIP_MPP)
    if(NOT ROCKCHIP_MPP_INCLUDE_DIR OR NOT ROCKCHIP_MPP_LIB)
        message(FATAL_ERROR "ENABLE_ROCKCHIP_MPP requires ROCKCHIP_MPP_INCLUDE_DIR and ROCKCHIP_MPP_LIB")
    endif()
    target_compile_definitions(stream_detect_core PRIVATE LWS_HAVE_ROCKCHIP_MPP=1)
    target_include_directories(stream_detect_core PRIVATE ${ROCKCHIP_MPP_INCLUDE_DIR})
    target_link_libraries(stream_detect_core PRIVATE ${ROCKCHIP_MPP_LIB})
endif()
target_link_libraries(stream_detect_core PUBLIC
    ${OpenCV_LIBS}
    opencv_stain_detect_core
    zero_point_core
)
if(ENABLE_EDGEDRAWING)
    target_compile_definitions(stream_detect_core PUBLIC ENABLE_EDGEDRAWING=1)
    target_link_libraries(stream_detect_core PUBLIC edgedrawing_core)
endif()
if(ENABLE_RKNN_STAIN_STREAM)
    target_compile_definitions(stream_detect_core PUBLIC ENABLE_RKNN_STAIN_STREAM=1)
endif()
if(ANDROID)
    target_link_libraries(stream_detect_core PUBLIC log)
    if(ENABLE_STREAM_DETECT_NDK_FALLBACK)
        target_link_libraries(stream_detect_core PUBLIC mediandk)
    endif()
endif()

# ── Sources ──────────────────────────────────────────────────
# Explicit list — do not GLOB (avoids linking test main() into libai.so).
set(AI_JNI_SOURCES
    src/central_scheduler.cpp
    src/config.cpp
    src/det_callback_json.cpp
    src/det_raw_concat.cpp
    src/frame_ring_buffer.cpp
    src/jni_bridge.cpp
    src/model_manager.cpp
    src/opencv_stain_detect_jni.cpp
    src/opencv_stain_detect_options.cpp
    src/opencv_stain_detect_session.cpp
    src/rknn_runner.cpp
    src/rknn_stain_detect_pp.cpp
    src/stain_infer_outcome.cpp
    src/stain_preprocess.cpp
    src/stain_worker_pool.cpp
    src/stream_detect_jni.cpp
    src/zero_point_jni.cpp
)
if(ENABLE_EDGEDRAWING)
    list(APPEND AI_JNI_SOURCES src/edgedrawing_jni.cpp)
endif()
add_library(yolo_postprocess STATIC
    cpp/yolo_postprocess/yolo_postprocess.cpp
    cpp/postprocess/det_decode.cpp
    cpp/postprocess/det_nms.cpp
)
set_target_properties(yolo_postprocess PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(yolo_postprocess PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/yolo_postprocess
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/postprocess
)

# ── Build as shared library (JNI) — Android product path ─────
if(ANDROID)
    option(BUILD_LIBAI "Build shared libai.so (JNI)" ON)
else()
    option(BUILD_LIBAI "Build shared libai.so (JNI)" OFF)
endif()
if(BUILD_LIBAI)
add_library(ai SHARED ${AI_JNI_SOURCES} ${MODEL_EMBED_OBJECTS})
# Fixed SONAME: libai.so (version is not part of the filename; LIB_VERSION still passed for metadata)
set_target_properties(ai PROPERTIES OUTPUT_NAME "ai")

target_include_directories(ai PRIVATE
    src
    ${RKNN_RT_INCLUDE}
)

target_link_libraries(ai PRIVATE
    ${OpenCV_LIBS}
    "${RKNN_RT_LIB}"
    yaml-cpp::yaml-cpp
    yolo_postprocess
    opencv_stain_detect_core
    zero_point_core
    stream_detect_core
)
if(ENABLE_EDGEDRAWING)
    target_link_libraries(ai PRIVATE edgedrawing_core)
endif()
target_compile_definitions(ai PRIVATE
    LENS_USE_REAL_RKNN_API=1
    LENS_LIB_VERSION="${LIB_VERSION}"
)
endif() # BUILD_LIBAI

# Verbose RKNN output attrs, buffer stats, and layout dual-read (YOLO stain path).
# Set OFF for quieter release builds (e.g. -DLENS_YOLO_PP_DIAG=OFF).
option(LENS_YOLO_PP_DIAG "Verbose YOLO/RKNN output diagnostics (tag YOLO_PP_DIAG)" OFF)
option(LWS_FRAME_RING_BUFFER "Dual-slot frame ring buffer in CentralScheduler (reduces BGR clones)" ON)
option(LENS_STAIN_PREPROCESS_SCALAR "Scalar BGR->NCHW preprocess instead of blobFromImage" OFF)
option(LENS_INFER_TIMING "Log preprocess/rknn/post ms in ModelManager::infer_stain" OFF)

if(TARGET ai)
    if(LENS_YOLO_PP_DIAG)
        target_compile_definitions(ai PRIVATE LENS_YOLO_PP_DIAG=1)
    endif()
    if(LENS_INFER_TIMING)
        target_compile_definitions(ai PRIVATE LENS_INFER_TIMING=1)
    endif()
    if(LWS_FRAME_RING_BUFFER)
        target_compile_definitions(ai PRIVATE LWS_FRAME_RING_BUFFER=1)
    endif()
    if(LENS_STAIN_PREPROCESS_SCALAR)
        target_compile_definitions(ai PRIVATE LENS_STAIN_PREPROCESS_SCALAR=1)
    endif()
endif()
if(LENS_INFER_TIMING)
    target_compile_definitions(yolo_postprocess PRIVATE LENS_INFER_TIMING=1)
    if(TARGET rknn_infer)
        target_compile_definitions(rknn_infer PRIVATE LENS_INFER_TIMING=1)
    endif()
    if(TARGET rknn_mem_demo)
        target_compile_definitions(rknn_mem_demo PRIVATE LENS_INFER_TIMING=1)
    endif()
endif()
if(LENS_STAIN_PREPROCESS_SCALAR)
    if(TARGET rknn_infer)
        target_compile_definitions(rknn_infer PRIVATE LENS_STAIN_PREPROCESS_SCALAR=1)
    endif()
endif()

# Android: link log for __android_log_print, no explicit pthread needed
# Linux:   link pthread
if(TARGET ai)
    if(ANDROID)
        target_link_libraries(ai PRIVATE log mediandk)
        # Keep JNI entry points visible when the linker uses --gc-sections (only Java calls them).
        target_link_options(ai PRIVATE
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeCreateOpencvStainDetectSession"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeDestroyOpencvStainDetectSession"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeOpencvStainDetectFromJpg"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeOpencvStainDetectFromRgb"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeOpencvStainDetectFromNv12"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeCreateOpencvZeroPointDetector"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeDestroyOpencvZeroPointDetector"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeOpencvZeroPointDetectFromJpg"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeOpencvZeroPointDetectFromRgb"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeOpencvZeroPointDetectFromNv12"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeCreateOpencvEdgeDrawingDetector"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeDestroyOpencvEdgeDrawingDetector"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeOpencvEdgeDrawingDetectFromJpg"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeOpencvEdgeDrawingDetectFromRgb"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeOpencvEdgeDrawingDetectFromNv12"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeRknnStainDetectFromVideoAndSave"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeRknnStainDetectFromJpg"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeRknnStainDetectFromNv12"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeRknnStainDetectFromRgb"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeStartStreamDetect"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeStopStreamDetect"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeSetStreamDetectLaserOn"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeIsStreamDetectRunning"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeSetStreamDetectListener"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeConfigureStreamDetect"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeSetStreamDetectBurstMode"
            "LINKER:--undefined=Java_com_lasercyber_lws_ai_NativeBridge_nativeSetStreamDetectZeroPointTargetMode")
    else()
        target_link_libraries(ai PRIVATE pthread)
    endif()

    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        add_custom_command(TARGET ai POST_BUILD
            COMMAND ${CMAKE_STRIP} $<TARGET_FILE:ai>
            COMMENT "Stripping release libai.so"
        )
    endif()
endif() # TARGET ai

# ── Standalone AI daemon (Unix socket IPC) ───────────────────
option(BUILD_LWS_AI_DAEMON "Build lws_ai_daemon executable" ON)
if(BUILD_LWS_AI_DAEMON)
    add_executable(lws_ai_daemon
        src/daemon/main.cpp
        src/daemon/daemon_ipc.cpp
        src/daemon/daemon_stream_controller.cpp
        src/opencv_stain_detect_session.cpp
        src/config.cpp
        src/opencv_stain_detect_options.cpp
        # RKNN stain cores (non-JNI) — live hook inside daemon; App no longer loads libai.
        src/central_scheduler.cpp
        src/det_callback_json.cpp
        src/det_raw_concat.cpp
        src/frame_ring_buffer.cpp
        src/model_manager.cpp
        src/rknn_runner.cpp
        src/rknn_stain_detect_pp.cpp
        src/stain_infer_outcome.cpp
        src/stain_preprocess.cpp
        src/stain_worker_pool.cpp
        ${MODEL_EMBED_OBJECTS}
    )
    target_compile_features(lws_ai_daemon PRIVATE cxx_std_17)
    target_include_directories(lws_ai_daemon PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/src/stream_detect
        ${CMAKE_CURRENT_SOURCE_DIR}/src/opencv_stain_detect
        ${CMAKE_CURRENT_SOURCE_DIR}/src/zero_point
        ${RKNN_RT_INCLUDE}
    )
    target_link_libraries(lws_ai_daemon PRIVATE
        stream_detect_core
        ${OpenCV_LIBS}
        yaml-cpp::yaml-cpp
        yolo_postprocess
        "${RKNN_RT_LIB}"
    )
    if(ANDROID)
        target_link_libraries(lws_ai_daemon PRIVATE log)
    else()
        target_link_libraries(lws_ai_daemon PRIVATE pthread)
        if(LWS_FRAME_RING_BUFFER)
            target_compile_definitions(lws_ai_daemon PRIVATE LWS_FRAME_RING_BUFFER=1)
        endif()
    endif()
    target_compile_definitions(lws_ai_daemon PRIVATE
        LENS_USE_REAL_RKNN_API=1
        LENS_LIB_VERSION="${LIB_VERSION}"
    )
    if(ENABLE_EDGEDRAWING)
        target_link_libraries(lws_ai_daemon PRIVATE edgedrawing_core)
    endif()
    if(ENABLE_STREAM_DETECT_NDK_FALLBACK)
        target_link_libraries(lws_ai_daemon PRIVATE mediandk)
    endif()
    if(ANDROID)
        # Child ProcessBuilder: resolve libs from $ORIGIN (nativeLibraryDir).
        target_link_options(lws_ai_daemon PRIVATE "-Wl,-rpath,\$ORIGIN")
    else()
        # App-owned: /opt/hmi/bin/lws_ai_daemon + /opt/hmi/lib/*.so
        target_link_options(lws_ai_daemon PRIVATE "-Wl,-rpath,\$ORIGIN/../lib")
    endif()
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        add_custom_command(TARGET lws_ai_daemon POST_BUILD
            COMMAND ${CMAKE_STRIP} $<TARGET_FILE:lws_ai_daemon>
            COMMENT "Stripping release lws_ai_daemon"
        )
    endif()
endif()

option(BUILD_RKNN_STAIN_DETECT_PP_SMOKE_TEST "Build RKNN stain contamination rule smoke test" ON)
if(BUILD_RKNN_STAIN_DETECT_PP_SMOKE_TEST AND NOT ANDROID)
    add_executable(rknn_stain_detect_pp_smoke_test
        src/rknn_stain_detect_pp_smoke_test.cpp
        src/rknn_stain_detect_pp.cpp
    )
    target_compile_features(rknn_stain_detect_pp_smoke_test PRIVATE cxx_std_17)
    target_include_directories(rknn_stain_detect_pp_smoke_test PRIVATE src)

    add_executable(preview_det_json_smoke_test
        src/preview_det_json_smoke_test.cpp
        src/det_callback_json.cpp
    )
    target_compile_features(preview_det_json_smoke_test PRIVATE cxx_std_17)
    target_include_directories(preview_det_json_smoke_test PRIVATE src)
endif()

option(BUILD_OPENCV_DETECT_CODES_SMOKE_TEST "Build unified OpenCV detect code/reason smoke test" ON)
if(BUILD_OPENCV_DETECT_CODES_SMOKE_TEST AND NOT ANDROID)
    add_executable(opencv_detect_codes_smoke_test
        src/opencv_detect/opencv_detect_codes_smoke_test.cpp
    )
    target_compile_features(opencv_detect_codes_smoke_test PRIVATE cxx_std_17)
    target_include_directories(opencv_detect_codes_smoke_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/src/opencv_stain_detect
        ${CMAKE_CURRENT_SOURCE_DIR}/src/zero_point
    )
    target_link_libraries(opencv_detect_codes_smoke_test PRIVATE
        opencv_stain_detect_core
        zero_point_core
    )

    add_executable(red_frame_validator_test
        src/opencv_detect/red_frame_validator_test.cpp
    )
    target_compile_features(red_frame_validator_test PRIVATE cxx_std_17)
    target_include_directories(red_frame_validator_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src/opencv_detect
    )
    target_link_libraries(red_frame_validator_test PRIVATE opencv_detect_common ${OpenCV_LIBS})

    add_executable(sps_dimensions_test
        src/stream_detect/sps_dimensions_test.cpp
        src/stream_detect/sps_dimensions.cpp
        src/stream_detect/rtsp_util.cpp
    )
    target_compile_features(sps_dimensions_test PRIVATE cxx_std_17)
    target_include_directories(sps_dimensions_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/src/stream_detect
    )
endif()

option(BUILD_OPENCV_STAIN_DETECT_INFER "Build offline lens_det infer CLI (tools/opencv_stain_detect_infer)" ON)
if(BUILD_OPENCV_STAIN_DETECT_INFER AND NOT ANDROID)
    add_executable(opencv_stain_detect_infer tools/opencv_stain_detect_infer/main.cpp)
    target_include_directories(opencv_stain_detect_infer PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src/lens_det
    )
    target_compile_features(opencv_stain_detect_infer PRIVATE cxx_std_17)
    target_link_libraries(opencv_stain_detect_infer PRIVATE opencv_stain_detect_core ${OpenCV_LIBS})
endif()

option(BUILD_ZERO_POINT_INFER "Build offline zero-point infer CLI (tools/zero_point_infer)" ON)
if(BUILD_ZERO_POINT_INFER AND NOT ANDROID)
    add_executable(zero_point_infer tools/zero_point_infer/main.cpp)
    target_include_directories(zero_point_infer PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src/zero_point
        ${CMAKE_CURRENT_SOURCE_DIR}/src/opencv_detect
    )
    target_link_libraries(zero_point_infer PRIVATE zero_point_core ${OpenCV_LIBS})
endif()

option(BUILD_EDGEDRAWING_INFER "Build offline EdgeDrawing infer CLI (tools/edgedrawing_infer)" ON)
if(BUILD_EDGEDRAWING_INFER AND NOT ANDROID)
    add_executable(edgedrawing_infer tools/edgedrawing_infer/main.cpp)
    target_include_directories(edgedrawing_infer PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src/edgedrawing
    )
    target_link_libraries(edgedrawing_infer PRIVATE edgedrawing_core ${OpenCV_LIBS})
endif()

option(BUILD_RKNN_INFER "Build offline RKNN infer CLI (tools/rknn_infer)" ON)
if(BUILD_RKNN_INFER AND NOT ANDROID)
    add_executable(rknn_infer
        tools/rknn_infer/main.cpp
        src/rknn_runner.cpp
        src/det_raw_concat.cpp
        src/stain_preprocess.cpp
    )
    target_include_directories(rknn_infer PRIVATE
        src
        tools/rknn_infer
        ${RKNN_RT_INCLUDE}
    )
    target_link_libraries(rknn_infer PRIVATE
        ${OpenCV_LIBS}
        "${RKNN_RT_LIB}"
        yolo_postprocess
    )
    target_compile_definitions(rknn_infer PRIVATE LENS_USE_REAL_RKNN_API=1)
    if(LENS_INFER_TIMING)
        target_compile_definitions(rknn_infer PRIVATE LENS_INFER_TIMING=1)
        target_compile_definitions(yolo_postprocess PRIVATE LENS_INFER_TIMING=1)
    endif()
    if(NOT ANDROID)
        target_link_libraries(rknn_infer PRIVATE pthread)
    endif()
endif()

option(BUILD_RKNN_MEM_DEMO "Build standalone RKNN memory demo executable" ON)
if(BUILD_RKNN_MEM_DEMO AND NOT ANDROID)
    add_executable(rknn_mem_demo
        src/rknn_demo_main.cpp
        src/rknn_runner.cpp
    )
    target_include_directories(rknn_mem_demo PRIVATE
        src
        ${RKNN_RT_INCLUDE}
    )
    target_link_libraries(rknn_mem_demo PRIVATE
        ${OpenCV_LIBS}
        "${RKNN_RT_LIB}"
    )
    target_compile_definitions(rknn_mem_demo PRIVATE LENS_USE_REAL_RKNN_API=1)
endif()
