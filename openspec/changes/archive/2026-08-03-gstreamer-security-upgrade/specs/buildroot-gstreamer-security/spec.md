## ADDED Requirements

### Requirement: Overlay pins GStreamer stack at 1.28.5 or newer

The product SHALL track Buildroot packages **gstreamer1**, **gst1-plugins-base**, **gst1-plugins-good**, **gst1-plugins-bad**, and any other co-versioned gst1 packages compiled for the product image, under `overlay/buildroot/package/gstreamer1/` (or equivalent overlay paths synced by `apply-overlay`), with versions locked to at least **1.28.5**, or a newer **1.28.x** tip chosen at implementation time. Shipped `libgstreamer-1.0.so` / `gst-inspect-1.0 --version` (or equivalent) MUST report that pin and MUST NOT remain **1.22.9**.

#### Scenario: apply-overlay syncs GStreamer recipes

- **WHEN** a developer changes the overlay GStreamer package pins and runs `make apply-overlay`
- **THEN** SDK `buildroot/package/gstreamer1/` recipes reflect the overlay versions (≥ 1.28.5)

#### Scenario: device or prebuilt reports pinned GStreamer

- **WHEN** rootfs or `prebuilt/gstreamer/target` built from the pin is inspected
- **THEN** GStreamer core version is ≥ 1.28.5 and matches the overlay pin

### Requirement: Post-tip security patches are overlay-owned

When the GStreamer Security Center (or vendor) publishes fixes that are not yet included in the locked point release, the product SHALL carry those fixes as overlay package patches (or bump to a newer 1.28.x tip that includes them) rather than leaving the known issue unpatched on the shipped tip. Buildroot/meson and Rockchip `gstreamer1-rockchip` compatibility patches MAY live in the same overlay series.

#### Scenario: SA after tip uses overlay patch or tip bump

- **WHEN** a relevant Security Advisory affects the locked tarball and a fix exists upstream
- **THEN** implementers either raise the pin to a newer 1.28.x that contains the fix or add an overlay patch and rebuild the GStreamer prebuilt stack

### Requirement: Prebuilt and eLinux GStreamer rebuild is mandatory

Changing GStreamer recipes MUST invalidate and rebuild via the product prebuilt path (`make build-gstreamer` / `scripts/br-make-packages.sh` for the gst package set, export to `prebuilt/gstreamer/target`) and MUST rebuild the flutter-embedded-linux client so the GStreamer video player plugin links against the new staging libraries. `make build-rootfs` alone MUST NOT be treated as sufficient when prebuilt stamps would reuse 1.22.9 binaries.

#### Scenario: stamp reuse avoided

- **WHEN** developers rebuild after changing `GSTREAMER1_VERSION` (and matching plugin versions)
- **THEN** they force a GStreamer prebuilt rebuild and refresh the eLinux GStreamer video-player stamp before shipping rootfs

### Requirement: Optional hardening reduces unused GStreamer surface

Where the product does not require a plugin class, the image SHALL omit it at Buildroot Kconfig when feasible: **gst-plugins-ugly** MUST remain disabled; **gst1-libav** and unused bad/good plugins (including WebRTC, DTLS, RFB/VNC, and demuxers not needed for RTSP preview or MP4 remux) MUST remain disabled unless a documented product requirement needs them. Runtime plugin blacklist MAY supplement compile-time trim. Hardening MUST NOT remove RTSP/RTP, H.264/H.265 videoparsers, Rockchip MPP decode integration, ISOMP4 mux for recording, or the eLinux video player plugin required by `buildroot-lws-hmi-image`.

#### Scenario: ugly and unused high-risk plugins stay off

- **WHEN** hardening tiers H1–H2 are applied
- **THEN** gst-plugins-ugly is not enabled and WebRTC/DTLS/RFB (and similarly unused) plugins are not installed in the product GStreamer plugin path unless a documented product requirement needs them

### Requirement: Residual GStreamer CVEs on required plugins are documented

Acceptance MUST document that enabling **isomp4** (qtdemux/qtmux), **videoparsers** (including H.265), and **RTSP/RTP** for product features means future Security Advisories against those elements may still apply after upgrading to ≥ 1.28.5. The change SHALL maximize available tip upgrades, overlay patches, and surface reduction without claiming complete elimination of all GStreamer CVEs.

#### Scenario: PR records residual risk

- **WHEN** the implementing PR is opened
- **THEN** it lists closed/mitigated items (version pin, patches applied, plugins omitted) and residual risk on required preview/recording plugins

### Requirement: Rockchip MPP GStreamer plugin remains functional

The upgraded stack MUST continue to provide Rockchip MPP hardware decode integration (`gstreamer1-rockchip` / equivalent) compatible with GStreamer ≥ 1.28.5 for the product preview path.

#### Scenario: rockchipmpp plugin loads

- **WHEN** the rebuilt prebuilt or device image is inspected with `gst-inspect-1.0`
- **THEN** the Rockchip MPP plugin (or documented successor element set) is present and loadable
