## ADDED Requirements

### Requirement: Product image includes the GStreamer/MPP live IP-camera preview runtime

The lws_hmi product rootfs SHALL include the runtime needed for the Flutter HMI to decode and render the local MediaMTX RTSP preview: GStreamer core, RTSP/RTP transports, required H.264/H.265 parsing, and Rockchip MPP hardware decode integration. The default Weston rootfs SHALL include a flutter-embedded-linux client linked with the Sony eLinux GStreamer video player plugin and install its required shared library; the alternate flutter-pi rootfs SHALL include the flutter-pi GStreamer video player plugin. The active product defconfig SHALL include `lws_hmi_gst_rtsp.config` or its generated prebuilt equivalent. This runtime is required by the IP Camera settings preview and MUST NOT remain deferred/commented out after this change.

#### Scenario: Rootfs contains the preview runtime

- **WHEN** the product rootfs for this change is built and deployed
- **THEN** the required GStreamer shared libraries and RTSP/RTP plugins SHALL be present
- **AND** Rockchip MPP decode integration SHALL be available
- **AND** the active display-stack video player plugin SHALL be registered for the App

#### Scenario: Default Weston image contains its video texture plugin

- **WHEN** `build-rootfs` is built and deployed
- **THEN** `flutter-wayland-client` SHALL be linked against the eLinux video player plugin
- **AND** `libvideo_player_plugin.so` and the shared GStreamer/MPP runtime SHALL be installed
- **AND** the App SHALL not replace the eLinux platform implementation with `FlutterpiVideoPlayer`

#### Scenario: Alternate flutter-pi image contains its video texture plugin

- **WHEN** `build-rootfs-flutter-pi` is built and deployed
- **THEN** flutter-pi SHALL register the GStreamer video player plugin used by the App
- **AND** the shared GStreamer/MPP runtime SHALL be installed

#### Scenario: Local relay stream produces a Flutter video texture

- **WHEN** MediaMTX is running and `rtsp://127.0.0.1:8554/camera/pr1` is readable
- **AND** the App initializes its preview controller
- **THEN** the plugin SHALL create a video texture and deliver moving frames to the Flutter widget

#### Scenario: Host build remains usable without the device plugin

- **WHEN** the App runs on a host/emulator without the device GStreamer plugin
- **THEN** the preview wrapper SHALL fail softly or use a host stub
- **AND** Settings navigation MUST remain usable

### Requirement: Product image includes encoded RTSP recording runtime

The product GStreamer runtime SHALL include TCP RTSP/RTP depayloading, H.264 and
H.265 parsers, and ISO MP4/QuickTime mux support required by the HAL recorder.
Recording SHALL remux encoded video without requiring a second decode path.

#### Scenario: RTSP recording can finalize MP4

- **WHEN** HAL records a supported PR0 stream to an `.mp4` destination
- **THEN** `rtspsrc`, the matching RTP depay/parser elements, `qtmux`/equivalent,
  and `filesink` SHALL be available
- **AND** stopping through EOS SHALL produce a finalized non-empty MP4
