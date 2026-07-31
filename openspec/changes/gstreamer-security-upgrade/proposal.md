## Why

Device and Buildroot ship **GStreamer 1.22.9** (core + plugins-base/good/bad + Rockchip MPP plugin via `make build-gstreamer` → `prebuilt/gstreamer`). The **1.22** series is superseded (last point release **1.22.12**). An NVD / GStreamer Security Center review against 1.22.9 found many **Critical/High** issues still open on that pin — notably the **2024-12 GHSL batch** (e.g. CVE-2024-47537 and related MP4/WAV findings) that need **≥ 1.24.10** (1.22.12 alone is insufficient), plus later 1.26/1.28 series advisories through **1.28.5** (2026-07-08). Product attack surface includes **qtdemux (isomp4)**, **wavparse**/audioparsers, **rtspsrc**, and **h265parse** for MediaMTX preview and HAL RTSP→MP4 recording — so we should take the supported tip and reduce unused plugins even when future CVEs on required elements cannot be eliminated completely.

## What Changes

- Pin the product GStreamer stack (**gstreamer1**, **gst1-plugins-base/good/bad**, and any other co-versioned gst1 packages we build) from **1.22.9 → 1.28.5** (floor **≥ 1.28.5**; newer 1.28.x tip at implement time if available) via git-tracked overlay recipes under `overlay/buildroot/package/gstreamer1/` (+ Rockchip `gstreamer1-rockchip` adaptation as needed).
- Carry **overlay security patches** on top of the locked tip when GStreamer Security Center publishes fixes that are not yet in a newer point release (or when Rockchip plugins need product-local fixes).
- Rebuild through the existing prebuilt path: `scripts/br-make-packages.sh` / `make build-gstreamer` → refresh `prebuilt/gstreamer` → rebuild **flutter-embedded-linux** GStreamer video player linkage → `make build-rootfs` / `make upgrade`.
- Apply **optional hardening**: keep **ugly** disabled; omit or denylist plugins not required for RTSP preview / MP4 remux (e.g. WebRTC/DTLS/RFB/AV1/unused demuxers when product-unused); prefer Buildroot plugin Kconfig off over runtime denylist when feasible.
- Document residual risk: required **isomp4** / **videoparsers** / **RTSP** surface will keep receiving advisories; this change maximizes available tip + patches + trim, not zero CVE forever.
- **Out of scope:** replacing GStreamer; rewriting Flutter preview/recorder APIs; enabling gst-plugins-ugly or gst-libav solely for feature growth; claiming closure of every NVD hit on unused plugins we never ship.

## Capabilities

### New Capabilities

- `buildroot-gstreamer-security`: Overlay-owned GStreamer 1.28.5+ pin, co-versioned plugins, optional post-tip security patches, Rockchip gst/MPP rebuild contract, optional plugin-surface hardening, residual-risk documentation, and device/prebuilt verification.

### Modified Capabilities

- `buildroot-lws-hmi-image`: Product GStreamer/MPP runtime MUST ship the overlay-pinned ≥ 1.28.5 stack (not vendor 1.22.9), while preserving RTSP preview + MP4 recording requirements.
- `linux-sdk-own-tree`: Confirm gstreamer1 family (+ rockchip gst) overlay pins stay on the always-injected Buildroot package sync path.

## Impact

- Overlay: `overlay/buildroot/package/gstreamer1/**` (and rockchip `gstreamer1-rockchip` if overlaid), `lws_hmi_gst_rtsp.config` trim knobs, `overlay/third-party/gstreamer.version` stamp text as needed, `scripts/apply-overlay.sh` sync.
- Build: `make apply-overlay`, `FORCE=1 make build-gstreamer` (or `br-make-packages` for gst packages), `make build-flutter-embedded-linux` (or equivalent stamp refresh), `make build-rootfs`, `make upgrade`.
- Runtime regression: Settings camera preview (MediaMTX RTSP), HAL RTSP remux to MP4, Rockchip MPP decode path, eLinux `libvideo_player_plugin.so`.
- Cross-change: independent of OpenSSL/BlueZ/kernel LTS; may need glib/meson/BR recipe tweaks for 1.28.
- Residual: future SAs against enabled isomp4/H.265/RTSP; unused-plugin CVEs mitigated only when those plugins stay out of the image.
