## ADDED Requirements

### Requirement: Product HMI does not ship ffmpeg for frame extract

After `gstreamer-frame-extract` is implemented, the product HMI image / App bundle SHALL NOT require `/opt/hmi/bin/ffmpeg` for process-video covers or AI Vision offline frame samples. Rootfs GStreamer MUST provide the elements needed for the documented extract helper pipeline.

#### Scenario: Bundle without product ffmpeg

- **WHEN** `make build-app` produces `/opt/hmi` for a release tip with frame-extract cutover complete
- **THEN** product cover and AI sample paths MUST work without installing ffmpeg into `/opt/hmi/bin`
- **AND** host-only measurement scripts MAY still use a separate ffmpeg binary outside the product HMI contract
