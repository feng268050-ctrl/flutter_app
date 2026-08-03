## ADDED Requirements

### Requirement: Process-video cover stills use GStreamer frame-extract

When the App extracts a local JPEG cover for a process-video row (detail poster, upload, or cache under `/var/lib/hmi/video-covers/`), it SHALL use the product GStreamer frame-extract path defined by `gstreamer-frame-extract` and MUST NOT depend on App-bundled ffmpeg for that operation.

#### Scenario: Detail poster without ffmpeg binary

- **WHEN** the operator opens process-video detail and cover extract runs
- **THEN** a JPEG poster MUST be obtainable via GStreamer when the MP4 is valid and rootfs GStreamer is present
