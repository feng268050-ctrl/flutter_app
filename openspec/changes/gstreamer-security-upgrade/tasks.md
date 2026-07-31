## 1. Version spike and overlay pin

- [ ] 1.1 Confirm SDK pins (`GSTREAMER1_VERSION` / `GST1_PLUGINS_*` = 1.22.9) and inventory packages built by `scripts/build-gstreamer.sh`
- [ ] 1.2 Spike Buildroot recipes for GStreamer **1.28.5** (core + base/good/bad at minimum); adapt `.mk` / `.hash` / meson options from newer BR if needed
- [ ] 1.3 Spike `gstreamer1-rockchip` (and MPP/RGA as needed) against 1.28.5; add overlay patches or vendor bump if required
- [ ] 1.4 If 1.28.5 cannot build, lock fallback ≥ **1.24.10** (prefer 1.26 tip) and document; otherwise lock ≥ **1.28.5** (newer 1.28.x tip if available)
- [ ] 1.5 Add overlay `overlay/buildroot/package/gstreamer1/**` (+ rockchip gst overlay if needed) and extend `apply-overlay` sync
- [ ] 1.6 Check GStreamer Security Center for SAs after the locked tip; add overlay security patches or bump tip as required (D2)

## 2. Rebuild prebuilt and eLinux

- [ ] 2.1 `make apply-overlay` and confirm SDK recipes show the new versions
- [ ] 2.2 `FORCE=1 make build-gstreamer` (or equivalent `br-make-packages` + export) so `prebuilt/gstreamer` is not 1.22.9
- [ ] 2.3 Rebuild flutter-embedded-linux / refresh `.lws-gstreamer-video-player` against new staging `.pc`
- [ ] 2.4 Update `overlay/third-party/gstreamer.version` (or stamp metadata) to reflect the new stack identity
- [ ] 2.5 `make build-rootfs`; verify target/`prebuilt` `gst-inspect-1.0 --version` ≥ pin and `rockchipmpp` (or successor) loads

## 3. Optional hardening

- [ ] 3.1 H1: Confirm gst-plugins-ugly remains disabled in `lws_hmi_gst_rtsp.config`
- [ ] 3.2 H2: Inventory `usr/lib/gstreamer-1.0` in prebuilt; keep WebRTC/DTLS/RFB/libav and unused demuxers off unless product-required
- [ ] 3.3 H3: Spike trimming non-essential good/base/bad plugins while keeping RTSP preview + MP4 remux + H.264/H.265 + ALSA path
- [ ] 3.4 H4: If leftover unused `.so` remain, add runtime blacklist or stop exporting them from `export-runtime-prebuilt.sh`
- [ ] 3.5 H5: Note App/HAL policy preference for trusted MediaMTX URLs / avoid untrusted local demux in acceptance notes

## 4. Ship, regress, residual risk

- [ ] 4.1 `make upgrade` (or equivalent); on device confirm GStreamer ≥ pin and MediaMTX Settings preview shows frames
- [ ] 4.2 Smoke: H.264 and H.265 RTSP preview; HAL recording finalizes non-empty MP4; MPP path still used
- [ ] 4.3 Document residual risk on required isomp4 / videoparsers / RTSP plugins and list patches/hardening applied
- [ ] 4.4 Note follow-up process: track next 1.28.x / Security Center and re-run prebuilt rebuild when bumping
