## Context

Product GStreamer is built in Rockchip Buildroot (`GSTREAMER1_VERSION = 1.22.9` and matching `GST1_PLUGINS_*_VERSION`), then exported by `scripts/build-gstreamer.sh` into `prebuilt/gstreamer/target` and overlaid via `lws_hmi_gst_prebuilt.config`. Fragment `lws_hmi_gst_rtsp.config` enables a trimmed set for MediaMTX preview + HAL recording: core, base (app/alsa/tcp/videoconvert/…), good (rtp/rtsp/udp/**isomp4**/audioparsers), bad (videoparsers/kms/sdp/faad), Rockchip MPP (`gstreamer1-rockchip`), RGA. **gst-plugins-ugly is not set.** Flutter eLinux links `flutterpi_gstreamer_video_player` / `libvideo_player_plugin.so` against staging GStreamer `.pc` files.

Device audit (2026-07-31): runtime **1.22.9**; plugins include **qtdemux**, **wavparse**, **rtspsrc**, **h265parse**, **av1parse**, **rockchipmpp**.

Security center (as of 2026-07-08): **1.28.5** is the latest 1.28 bug-fix and bundles a large security batch (SA-2026-0001 … SA-2026-0065 family, including MP4/WAV/H.265/H.266/WebRTC/DTLS/RFB and earlier 2024–2025 advisories absorbed into the 1.24→1.28 lineage). Jumping only to **1.22.12** does **not** close the 2024-12 Critical demuxer set.

Philosophy: **take tip 1.28.5 + overlay patches when needed + trim unused plugins**; document residual risk on required surface.

## Goals / Non-Goals

**Goals:**

- Ship co-versioned GStreamer userspace **≥ 1.28.5** from overlay-owned recipes.
- Preserve product behaviors: local MediaMTX RTSP preview (H.264/H.265 + MPP), HAL encoded remux to MP4 (`isomp4` / qtmux).
- Rebuild prebuilt + eLinux video player so staging ABI and rootfs match.
- Apply optional hardening that does not break those behaviors.
- Carry post-tip security patches when a newer SA lands before the next point release.
- Be honest about residual CVEs on required plugins.

**Non-Goals:**

- Claiming zero GStreamer CVEs after this change.
- Waiting for a perfect NVD-clean CPE before shipping 1.28.5.
- Replacing GStreamer or changing Dart/Flutter preview APIs.
- Enabling ugly/libav for convenience.
- Fixing Rockchip kernel V4L2/MPP driver CVEs via this change.

## Decisions

### D1 — Target: GStreamer **1.28.5** (or newer 1.28.x tip)

Lock `GSTREAMER1_VERSION` and matching `GST1_PLUGINS_{BASE,GOOD,BAD,…}_VERSION` (and any other co-versioned gst1 packages we compile) to **1.28.5**, or the newest **1.28.x** security tip at implement time if released. Prefer full recipe overlays under `overlay/buildroot/package/gstreamer1/<pkg>/` synced by `apply-overlay`.

**Alternatives considered:**

| Option | Verdict |
|--------|---------|
| Stay on 1.22.9 + cherry-pick Criticals | Rejected — incomplete SoT, huge patch debt |
| Jump only to 1.22.12 | Rejected — misses 2024-12 Critical batch |
| Jump to 1.24.10+ only | Acceptable fallback if 1.28 fails spike; prefer 1.28.5 per product ask |
| Jump to 1.26.x tip | Acceptable alternate if 1.28 BR/meson/Rockchip incompatible; document |

Floor for acceptance of the preferred path: **≥ 1.28.5**. Fallback floor if 1.28 cannot build: **≥ 1.24.10** with explicit design note and still apply hardening.

### D2 — Overlay patches on top of the tip

Maintain `overlay/buildroot/package/gstreamer1/<pkg>/` patch series for:

1. Security Center fixes published **after** the locked tarball (until the next point release can be adopted).
2. Buildroot / meson / aarch64 build fixes required to compile 1.28.5 in this SDK.
3. Minimal Rockchip `gstreamer1-rockchip` API adaptions if upstream plugin breaks against 1.28.

Do **not** use long-lived backports as a substitute for staying on an EOL 1.22 line.

### D3 — Rebuild contract: prebuilt + eLinux, not rootfs alone

Changing GST recipes **must** invalidate and rebuild:

