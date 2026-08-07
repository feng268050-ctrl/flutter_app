## ADDED Requirements

### Requirement: GStreamer overlay and prebuilt refresh after Buildroot LTS bump

After owned Buildroot moves to the pinned **2025.02.x** tip, `make apply-overlay` MUST still sync product GStreamer family recipes (and Rockchip `gstreamer1-rockchip` when present). The first ship on the new baseline MUST force a GStreamer prebuilt rebuild and refresh the flutter-embedded-linux GStreamer video-player linkage when staging libraries change; `make build-rootfs` alone MUST NOT reuse pre-bump GStreamer stamps. Version floors from this capability remain unchanged.

#### Scenario: post-BR-bump GStreamer prebuilt refresh

- **WHEN** developers ship the first product rootfs after the Buildroot LTS upgrade and GStreamer staging differs or stamps are stale
- **THEN** they rebuild/export the GStreamer prebuilt stack and refresh eLinux as required by the existing prebuilt rebuild requirement, then pack rootfs
