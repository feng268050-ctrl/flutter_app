## Why

Playback already depends on rootfs GStreamer (including Rockchip MPP). Cover JPEG and AI Vision offline frame samples still shell out to a bundled `/opt/hmi/bin/ffmpeg`, duplicating demux/decode stacks, license/CVE surface, and App bundle weight. Once GStreamer is upgraded and the eLinux video-player patches are stable, frame extract should use the same ecosystem already shipped for playback.

## What Changes

- Add a **GStreamer-based JPEG frame extract** path (CLI `gst-launch` helper and/or short native/Dart-invoked pipeline) that can take a local MP4 and media time and write a JPEG under the existing cover/AI sample directories.
- Switch `VideoCoverExtractor` and `ProcessVideoAiFrameSampler` off bundled ffmpeg onto that path (same call sites and cache layout).
- Stop installing `/opt/hmi/bin/ffmpeg` into the HMI bundle for product features; keep host-only ffmpeg scripts (e.g. bitrate measure) out of scope or explicitly optional.
- Document sequencing: **after** `gstreamer-security-upgrade` lands and video-player overlay fixes (`0002` / VOD PTS pace / `0007` no-op rate seek) are on the board tip.
- **Non-goals:** replacing GStreamer playback with ffmpeg; rewriting AI daemon infer APIs; changing R2 cover upload contract beyond the extract backend.

## Capabilities

### New Capabilities

- `gstreamer-frame-extract`: Product requirement that local MP4 → JPEG frame extract (cover + timed AI samples) uses rootfs GStreamer, not App-bundled ffmpeg, with parity on first-frame / timestamp semantics and soft-fail behavior.

### Modified Capabilities

- `process-video`: Cover JPEG extraction MUST use GStreamer frame extract (not bundled ffmpeg).
- `process-video-ai-sse`: Offline sample JPEG extraction MUST use GStreamer frame extract.
- `process-video-cloud-upload`: Cover-before-video upload remains; extract backend changes to GStreamer (failure semantics unchanged).
- `buildroot-lws-hmi-image` / App bundle notes: product image SHALL NOT require `/opt/hmi/bin/ffmpeg` for Monitor covers or AI Vision sampling (host tooling may still use ffmpeg).

## Impact

- App: `video_cover_extractor.dart`, `process_video_ai_frame_sampler.dart`, `scripts/hmi-bundle-common.sh` (`hmi_bundle_install_ffmpeg`).
- Rootfs: rely on existing GStreamer plugins (decode/jpegenc/filesink or equivalent); may need a small `/usr/libexec/hmi/` helper script if Dart should not own long `gst-launch` lines.
- Sequencing / deps: blocked on `openspec/changes/gstreamer-security-upgrade` + stable eLinux video-player patches; coordinate rebuild after gst tip if pipeline elements change.
- Residual: host `scripts/measure-ip-camera-rtsp-ssh.sh` may keep a host/device temp ffmpeg — not product HMI playback/cover path.
