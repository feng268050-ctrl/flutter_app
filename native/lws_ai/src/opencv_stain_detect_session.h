#pragma once

#include "opencv_stain_detect/opencv_stain_detect_analyzer.h"

#include <string>

namespace opencv_stain_detect {

/** Holds OpenCV stain-detect options loaded from deployed config.yaml (independent of RKNN engine handle). */
class Session {
public:
    Session(const std::string& config_yaml_path, const std::string& project_root);

    const Options& options() const { return options_; }
    GlobalErodeIslandSlotSession& islandSlotSession() { return island_slot_session_; }
    const GlobalErodeIslandSlotSession& islandSlotSession() const { return island_slot_session_; }

private:
    Options options_;
    GlobalErodeIslandSlotSession island_slot_session_;
};

}  // namespace opencv_stain_detect
