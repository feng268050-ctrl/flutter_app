#include "opencv_stain_detect_session.h"

#include "config.h"
#include "opencv_detect/red_frame_validator.h"
#include "opencv_stain_detect_options.h"

namespace opencv_stain_detect {

Session::Session(const std::string& config_yaml_path, const std::string& project_root) {
    const AppConfig config = load_config(config_yaml_path, project_root);
    opencv_detect::setRedFrameGateEnabled(config.opencv_detect.enable_red_frame_gate);
    options_ = opencvStainDetectOptionsFromAppConfig(config);
}

}  // namespace opencv_stain_detect
