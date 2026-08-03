# GStreamer security upgrade — acceptance notes

## Locked tip

| Component | Pin |
|-----------|-----|
| gstreamer1 / gst1-plugins-{base,good,bad} | **1.28.5** |
| host meson (Buildroot) | **1.5.2** (was 1.3.1; required for GST ≥ 1.26) |
| gstreamer1-rockchip | vendor `external/gstreamer-rockchip` (built OK vs 1.28.5) |
| Stamp | `overlay/third-party/gstreamer.version` → `1.28.5-rockchip-mpp-gst-rtsp` |
| Tools | `gst-inspect` / `gst-launch` forced via `-Dtools=enabled` in overlay `.mk` (Kconfig `INSTALL_TOOLS` also set). Export rejects known-stale 1.22.9 tool size. |
| Debug ABI | `-Dgst_debug=true` forced in overlay `.mk` + `BR2_PACKAGE_GSTREAMER1_GST_DEBUG=y`. Without this, core omits `_gst_debug_min` and product plugins fail to load. |
| RGA / preview FPS | Overlay `gstreamer1-rockchip.mk` always sets `-Drga=enabled` (stock keys only off `BR2_PREFER_ROCKCHIP_RGA`). Without RGA, `mppvideodec` has no `format`/`width`/`height` and Flutter preview falls back to CPU NV12→RGBA (~1fps). Export refuses `"RGA disabled at compile time"`. Also set `BR2_PREFER_ROCKCHIP_RGA=y` in `lws_hmi_gst_rtsp.config`. |

Security Center as of implement (2026-08-03): tip is still **1.28.5** (2026-07-08). SAs through SA-2026-0065 are in that release. **No post-tip overlay security patches** required yet. Prefer bumping to the next 1.28.x tip when published over long-lived backports.

## Hardening applied

| Tier | Status |
|------|--------|
| **H1** | gst-plugins-ugly remains disabled (`lws_hmi_gst_rtsp.config`); removed from `build-gstreamer.sh` package list |
| **H2** | WebRTC / DTLS / RFB / libav / Matroska / FLV not enabled; comments in config |
| **H3** | Disabled default-y AVI + wavparse; disabled 1.28 meson-auto plugins without Config.in (HIP, nvcodec, MSE, closedcaption, …) in overlay `gst1-plugins-bad.mk` |
| **H4** | `export-runtime-prebuilt.sh` allowlists product plugin `.so` set and drops stale `*.so.0.2209.0` ABI leftovers |
| **H5** | Prefer trusted local MediaMTX loopback RTSP URLs for Settings preview; do not feed untrusted user files into qtdemux/`isomp4` on device |

## Residual risk (required surface)

These remain enabled for product features and will keep attracting Security Advisories:

- **isomp4** (`qtdemux` / `qtmux`) — HAL RTSP→MP4 recording
- **videoparsers** (incl. H.264/H.265 parse) — preview + remux
- **rtspsrc / rtp / udp** — MediaMTX preview
- **audioparsers** — RTSP audio path (WAV demuxer plugin itself is off)

This change maximizes tip + patches + trim; it does **not** claim zero GStreamer CVEs.

## Follow-up process

1. Watch [GStreamer Security Center](https://gstreamer.freedesktop.org/security/) and 1.28.x release notes.
2. When a newer **1.28.x ≥ 1.28.5** ships (or a fix lands only as a patch), bump overlay `.mk` / `.hash` (or add overlay patches) and run:

```text
make apply-overlay
FORCE=1 make build-gstreamer
FORCE=1 make rebuild-flutter-embedded-linux
make apply-overlay
make build-rootfs
make upgrade
```

3. Do **not** treat `make build-rootfs` alone as sufficient after a GST recipe change (prebuilt stamp reuse).

## Device smoke (manual)

After `make upgrade`:

1. `gst-inspect-1.0 --version` → 1.28.5
2. `gst-inspect-1.0 rockchipmpp` loads
3. Settings camera preview (MediaMTX) shows H.264 and H.265 frames
4. HAL recording finalizes a non-empty MP4
