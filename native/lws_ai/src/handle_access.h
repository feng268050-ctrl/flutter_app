#pragma once

#include "config.h"

class CentralScheduler;

const AppConfig* lens_app_config_from_handle(long long native_handle);

/** RKNN {@link NativeBridge#nativeCreate} handle → live stain scheduler (null if invalid). */
CentralScheduler* central_scheduler_from_handle(long long native_handle);
