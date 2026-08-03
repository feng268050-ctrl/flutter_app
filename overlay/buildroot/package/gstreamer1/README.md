# GStreamer overlay pin (security upgrade)

Product pin: **GStreamer 1.28.5** (core + plugins-base/good/bad).

- Recipes under `gstreamer1/`, `gst1-plugins-{base,good,bad}/` are synced into the SDK by `scripts/apply-overlay.sh` (`sync_gstreamer1_package`).
- Rockchip vendor patches written for **1.22.9** are stashed under `.lws-rockchip-gst-patches-disabled/` — they do not apply to 1.28. Hardware decode remains via `gstreamer1-rockchip` + MPP/RGA.
- Host **Meson ≥ 1.4** is required; see sibling `overlay/buildroot/package/meson/` (1.5.2).
- `gst-plugins-ugly` stays disabled (`lws_hmi_gst_rtsp.config`).
- Rebuild: `make apply-overlay`, then `FORCE=1 make build-gstreamer`, then rebuild flutter-embedded-linux and `make build-rootfs`.

Security Center tip at implement time: **1.28.5** (2026-07-08). Post-tip SAs: none published yet — add overlay patches or bump the tip when they land.
