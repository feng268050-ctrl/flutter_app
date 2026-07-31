# Host-only edgedrawing_infer (Homebrew OpenCV + ximgproc). Not used for Android libai.so.
cmake_minimum_required(VERSION 3.14)
project(edgedrawing_host_infer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(LENS_ROOT "${CMAKE_CURRENT_LIST_DIR}/..")

find_package(OpenCV REQUIRED COMPONENTS core imgproc imgcodecs ximgproc)

add_library(opencv_detect_common STATIC
    ${LENS_ROOT}/src/opencv_detect/opencv_detect_json.cpp
    ${LENS_ROOT}/src/opencv_detect/red_frame_validator.cpp
)
target_include_directories(opencv_detect_common PUBLIC
    ${LENS_ROOT}/src/opencv_detect
)
target_link_libraries(opencv_detect_common PUBLIC ${OpenCV_LIBS})

add_library(roi_config_common STATIC
    ${LENS_ROOT}/src/zero_point/roi_config.cpp
)
target_include_directories(roi_config_common PUBLIC
    ${LENS_ROOT}/src/zero_point
    ${LENS_ROOT}/src/opencv_detect
)

add_library(edgedrawing_core STATIC
    ${LENS_ROOT}/src/edgedrawing/radial_scan_core.cpp
    ${LENS_ROOT}/src/edgedrawing/radial_scan_debug.cpp
    ${LENS_ROOT}/src/edgedrawing/edgedrawing_util.cpp
    ${LENS_ROOT}/src/edgedrawing/edgedrawing_json.cpp
    ${LENS_ROOT}/src/edgedrawing/edgedrawing_detector.cpp
    ${LENS_ROOT}/src/edgedrawing/edgedrawing_context.cpp
)
target_include_directories(edgedrawing_core PUBLIC
    ${LENS_ROOT}/src/edgedrawing
    ${LENS_ROOT}/src/zero_point
    ${LENS_ROOT}/src/opencv_detect
)
target_link_libraries(edgedrawing_core PUBLIC
    roi_config_common
    opencv_detect_common
    ${OpenCV_LIBS}
)

add_executable(edgedrawing_infer ${LENS_ROOT}/tools/edgedrawing_infer/main.cpp)
target_include_directories(edgedrawing_infer PRIVATE ${LENS_ROOT}/src/edgedrawing)
target_link_libraries(edgedrawing_infer PRIVATE edgedrawing_core ${OpenCV_LIBS})

add_executable(red_frame_validator_test ${LENS_ROOT}/src/opencv_detect/red_frame_validator_test.cpp)
target_include_directories(red_frame_validator_test PRIVATE ${LENS_ROOT}/src/opencv_detect)
target_link_libraries(red_frame_validator_test PRIVATE opencv_detect_common ${OpenCV_LIBS})
