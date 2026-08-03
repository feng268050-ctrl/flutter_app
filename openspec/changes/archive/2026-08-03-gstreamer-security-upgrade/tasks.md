## 1. Version spike and overlay pin

- [x] 1.1 Confirm SDK pins (`GSTREAMER1_VERSION` / `GST1_PLUGINS_*` = 1.22.9) and inventory packages built by `scripts/build-gstreamer.sh`
- [x] 1.2 Spike Buildroot recipes for GStreamer **1.28.5** (core + base/good/bad at minimum); adapt `.mk` / `.hash` / meson options from newer BR if needed
- [x] 1.3 Spike `gstreamer1-rockchip` (and MPP/RGA as needed) against 1.28.5; add overlay patches or vendor bump if required
- [x] 1.4 If 1.28.5 cannot build, lock fallback ≥ **1.24.10** (prefer 1.26 tip) and document; otherwise lock ≥ **1.28.5** (newer 1.28.x tip if available)
- [x] 1.5 Add overlay `overlay/buildroot/package/gstreamer1/**` (+ rockchip gst overlay if needed) and extend `apply-overlay` sync
- [x] 1.6 Check GStreamer Security Center for SAs after the locked tip; add overlay security patches or bump tip as required (D2)

## 2. Rebuild prebuilt and eLinux

- [x] 2.1 `make apply-overlay` and confirm SDK recipes show the new versions
- [x] 2.2 `FORCE=1 make build-gstreamer` (or equivalent `br-make-packages` + export) so `prebuilt/gstreamer` is not 1.22.9
- [x] 2.3 Rebuild flutter-embedded-linux / refresh `.lws-gstreamer-video-player` against new staging `.pc`
- [x] 2.4 Update `overlay/third-party/gstreamer.version` (or stamp metadata) to reflect the new stack identity
- [x] 2.5 `make build-rootfs`; verify target/`prebuilt` `gst-inspect-1.0 --version` ≥ pin and `rockchipmpp` (or successor) loads

## 3. Optional hardening

- [x] 3.1 H1: Confirm gst-plugins-ugly remains disabled in `lws_hmi_gst_rtsp.config`
- [x] 3.2 H2: Inventory `usr/lib/gstreamer-1.0` in prebuilt; keep WebRTC/DTLS/RFB/libav and unused demuxers off unless product-required
- [x] 3.3 H3: Spike trimming non-essential good/base/bad plugins while keeping RTSP preview + MP4 remux + H.264/H.265 + ALSA path
- [x] 3.4 H4: If leftover unused `.so` remain, add runtime blacklist or stop exporting them from `export-runtime-prebuilt.sh`
- [x] 3.5 H5: Note App/HAL policy preference for trusted MediaMTX URLs / avoid untrusted local demux in acceptance notes

## 4. Ship, regress, residual risk

- [x] 4.1 `make upgrade` (or equivalent); on device confirm GStreamer ≥ pin and MediaMTX Settings preview shows frames
- [x] 4.2 Smoke: H.264 and H.265 RTSP preview; HAL recording finalizes non-empty MP4; MPP path still used
- [x] 4.3 Document residual risk on required isomp4 / videoparsers / RTSP plugins and list patches/hardening applied
- [x] 4.4 Note follow-up process: track next 1.28.x / Security Center and re-run prebuilt rebuild when bumping

### Spike notes (1.1–1.6)

- SDK confirmed **1.22.9** for core/base/good/bad; `build-gstreamer.sh` builds mpp/rga/gstreamer1-rockchip + gst family (ugly removed from package list — disabled in Kconfig and broke `br-make-packages`).
- **1.28.5** is still the tip (no 1.28.6); Security Center SAs through **2026-07-08** are in 1.28.5 — no post-tip overlay security patches yet.
- **Meson**: 1.28 requires ≥1.4; SDK host meson was **1.3.1** → overlay pin **meson 1.5.2** (`overlay/buildroot/package/meson/`) with Rockchip 1.3.x patches stashed.
- **gstreamer1-rockchip**: local `external/gstreamer-rockchip` declares project version 1.14.4 but only requires `gstreamer-1.0 >= 1.14`; built cleanly against 1.28.5 (`libgstrockchipmpp.so` exported).
- Rockchip **1.22.x** vendor patches on core/plugins are stashed (do not apply to 1.28); product MPP path is via rockchip plugin, not those patches.

### Acceptance

See [`acceptance.md`](acceptance.md) for residual risk, hardening table, and follow-up rebuild commands.

### Device verification (2026-08-03)

Automated on ynh960 after `make upgrade`:

- `gst-inspect-1.0 --version` → **1.28.5**
- Elements load: `rockchipmpp`, `rtspsrc`, `qtmux`, `h264parse`, `h265parse`, `mppvideodec`
- MediaMTX running (`/opt/hmi/bin/mediamtx`, listen **:8554**); `hmi.service` active
- Mid-ship fixes: `-Dgst_debug=true` (plugin `dlopen`); overlay `gstreamer1-rockchip.mk` force `-Drga=enabled` (`mppvideodec` `format`/`width`/`height` for HW RGBA)

**Operator confirmed:** Settings RTSP preview frame rate normal again after RGA rebuild.
