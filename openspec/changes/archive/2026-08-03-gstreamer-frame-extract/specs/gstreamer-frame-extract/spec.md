## ADDED Requirements

### Requirement: Local MP4 JPEG extract uses rootfs GStreamer

The product SHALL extract JPEG stills from local process-video MP4 files using the rootfs GStreamer stack (helper under `/usr/libexec/hmi/` or equivalent invoking `gst-launch-1.0` / documented pipeline), and MUST NOT require App-bundled `/opt/hmi/bin/ffmpeg` for Monitor covers or AI Vision offline sampling.

#### Scenario: Cover extract without bundled ffmpeg

- **WHEN** the HMI bundle has no `/opt/hmi/bin/ffmpeg` and rootfs GStreamer is present
- **THEN** cover JPEG extract for a valid local MP4 MUST still succeed via the GStreamer extract path

#### Scenario: Timed sample extract

- **WHEN** AI Vision requests a JPEG at media time T ms (T > 0)
- **THEN** the system MUST write a JPEG using the GStreamer extract path at that media time (within documented seek tolerance)

### Requirement: First-frame cover is display-order start

Cover extract at t≈0 MUST decode from the beginning of the file (not an input-side keyframe-only seek that skips early delta frames), matching the product intent of a true first usable frame.

#### Scenario: Cover matches early content

- **WHEN** cover extract runs for a newly recorded process video
- **THEN** the JPEG MUST reflect the first decodable display frame near the start of the file

### Requirement: Soft-fail extract preserves App stability

Extract failure (missing file, pipeline error, timeout) MUST soft-fail: log/record error, return null/failure to callers, and MUST NOT crash the HMI process.

#### Scenario: Corrupt or missing MP4

- **WHEN** extract is requested for a missing or undecodable path
- **THEN** the caller MUST receive failure without terminating the App

### Requirement: Implementation gated on GStreamer upgrade and playback patches

This capability SHALL be implemented only after `gstreamer-security-upgrade` has shipped the product GStreamer pin and eLinux video-player overlay fixes for VOD PTS pacing and no-op playback-rate seek are present on the validation tip (or an explicit spike documents extract success on that tip).

#### Scenario: Sequencing gate

- **WHEN** planning implementation work for this change
- **THEN** tasks MUST treat gst upgrade + video-player patches as prerequisites, not parallel product cutover on the pre-upgrade stack
