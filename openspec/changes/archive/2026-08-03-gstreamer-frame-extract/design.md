## Context

Playback on ynh960 uses rootfs GStreamer (`prebuilt/gstreamer` → `lws-hmi-prebuilt-gstreamer`) plus eLinux `libvideo_player_plugin.so`. Cover JPEG (`VideoCoverExtractor`) and AI Vision offline samples (`ProcessVideoAiFrameSampler`) instead spawn App-bundled `/opt/hmi/bin/ffmpeg` (`hmi_bundle_install_ffmpeg`, soft-skip if missing). That splits demux/decode across two stacks for the same local MP4s.

Related in-flight work:

1. **`gstreamer-security-upgrade`** — pin ≥ 1.28.5 and rebuild prebuilt + eLinux plugin linkage.
2. **eLinux video-player overlay** — live RTSP / MPP (`0002`), VOD PTS pacing (`0006-video-player-vod-pts-pace.py`), no-op `SetPlaybackRate` skip (`0007`) — stabilize Monitor local playback before adding more GStreamer consumers.

This change starts **after** those land on the board tip (or an explicit spike proves extract pipelines work on the upgraded stack).

## Goals / Non-Goals

**Goals:**

- One multimedia stack for product: GStreamer for playback **and** MP4→JPEG extract (first frame + seek-by-time).
- Preserve cover upload and AI Vision sample contracts (paths, soft-fail, 500 ms grid).
- Remove product dependency on `/opt/hmi/bin/ffmpeg`.

**Non-Goals:**

- Replacing the Flutter `video_player` / eLinux texture path.
- Changing R2 keys, SSE shapes, or daemon `offline_infer_opencv_stain_jpg`.
- Mandating GStreamer for host-only measurement scripts (`measure-ip-camera-rtsp-ssh.sh`).
- Implementing this before gst upgrade + playback patches are accepted on device.

## Decisions

### D1 — Sequence: after gst upgrade + video-player patches

Do not implement extract cutover on 1.22.9 + broken VOD sync path. Gate: device tip has GStreamer ≥ upgraded pin, `VOD BufferProbe paces to PTS` and `SetPlaybackRate: skip no-op rate seek` markers in `libvideo_player_plugin.so`, and local MP4 play is acceptable.

**Alternative:** implement extract on current tip in parallel — **rejected** (double rebuild churn; decode/plugin set may move with 1.28).

### D2 — Prefer small `/usr/libexec/hmi/` helper over Dart-owned mega `gst-launch` strings

Ship e.g. `extract-video-frame.sh` (or a tiny C helper) that takes `input`, `output.jpg`, optional `start_ms`, writes one JPEG using rootfs `gst-launch-1.0` / `gst-launch` with a documented pipeline (filesrc → decodebin/qtdemux path → videoconvert → jpegenc → filesink; accurate seek for non-zero times). Dart keeps `VideoCoverExtractor` / sampler APIs but invokes the helper via `Process.run`.

**Alternatives:**

| Option | Verdict |
|--------|---------|
| Keep calling ffmpeg | Rejected — contradicts single-stack policy |
| Pure Dart FFI to libgstreamer | Deferred — heavier than helper; revisit if helper latency is bad |
| Extend `libvideo_player_plugin.so` with “export frame” | Optional later; couples UI plugin to offline batch jobs |

### D3 — First-frame semantics: decode from start, not input-side keyframe seek

Cover extract MUST produce display-order first usable frame (parity with Android MMR / current intent after removing ffmpeg `-ss` before `-i`). Timed samples MAY use accurate seek after demux (accept nearest decodable frame with documented tolerance ≤ one GOP if needed).

### D4 — Remove App ffmpeg install once cutover verified

After board smoke (cover + one AI sample session), drop `hmi_bundle_install_ffmpeg` from product bundle path (or gate behind explicit env for transition). Host scripts that push a temp ffmpeg remain allowed.

## Risks / Trade-offs

- **[Risk] MPP/decodebin pipeline fails on some remuxed MP4s** → Mitigation: spike matrix on device recordings; soft-fail same as today; optional software decode fallback element if product allows.
- **[Risk] Seek accuracy worse than ffmpeg `-ss` after `-i`** → Mitigation: document tolerance; prefer accurate seek flags; AI grid already skips t=0.
- **[Risk] gst-launch process spawn latency vs static ffmpeg** → Mitigation: measure; if too slow for 500 ms AI grid, move to long-lived helper or appsink in a small daemon — out of first slice.
- **[Risk] Missing jpegenc / decoder plugins after hardening trim** → Mitigation: list required elements in acceptance; block gst hardening from removing them.

## Migration Plan

1. Land / verify `gstreamer-security-upgrade` + video-player patches on ynh960.
2. Spike `gst-launch` extract on device; lock pipeline string in helper.
3. Point Dart extractors at helper; keep ffmpeg fallback behind flag for one release if needed.
4. Remove bundle ffmpeg; update specs archive; `make build-app` / `push-app` (+ rootfs if helper is fs-overlay).

## Open Questions

- ~~Exact pipeline element set on ≥1.28.5 + rockchipmpp (spike).~~ → Resolved (spike 2026-08-03).
- Whether cover scale-down (Android 720px max edge) stays in ffmpeg-equivalent `videoscale` or remains optional.

## Spike notes (locked pipeline)

Device tip: GStreamer **1.28.5**, `mppjpegenc` present (software `jpegenc` **not** in harden allowlist — do not require it).

Working single-frame encode (shell proof):

```text
filesrc ! decodebin ! videoconvert ! video/x-raw,format=NV12 !
videorate drop-only=true ! video/x-raw,framerate=1/1000 !
mppjpegenc rc-mode=fixqp q-factor=80 ! filesink
```

Without `videorate` / single-buffer limit, `mppjpegenc` + `filesink` concatenates many JPEGs into one huge file. Default CBR (`bps=0`) asserts in `mpp_enc` on RK3566 — always use `rc-mode=fixqp` for stills.

Product helper: `native/extract_video_frame/extract_video_frame.c` → `/usr/libexec/hmi/extract-video-frame` (appsink + optional ACCURATE seek; KEY_UNIT fallback). Required elements already on tip: `filesrc`, `decodebin`, `videoconvert`, `videorate`, `mppjpegenc`, `appsink`.

**HMI stability:** Do not overlap helper MPP encode with eLinux `video_player` MPP decode (Videos detail must serialize cover extract then player init; reuse `/var/lib/hmi/video-covers/` cache).
