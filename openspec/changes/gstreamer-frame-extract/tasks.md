## 1. Prerequisites (do not cut over before these)

- [ ] 1.1 Confirm `gstreamer-security-upgrade` is applied on the validation tip (GStreamer ≥ pin; `make build-gstreamer` / rootfs refreshed)
- [ ] 1.2 Confirm eLinux video-player markers on device/prebuilt: `VOD BufferProbe paces to PTS` and `SetPlaybackRate: skip no-op rate seek`
- [ ] 1.3 Smoke local MP4 playback on Monitor Videos detail (play + visible frames at ~1×) before starting extract work

## 2. Spike GStreamer extract pipeline

- [ ] 2.1 On device, spike `gst-launch-1.0` (or equivalent) MP4 → single JPEG at t≈0 without input-side keyframe-only seek
- [ ] 2.2 Spike extract at media time T ms (AI sample grid); document seek flags and tolerance
- [ ] 2.3 List required GStreamer elements; ensure gst hardening / `lws_hmi_gst_*` does not omit them
- [ ] 2.4 Record chosen pipeline string(s) in design notes or helper header comment

## 3. Rootfs helper

- [ ] 3.1 Add `/usr/libexec/hmi/extract-video-frame` (script or small binary): args for input path, output JPEG, optional start_ms
- [ ] 3.2 Wire into rootfs overlay + `post-build` / PATH policy as needed; timeout and non-zero exit on failure
- [ ] 3.3 `make apply-overlay` → `make build-rootfs` → `make upgrade`; verify helper on device

## 4. App cutover

- [ ] 4.1 Point `VideoCoverExtractor` at the GStreamer helper (keep API/cache dirs); remove ffmpeg `-ss`/`Process.run` product path
- [ ] 4.2 Point `ProcessVideoAiFrameSampler` at the same helper for timed samples
- [ ] 4.3 Optional: short-lived ffmpeg fallback flag for one tip; default off on release tip
- [ ] 4.4 Stop product `hmi_bundle_install_ffmpeg` (or make it non-default); update bundle docs/comments
- [ ] 4.5 `make build-app` → `make push-app`; smoke cover poster, cover upload drain, one AI Vision detect sample session

## 5. Verify and docs

- [ ] 5.1 Confirm `/opt/hmi/bin/ffmpeg` absent (or unused) on product path while covers + AI samples still work
- [ ] 5.2 Note host `measure-ip-camera-rtsp-ssh.sh` may still use separate ffmpeg (out of product contract)
- [ ] 5.3 Archive this change when acceptance passes
