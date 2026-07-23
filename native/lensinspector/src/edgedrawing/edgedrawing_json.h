#pragma once

#include "edgedrawing_types.h"

#include <string>

namespace edgedrawing {

std::string frameResultToJson(const FrameResult& result);

std::string errorJson(int code, const std::string& reason);

}  // namespace edgedrawing