1. `bash scripts/br-make-packages.sh gstreamer …` (or `FORCE=1 make build-gstreamer`)
2. Export `prebuilt/gstreamer/target`
3. Rebuild flutter-embedded-linux so `.lws-gstreamer-video-player` matches new `.so` / `.pc`
4. `make apply-overlay` + `make build-rootfs` (+ `make upgrade`)

`build-rootfs` alone MUST NOT be treated as sufficient (prebuilt stamp reuse is a known footgun).

### D4 — Optional hardening ladder (apply what product allows)

| Tier | Action | Default |
|------|--------|---------|
| **H1** | Keep **gst-plugins-ugly** disabled | **Yes** (already) |
| **H2** | Do not enable **gst1-libav** / unused bad plugins (WebRTC, DTLS, RFB/VNC, RealMedia, ASF, Matroska demux if unused) | **Yes** — leave off unless a product path needs them |
| **H3** | Trim good/base plugins not required for RTSP preview + MP4 remux + local ALSA (e.g. drop AV1 parse if unused; review audioparsers/wav surface) | Spike — keep **isomp4**, **rtp/rtsp/udp**, **videoparsers**, **app**, **tcp** |
| **H4** | Runtime `GST_PLUGIN_FEATURE_RANK` / blacklist unused `.so` if compile-time trim is incomplete | Only if H2/H3 leave residual `.so` in `usr/lib/gstreamer-1.0` |
| **H5** | Prefer trusted local MediaMTX loopback URLs; avoid feeding untrusted user files into qtdemux on device | App/HAL policy note — assist only |

**Must keep:** RTSP/RTP path, H.264/H.265 parse, Rockchip MPP decode, ISOMP4 mux for recording, eLinux video player plugin.

### D5 — Residual risk acceptance

Even on 1.28.5 with H1–H4, **qtdemux / h265parse / rtspsrc** remain enabled and will attract future SAs. Acceptance text: upgraded to ≥ 1.28.5, post-tip patches as applied, unused plugins omitted; residual tracked as “follow next 1.28.x / Security Center.”

### D6 — Rockchip MPP plugin and RGA

`rockchip-mpp` / `rockchip-rga` versions may stay; **gstreamer1-rockchip** MUST build and register against new GStreamer. If incompatible, spike vendor fork update or minimal patches before falling back to 1.26/1.24.

### D7 — Version stamp file

Update `overlay/third-party/gstreamer.version` (or equivalent prebuilt stamp metadata) so `check-prebuilt` / export scripts reflect the new stack identity (not only `rockchip-mpp-gst-rtsp` opaque label — at least document 1.28.5 in change notes / stamp content as implementer chooses).

## Risks / Trade-offs

- **[Risk] 1.28 meson/options diverge from BR 1.22 recipes** → Mitigation: adapt `.mk` from upstream Buildroot newer recipe; fallback D1 to 1.26/1.24.10+.
- **[Risk] gstreamer1-rockchip fails against 1.28** → Mitigation: patch or vendor bump; fallback series; keep MPP smoke in tasks.
- **[Risk] eLinux video player ABI break** → Mitigation: mandatory rebuild of flutter-embedded-linux + Settings preview smoke.
- **[Risk] Hardening removes a plugin still needed for a codec** → Mitigation: H3 spike-gated; recording + H.265 camera mandatory before landing trim.
- **[Risk] False sense of “all CVEs fixed”** → Mitigation: D5 residual documentation in PR.
- **[Trade-off] Keep isomp4 (recording) vs drop to dodge MP4 CVEs** → Prefer keep isomp4 + tip; do not remove recording path.

## Migration Plan

1. Overlay-pin 1.28.5 (+ patches) for gstreamer1 family; adapt rockchip gst.
2. `apply-overlay` → `FORCE=1 make build-gstreamer` → rebuild eLinux GStreamer player → `build-rootfs` → `upgrade`.
3. Apply H1–H4 as decided after plugin inventory on device/prebuilt.
4. Smoke: MediaMTX preview, H.264/H.265, MP4 finalize, MPP element present.
5. Rollback: previous rootfs A/B letter / prior `prebuilt/gstreamer` stamp + image.

## Open Questions

- Exact 1.28.x tip if **1.28.6+** ships before implement (prefer newest 1.28.x ≥ 1.28.5).
- Whether any product path needs Matroska/WebM, AV1, or gst-libav (default **no**).
- Whether `gst1-plugins-ugly` or `gst1-libav` appear transitively today in prebuilt export (inventory; strip if accidental).
- Rockchip `gstreamer1-rockchip` source tag compatibility with 1.28.
