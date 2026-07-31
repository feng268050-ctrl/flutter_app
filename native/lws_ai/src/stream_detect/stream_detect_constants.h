#pragma once

namespace stream_detect {

/** Initial RTSP reconnect delay after read failure (Phase 4 field-tunable). */
constexpr int kReconnectBackoffInitialMs = 250;
/** Maximum RTSP reconnect backoff (exponential cap). */
constexpr int kReconnectBackoffMaxMs = 5000;

}  // namespace stream_detect
