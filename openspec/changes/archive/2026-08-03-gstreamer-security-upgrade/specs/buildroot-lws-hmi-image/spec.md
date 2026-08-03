## ADDED Requirements

### Requirement: Rootfs ships overlay-pinned GStreamer ≥ 1.28.5

The lws_hmi product rootfs SHALL include the GStreamer/MPP live preview and recording runtime built from the overlay-pinned GStreamer stack required by `buildroot-gstreamer-security` (core and co-versioned plugins at least **1.28.5**), not the vendor SDK default of **1.22.9**. Functional presence requirements for RTSP preview, MPP decode, eLinux video player plugin, and MP4 remux remain in force.

#### Scenario: rootfs GStreamer version is pinned

- **WHEN** a product rootfs built after this change is inspected
- **THEN** `gst-inspect-1.0 --version` or `libgstreamer-1.0.so` reports the overlay-pinned version ≥ 1.28.5 (not `1.22.9`)

## MODIFIED Requirements

### Requirement: Product image includes the GStreamer/MPP live IP-camera preview runtime

The lws_hmi product rootfs SHALL include the runtime needed for the Flutter HMI to decode and render the local MediaMTX RTSP preview: overlay-pinned GStreamer core (≥ **1.28.5** per `buildroot-gstreamer-security`), RTSP/RTP transports, required H.264/H.265 parsing, and Rockchip MPP hardware decode integration. The product rootfs SHALL include a flutter-embedded-linux client linked with the Sony eLinux GStreamer video player plugin and install its required shared library. The active product defconfig SHALL include `lws_hmi_gst_rtsp.config` or its generated prebuilt equivalent. This runtime is required by the IP Camera settings preview and MUST NOT remain deferred/commented out after this change.

#### Scenario: Rootfs contains the preview runtime

- **WHEN** the product rootfs for this change is built and deployed
- **THEN** the required GStreamer shared libraries and RTSP/RTP plugins SHALL be present
- **AND** Rockchip MPP decode integration SHALL be available
- **AND** the eLinux video player plugin SHALL be registered for the App
- **AND** GStreamer core version SHALL be ≥ 1.28.5

#### Scenario: Product image contains its video texture plugin

- **WHEN** `build-rootfs` is built and deployed
- **THEN** `flutter-wayland-client` SHALL be linked against the eLinux video player plugin
- **AND** `libvideo_player_plugin.so` and the shared GStreamer/MPP runtime SHALL be installed
- **AND** the App SHALL not replace the eLinux platform implementation with a DRM-only video player

#### Scenario: Local relay stream produces a Flutter video texture

- **WHEN** MediaMTX is running and `rtsp://127.0.0.1:8554/camera/pr1` is readable
- **AND** the App initializes its preview controller
- **THEN** the plugin SHALL create a video texture and deliver moving frames to the Flutter widget

#### Scenario: Host build remains usable without the device plugin

- **WHEN** the App runs on a host/emulator without the device GStreamer plugin
- **THEN** the preview wrapper SHALL fail softly or use a host stub
- **AND** Settings navigation MUST remain usable
